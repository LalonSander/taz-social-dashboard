class AddSimpleSearchIndexToPosts < ActiveRecord::Migration[7.1]
  def change
    # Simple index for ILIKE searches on content
    # Uses standard btree with text_pattern_ops for better ILIKE performance
    add_index :posts, :content, opclass: :text_pattern_ops, name: 'index_posts_on_content_pattern'
  end
end
