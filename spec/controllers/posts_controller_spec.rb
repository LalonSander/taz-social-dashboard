# spec/controllers/posts_controller_spec.rb

require 'rails_helper'

RSpec.describe PostsController, type: :controller do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    let!(:posts) { create_list(:post, 5) }

    it 'returns success' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @posts' do
      get :index
      expect(assigns(:posts)).to match_array(posts)
    end

    it 'assigns @last_sync' do
      account = create(:social_account, last_synced_at: 1.hour.ago)
      get :index
      expect(assigns(:last_sync)).to be_present
    end
  end

  describe 'POST #sync' do
    let!(:account) { create(:social_account, platform: 'bluesky', active: true) }

    context 'when sync succeeds' do
      before do
        allow_any_instance_of(SocialPlatform::Bluesky).to receive(:sync).and_return({
                                                                                      success: true,
                                                                                      new_posts: 5,
                                                                                      updated_metrics: 10,
                                                                                      synced_at: Time.current
                                                                                    })
      end

      it 'redirects to posts path' do
        post :sync
        expect(response).to redirect_to(posts_path)
      end

      it 'sets success flash message' do
        post :sync
        expect(flash[:notice]).to include('Sync completed')
        expect(flash[:notice]).to include('5 new posts')
      end

      it 'updates account last_synced_at' do
        expect do
          post :sync
        end.to(change { account.reload.last_synced_at })
      end
    end

    context 'when sync fails' do
      before do
        allow_any_instance_of(SocialPlatform::Bluesky).to receive(:sync).and_return({
                                                                                      success: false,
                                                                                      error: 'Authentication failed'
                                                                                    })
      end

      it 'sets error flash message' do
        post :sync
        expect(flash[:alert]).to include('Authentication failed')
      end
    end

    context 'when no active accounts' do
      before do
        account.update!(active: false)
      end

      it 'sets error flash message' do
        post :sync
        expect(flash[:alert]).to include('No active Bluesky accounts')
      end
    end
  end
end
