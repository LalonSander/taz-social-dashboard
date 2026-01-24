# app/controllers/posts_controller.rb

class PostsController < ApplicationController
  before_action :authenticate_user!

  def index
    @posts = Post.includes(:social_account, :post_metrics)

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

    # Sorting
    sort_column = params[:sort] || 'posted_at'
    sort_direction = params[:direction] || 'desc'

    # Only apply database sorting if NOT filtering by performance
    # (performance filter requires in-memory filtering, so sort happens later)
    unless @filtered_by_performance
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
        # This is complex, we'll calculate it in memory after fetching
        # For now, just sort by total interactions as a proxy
        @posts = @posts
                 .joins("LEFT JOIN LATERAL (
            SELECT * FROM post_metrics
            WHERE post_metrics.post_id = posts.id
            ORDER BY recorded_at DESC
            LIMIT 1
          ) latest_metrics ON true")
                 .order("latest_metrics.total_interactions #{sort_direction} NULLS LAST")
      else
        @posts = @posts.order("posted_at #{sort_direction}")
      end
    end

    # Apply pagination
    if @filtered_by_performance
      # Performance filter requires in-memory filtering, so paginate manually
      # Also apply sorting here since we skipped it above
      case sort_column
      when 'posted_at'
        @posts_with_performance.sort_by! { |p| p.posted_at }
        @posts_with_performance.reverse! if sort_direction == 'desc'
      when 'likes'
        @posts_with_performance.sort_by! { |p| p.latest_metrics&.likes || 0 }
        @posts_with_performance.reverse! if sort_direction == 'desc'
      when 'replies'
        @posts_with_performance.sort_by! { |p| p.latest_metrics&.replies || 0 }
        @posts_with_performance.reverse! if sort_direction == 'desc'
      when 'reposts'
        @posts_with_performance.sort_by! { |p| p.latest_metrics&.reposts || 0 }
        @posts_with_performance.reverse! if sort_direction == 'desc'
      when 'total_interactions'
        @posts_with_performance.sort_by! { |p| p.latest_total_interactions }
        @posts_with_performance.reverse! if sort_direction == 'desc'
      when 'overperformance'
        @posts_with_performance.sort_by! { |p| p.overperformance_score }
        @posts_with_performance.reverse! if sort_direction == 'desc'
      end

      total_count = @posts_with_performance.size
      page = (params[:page] || 1).to_i
      per_page = 25
      offset = (page - 1) * per_page

      @posts = Kaminari.paginate_array(@posts_with_performance, total_count: total_count)
                       .page(page)
                       .per(per_page)
    else
      @posts = @posts.page(params[:page]).per(25)
    end

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
      result = service.sync

      if result[:success]
        total_new_posts += result[:new_posts]
        total_updated_metrics += result[:updated_metrics]
        account.update!(last_synced_at: result[:synced_at])
      else
        errors << "#{account.display_name}: #{result[:error]}"
      end
    end

    if errors.empty?
      redirect_to posts_path,
                  notice: "Sync completed! #{total_new_posts} new posts, #{total_updated_metrics} metrics updated."
    else
      redirect_to posts_path, alert: "Sync completed with errors: #{errors.join('; ')}"
    end
  end
end
