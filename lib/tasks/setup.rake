# lib/tasks/setup.rake

namespace :setup do
  desc "Initial setup: Create social account and download all historical posts"
  task initial: :environment do
    puts "🚀 Starting initial setup for Social Media Analytics Suite..."
    puts ""

    # Check for required environment variables
    unless ENV['BLUESKY_APP_PASSWORD']
      puts "❌ ERROR: BLUESKY_APP_PASSWORD environment variable not set"
      puts "Please set it in your .env file or environment"
      exit 1
    end

    # Get handle from user or use default
    handle = ENV['BLUESKY_HANDLE'] || 'taz.de'
    puts "📱 Setting up Bluesky account: #{handle}"

    # Create or find social account
    account = SocialAccount.find_or_create_by!(
      platform: 'bluesky',
      handle: handle
    ) do |a|
      a.active = true
      puts "✅ Created new social account: @#{handle}"
    end

    puts "✅ Social account already exists: @#{handle}" if account.persisted? && !account.new_record?

    # Check if posts already exist
    existing_posts = account.posts.count

    if existing_posts > 0
      puts "⚠️  Warning: #{existing_posts} posts already exist for this account"
      print "Do you want to continue and fetch more posts? (y/n): "
      response = STDIN.gets.chomp.downcase
      unless ['y', 'yes'].include?(response)
        puts "❌ Setup cancelled"
        exit 0
      end
    end

    puts ""
    puts "📥 Starting to download all posts from Bluesky..."
    puts "This may take several minutes depending on post count..."
    puts ""

    # Perform initial sync with backfill
    begin
      service = SocialPlatform::Bluesky.new(account)

      # Track progress
      total_posts = 0
      total_metrics = 0
      page = 1

      # Fetch all posts with pagination
      puts "📄 Fetching posts (this will paginate through all history)..."

      # Call the backfill method
      result = backfill_all_posts(account, service)

      total_posts = result[:posts_count]
      total_metrics = result[:metrics_count]

      puts ""
      puts "✅ Initial sync completed!"
      puts "   Posts downloaded: #{total_posts}"
      puts "   Metrics recorded: #{total_metrics}"
      puts ""

      # Update last synced timestamp
      account.update!(last_synced_at: Time.current)

      puts "🎉 Setup complete! Your dashboard is ready."
      puts ""
      puts "Next steps:"
      puts "  1. Start your Rails server: rails server"
      puts "  2. Visit http://localhost:3000"
      puts "  3. Use 'Sync Now' button to update metrics periodically"
      puts ""
    rescue SocialPlatform::Bluesky::AuthenticationError => e
      puts "❌ Authentication failed: #{e.message}"
      puts "Please check your BLUESKY_APP_PASSWORD in .env file"
      exit 1
    rescue StandardError => e
      puts "❌ Error during setup: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc "Backfill historical posts for an existing account"
  task backfill: :environment do
    handle = ENV['BLUESKY_HANDLE'] || 'taz.de'

    account = SocialAccount.find_by(platform: 'bluesky', handle: handle)

    unless account
      puts "❌ Account not found: #{handle}"
      puts "Run 'rails setup:initial' first"
      exit 1
    end

    puts "📥 Backfilling posts for @#{handle}..."
    puts ""

    service = SocialPlatform::Bluesky.new(account)
    result = backfill_all_posts(account, service)

    puts ""
    puts "✅ Backfill completed!"
    puts "   Total posts: #{account.posts.count}"
    puts "   New posts added: #{result[:posts_count]}"
    puts ""
  end

  private

  def backfill_all_posts(account, service)
    total_posts = 0
    total_metrics = 0
    cursor = nil
    page = 1
    max_pages = 100 # Safety limit (100 pages * 100 posts = 10,000 posts max)

    loop do
      print "\rFetching page #{page}..."

      # Fetch posts with cursor for pagination
      response = service.send(:fetch_posts_from_api, cursor: cursor, limit: 100)
      data = JSON.parse(response.body)

      posts = data['feed'] || []
      break if posts.empty?

      # Process each post
      posts.each do |feed_item|
        post_data = service.send(:extract_post_data, feed_item)
        next unless post_data

        next unless service.send(:save_post, post_data)

        total_posts += 1
        total_metrics += 1

        # Show progress every 10 posts
        print "\rDownloaded #{total_posts} posts..." if total_posts % 10 == 0
      end

      # Get cursor for next page
      cursor = data['cursor']
      break if cursor.nil?

      page += 1

      # Safety limit
      if page > max_pages
        puts "\n⚠️  Reached safety limit of #{max_pages} pages"
        break
      end

      # Small delay to avoid rate limiting
      sleep(0.5)
    end

    print "\rDownloaded #{total_posts} posts... Done!   \n"

    { posts_count: total_posts, metrics_count: total_metrics }
  end
end
