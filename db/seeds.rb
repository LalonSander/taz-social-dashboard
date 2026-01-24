# db/seeds.rb - Add this to your existing seeds file

puts "🌱 Seeding database..."

# Create a test Bluesky account
account = SocialAccount.find_or_create_by!(
  platform: 'bluesky',
  handle: 'taz.de'
) do |a|
  a.platform_id = 'did:plc:example123'
  a.active = true
  a.last_synced_at = 2.hours.ago
  a.metadata = { display_name: 'taz' }
end

puts "✅ Created SocialAccount: @taz.de"

# Create sample posts
sample_posts = [
  {
    platform_post_id: 'post_001',
    content: 'Breaking: New climate policy announced. Read more at taz.de/climate2024',
    external_url: 'https://taz.de/climate2024',
    post_type: 'link',
    posted_at: 3.days.ago
  },
  {
    platform_post_id: 'post_002',
    content: 'Interview with environmental activists about the latest protests.',
    external_url: 'https://taz.de/protests-interview',
    post_type: 'link',
    posted_at: 2.days.ago
  },
  {
    platform_post_id: 'post_003',
    content: 'Photo essay: Berlin street art scene 2024',
    external_url: 'https://taz.de/berlin-art-2024',
    post_type: 'image',
    posted_at: 1.day.ago
  },
  {
    platform_post_id: 'post_004',
    content: 'Opinion: Why renewable energy is the future',
    external_url: 'https://taz.de/renewable-opinion',
    post_type: 'link',
    posted_at: 12.hours.ago
  },
  {
    platform_post_id: 'post_005',
    content: 'Just thinking about the weekend...',
    external_url: nil,
    post_type: 'text',
    posted_at: 6.hours.ago
  }
]

sample_posts.each do |post_data|
  post = account.posts.find_or_create_by!(
    platform: 'bluesky',
    platform_post_id: post_data[:platform_post_id]
  ) do |p|
    p.content = post_data[:content]
    p.external_url = post_data[:external_url]
    p.post_type = post_data[:post_type]
    p.posted_at = post_data[:posted_at]
    p.platform_data = { language: 'de' }
  end

  # Create metrics for each post (simulating growth over time)
  base_time = post.posted_at

  # Initial metrics (right after posting)
  post.post_metrics.find_or_create_by!(recorded_at: base_time) do |m|
    m.likes = rand(5..15)
    m.replies = rand(0..3)
    m.reposts = rand(0..5)
    m.quotes = rand(0..2)
  end

  # Metrics after 1 hour
  post.post_metrics.find_or_create_by!(recorded_at: base_time + 1.hour) do |m|
    m.likes = rand(20..50)
    m.replies = rand(2..8)
    m.reposts = rand(3..15)
    m.quotes = rand(1..5)
  end

  # Metrics after 6 hours
  if post.posted_at < 6.hours.ago
    post.post_metrics.find_or_create_by!(recorded_at: base_time + 6.hours) do |m|
      m.likes = rand(50..150)
      m.replies = rand(5..20)
      m.reposts = rand(10..40)
      m.quotes = rand(3..10)
    end
  end

  # Metrics after 24 hours
  if post.posted_at < 1.day.ago
    post.post_metrics.find_or_create_by!(recorded_at: base_time + 24.hours) do |m|
      m.likes = rand(100..300)
      m.replies = rand(10..40)
      m.reposts = rand(20..80)
      m.quotes = rand(5..20)
    end
  end

  puts "✅ Created Post: #{post.truncated_content(50)}"
end

puts "\n📊 Database Summary:"
puts "- SocialAccounts: #{SocialAccount.count}"
puts "- Posts: #{Post.count}"
puts "- PostMetrics: #{PostMetric.count}"
puts "\n🎉 Seeding completed!"
