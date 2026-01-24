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
end
