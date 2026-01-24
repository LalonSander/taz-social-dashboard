class PostMetric < ApplicationRecord
  # Associations
  belongs_to :post

  # Validations
  validates :post_id, presence: true
  validates :recorded_at, presence: true

  # Callbacks
  before_save :calculate_total_interactions

  # Scopes
  scope :recent, -> { order(recorded_at: :desc) }
  scope :for_date, ->(date) { where('DATE(recorded_at) = ?', date) }

  # Instance methods
  def interaction_breakdown
    {
      likes: likes || 0,
      replies: replies || 0,
      reposts: reposts || 0,
      quotes: quotes || 0,
      total: total_interactions
    }
  end

  private

  def calculate_total_interactions
    self.total_interactions = (likes || 0) + (replies || 0) + (reposts || 0) + (quotes || 0)
  end
end
