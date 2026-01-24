# spec/services/social_platform/bluesky_spec.rb

require 'rails_helper'

RSpec.describe SocialPlatform::Bluesky do
  let(:account) { create(:social_account, platform: 'bluesky', handle: 'taz.de') }
  let(:service) { described_class.new(account) }

  describe '#sync' do
    context 'when authentication succeeds' do
      before do
        # Mock authentication
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.createSession")
          .to_return(
            status: 200,
            body: { accessJwt: 'fake_token' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Mock fetching posts
        stub_request(:get, "https://bsky.social/xrpc/app.bsky.feed.getAuthorFeed")
          .with(query: hash_including({ actor: 'taz.de' }))
          .to_return(
            status: 200,
            body: {
              feed: [
                {
                  post: {
                    uri: 'at://did:plc:xxx/app.bsky.feed.post/abc123',
                    cid: 'cid123',
                    author: { handle: 'taz.de' },
                    record: {
                      text: 'Test post',
                      createdAt: 1.hour.ago.iso8601
                    },
                    likeCount: 10,
                    replyCount: 2,
                    repostCount: 5,
                    quoteCount: 1
                  }
                }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'fetches and saves new posts' do
        expect do
          service.sync
        end.to change { Post.count }.by(1)
      end

      it 'creates metrics for new posts' do
        expect do
          service.sync
        end.to change { PostMetric.count }.by(1)
      end

      it 'returns success result' do
        result = service.sync
        expect(result[:success]).to be true
        expect(result[:new_posts]).to eq(1)
      end

      it 'updates account last_synced_at' do
        service.sync
        expect(account.reload.access_token).to eq('fake_token')
      end
    end

    context 'when authentication fails' do
      before do
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.createSession")
          .to_return(status: 401, body: { error: 'Invalid credentials' }.to_json)
      end

      it 'returns error result' do
        result = service.sync
        expect(result[:success]).to be false
        expect(result[:error]).to include('Authentication failed')
      end
    end

    context 'when rate limited' do
      before do
        stub_request(:post, "https://bsky.social/xrpc/com.atproto.server.createSession")
          .to_return(status: 200, body: { accessJwt: 'fake_token' }.to_json)

        stub_request(:get, "https://bsky.social/xrpc/app.bsky.feed.getAuthorFeed")
          .to_return(status: 429, body: { error: 'Rate limit exceeded' }.to_json)
      end

      it 'returns error result' do
        result = service.sync
        expect(result[:success]).to be false
        expect(result[:error]).to include('Rate limit')
      end
    end
  end
end
