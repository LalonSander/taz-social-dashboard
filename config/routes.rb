# config/routes.rb
# Add these lines to your existing routes.rb file

Rails.application.routes.draw do
  # Devise routes (should already exist)
  devise_for :users

  # Root route - redirect to posts after login
  authenticated :user do
    root 'posts#index', as: :authenticated_root
  end

  root 'posts#index'

  # Posts routes
  resources :posts, only: [:index] do
    collection do
      post :sync  # POST /posts/sync
    end
  end

  # Health check (optional, useful for deployment)
  get 'up' => 'rails/health#show', as: :rails_health_check
end
