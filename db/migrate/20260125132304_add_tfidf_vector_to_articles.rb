# db/migrate/YYYYMMDDHHMMSS_add_tfidf_vector_to_articles.rb

class AddTfidfVectorToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :tfidf_vector, :jsonb
    add_index :articles, :tfidf_vector, using: :gin
  end
end
