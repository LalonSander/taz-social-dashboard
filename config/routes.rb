# config/routes.rb

Rails.application.routes.draw do
  # Devise routes
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

  # Articles routes
  resources :articles, only: [:index, :show] do
    collection do
      post :sync  # POST /articles/sync - Import RSS feeds
    end

    member do
      post :refresh  # POST /articles/:id/refresh - Refresh from XML
    end
  end

  # Health check (optional, useful for deployment)
  get 'up' => 'rails/health#show', as: :rails_health_check

  get 'analysis/predictions', to: 'analysis#predictions'
end
