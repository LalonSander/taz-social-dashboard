class CreatePostMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :post_metrics do |t|
      t.references :post, null: false, foreign_key: true
      t.integer :likes, default: 0
      t.integer :replies, default: 0
      t.integer :reposts, default: 0
      t.integer :quotes, default: 0
      t.integer :total_interactions, default: 0
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :post_metrics, [:post_id, :recorded_at], name: 'index_post_metrics_on_post_and_recorded_at'
    add_index :post_metrics, :recorded_at

    # Add trigger to automatically calculate total_interactions
    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE OR REPLACE FUNCTION calculate_total_interactions()
          RETURNS TRIGGER AS $$
          BEGIN
            NEW.total_interactions = COALESCE(NEW.likes, 0) +
                                    COALESCE(NEW.replies, 0) +
                                    COALESCE(NEW.reposts, 0) +
                                    COALESCE(NEW.quotes, 0);
            RETURN NEW;
          END;
          $$ LANGUAGE plpgsql;

          CREATE TRIGGER set_total_interactions
            BEFORE INSERT OR UPDATE ON post_metrics
            FOR EACH ROW
            EXECUTE FUNCTION calculate_total_interactions();
        SQL
      end

      dir.down do
        execute <<-SQL
          DROP TRIGGER IF EXISTS set_total_interactions ON post_metrics;
          DROP FUNCTION IF EXISTS calculate_total_interactions();
        SQL
      end
    end
  end
end
