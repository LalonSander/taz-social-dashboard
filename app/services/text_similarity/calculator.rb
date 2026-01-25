# app/services/text_similarity/calculator.rb - SIMPLIFIED VERSION

module TextSimilarity
  class Calculator
    # Calculate similarity between two articles (on-the-fly)
    # Returns score from 0 to 1
    def self.calculate_similarity(article1, article2)
      tokens1 = GermanPreprocessor.preprocess(article1)
      tokens2 = GermanPreprocessor.preprocess(article2)

      return 0.0 if tokens1.empty? || tokens2.empty?

      # Calculate Jaccard similarity
      cosine_similarity(tokens1, tokens2)
    end

    # Find similar articles to a given article
    # Returns array of hashes with article and similarity_score
    def self.find_similar_articles(target_article, candidates, min_similarity: 0.1)
      results = []

      candidates.each do |candidate|
        next if candidate.id == target_article.id

        similarity = calculate_similarity(target_article, candidate)

        next unless similarity >= min_similarity

        results << {
          article: candidate,
          similarity: similarity
        }
      end

      # Sort by similarity descending
      results.sort_by { |r| -r[:similarity] }
    end

    private

    # Calculate Jaccard similarity between two token arrays
    def self.jaccard_similarity(tokens1, tokens2)
      set1 = tokens1.to_set
      set2 = tokens2.to_set

      intersection = set1 & set2
      return 0.0 if intersection.empty?

      union = set1 | set2
      intersection.size.to_f / union.size.to_f
    end

    # Alternative: TF-IDF weighted cosine similarity
    # Uncomment to use this instead of Jaccard
    def self.cosine_similarity(tokens1, tokens2)
      # Build vocabulary
      vocab = (tokens1 + tokens2).uniq

      # Calculate term frequencies
      tf1 = calculate_tf(tokens1, vocab)
      tf2 = calculate_tf(tokens2, vocab)

      # Calculate cosine similarity
      dot_product = 0.0
      magnitude1 = 0.0
      magnitude2 = 0.0

      vocab.each do |term|
        dot_product += tf1[term] * tf2[term]
        magnitude1 += tf1[term]**2
        magnitude2 += tf2[term]**2
      end

      return 0.0 if magnitude1.zero? || magnitude2.zero?

      dot_product / (Math.sqrt(magnitude1) * Math.sqrt(magnitude2))
    end

    def self.calculate_tf(tokens, vocab)
      tf = Hash.new(0.0)
      token_count = tokens.size.to_f

      tokens.each do |token|
        tf[token] += 1.0 / token_count
      end

      # Fill in zeros for missing terms
      vocab.each do |term|
        tf[term] ||= 0.0
      end

      tf
    end
  end
end
