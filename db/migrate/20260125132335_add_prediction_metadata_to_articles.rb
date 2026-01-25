# db/migrate/YYYYMMDDHHMMSS_add_prediction_metadata_to_articles.rb

class AddPredictionMetadataToArticles < ActiveRecord::Migration[7.1]
  def change
    # Store metadata about prediction calculation
    # Includes: similar_articles used, count, calculation method, timestamp
    add_column :articles, :prediction_metadata, :jsonb, default: {}

    # Add index for querying articles by calculation method
    add_index :articles, :prediction_metadata, using: :gin
  end
end
