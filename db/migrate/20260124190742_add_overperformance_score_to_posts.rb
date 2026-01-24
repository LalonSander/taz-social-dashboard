class AddOverperformanceScoreToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :posts, :overperformance_score_cache, :decimal, precision: 10, scale: 2
    add_index :posts, :overperformance_score_cache

    add_column :posts, :score_calculated_at, :datetime
  end
end
