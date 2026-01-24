# lib/tasks/performance.rake

namespace :performance do
  desc "Update cached overperformance scores for all recent posts"
  task update_scores: :environment do
    puts "🔄 Updating overperformance scores..."

    # Only update posts from last 30 days (older posts don't change much)
    posts = Post.where('posted_at > ?', 30.days.ago)

    total = posts.count
    updated = 0

    posts.find_each.with_index do |post, index|
      post.calculate_and_cache_overperformance_score!
      updated += 1

      print "\rUpdated #{index + 1}/#{total} posts..." if (index + 1) % 100 == 0
    end

    puts "\n✅ Updated #{updated} posts"
  end

  desc "Update scores for posts that need it (cache older than 1 hour)"
  task update_stale_scores: :environment do
    puts "🔄 Updating stale overperformance scores..."

    posts = Post.where('posted_at > ?', 30.days.ago)
                .where('score_calculated_at IS NULL OR score_calculated_at < ?', 1.hour.ago)

    total = posts.count
    puts "Found #{total} posts with stale scores..."

    posts.find_each.with_index do |post, index|
      post.calculate_and_cache_overperformance_score!

      print "\rUpdated #{index + 1}/#{total} posts..." if (index + 1) % 100 == 0
    end

    puts "\n✅ Done"
  end
end
