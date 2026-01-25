class RemoveDuplicatePostMetrics < ActiveRecord::Migration[7.1]
  def up
    say "Removing duplicate consecutive post metrics..."

    # Get all posts with metrics
    post_ids = PostMetric.distinct.pluck(:post_id)
    total_deleted = 0

    post_ids.each_with_index do |post_id, index|
      # Get all metrics for this post, ordered by time
      metrics = PostMetric.where(post_id: post_id).order(:recorded_at).to_a

      next if metrics.size <= 1

      ids_to_delete = []
      previous_metric = metrics.first

      # Compare each metric with the previous one
      metrics[1..-1].each do |current_metric|
        # Check if all values are the same
        if current_metric.likes == previous_metric.likes &&
           current_metric.replies == previous_metric.replies &&
           current_metric.reposts == previous_metric.reposts &&
           current_metric.quotes == previous_metric.quotes
          # This is a duplicate, mark for deletion
          ids_to_delete << current_metric.id
        else
          # Values changed, update previous_metric reference
          previous_metric = current_metric
        end
      end

      # Delete duplicates in batch
      if ids_to_delete.any?
        PostMetric.where(id: ids_to_delete).delete_all
        total_deleted += ids_to_delete.size
      end

      # Progress indicator
      say "Processed #{index + 1}/#{post_ids.size} posts" if (index + 1) % 100 == 0
    end

    say "Cleanup complete! Removed #{total_deleted} duplicate metric records."
  end

  def down
    say "This migration cannot be reversed - duplicate data has been permanently removed."
  end
end
