# app/services/taz/rss_importer.rb

module Taz
  class RssImporter
    include HTTParty

    # RSS Feed URLs
    HOMEPAGE_RSS_URL = 'https://taz.de/!p4608;twitterbotrss/'
    SOCIAL_BOT_RSS_URL = 'http://taz.de/socialbotrss/social-feed'

    class FeedError < StandardError; end

    def initialize
      @stats = {
        homepage: { new: 0, skipped: 0, errors: 0 },
        social_bot: { new: 0, skipped: 0, errors: 0 }
      }
    end

    # Import from all RSS feeds
    def import_all
      Rails.logger.info "Starting RSS import from all feeds..."

      import_homepage_feed
      import_social_bot_feed

      Rails.logger.info "RSS import completed: #{total_stats}"

      @stats
    end

    # Import from homepage/Twitter bot RSS feed
    def import_homepage_feed
      Rails.logger.info "Importing from homepage RSS: #{HOMEPAGE_RSS_URL}"

      begin
        feed = Feedjira.parse(fetch_feed(HOMEPAGE_RSS_URL))

        if feed.nil?
          Rails.logger.error "Failed to parse homepage RSS feed"
          return @stats[:homepage]
        end

        feed.entries.each do |entry|
          process_entry(entry, :homepage)
        end
      rescue StandardError => e
        Rails.logger.error "Homepage RSS import failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end

      @stats[:homepage]
    end

    # Import from social bot RSS feed
    def import_social_bot_feed
      Rails.logger.info "Importing from social bot RSS: #{SOCIAL_BOT_RSS_URL}"

      begin
        feed = Feedjira.parse(fetch_feed(SOCIAL_BOT_RSS_URL))

        if feed.nil?
          Rails.logger.error "Failed to parse social bot RSS feed"
          return @stats[:social_bot]
        end

        feed.entries.each do |entry|
          process_entry(entry, :social_bot)
        end
      rescue StandardError => e
        Rails.logger.error "Social bot RSS import failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end

      @stats[:social_bot]
    end

    private

    # Fetch RSS feed content
    def fetch_feed(url)
      response = HTTParty.get(url, timeout: 30)

      raise FeedError, "HTTP #{response.code} error fetching #{url}" unless response.success?

      response.body
    rescue HTTParty::Error => e
      Rails.logger.error "HTTP error fetching feed #{url}: #{e.message}"
      raise FeedError, e.message
    end

    # Process a single RSS entry
    def process_entry(entry, source)
      # Extract msid from URL
      msid = extract_msid(entry.url)

      unless msid
        Rails.logger.warn "Could not extract msid from URL: #{entry.url}"
        @stats[source][:errors] += 1
        return
      end

      # Check if article already exists
      if Article.exists?(msid: msid)
        Rails.logger.debug "Article #{msid} already exists, skipping"
        @stats[source][:skipped] += 1
        return
      end

      # Create new article
      article_data = extract_article_data(entry, msid)

      article = Article.new(article_data)

      if article.save
        Rails.logger.info "Created article #{msid}: #{article.truncated_title(50)}"
        @stats[source][:new] += 1
      else
        Rails.logger.error "Failed to save article #{msid}: #{article.errors.full_messages.join(', ')}"
        @stats[source][:errors] += 1
      end
    rescue StandardError => e
      Rails.logger.error "Error processing entry #{entry.url}: #{e.message}"
      @stats[source][:errors] += 1
    end

    # Extract article data from RSS entry
    def extract_article_data(entry, msid)
      {
        msid: msid,
        title: entry.title&.strip,
        lead: extract_lead(entry),
        published_at: entry.published || Time.current
      }
    end

    # Extract lead/description from entry
    def extract_lead(entry)
      # Try different possible field names
      lead = entry.summary || entry.description || entry.content

      # Clean HTML if present
      if lead.present?
        # Remove HTML tags
        lead = ActionView::Base.full_sanitizer.sanitize(lead)
        lead.strip
      else
        nil
      end
    end

    # Extract msid from various taz.de URL formats
    def extract_msid(url)
      Article.extract_msid_from_url(url)
    end

    # Generate summary stats
    def total_stats
      total_new = @stats.values.sum { |s| s[:new] }
      total_skipped = @stats.values.sum { |s| s[:skipped] }
      total_errors = @stats.values.sum { |s| s[:errors] }

      "#{total_new} new, #{total_skipped} skipped, #{total_errors} errors"
    end
  end
end
