require 'rails_helper'

RSpec.describe PostMetric, type: :model do
  describe 'associations' do
    it { should belong_to(:post) }
  end

  describe 'validations' do
    it { should validate_presence_of(:post_id) }
    it { should validate_presence_of(:recorded_at) }
  end

  describe 'scopes' do
    let(:post) { create(:post) }
    let!(:old_metric) { create(:post_metric, post: post, recorded_at: 2.days.ago) }
    let!(:new_metric) { create(:post_metric, post: post, recorded_at: 1.hour.ago) }

    describe '.recent' do
      it 'orders metrics by recorded_at descending' do
        expect(PostMetric.recent.first).to eq(new_metric)
        expect(PostMetric.recent.last).to eq(old_metric)
      end
    end

    describe '.for_date' do
      let!(:today_metric) { create(:post_metric, recorded_at: Time.current) }
      let!(:yesterday_metric) { create(:post_metric, recorded_at: 1.day.ago) }

      it 'returns metrics for specific date' do
        expect(PostMetric.for_date(Date.today)).to include(today_metric)
        expect(PostMetric.for_date(Date.today)).not_to include(yesterday_metric)
      end
    end
  end

  describe '#calculate_total_interactions' do
    it 'calculates total interactions before save' do
      metric = build(:post_metric, likes: 10, replies: 5, reposts: 3, quotes: 2)
      metric.save!
      
      expect(metric.total_interactions).to eq(20)
    end

    it 'handles nil values as zero' do
      metric = build(:post_metric, likes: 10, replies: nil, reposts: nil, quotes: nil)
      metric.save!
      
      expect(metric.total_interactions).to eq(10)
    end

    it 'recalculates on update' do
      metric = create(:post_metric, likes: 10, replies: 5, reposts: 3, quotes: 2)
      expect(metric.total_interactions).to eq(20)
      
      metric.update!(likes: 20)
      expect(metric.total_interactions).to eq(30)
    end
  end

  describe '#interaction_breakdown' do
    let(:metric) { create(:post_metric, likes: 100, replies: 20, reposts: 30, quotes: 10) }

    it 'returns hash with all interaction types' do
      breakdown = metric.interaction_breakdown
      
      expect(breakdown).to eq({
        likes: 100,
        replies: 20,
        reposts: 30,
        quotes: 10,
        total: 160
      })
    end

    it 'handles nil values' do
      metric = create(:post_metric, likes: 50, replies: nil, reposts: nil, quotes: nil)
      breakdown = metric.interaction_breakdown
      
      expect(breakdown).to eq({
        likes: 50,
        replies: 0,
        reposts: 0,
        quotes: 0,
        total: 50
      })
    end
  end
end
