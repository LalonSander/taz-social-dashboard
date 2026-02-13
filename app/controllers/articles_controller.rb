# app/controllers/articles_controller.rb

class ArticlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_article, only: %i[show refresh]

  def index
    @articles = Article.includes(:posts).all

    # Search by title or msid
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @articles = @articles.where("title ILIKE ? OR msid ILIKE ?", search_term, search_term)
    end

    # Filter by date range
    @articles = @articles.published_after(params[:date_from]) if params[:date_from].present?
    @articles = @articles.published_before(params[:date_to].to_date.end_of_day) if params[:date_to].present?

    # Filter by prediction status
    case params[:prediction_status]
    when 'with_predictions'
      @articles = @articles.with_predictions
    when 'without_predictions'
      @articles = @articles.without_predictions
    end

    # Filter by posting status
    case params[:posting_status]
    when 'posted'
      @articles = @articles.joins(:posts).distinct
    when 'not_posted'
      @articles = @articles.left_joins(:posts).where(posts: { id: nil })
    end

    # Sorting
    sort_column = params[:sort] || 'published_at'
    sort_direction = params[:direction] || 'desc'

    case sort_column
    when 'published_at'
      @articles = @articles.order("published_at #{sort_direction}")
    when 'title'
      @articles = @articles.order("title #{sort_direction}")
    when 'posts_count'
      @articles = @articles.left_joins(:posts)
                           .group('articles.id')
                           .order("COUNT(posts.id) #{sort_direction}")
    when 'predicted_performance_score'
      @articles = @articles.order("predicted_performance_score #{sort_direction} NULLS LAST")
    else
      @articles = @articles.order("published_at #{sort_direction}")
    end

    # Pagination
    @articles = @articles.page(params[:page]).per(25)

    # Get last RSS sync time (most recent article published date)
    @last_rss_sync = Article.maximum(:published_at)
  end

  def show
    @posts = @article.posts.includes(:social_account, :post_metrics).order(posted_at: :desc)
  end

  def sync
    importer = Taz::RssImporter.new
    stats = importer.import_all

    total_new = stats[:homepage][:new] + stats[:social_bot][:new]
    total_errors = stats[:homepage][:errors] + stats[:social_bot][:errors]

    # Link only recent unlinked posts (last 500) to avoid timeout
    recent_unlinked_posts = Post.with_links
                                .order(posted_at: :desc)
                                .limit(500)

    linker_stats = {
      linked: 0,
      already_linked: 0,
      not_taz_link: 0,
      no_msid: 0,
      article_not_found: 0,
      article_created: 0,
      errors: 0
    }

    recent_unlinked_posts.each do |post|
      next unless post.taz_article_link?

      msid = post.extract_msid_from_external_url
      next unless msid

      article = Article.find_by(msid: msid)

      # Create article from XML if not found
      unless article
        article_data = Taz::XmlScraper.scrape_article(msid)
        if article_data
          article = Article.create(article_data)
          linker_stats[:article_created] += 1 if article.persisted?
        end
      end

      linker_stats[:linked] += 1 if article && post.update(article: article)
    end

    if total_errors.zero? && linker_stats[:errors].zero?
      redirect_to articles_path,
                  notice: "RSS sync completed! #{total_new} new articles imported. #{linker_stats[:linked]} posts linked (from 500 most recent)."
    else
      redirect_to articles_path,
                  alert: "RSS sync completed with #{total_errors} errors. #{linker_stats[:errors]} linking errors."
    end
  end

  def refresh
    if @article.refresh_from_xml!
      # Calculate prediction after successful refresh
      begin
        @article.calculate_prediction!
        redirect_to @article, notice: "Article refreshed successfully from XML. Prediction recalculated."
      rescue StandardError => e
        Rails.logger.error "Failed to calculate prediction for article #{@article.msid}: #{e.message}"
        redirect_to @article, notice: "Article refreshed successfully from XML, but prediction calculation failed."
      end
    else
      redirect_to @article, alert: "Failed to refresh article from XML. Please try again."
    end
  end

  private

  def set_article
    @article = Article.find(params[:id])
  end
end
