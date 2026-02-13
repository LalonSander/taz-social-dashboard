# app/services/text_similarity/calculator.rb

module TextSimilarity
  class Calculator
    # Calculate similarity between two articles using IDF-weighted cosine similarity
    # Returns score from 0 to 1
    def self.calculate_similarity(article1, article2, all_candidates:)
      tokens1 = GermanPreprocessor.preprocess(article1)
      tokens2 = GermanPreprocessor.preprocess(article2)

      return 0.0 if tokens1.empty? || tokens2.empty?

      # Calculate term rarity (IDF) across all candidate articles
      term_rarity = calculate_term_rarity(all_candidates)

      # Calculate IDF-weighted cosine similarity
      weighted_cosine_similarity(tokens1, tokens2, term_rarity)
    end

    # Find similar articles to a given article
    # Returns array of hashes with article and similarity_score
    def self.find_similar_articles(target_article, candidates, min_similarity: 0.1)
      results = []

      candidates.each do |candidate|
        next if candidate.id == target_article.id

        similarity = calculate_similarity(
          target_article,
          candidate,
          all_candidates: candidates
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
      document_frequency = Hash.new(0)
      total_documents = candidates.size.to_f

      # Count how many documents each term appears in
      candidates.each do |candidate|
        tokens = GermanPreprocessor.preprocess(candidate)
        unique_tokens = tokens.uniq

        unique_tokens.each do |token|
          document_frequency[token] += 1
        end
      end

      # Calculate IDF score for each term
      # IDF = log(total_documents / document_frequency)
      # Higher score = rarer term = more important
      term_rarity = {}

      document_frequency.each do |term, freq|
        term_rarity[term] = Math.log(total_documents / freq)
      end

      term_rarity
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
      term_frequency = Hash.new(0.0)
      token_count = tokens.size.to_f

      tokens.each do |token|
        term_frequency[token] += 1.0 / token_count
      end

      # Fill in zeros for missing terms in vocabulary
      vocabulary.each do |term|
        term_frequency[term] ||= 0.0
      end

      term_frequency
    end
  end
end
