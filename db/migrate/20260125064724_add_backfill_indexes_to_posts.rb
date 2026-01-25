class AddBackfillIndexesToPosts < ActiveRecord::Migration[7.1]
  def change
    # Composite index for finding posts that need score calculation
    # Helps with query: WHERE score_calculation_status = 'not_calculated' ORDER BY posted_at DESC
    add_index :posts, [:score_calculation_status, :posted_at],
              name: 'index_posts_on_status_and_posted_at'

    # Composite index for finding posts needing metric updates
    # Helps with query: WHERE posted_at > X AND metrics_updated_at < Y
    add_index :posts, [:posted_at, :metrics_updated_at],
              name: 'index_posts_on_posted_and_metrics_updated'

    # Index for finding posts by social_account that need updates
    # Helps with query: WHERE social_account_id = X AND metrics_updated_at < Y
    add_index :posts, [:social_account_id, :metrics_updated_at],
              name: 'index_posts_on_account_and_metrics_updated'
  end
end
