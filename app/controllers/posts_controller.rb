class PostsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Will implement in Step 1.5
    render html: "
      <div class='container mx-auto px-4 py-8'>
        <h1 class='text-3xl font-bold mb-4'>Social Media Dashboard</h1>
        <p class='text-gray-600'>Posts will be displayed here once we complete Step 1.2-1.5</p>
        <div class='mt-8'>
          <form action='/posts/sync' method='post' data-turbo='false'>
            <input type='hidden' name='authenticity_token' value='#{form_authenticity_token}'>
            <button type='submit' class='bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600'>
              Sync Posts Now
            </button>
          </form>
          <a href='/users/sign_out' data-turbo-method='delete' class='ml-4 bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600'>
            Sign Out
          </a>
        </div>
      </div>
    ".html_safe
  end

  def sync
    # Will implement in Step 1.3
    # This will call the Bluesky API directly in the request
    redirect_to posts_path, notice: "Sync functionality will be implemented in Step 1.3"
  end

  def show
    # Will implement in Step 1.5
  end
end
