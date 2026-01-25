# db/migrate/20260125_add_article_foreign_key_to_posts.rb

class AddArticleForeignKeyToPosts < ActiveRecord::Migration[7.1]
  def change
    # Add foreign key constraint to existing article_id column
    # This ensures referential integrity between posts and articles
    add_foreign_key :posts, :articles, on_delete: :nullify
  end
end
