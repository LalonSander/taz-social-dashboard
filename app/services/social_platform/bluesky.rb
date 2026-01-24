# app/services/social_platform/bluesky.rb

module SocialPlatform
  class Bluesky
    include HTTParty

    base_uri 'https://bsky.social'

    class AuthenticationError < StandardError; end
    class RateLimitError < StandardError; end
    class ApiError < StandardError; end

    def initialize(social_account)
      @account = social_account
      @access_token = @account.access_token
    end

    # Main sync method: fetch new posts and update metrics
    def sync
      authenticate unless @access_token

      new_posts_count = fetch_and_save_posts
      result = update_recent_metrics

      {
        success: true,
        new_posts: new_posts_count,
        updated_metrics: result[:updated],
        skipped_metrics: result[:skipped],
        synced_at: Time.current
      }
    rescue AuthenticationError => e
      Rails.logger.error "Bluesky authentication failed for #{@account.handle}: #{e.message}"

      # Try to refresh token once
      if @access_token && !@authentication_retry
        @authentication_retry = true
        @access_token = nil
        authenticate
        retry
      end

      { success: false, error: "Authentication failed. Please check credentials." }
    rescue RateLimitError => e
      Rails.logger.error "Bluesky rate limit hit for #{@account.handle}: #{e.message}"
      { success: false, error: "Rate limit exceeded. Please try again later." }
    rescue ApiError => e
      Rails.logger.error "Bluesky API error for #{@account.handle}: #{e.message}"

      # If token expired, try to refresh once
      if e.message.include?('expired') && !@authentication_retry
        @authentication_retry = true
        @access_token = nil
        authenticate
        retry
      end

      { success: false, error: "API error: #{e.message}" }
    rescue StandardError => e
      Rails.logger.error "Unexpected error syncing #{@account.handle}: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, error: "An unexpected error occurred." }
    end

    private

    # Authenticate and get access token
    def authenticate
      response = self.class.post(
        '/xrpc/com.atproto.server.createSession',
        body: {
          identifier: @account.handle,
          password: ENV.fetch('BLUESKY_APP_PASSWORD', nil)
        }.to_json,
        headers: { 'Content-Type' => 'application/json' },
        timeout: 30
      )

      handle_response(response)

      data = JSON.parse(response.body)
      @access_token = data['accessJwt']

      # Save token to account for future use
      @account.update!(access_token: @access_token)

      @access_token
    rescue JSON::ParserError => e
      raise AuthenticationError, "Invalid response from Bluesky API"
    end

    # Fetch posts from Bluesky and save to database
    def fetch_and_save_posts
      posts_count = 0
      cursor = nil

      # Fetch up to 100 posts (Bluesky's max per request)
      loop do
        response = fetch_posts_from_api(cursor: cursor, limit: 100)
        data = JSON.parse(response.body)

        posts = data['feed'] || []

        break if posts.empty?

        posts.each do |feed_item|
          post_data = extract_post_data(feed_item)
          next unless post_data

          posts_count += 1 if save_post(post_data)
        end

        # Check if there are more posts
        cursor = data['cursor']
        break if cursor.nil? || posts_count >= 100 # Limit initial sync
      end

      posts_count
    end

    # Fetch posts from Bluesky API
    def fetch_posts_from_api(cursor: nil, limit: 100)
      params = {
        actor: @account.handle,
        limit: limit
      }
      params[:cursor] = cursor if cursor

      response = self.class.get(
        '/xrpc/app.bsky.feed.getAuthorFeed',
        query: params,
        headers: { 'Authorization' => "Bearer #{@access_token}" },
        timeout: 30
      )

      handle_response(response)
      response
    end

    # Extract post data from API response
    def extract_post_data(feed_item)
      post = feed_item['post']
      return nil unless post

      record = post['record']
      return nil unless record

      # Determine post type
      post_type = determine_post_type(record)

      # Extract external URL if present
      external_url = extract_external_url(record)

      # Build Bluesky post URL
      author_handle = post.dig('author', 'handle')
      post_id = extract_post_id(post['uri'])
      platform_url = "https://bsky.app/profile/#{author_handle}/post/#{post_id}"

      {
        platform_post_id: post_id,
        content: record['text'] || '',
        external_url: external_url,
        platform_url: platform_url,
        post_type: post_type,
        posted_at: Time.parse(record['createdAt']),
        platform_data: {
          uri: post['uri'],
          cid: post['cid'],
          author: post['author'],
          embed: record['embed']
        },
        # Initial metrics from the post
        likes: post['likeCount'] || 0,
        replies: post['replyCount'] || 0,
        reposts: post['repostCount'] || 0,
        quotes: post['quoteCount'] || 0
      }
    rescue StandardError => e
      Rails.logger.error "Error extracting post data: #{e.message}"
      nil
    end

    # Save post to database
    def save_post(post_data)
      post = Post.find_or_initialize_by(
        platform: 'bluesky',
        platform_post_id: post_data[:platform_post_id]
      )

      # Skip if post already exists and is older than 30 days
      # (we'll update metrics separately for recent posts)
      return false if post.persisted? && post.posted_at < 30.days.ago

      post.assign_attributes(
        social_account: @account,
        content: post_data[:content],
        external_url: post_data[:external_url],
        platform_url: post_data[:platform_url],
        post_type: post_data[:post_type],
        posted_at: post_data[:posted_at],
        platform_data: post_data[:platform_data]
      )

      if post.save
        # Create or update metrics for the current hour
        current_hour = Time.current.beginning_of_hour

        metric = post.post_metrics.find_or_initialize_by(recorded_at: current_hour)
        metric.assign_attributes(
          likes: post_data[:likes],
          replies: post_data[:replies],
          reposts: post_data[:reposts],
          quotes: post_data[:quotes]
        )
        metric.save!

        true
      else
        Rails.logger.error "Failed to save post #{post_data[:platform_post_id]}: #{post.errors.full_messages.join(', ')}"
        false
      end
    end

    # Update metrics for posts from the last 30 days
    def update_recent_metrics
      recent_posts = @account.posts.where('posted_at > ?', 30.days.ago)
      updated_count = 0

      recent_posts.find_each do |post|
        updated_count += 1 if update_post_metrics(post)

        # Add small delay to avoid rate limiting
        sleep(0.1) if updated_count % 10 == 0
      end

      { updated: updated_count, skipped: 0 }
    end

    # Update metrics for a specific post
    def update_post_metrics(post)
      # Extract post ID from platform_data URI
      uri = post.platform_data['uri']
      return false unless uri

      # Get metrics from a fresh fetch of the post
      response = fetch_post_thread(uri)
      data = JSON.parse(response.body)

      thread_post = data.dig('thread', 'post')
      return false unless thread_post

      # Round to current hour for consistent snapshots
      current_hour = Time.current.beginning_of_hour

      # Find or create metric for this hour
      metric = post.post_metrics.find_or_initialize_by(recorded_at: current_hour)
      metric.assign_attributes(
        likes: thread_post['likeCount'] || 0,
        replies: thread_post['replyCount'] || 0,
        reposts: thread_post['repostCount'] || 0,
        quotes: thread_post['quoteCount'] || 0
      )

      was_new = metric.new_record?
      metric.save!

      # Recalculate and cache overperformance score
      post.calculate_and_cache_overperformance_score! if post.posted_at > 30.days.ago

      true
    end

    # Fetch a specific post thread
    def fetch_post_thread(uri)
      response = self.class.get(
        '/xrpc/app.bsky.feed.getPostThread',
        query: { uri: uri },
        headers: { 'Authorization' => "Bearer #{@access_token}" },
        timeout: 30
      )

      handle_response(response)
      response
    end

    # Determine post type based on content
    def determine_post_type(record)
      if record['embed']
        embed_type = record['embed']['$type']
        case embed_type
        when 'app.bsky.embed.images'
          'image'
        when 'app.bsky.embed.video'
          'video'
        when 'app.bsky.embed.external'
          'link'
        when 'app.bsky.embed.record'
          'text' # Quote post, treat as text
        else
          'text'
        end
      else
        'text'
      end
    end

    # Extract external URL from post
    def extract_external_url(record)
      # Check for external embed
      return record.dig('embed', 'external', 'uri') if record.dig('embed', '$type') == 'app.bsky.embed.external'

      # Check for URLs in facets
      facets = record['facets'] || []
      facets.each do |facet|
        features = facet['features'] || []
        features.each do |feature|
          return feature['uri'] if feature['$type'] == 'app.bsky.richtext.facet#link'
        end
      end

      nil
    end

    # Extract post ID from AT Protocol URI
    def extract_post_id(uri)
      # URI format: at://did:plc:xxx/app.bsky.feed.post/xxxxx
      uri.split('/').last
    end

    # Handle API response errors
    def handle_response(response)
      case response.code
      when 200..299
        # Success
      when 401
        raise AuthenticationError, "Invalid credentials"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      when 400..499
        error_message = begin
          JSON.parse(response.body)['message']
        rescue StandardError
          'Client error'
        end
        raise ApiError, error_message
      when 500..599
        raise ApiError, "Server error (#{response.code})"
      else
        raise ApiError, "Unexpected response code: #{response.code}"
      end
    end
  end
end
