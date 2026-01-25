# app/controllers/posts_controller.rb

class PostsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Auto-sync if it's been more than 1 hour since last sync
    auto_sync_if_needed

    @posts = Post
             .joins(:social_account)
             .includes(:social_account, :post_metrics)
             .where("posts.platform_url ILIKE '%' || social_accounts.handle || '%'")

    # Search
    @posts = @posts.where("content ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    # Filter by post type
    @posts = @posts.where(post_type: params[:post_type]) if params[:post_type].present? && params[:post_type] != 'all'

    # Filter by date range
    @posts = @posts.where("posted_at >= ?", params[:date_from]) if params[:date_from].present?

    @posts = @posts.where("posted_at <= ?", params[:date_to].to_date.end_of_day) if params[:date_to].present?

    # Filter by minimum interactions
    if params[:min_interactions].present? && params[:min_interactions].to_i > 0
      min = params[:min_interactions].to_i
      # Get posts with latest metrics above threshold
      post_ids = PostMetric
                 .select('DISTINCT ON (post_id) post_id')
                 .where('recorded_at IN (SELECT MAX(recorded_at) FROM post_metrics GROUP BY post_id)')
                 .where('total_interactions >= ?', min)
                 .pluck(:post_id)

      @posts = @posts.where(id: post_ids)
    end

    # Filter by minimum performance (overperformance score)
    if params[:min_performance].present? && params[:min_performance].to_i > 0
      min_perf = params[:min_performance].to_i
      @posts = @posts.where('overperformance_score_cache >= ?', min_perf)
    end

    # IMPORTANT: Calculate scores for all posts in the current result set BEFORE sorting
    # This ensures accurate sorting by overperformance
    ensure_scores_for_sorting if params[:sort] == 'overperformance'

    # Sorting
    sort_column = params[:sort] || 'posted_at'
    sort_direction = params[:direction] || 'desc'

    case sort_column
    when 'posted_at'
      @posts = @posts.order("posted_at #{sort_direction}")
    when 'likes', 'replies', 'reposts', 'total_interactions'
      # Join with latest metrics for sorting
      @posts = @posts
               .joins("LEFT JOIN LATERAL (
          SELECT * FROM post_metrics
          WHERE post_metrics.post_id = posts.id
          ORDER BY recorded_at DESC
          LIMIT 1
        ) latest_metrics ON true")
               .order("latest_metrics.#{sort_column} #{sort_direction} NULLS LAST")
    when 'overperformance'
      # Sort by cached overperformance score
      @posts = @posts.order("overperformance_score_cache #{sort_direction} NULLS LAST")
    else
      @posts = @posts.order("posted_at #{sort_direction}")
    end

    # Apply pagination
    @posts = @posts.page(params[:page]).per(25)

    # Calculate scores for posts on this page that need them
    calculate_scores_for_visible_posts

    # Get last sync time for all Bluesky accounts
    @last_sync = SocialAccount.bluesky.active.maximum(:last_synced_at)
  end

  def sync
    @accounts = SocialAccount.bluesky.active

    if @accounts.empty?
      redirect_to posts_path, alert: "No active Bluesky accounts to sync."
      return
    end

    total_new_posts = 0
    total_updated_metrics = 0
    errors = []

    @accounts.each do |account|
      service = SocialPlatform::Bluesky.new(account)
      result = service.fast_sync

      if result[:success]
        total_new_posts += result[:new_posts]
        total_updated_metrics += result[:updated_metrics]
        account.update!(last_synced_at: result[:synced_at])

        # Spawn background thread for slow backfill
        spawn_background_backfill(account)
      else
        errors << "#{account.display_name}: #{result[:error]}"
      end
    end

    if errors.empty?
      redirect_to posts_path,
                  notice: "Sync completed! #{total_new_posts} new posts, #{total_updated_metrics} posts updated. Background processing continues..."
    else
      redirect_to posts_path, alert: "Sync completed with errors: #{errors.join('; ')}"
    end
  end

  private

  def auto_sync_if_needed
    accounts = SocialAccount.bluesky.active
    return if accounts.empty?

    # Check if any account needs sync
    accounts_needing_sync = accounts.select(&:needs_sync?)
    return if accounts_needing_sync.empty?

    # Perform fast sync for accounts that need it
    accounts_needing_sync.each do |account|
      service = SocialPlatform::Bluesky.new(account)
      result = service.fast_sync

      if result[:success]
        account.update!(last_synced_at: result[:synced_at])
        # Spawn background thread for slow backfill
        spawn_background_backfill(account)
      end
    rescue StandardError => e
      Rails.logger.error "Auto-sync failed for #{account.handle}: #{e.message}"
    end
  end

  def ensure_scores_for_sorting
    # When sorting by overperformance, we need to ensure all posts have scores
    # Get a sample of posts to check (limit to avoid loading everything)
    sample_posts = @posts.limit(100).to_a
    posts_without_scores = sample_posts.select { |p| p.overperformance_score_cache.nil? }

    return if posts_without_scores.empty?

    # Calculate fast scores for posts without scores
    posts_without_scores.group_by(&:social_account).each do |account, posts|
      # Ensure baseline exists
      account.calculate_and_cache_baseline! if account.baseline_interactions_average.nil?

      # Calculate fast scores
      posts.each do |post|
        post.calculate_fast_overperformance_score if account.baseline_interactions_average.present?
      end
    end
  end

  def calculate_scores_for_visible_posts
    # Find posts on current page that don't have a score yet
    posts_needing_scores = @posts.select { |p| p.overperformance_score_cache.nil? }
    return if posts_needing_scores.empty?

    # Group by account to use cached baseline
    posts_needing_scores.group_by(&:social_account).each do |account, posts|
      # Ensure baseline exists
      account.calculate_and_cache_baseline! if account.baseline_interactions_average.nil?

      # Calculate fast scores for these posts
      posts.each do |post|
        post.calculate_fast_overperformance_score if account.baseline_interactions_average.present?
      end
    end
  end

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
end
