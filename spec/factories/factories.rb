FactoryBot.define do
  factory :social_account do
    platform { 'bluesky' }
    sequence(:handle) { |n| "user#{n}.bsky.social" }
    platform_id { "did:plc:#{SecureRandom.hex(8)}" }
    access_token { SecureRandom.hex(32) }
    active { true }
    last_synced_at { 1.hour.ago }
    metadata { { display_name: 'Test Account' } }

    trait :mastodon do
      platform { 'mastodon' }
      sequence(:handle) { |n| "user#{n}@mastodon.social" }
    end

    trait :inactive do
      active { false }
    end

    trait :never_synced do
      last_synced_at { nil }
    end
  end

  factory :post do
    association :social_account
    platform { 'bluesky' }
    sequence(:platform_post_id) { |n| "post_#{SecureRandom.hex(8)}_#{n}" }
    content { Faker::Lorem.paragraph(sentence_count: 3) }
    external_url { "https://taz.de/article-#{SecureRandom.hex(4)}" }
    post_type { 'link' }
    posted_at { 1.day.ago }
    platform_data { { language: 'de' } }

    trait :with_article do
      association :article
    end

    trait :text_only do
      post_type { 'text' }
      external_url { nil }
    end

    trait :image do
      post_type { 'image' }
    end

    trait :video do
      post_type { 'video' }
    end

    trait :recent do
      posted_at { 1.hour.ago }
    end

    trait :old do
      posted_at { 30.days.ago }
    end
  end

  factory :post_metric do
    association :post
    likes { rand(10..100) }
    replies { rand(0..20) }
    reposts { rand(0..30) }
    quotes { rand(0..10) }
    recorded_at { Time.current }

    trait :high_engagement do
      likes { rand(500..1000) }
      replies { rand(50..100) }
      reposts { rand(100..200) }
      quotes { rand(20..50) }
    end

    trait :low_engagement do
      likes { rand(0..10) }
      replies { rand(0..2) }
      reposts { rand(0..3) }
      quotes { 0 }
    end
  end

  factory :article do
    sequence(:url) { |n| "https://taz.de/article-#{n}-#{SecureRandom.hex(4)}" }
    title { Faker::Lorem.sentence(word_count: 8) }
    summary { Faker::Lorem.paragraph(sentence_count: 5) }
    published_at { 1.day.ago }
    author { Faker::Name.name }
    category { ['Politik', 'Wirtschaft', 'Kultur', 'Sport', 'Meinung'].sample }
    tags { ['klimawandel', 'berlin', 'bundestag'].sample(rand(1..3)) }
    metadata { { source: 'rss_feed' } }

    trait :with_full_text do
      full_text { Faker::Lorem.paragraphs(number: 10).join("\n\n") }
    end

    trait :recent do
      published_at { 1.hour.ago }
    end

    trait :old do
      published_at { 30.days.ago }
    end
  end
end
