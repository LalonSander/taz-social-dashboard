# db/migrate/YYYYMMDDHHMMSS_add_cms_id_to_articles.rb

class AddCmsIdToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :articles, :cms_id, :string
    add_index :articles, :cms_id
  end
end
