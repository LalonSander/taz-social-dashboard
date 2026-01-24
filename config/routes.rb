Rails.application.routes.draw do
  # Devise authentication
  devise_for :users

  # Root route
  root 'posts#index'

  # Posts dashboard
  resources :posts, only: [:index, :show] do
    collection do
      post :sync  # Manual sync action
    end
  end

  # Health check for deployment
  get 'up' => 'rails/health#show', as: :rails_health_check
end
