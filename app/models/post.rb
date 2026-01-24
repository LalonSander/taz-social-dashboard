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

  # Instance methods
  def latest_metrics
    post_metrics.order(recorded_at: :desc).first
  end

  def latest_total_interactions
    latest_metrics&.total_interactions || 0
  end

  def overperformance_score
    baseline = calculate_baseline
    return 0 if baseline.zero?

    ((latest_total_interactions / baseline.to_f) * 100).round(1)
  end

  def truncated_content(length = 100)
    content.length > length ? "#{content[0...length]}..." : content
  end

  private

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
