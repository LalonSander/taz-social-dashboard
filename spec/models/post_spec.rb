require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'associations' do
    it { should belong_to(:social_account) }
    it { should belong_to(:article).optional }
    it { should have_many(:post_metrics).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:post) }

    it { should validate_presence_of(:platform) }
    it { should validate_presence_of(:platform_post_id) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:posted_at) }
    it { should validate_presence_of(:post_type) }

    it 'validates uniqueness of platform_post_id scoped to platform' do
      create(:post, platform: 'bluesky', platform_post_id: 'post123')
      duplicate = build(:post, platform: 'bluesky', platform_post_id: 'post123')
      
      expect(duplicate).not_to be_valid
    end

    it 'allows same platform_post_id on different platforms' do
      create(:post, platform: 'bluesky', platform_post_id: 'post123')
      different_platform = build(:post, platform: 'mastodon', platform_post_id: 'post123')
      
      expect(different_platform).to be_valid
    end
  end

  describe 'enums' do
    it { should define_enum_for(:platform).with_values(bluesky: 'bluesky', mastodon: 'mastodon', instagram: 'instagram', tiktok: 'tiktok') }
    it { should define_enum_for(:post_type).with_values(link: 'link', image: 'image', text: 'text', video: 'video') }
  end

  describe 'scopes' do
    let!(:old_post) { create(:post, posted_at: 2.days.ago) }
    let!(:new_post) { create(:post, posted_at: 1.hour.ago) }
    let!(:post_with_article) { create(:post, :with_article) }
    let!(:post_without_article) { create(:post, article: nil) }
    let!(:post_with_link) { create(:post, external_url: 'https://taz.de/article') }

    describe '.recent' do
      it 'orders posts by posted_at descending' do
        expect(Post.recent.first).to eq(new_post)
        expect(Post.recent.last).to eq(old_post)
      end
    end

    describe '.with_articles' do
      it 'returns only posts with articles' do
        expect(Post.with_articles).to include(post_with_article)
        expect(Post.with_articles).not_to include(post_without_article)
      end
    end

    describe '.without_articles' do
      it 'returns only posts without articles' do
        expect(Post.without_articles).to include(post_without_article)
        expect(Post.without_articles).not_to include(post_with_article)
      end
    end

    describe '.with_links' do
      it 'returns only posts with external URLs' do
        expect(Post.with_links).to include(post_with_link)
      end
    end
  end

  describe '#latest_metrics' do
    let(:post) { create(:post) }
    let!(:old_metric) { create(:post_metric, post: post, recorded_at: 2.hours.ago) }
    let!(:new_metric) { create(:post_metric, post: post, recorded_at: 1.hour.ago) }

    it 'returns the most recent metric' do
      expect(post.latest_metrics).to eq(new_metric)
    end
  end

  describe '#latest_total_interactions' do
    let(:post) { create(:post) }

    context 'when post has metrics' do
      before do
        create(:post_metric, post: post, total_interactions: 150)
      end

      it 'returns the total interactions from latest metric' do
        expect(post.latest_total_interactions).to eq(150)
      end
    end

    context 'when post has no metrics' do
      it 'returns 0' do
        expect(post.latest_total_interactions).to eq(0)
      end
    end
  end

  describe '#truncated_content' do
    let(:short_post) { build(:post, content: 'Short post') }
    let(:long_post) { build(:post, content: 'a' * 150) }

    it 'returns full content if shorter than limit' do
      expect(short_post.truncated_content(100)).to eq('Short post')
    end

    it 'truncates long content with ellipsis' do
      expect(long_post.truncated_content(100)).to eq("#{'a' * 100}...")
    end
  end

  describe '#overperformance_score' do
    let(:account) { create(:social_account) }
    let(:post) { create(:post, social_account: account, posted_at: Time.current) }

    context 'with insufficient baseline data' do
      before do
        # Create only 10 posts (less than minimum 20)
        10.times do |i|
          p = create(:post, social_account: account, posted_at: (i + 1).hours.ago)
          create(:post_metric, post: p, total_interactions: 100)
        end
        create(:post_metric, post: post, total_interactions: 200)
      end

      it 'returns 0 when not enough baseline posts' do
        expect(post.overperformance_score).to eq(0)
      end
    end

    context 'with sufficient baseline data' do
      before do
        # Create 100 baseline posts with varying interactions
        100.times do |i|
          p = create(:post, social_account: account, posted_at: (i + 1).hours.ago)
          create(:post_metric, post: p, total_interactions: rand(50..150))
        end
        create(:post_metric, post: post, total_interactions: 200)
      end

      it 'calculates overperformance score' do
        score = post.overperformance_score
        expect(score).to be > 0
        expect(score).to be_a(Float)
      end
    end

    context 'when post has no metrics' do
      it 'returns 0' do
        expect(post.overperformance_score).to eq(0)
      end
    end
  end
end
