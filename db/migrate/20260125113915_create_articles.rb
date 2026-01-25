# db/migrate/20260125_create_articles.rb

class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :articles do |t|
      # Core identifiers
      t.string :msid, null: false

      # Content fields (from RSS)
      t.string :title, null: false
      t.text :lead
      t.datetime :published_at, null: false

      # Performance prediction (for Phase 3)
      t.decimal :predicted_performance_score, precision: 10, scale: 2

      # Metadata
      t.datetime :last_refreshed_at

      t.timestamps
    end

    # Indexes
    add_index :articles, :msid, unique: true
    add_index :articles, :published_at
    add_index :articles, :predicted_performance_score
  end
end
