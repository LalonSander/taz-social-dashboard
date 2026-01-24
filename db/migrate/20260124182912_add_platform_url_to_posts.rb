class AddPlatformUrlToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column :posts, :platform_url, :string
    add_index :posts, :platform_url
  end
end
