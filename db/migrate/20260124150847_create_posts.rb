class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.references :social_account, null: false, foreign_key: true
      t.references :article, null: true, foreign_key: false
      t.string :platform, null: false
      t.string :platform_post_id, null: false
      t.text :content, null: false
      t.string :external_url
      t.string :post_type, null: false
      t.datetime :posted_at, null: false
      t.jsonb :platform_data, default: {}

      t.timestamps
    end

    add_index :posts, [:platform, :platform_post_id], unique: true, name: 'index_posts_on_platform_and_platform_post_id'
    add_index :posts, :platform
    add_index :posts, :posted_at
    add_index :posts, :post_type
    add_index :posts, :external_url
  end
end
