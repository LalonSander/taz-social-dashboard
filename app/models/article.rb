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

  # Generate InterRed CMS edit URL
  def cms_edit_url
    return nil unless cms_id.present?

    "https://irre.taz.de/exec/login.pl?mode=stage_edit&bid=#{cms_id}"
  end

  # Check if we have CMS ID
  def has_cms_id?
    cms_id.present?
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
end
