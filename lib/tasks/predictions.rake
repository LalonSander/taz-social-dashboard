# lib/tasks/predictions.rake - COMPLETE FILE

namespace :predictions do
  desc "Recalculate TF-IDF vectors for all articles"
  task recalculate_vectors: :environment do
    puts "=" * 80
    puts "Recalculating TF-IDF Vectors"
    puts "=" * 80

    total = Article.count
    success = 0
    failed = 0

    Article.find_each.with_index do |article, index|
      print "Processing #{index + 1}/#{total}: #{article.msid}..."

      begin
        article.calculate_tfidf_vector
        puts " ✓"
        success += 1
      rescue StandardError => e
        puts " ✗ #{e.message}"
        failed += 1
      end
    end

    puts "\n" + ("=" * 80)
    puts "RESULTS:"
    puts "  ✓ Success: #{success}"
    puts "  ✗ Failed: #{failed}"
    puts "=" * 80
  end

  desc "Recalculate predictions for articles (usage: LIMIT=100 for recent N articles)"
  task recalculate_all: :environment do
    limit = (ENV['LIMIT'] || 'all').downcase

    puts "=" * 80
    puts "Recalculating Predictions"
    puts "=" * 80

    # Get articles to process
    articles = Article.order(published_at: :desc)

    if limit == 'all'
      puts "Processing ALL articles\n\n"
    else
      limit_num = limit.to_i
      articles = articles.limit(limit_num)
      puts "Processing #{limit_num} most recent articles\n\n"
    end

    total = articles.count
    success = 0
    failed = 0

    articles.find_each.with_index do |article, index|
      print "Processing #{index + 1}/#{total}: #{article.msid}..."

      begin
        prediction = article.calculate_prediction!
        score = prediction[:predicted_performance_score]
        method = prediction[:calculation_method]
        similar_count = prediction[:similar_articles_count]
        puts " ✓ Score: #{score.round(1)} (#{method}, #{similar_count} similar)"
        success += 1
      rescue StandardError => e
        puts " ✗ #{e.message}"
        failed += 1
      end

      sleep(0.1) if (index + 1) % 10 == 0
    end

    puts "\n" + ("=" * 80)
    puts "RESULTS:"
    puts "  ✓ Success: #{success}"
    puts "  ✗ Failed: #{failed}"
    puts "=" * 80
  end

  desc "Calculate predictions for articles missing them"
  task calculate_missing: :environment do
    puts "=" * 80
    puts "Calculating Missing Predictions"
    puts "=" * 80

    articles = Article.where(predicted_performance_score: nil).order(published_at: :desc)
    total = articles.count

    puts "Found #{total} articles without predictions\n\n"

    success = 0
    failed = 0

    articles.find_each.with_index do |article, index|
      print "Processing #{index + 1}/#{total}: #{article.msid}..."

      begin
        prediction = article.calculate_prediction!
        score = prediction[:predicted_performance_score]
        method = prediction[:calculation_method]
        puts " ✓ Score: #{score.round(1)} (#{method})"
        success += 1
      rescue StandardError => e
        puts " ✗ #{e.message}"
        failed += 1
      end

      sleep(0.1) if (index + 1) % 10 == 0
    end

    puts "\n" + ("=" * 80)
    puts "RESULTS:"
    puts "  ✓ Success: #{success}"
    puts "  ✗ Failed: #{failed}"
    puts "=" * 80
  end

  desc "Show prediction statistics"
  task stats: :environment do
    puts "=" * 80
    puts "PREDICTION STATISTICS"
    puts "=" * 80

    total = Article.count
    with_predictions = Article.where.not(predicted_performance_score: nil).count
    without_predictions = total - with_predictions

    similarity_based = Article.where("prediction_metadata->>'method' = ?", 'similarity').count
    default_based = Article.where("prediction_metadata->>'method' = ?", 'default').count

    avg_score = Article.where.not(predicted_performance_score: nil).average(:predicted_performance_score)

    puts "\nARTICLES:"
    puts "  Total: #{total}"
    puts "  With predictions: #{with_predictions}"
    puts "  Without predictions: #{without_predictions}"

    puts "\nPREDICTION METHODS:"
    puts "  Similarity-based: #{similarity_based}"
    puts "  Default (no similar articles): #{default_based}"

    puts "\nSCORES:"
    puts "  Average predicted score: #{avg_score&.round(2) || 'N/A'}"

    # Top predicted articles
    top_articles = Article.where.not(predicted_performance_score: nil)
                          .order(predicted_performance_score: :desc)
                          .limit(5)

    if top_articles.any?
      puts "\nTOP 5 PREDICTED PERFORMERS:"
      top_articles.each_with_index do |article, index|
        puts "  #{index + 1}. [#{article.predicted_performance_score.round(1)}] #{article.truncated_title(60)}"
      end
    end

    puts "=" * 80
  end
end
