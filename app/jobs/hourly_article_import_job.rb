# app/jobs/hourly_article_import_job.rb

class HourlyArticleImportJob < ApplicationJob
  queue_as :default

  # Retry on network errors with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info "=" * 80
    Rails.logger.info "Starting Hourly Article Import Job at #{Time.current}"
    Rails.logger.info "=" * 80

    results = {
      bluesky_sync: nil,
      rss_import: nil,
      xml_refresh: nil,
      post_linking: nil,
      success: false,
      errors: []
    }

    # Step 1: Sync Bluesky posts and update metrics
    results[:bluesky_sync] = sync_bluesky_posts

    # Step 2: Import articles from RSS feeds
    results[:rss_import] = import_from_rss

    # Step 3: Refresh articles from XML to get CMS IDs
    results[:xml_refresh] = refresh_articles_from_xml

    # Step 4: Link posts to articles
    results[:post_linking] = link_posts_to_articles

    # Mark as successful if all steps completed
    results[:success] = results[:errors].empty?

    log_final_summary(results)

    results
  rescue StandardError => e
    Rails.logger.error "Hourly Article Import Job failed with exception: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  # Step 1: Sync Bluesky posts and update metrics
  def sync_bluesky_posts
    Rails.logger.info "\n" + ("-" * 80)
    Rails.logger.info "STEP 1: Syncing Bluesky posts and metrics"
    Rails.logger.info "-" * 80

    start_time = Time.current

    begin
      accounts = SocialAccount.bluesky.active

      if accounts.empty?
        Rails.logger.info "No active Bluesky accounts to sync"
        return {
          success: true,
          duration: Time.current - start_time,
          accounts_synced: 0,
          total_new_posts: 0,
          total_updated_metrics: 0
        }
      end

      total_new_posts = 0
      total_updated_metrics = 0
      accounts_synced = 0
      errors = []

      accounts.each do |account|
        service = SocialPlatform::Bluesky.new(account)
        result = service.fast_sync

        if result[:success]
          total_new_posts += result[:new_posts]
          total_updated_metrics += result[:updated_metrics]
          accounts_synced += 1
          account.update!(last_synced_at: result[:synced_at])

          Rails.logger.info "Synced #{account.display_name}: #{result[:new_posts]} new posts, #{result[:updated_metrics]} updated"

          # Spawn background thread for slow backfill
          spawn_background_backfill(account)
        else
          error_msg = "#{account.display_name}: #{result[:error]}"
          errors << error_msg
          Rails.logger.error "Sync failed for #{error_msg}"
        end
      rescue StandardError => e
        error_msg = "#{account.display_name}: #{e.message}"
        errors << error_msg
        Rails.logger.error "Error syncing #{error_msg}"
      end

      duration = Time.current - start_time

      Rails.logger.info "Bluesky sync completed in #{duration.round(2)}s"
      Rails.logger.info "  Accounts synced: #{accounts_synced}/#{accounts.count}"
      Rails.logger.info "  New posts: #{total_new_posts}"
      Rails.logger.info "  Updated metrics: #{total_updated_metrics}"
      Rails.logger.info "  Errors: #{errors.size}"

      {
        success: errors.empty?,
        duration: duration,
        accounts_synced: accounts_synced,
        total_accounts: accounts.count,
        total_new_posts: total_new_posts,
        total_updated_metrics: total_updated_metrics,
        errors: errors
      }
    rescue StandardError => e
      error_message = "Bluesky sync failed: #{e.message}"
      Rails.logger.error error_message
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        error: error_message,
        duration: Time.current - start_time
      }
    end
  end

  # Step 2: Import articles from RSS feeds
  def import_from_rss
    Rails.logger.info "\n" + ("-" * 80)
    Rails.logger.info "STEP 2: Importing articles from RSS feeds"
    Rails.logger.info "-" * 80

    start_time = Time.current

    begin
      importer = Taz::RssImporter.new
      stats = importer.import_all

      duration = Time.current - start_time

      Rails.logger.info "RSS import completed in #{duration.round(2)}s"
      Rails.logger.info "  Homepage feed: #{stats[:homepage][:new]} new, #{stats[:homepage][:skipped]} skipped, #{stats[:homepage][:errors]} errors"
      Rails.logger.info "  Social bot feed: #{stats[:social_bot][:new]} new, #{stats[:social_bot][:skipped]} skipped, #{stats[:social_bot][:errors]} errors"

      {
        success: true,
        duration: duration,
        stats: stats,
        total_new: stats[:homepage][:new] + stats[:social_bot][:new],
        total_errors: stats[:homepage][:errors] + stats[:social_bot][:errors]
      }
    rescue StandardError => e
      error_message = "RSS import failed: #{e.message}"
      Rails.logger.error error_message
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        error: error_message,
        duration: Time.current - start_time
      }
    end
  end

  # Step 3: Refresh articles from XML to get CMS IDs and other metadata
  def refresh_articles_from_xml
    Rails.logger.info "\n" + ("-" * 80)
    Rails.logger.info "STEP 3: Refreshing articles from XML"
    Rails.logger.info "-" * 80

    start_time = Time.current

    begin
      # Find articles that need XML refresh
      # Priority: articles without CMS ID, then articles older than 1 day
      articles_without_cms = Article.where(cms_id: nil).order(published_at: :desc).limit(50)
      articles_needing_refresh = Article.where('last_refreshed_at IS NULL OR last_refreshed_at < ?', 1.day.ago)
                                        .where.not(id: articles_without_cms.pluck(:id))
                                        .order(published_at: :desc)
                                        .limit(20)

      articles_to_refresh = (articles_without_cms.to_a + articles_needing_refresh.to_a).uniq

      Rails.logger.info "Found #{articles_to_refresh.size} articles to refresh"
      Rails.logger.info "  - #{articles_without_cms.size} without CMS ID"
      Rails.logger.info "  - #{articles_needing_refresh.size} needing general refresh"

      return { success: true, refreshed: 0, skipped: articles_to_refresh.size, errors: 0 } if articles_to_refresh.empty?

      refreshed_count = 0
      error_count = 0

      articles_to_refresh.each_with_index do |article, index|
        if article.refresh_from_xml!
          refreshed_count += 1
          Rails.logger.debug "Refreshed article #{article.msid} (#{index + 1}/#{articles_to_refresh.size})"
        else
          error_count += 1
          Rails.logger.warn "Failed to refresh article #{article.msid}"
        end

        # Small delay to avoid hammering the XML endpoint
        sleep(0.2) if (index + 1) % 10 == 0
      rescue StandardError => e
        error_count += 1
        Rails.logger.error "Error refreshing article #{article.msid}: #{e.message}"
      end

      duration = Time.current - start_time

      Rails.logger.info "XML refresh completed in #{duration.round(2)}s"
      Rails.logger.info "  Refreshed: #{refreshed_count}"
      Rails.logger.info "  Errors: #{error_count}"

      {
        success: true,
        duration: duration,
        refreshed: refreshed_count,
        errors: error_count,
        total_processed: articles_to_refresh.size
      }
    rescue StandardError => e
      error_message = "XML refresh failed: #{e.message}"
      Rails.logger.error error_message
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        error: error_message,
        duration: Time.current - start_time
      }
    end
  end

  # Step 4: Link posts to articles
  def link_posts_to_articles
    Rails.logger.info "\n" + ("-" * 80)
    Rails.logger.info "STEP 4: Linking posts to articles"
    Rails.logger.info "-" * 80

    start_time = Time.current

    begin
      linker_stats = PostArticleLinker.link_all_unlinked_posts

      duration = Time.current - start_time

      Rails.logger.info "Post-article linking completed in #{duration.round(2)}s"
      Rails.logger.info "  Linked: #{linker_stats[:linked]}"
      Rails.logger.info "  Already linked: #{linker_stats[:already_linked]}"
      Rails.logger.info "  Articles created from XML: #{linker_stats[:article_created]}"
      Rails.logger.info "  Not taz.de links: #{linker_stats[:not_taz_link]}"
      Rails.logger.info "  No msid found: #{linker_stats[:no_msid]}"
      Rails.logger.info "  Article not found: #{linker_stats[:article_not_found]}"
      Rails.logger.info "  Errors: #{linker_stats[:errors]}"

      {
        success: true,
        duration: duration,
        stats: linker_stats
      }
    rescue StandardError => e
      error_message = "Post-article linking failed: #{e.message}"
      Rails.logger.error error_message
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        error: error_message,
        duration: Time.current - start_time
      }
    end
  end

  # Spawn background thread for slow backfill
  def spawn_background_backfill(account)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        service = SocialPlatform::Bluesky.new(account)
        service.slow_backfill
      rescue StandardError => e
        Rails.logger.error "Background backfill failed for #{account.handle}: #{e.message}"
      end
    end
  end

  # Log final summary of the entire job
  def log_final_summary(results)
    Rails.logger.info "\n" + ("=" * 80)
    Rails.logger.info "HOURLY ARTICLE IMPORT JOB SUMMARY"
    Rails.logger.info "=" * 80

    total_duration = [
      results[:bluesky_sync]&.dig(:duration) || 0,
      results[:rss_import]&.dig(:duration) || 0,
      results[:xml_refresh]&.dig(:duration) || 0,
      results[:post_linking]&.dig(:duration) || 0
    ].sum

    Rails.logger.info "Total Duration: #{total_duration.round(2)}s"
    Rails.logger.info "Overall Success: #{results[:success] ? 'YES' : 'NO'}"

    if results[:bluesky_sync]
      Rails.logger.info "\nBluesky Sync:"
      if results[:bluesky_sync][:success]
        Rails.logger.info "  ✓ #{results[:bluesky_sync][:accounts_synced]} accounts synced"
        Rails.logger.info "  ✓ #{results[:bluesky_sync][:total_new_posts]} new posts"
        Rails.logger.info "  ✓ #{results[:bluesky_sync][:total_updated_metrics]} metrics updated"
      else
        Rails.logger.info "  ✗ Failed: #{results[:bluesky_sync][:error]}"
      end
    end

    if results[:rss_import]
      Rails.logger.info "\nRSS Import:"
      if results[:rss_import][:success]
        Rails.logger.info "  ✓ #{results[:rss_import][:total_new]} new articles imported"
      else
        Rails.logger.info "  ✗ Failed: #{results[:rss_import][:error]}"
      end
    end

    if results[:xml_refresh]
      Rails.logger.info "\nXML Refresh:"
      if results[:xml_refresh][:success]
        Rails.logger.info "  ✓ #{results[:xml_refresh][:refreshed]} articles refreshed"
      else
        Rails.logger.info "  ✗ Failed: #{results[:xml_refresh][:error]}"
      end
    end

    if results[:post_linking]
      Rails.logger.info "\nPost Linking:"
      if results[:post_linking][:success]
        Rails.logger.info "  ✓ #{results[:post_linking][:stats][:linked]} posts linked"
        Rails.logger.info "  ✓ #{results[:post_linking][:stats][:article_created]} articles created from XML"
      else
        Rails.logger.info "  ✗ Failed: #{results[:post_linking][:error]}"
      end
    end

    Rails.logger.info "\nCompleted at #{Time.current}"
    Rails.logger.info "=" * 80
  end
end
