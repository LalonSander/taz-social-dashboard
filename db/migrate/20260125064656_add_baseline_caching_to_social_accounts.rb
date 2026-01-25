class AddBaselineCachingToSocialAccounts < ActiveRecord::Migration[7.1]
  def change
    # Cache the baseline average for overperformance calculations
    # Avoids querying 100 posts every time we calculate overperformance
    add_column :social_accounts, :baseline_interactions_average, :decimal, precision: 10, scale: 2

    # Track when baseline was last calculated
    add_column :social_accounts, :baseline_calculated_at, :datetime
    add_index :social_accounts, :baseline_calculated_at

    # Optional: Track how many posts were used to calculate the baseline
    # Useful for confidence scoring and debugging
    add_column :social_accounts, :baseline_sample_size, :integer
  end
end
