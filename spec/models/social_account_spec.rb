require 'rails_helper'

RSpec.describe SocialAccount, type: :model do
  describe 'associations' do
    it { should have_many(:posts).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:social_account) }

    it { should validate_presence_of(:platform) }
    it { should validate_presence_of(:handle) }
    
    it 'validates uniqueness of platform and handle combination' do
      create(:social_account, platform: 'bluesky', handle: 'test.bsky.social')
      duplicate = build(:social_account, platform: 'bluesky', handle: 'test.bsky.social')
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:platform]).to include('and handle combination already exists')
    end
  end

  describe 'enums' do
    it { should define_enum_for(:platform).with_values(bluesky: 'bluesky', mastodon: 'mastodon', instagram: 'instagram', tiktok: 'tiktok') }
  end

  describe 'scopes' do
    let!(:active_account) { create(:social_account, active: true) }
    let!(:inactive_account) { create(:social_account, active: false) }

    it 'returns active accounts' do
      expect(SocialAccount.active).to include(active_account)
      expect(SocialAccount.active).not_to include(inactive_account)
    end

    it 'returns inactive accounts' do
      expect(SocialAccount.inactive).to include(inactive_account)
      expect(SocialAccount.inactive).not_to include(active_account)
    end
  end

  describe '#needs_sync?' do
    it 'returns true when never synced' do
      account = build(:social_account, last_synced_at: nil)
      expect(account.needs_sync?).to be true
    end

    it 'returns true when last synced over an hour ago' do
      account = build(:social_account, last_synced_at: 2.hours.ago)
      expect(account.needs_sync?).to be true
    end

    it 'returns false when synced recently' do
      account = build(:social_account, last_synced_at: 30.minutes.ago)
      expect(account.needs_sync?).to be false
    end
  end

  describe '#display_name' do
    it 'returns handle with @ prefix' do
      account = build(:social_account, handle: 'taz.bsky.social')
      expect(account.display_name).to eq('@taz.bsky.social')
    end
  end
end
