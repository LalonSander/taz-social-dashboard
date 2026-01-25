# app/controllers/analysis_controller.rb - ADD CLASSIFICATION METRICS

class AnalysisController < ApplicationController
  before_action :authenticate_user!

  def predictions
    # Get articles that have both:
    # 1. Predicted performance score (not default 100%)
    # 2. At least one post with actual performance score
    @articles = Article
                .joins(:posts)
                .where.not(predicted_performance_score: nil)
                .where.not(predicted_performance_score: 100.0) # Exclude default predictions
                .where.not(posts: { overperformance_score_cache: nil })
                .distinct
                .includes(:posts)

    # Calculate actual performance for each article
    @data_points = @articles.map do |article|
      # Get best performing post for this article
      best_post = article.posts
                         .where.not(overperformance_score_cache: nil)
                         .order(overperformance_score_cache: :desc)
                         .first

      next unless best_post

      predicted = article.predicted_performance_score.to_f
      actual = best_post.overperformance_score_cache.to_f

      # Skip if either predicted or actual is over 250%
      next if predicted > 250 || actual > 250

      {
        article_id: article.id,
        article_title: article.truncated_title(60),
        predicted: predicted,
        actual: actual,
        posts_count: article.posts.count,
        predicted_above: predicted > 100,
        actual_above: actual > 100
      }
    end.compact

    # Calculate statistics
    calculate_statistics
    calculate_classification_metrics
  end

  private

  def calculate_statistics
    return if @data_points.empty?

    predicted = @data_points.map { |p| p[:predicted] }
    actual = @data_points.map { |p| p[:actual] }

    # Mean Absolute Error
    @mae = @data_points.map { |p| (p[:predicted] - p[:actual]).abs }.sum / @data_points.size

    # Root Mean Squared Error
    squared_errors = @data_points.map { |p| (p[:predicted] - p[:actual])**2 }
    @rmse = Math.sqrt(squared_errors.sum / @data_points.size)

    # Correlation coefficient
    @correlation = calculate_correlation(predicted, actual)

    # Summary stats
    @total_articles = @data_points.size
    @avg_predicted = predicted.sum / predicted.size
    @avg_actual = actual.sum / actual.size
  end

  def calculate_classification_metrics
    return if @data_points.empty?

    # Confusion matrix for above/below 100%
    @true_positives = @data_points.count { |p| p[:predicted_above] && p[:actual_above] }
    @true_negatives = @data_points.count { |p| !p[:predicted_above] && !p[:actual_above] }
    @false_positives = @data_points.count { |p| p[:predicted_above] && !p[:actual_above] }
    @false_negatives = @data_points.count { |p| !p[:predicted_above] && p[:actual_above] }

    # Accuracy: (TP + TN) / Total
    @accuracy = ((@true_positives + @true_negatives).to_f / @data_points.size * 100).round(1)

    # Precision: TP / (TP + FP)
    @precision = if (@true_positives + @false_positives) > 0
                   (@true_positives.to_f / (@true_positives + @false_positives) * 100).round(1)
                 else
                   0
                 end

    # Recall: TP / (TP + FN)
    @recall = if (@true_positives + @false_negatives) > 0
                (@true_positives.to_f / (@true_positives + @false_negatives) * 100).round(1)
              else
                0
              end

    # F1 Score: 2 * (Precision * Recall) / (Precision + Recall)
    @f1_score = if (@precision + @recall) > 0
                  (2 * @precision * @recall / (@precision + @recall)).round(1)
                else
                  0
                end
  end

  def calculate_correlation(x, y)
    n = x.size
    return 0 if n == 0

    sum_x = x.sum
    sum_y = y.sum
    sum_xy = x.zip(y).map { |a, b| a * b }.sum
    sum_x2 = x.map { |a| a**2 }.sum
    sum_y2 = y.map { |a| a**2 }.sum

    numerator = (n * sum_xy) - (sum_x * sum_y)
    denominator = Math.sqrt(((n * sum_x2) - (sum_x**2)) * ((n * sum_y2) - (sum_y**2)))

    return 0 if denominator.zero?

    numerator / denominator
  end
end
