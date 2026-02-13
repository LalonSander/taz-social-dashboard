# app/services/text_similarity/calculator.rb

module TextSimilarity
  class Calculator
    # Calculate similarity between two articles using IDF-weighted cosine similarity
    # Returns score from 0 to 1
    def self.calculate_similarity(article1, article2, term_rarity:)
      tokens1 = GermanPreprocessor.preprocess(article1)
      tokens2 = GermanPreprocessor.preprocess(article2)

      return 0.0 if tokens1.empty? || tokens2.empty?

      # Calculate IDF-weighted cosine similarity
      weighted_cosine_similarity(tokens1, tokens2, term_rarity)

      # Simplified: use unweighted cosine similarity
      # weighted_cosine_similarity(tokens1, tokens2, {})
    end

    # Find similar articles to a given article
    # Returns array of hashes with article and similarity_score
    def self.find_similar_articles(target_article, candidates, min_similarity: 0.2)
      results = []

      # Calculate term rarity ONCE for all candidates
      term_rarity = calculate_term_rarity(candidates)

      candidates.each do |candidate|
        next if candidate.id == target_article.id

        similarity = calculate_similarity(
          target_article,
          candidate,
          term_rarity: term_rarity # Pass pre-calculated rarity
        )

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

    # Calculate term rarity (IDF) across all candidate articles
    # Returns hash of term => rarity_score
    def self.calculate_term_rarity(candidates)
      # Combine all candidate text into one big string
      combined_text = candidates.map do |candidate|
        GermanPreprocessor.combine_text(candidate)
      end.join(' ')

      # Preprocess once
      all_tokens = GermanPreprocessor.tokenize(combined_text)
      all_tokens = GermanPreprocessor.remove_stopwords(all_tokens)

      # Count term frequency - using tally (Ruby 2.7+)
      term_counts = all_tokens.tally

      # Calculate IDF-like score based on total frequency
      # Lower frequency = higher rarity = higher weight
      max_count = term_counts.values.max.to_f

      term_counts.transform_values do |count|
        Math.log(max_count / count)
      end
    end

    # Calculate IDF-weighted cosine similarity between two token arrays
    def self.weighted_cosine_similarity(tokens1, tokens2, term_rarity)
      # Build vocabulary from both documents
      vocabulary = (tokens1 + tokens2).uniq

      # Calculate term frequencies for each document
      tf1 = calculate_term_frequency(tokens1, vocabulary)
      tf2 = calculate_term_frequency(tokens2, vocabulary)

      # Calculate weighted cosine similarity
      dot_product = 0.0
      magnitude1 = 0.0
      magnitude2 = 0.0

      vocabulary.each do |term|
        # Get IDF weight (default to 1.0 if term not in rarity hash)
        idf_weight = term_rarity[term] || 1.0

        # Weight the term frequencies by IDF
        weighted_tf1 = tf1[term] * idf_weight
        weighted_tf2 = tf2[term] * idf_weight

        dot_product += weighted_tf1 * weighted_tf2
        magnitude1 += weighted_tf1**2
        magnitude2 += weighted_tf2**2
      end

      return 0.0 if magnitude1.zero? || magnitude2.zero?

      dot_product / (Math.sqrt(magnitude1) * Math.sqrt(magnitude2))
    end

    # Calculate term frequency for tokens
    # Returns hash of term => frequency
    def self.calculate_term_frequency(tokens, vocabulary)
      token_count = tokens.size.to_f

      # Count occurrences and normalize in one step
      term_frequency = tokens.tally.transform_values { |count| count / token_count }

      # Fill in zeros for missing terms in vocabulary
      vocabulary.each do |term|
        term_frequency[term] ||= 0.0
      end

      term_frequency
    end
  end
end
