# app/models/article.rb

class Article < ApplicationRecord
  # Associations
  has_many :posts, dependent: :nullify

  # Validations
  validates :msid, presence: true, uniqueness: true
  validates :title, presence: true
  validates :published_at, presence: true

  # Scopes
  scope :recent, -> { order(published_at: :desc) }
  scope :with_predictions, -> { where.not(predicted_performance_score: nil) }
  scope :without_predictions, -> { where(predicted_performance_score: nil) }
  scope :published_after, ->(date) { where('published_at >= ?', date) }
  scope :published_before, ->(date) { where('published_at <= ?', date) }

  # Callbacks
  after_create :calculate_prediction_async

  # Class methods

  # Extract msid from any taz.de URL format
  # Examples:
  #   https://taz.de/Trump-beim-Weltwirtschaftsforum/!6144278/
  #   https://taz.de/!6144278
  #   https://taz.de/!6144278/
  #   !6144278
  def self.extract_msid_from_url(url)
    return nil if url.blank?

    # Match pattern: exclamation mark followed by digits
    match = url.match(/!(\d+)/)
    match ? match[1] : nil
  end

  # Find article by URL (extracts msid first)
  def self.find_by_url(url)
    msid = extract_msid_from_url(url)
    return nil unless msid

    find_by(msid: msid)
  end

  # Instance methods

  # Generate canonical taz.de URL
  def canonical_url
    "https://taz.de/!#{msid}"
  end

  # Generate XML scraper URL
  def xml_url
    "https://taz.de/!#{msid}/c.xml"
  end

  # Check if article needs refresh (older than 1 day)
  def needs_refresh?
    last_refreshed_at.nil? || last_refreshed_at < 1.day.ago
  end

  # Refresh article data from XML scraper
  # Returns true on success, false on failure
  def refresh_from_xml!
    Taz::XmlScraper.refresh_article(self)
  end

  # Calculate and cache performance prediction
  def calculate_prediction!
    prediction = PerformancePredictor.predict_for_article(self)

    update_columns(
      predicted_performance_score: prediction[:predicted_performance_score],
      prediction_metadata: {
        similar_articles: prediction[:similar_articles_used],
        count: prediction[:similar_articles_count],
        calculated_at: Time.current,
        method: prediction[:calculation_method],
        details: prediction[:similar_articles_details]
      }
    )

    prediction
  end

  # Get similar articles used in prediction
  def similar_articles
    return [] unless prediction_metadata.present?

    article_ids = prediction_metadata['similar_articles'] || []
    Article.where(id: article_ids)
  end

  # Get prediction calculation details
  def prediction_details
    return nil unless prediction_metadata.present?

    prediction_metadata['details'] || []
  end

  # Check if prediction needs recalculation
  def needs_prediction_recalculation?
    predicted_performance_score.nil? ||
      prediction_metadata.blank? ||
      prediction_metadata['calculated_at'].nil?
  end

  # Truncated title for display
  def truncated_title(length = 100)
    title.length > length ? "#{title[0...length]}..." : title
  end

  # Count of associated posts
  def posts_count
    posts.count
  end

  # Has any associated posts?
  def posted?
    posts.any?
  end

  # Display published date in readable format
  def published_date
    published_at.strftime('%b %d, %Y')
  end

  # Display published datetime in readable format
  def published_datetime
    published_at.strftime('%b %d, %Y at %H:%M')
  end

  # Generate InterRed CMS edit URL
  def cms_edit_url
    return nil unless cms_id.present?

    "https://irre.taz.de/exec/login.pl?mode=stage_edit&bid=#{cms_id}"
  end

  # Check if we have CMS ID
  def has_cms_id?
    cms_id.present?
  end

  private

  # Calculate prediction in background (non-blocking)
  def calculate_prediction_async
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        sleep(0.5) # Small delay to ensure article is fully saved
        calculate_prediction!
      rescue StandardError => e
        Rails.logger.error "Failed to calculate prediction for article #{id}: #{e.message}"
      end
    end
  end
end
