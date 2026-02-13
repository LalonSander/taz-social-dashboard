class SocialAccount < ApplicationRecord
  # Associations
  has_many :posts, dependent: :destroy

  # Enums (string-based)
  enum platform: {
    bluesky: 'bluesky',
    mastodon: 'mastodon',
    instagram: 'instagram',
    tiktok: 'tiktok'
  }

  # Validations
  validates :platform, presence: true
  validates :handle, presence: true
  validates :platform, uniqueness: { scope: :handle, message: "and handle combination already exists" }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Instance methods
  def needs_sync?
    last_synced_at.nil? || last_synced_at < 1.hour.ago
  end

  def display_name
    "@#{handle}"
  end

  # Check if baseline needs recalculation
  def needs_baseline_recalculation?
    baseline_calculated_at.nil? || baseline_calculated_at < 1.hour.ago
  end

  # Calculate and cache the baseline average for overperformance calculations
  def calculate_and_cache_baseline!
    # Get last 100 posts, excluding text posts
    baseline_posts = posts
                     .where("posts.platform_url ILIKE '%' || ? || '%'", handle) # Only our posts
                     .where.not(post_type: 'text') # Exclude all text posts
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

    baseline_avg = (trimmed.sum / trimmed.size.to_f).round(2)

    update_columns(
      baseline_interactions_average: baseline_avg,
      baseline_calculated_at: Time.current,
      baseline_sample_size: trimmed.size
    )

    baseline_avg
  end
end
