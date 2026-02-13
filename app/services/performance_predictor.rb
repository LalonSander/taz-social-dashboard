# app/services/performance_predictor.rb - FIXED VERSION

class PerformancePredictor
  SIMILARITY_THRESHOLD = 0.2
  MAX_ARTICLE_AGE_MONTHS = 3
  DECAY_CONSTANT = 0.3 # Lambda for exponential decay
  DEFAULT_SCORE = 100.0 # Baseline average when no similar articles found

  # Main prediction method
  # Returns hash with predicted score and metadata
  def self.predict_for_article(article)
    new(article).predict
  end

  def initialize(article)
    @article = article
  end

  def predict
    # Find similar articles
    similar_articles = find_similar_articles

    # If no similar articles found, return default
    return default_prediction if similar_articles.empty?

    # Calculate weighted prediction
    predicted_score = calculate_weighted_prediction(similar_articles)

    {
      predicted_performance_score: predicted_score.round(2),
      similar_articles_used: similar_articles.map { |sa| sa[:article].id },
      similar_articles_count: similar_articles.length,
      calculation_method: 'similarity',
      similar_articles_details: similar_articles.map do |sa|
        {
          id: sa[:article].id,
          title: sa[:article].title,
          similarity: sa[:similarity].round(3),
          recency_weight: sa[:recency_weight].round(3),
          avg_performance: sa[:avg_performance].round(2)
        }
      end
    }
  end

  private

  # Find articles similar to target article
  def find_similar_articles
    # Get candidate articles from 3 months BEFORE the target article's publication
    # This simulates what we would have known at the time of prediction
    cutoff_date = @article.published_at - MAX_ARTICLE_AGE_MONTHS.months

    candidates = Article
                 .joins(:posts)
                 .joins('INNER JOIN social_accounts ON posts.social_account_id = social_accounts.id')
                 .where('articles.published_at > ?', cutoff_date)
                 .where('articles.published_at < ?', @article.published_at) # Only past articles
                 .where.not(id: @article.id)
                 .where("posts.platform_url ILIKE '%' || social_accounts.handle || '%'") # Only posts from our accounts
                 .distinct

    puts candidates.count

    return [] if candidates.empty?

    # Calculate similarity for each candidate
    similar = TextSimilarity::Calculator.find_similar_articles(
      @article,
      candidates,
      min_similarity: SIMILARITY_THRESHOLD
    )

    # Add performance and recency data
    similar.map do |item|
      article = item[:article]

      {
        article: article,
        similarity: item[:similarity],
        recency_weight: calculate_recency_weight(article),
        avg_performance: calculate_article_performance(article)
      }
    end.reject { |item| item[:avg_performance].nil? }
  end

  # Calculate exponential decay weight based on article age
  # weight = e^(-λ * months_old)
  # With λ = 0.3:
  # - 1 month old: 0.74 weight
  # - 2 months old: 0.55 weight
  # - 3 months old: 0.41 weight
  def calculate_recency_weight(article)
    months_old = (Time.current - article.published_at) / 1.month
    Math.exp(-DECAY_CONSTANT * months_old)
  end

  # Calculate average overperformance score for an article's posts
  def calculate_article_performance(article)
    posts = article.posts.where.not(overperformance_score_cache: nil)

    return nil if posts.empty?

    scores = posts.pluck(:overperformance_score_cache)
    scores.sum / scores.size.to_f
  end

  # Calculate weighted average prediction
  # Formula: SUM(performance * similarity * recency) / SUM(similarity * recency)
  def calculate_weighted_prediction(similar_articles)
    weighted_sum = 0.0
    weight_sum = 0.0

    similar_articles.each do |item|
      performance = item[:avg_performance]
      similarity = item[:similarity]
      recency = item[:recency_weight]

      combined_weight = similarity * recency
      weighted_sum += performance * combined_weight
      weight_sum += combined_weight
    end

    return DEFAULT_SCORE if weight_sum.zero?

    weighted_sum / weight_sum
  end

  # Return default prediction when no similar articles found
  def default_prediction
    {
      predicted_performance_score: DEFAULT_SCORE,
      similar_articles_used: [],
      similar_articles_count: 0,
      calculation_method: 'default',
      similar_articles_details: []
    }
  end
end
