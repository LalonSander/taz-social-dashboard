class CreateSocialAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :social_accounts do |t|
      t.string :platform, null: false
      t.string :handle, null: false
      t.string :platform_id
      t.text :access_token
      t.datetime :last_synced_at
      t.boolean :active, default: true
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :social_accounts, :platform
    add_index :social_accounts, :active
    add_index :social_accounts, [:platform, :handle], unique: true, name: 'index_social_accounts_on_platform_and_handle'
  end
end
