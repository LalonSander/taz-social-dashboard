class AddSyncOptimizationFieldsToPosts < ActiveRecord::Migration[7.1]
  def change
    # Track the calculation status of overperformance score
    # Values: 'not_calculated', 'fast_calculated', 'fully_calculated'
    add_column :posts, :score_calculation_status, :string, default: 'not_calculated', null: false
    add_index :posts, :score_calculation_status

    # Track when metrics were last updated from API
    add_column :posts, :metrics_updated_at, :datetime
    add_index :posts, :metrics_updated_at

    # Store the interaction count used for last score calculation
    # Used to detect if metrics have changed and score needs recalculation
    add_column :posts, :last_calculated_interactions, :integer

    # Backfill existing posts
    reversible do |dir|
      dir.up do
        # Posts with cached scores are considered fully calculated
        execute <<-SQL
          UPDATE posts
          SET score_calculation_status = 'fully_calculated',
              last_calculated_interactions = overperformance_score_cache
          WHERE overperformance_score_cache IS NOT NULL
        SQL

        # Set metrics_updated_at to score_calculated_at for existing posts
        execute <<-SQL
          UPDATE posts
          SET metrics_updated_at = score_calculated_at
          WHERE score_calculated_at IS NOT NULL
        SQL
      end
    end
  end
end
