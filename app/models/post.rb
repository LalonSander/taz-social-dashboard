# app/models/post.rb

class Post < ApplicationRecord
  # Associations
  belongs_to :social_account
  belongs_to :article, optional: true
  has_many :post_metrics, dependent: :destroy

  # Enums (string-based)
  enum platform: {
    bluesky: 'bluesky',
    mastodon: 'mastodon',
    instagram: 'instagram',
    tiktok: 'tiktok'
  }

  enum post_type: {
    link: 'link',
    image: 'image',
    text: 'text',
    video: 'video'
  }

  enum score_calculation_status: {
    not_calculated: 'not_calculated',
    fast_calculated: 'fast_calculated',
    fully_calculated: 'fully_calculated'
  }, _prefix: :score

  # Validations
  validates :platform, presence: true
  validates :platform_post_id, presence: true, uniqueness: { scope: :platform }
  validates :content, presence: true
  validates :posted_at, presence: true
  validates :post_type, presence: true

  # Scopes
  scope :recent, -> { order(posted_at: :desc) }
  scope :with_articles, -> { where.not(article_id: nil) }
  scope :without_articles, -> { where(article_id: nil) }
  scope :with_links, -> { where.not(external_url: nil) }
  scope :needs_score_calculation, -> { where(score_calculation_status: ['not_calculated', 'fast_calculated']) }
  scope :needs_metric_update, ->(since) { where('metrics_updated_at IS NULL OR metrics_updated_at < ?', since) }
  scope :from_last_24_hours, -> { where('posted_at > ?', 24.hours.ago) }
  scope :older_than_24_hours, -> { where('posted_at <= ?', 24.hours.ago) }

  # Instance methods
  def latest_metrics
    post_metrics.order(recorded_at: :desc).first
  end

  def latest_total_interactions
    latest_metrics&.total_interactions || 0
  end

  # Use cached score if available and recent, otherwise calculate
  def overperformance_score
    # If cache exists and is less than 1 hour old, use it
    if overperformance_score_cache.present? &&
       score_calculated_at.present? &&
       score_calculated_at > 1.hour.ago
      return overperformance_score_cache
    end

    # Otherwise calculate fresh
    calculate_overperformance_score
  end

  # Calculate using cached baseline (fast calculation)
  def calculate_fast_overperformance_score
    baseline = social_account.baseline_interactions_average
    return 0 if baseline.nil? || baseline.zero?

    score = ((latest_total_interactions / baseline.to_f) * 100).round(2)

    update_columns(
      overperformance_score_cache: score,
      score_calculated_at: Time.current,
      score_calculation_status: 'fast_calculated',
      last_calculated_interactions: latest_total_interactions
    )

    score
  end

  # Calculate and cache the score (full calculation with baseline recalc)
  def calculate_and_cache_overperformance_score!
    score = calculate_overperformance_score
    update_columns(
      overperformance_score_cache: score,
      score_calculated_at: Time.current,
      score_calculation_status: 'fully_calculated',
      last_calculated_interactions: latest_total_interactions
    )
    score
  end

  # Check if metrics have changed since last calculation
  def metrics_changed?
    return true if last_calculated_interactions.nil?

    latest_total_interactions != last_calculated_interactions
  end

  # Check if this post needs a score recalculation
  def needs_score_recalculation?
    score_not_calculated? ||
      score_fast_calculated? ||
      metrics_changed? ||
      (score_calculated_at && score_calculated_at < 1.hour.ago)
  end

  def truncated_content(length = 100)
    content.length > length ? "#{content[0...length]}..." : content
  end

  # Generate platform URL if not already stored
  def platform_url
    read_attribute(:platform_url) || generate_platform_url
  end

  # NEW: Extract msid from external_url
  # Examples:
  #   https://taz.de/Trump-beim-Weltwirtschaftsforum/!6144278/
  #   https://taz.de/!6144278
  #   https://taz.de/!6144278/
  def extract_msid_from_external_url
    return nil if external_url.blank?

    Article.extract_msid_from_url(external_url)
  end

  # NEW: Check if external_url is a taz.de link
  def taz_article_link?
    return false if external_url.blank?

    external_url.match?(/taz\.de/i)
  end

  private

  def calculate_overperformance_score
    baseline = calculate_baseline
    return 0 if baseline.zero?

    ((latest_total_interactions / baseline.to_f) * 100).round(2)
  end

  def generate_platform_url
    case platform
    when 'bluesky'
      generate_bluesky_url
    when 'mastodon'
      # Future: generate_mastodon_url
      nil
    when 'instagram'
      # Future: generate_instagram_url
      nil
    else
      nil
    end
  end

  def generate_bluesky_url
    return nil unless platform_data.present?

    author_handle = platform_data.dig('author', 'handle') || social_account&.handle
    return nil unless author_handle && platform_post_id

    "https://bsky.app/profile/#{author_handle}/post/#{platform_post_id}"
  end

  def calculate_baseline
    # Get last 100 posts before this one from the same account
    baseline_posts = Post
                     .where(social_account_id: social_account_id)
                     .where("posted_at < ?", posted_at)
                     .order(posted_at: :desc)
                     .limit(100)
                     .includes(:post_metrics)

    # Get latest interaction count for each post
    interactions = baseline_posts.map(&:latest_total_interactions).compact

    return 0 if interactions.size < 20 # Not enough data

    # Remove top 10 and bottom 10
    sorted = interactions.sort
    trimmed = if sorted.size > 20
                sorted[10..-11]
              else
                sorted
              end

    return 0 if trimmed.empty?

    trimmed.sum / trimmed.size.to_f
  end
end
