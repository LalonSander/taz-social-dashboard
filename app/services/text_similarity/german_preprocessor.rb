# app/services/text_similarity/german_preprocessor.rb - ALTERNATIVE WITH BUILT-IN STOPWORDS

module TextSimilarity
  class GermanPreprocessor
    # Common German stopwords
    GERMAN_STOPWORDS = %w[
      aber alle allem allen aller alles als also am an ander andere anderem anderen
      anderer anderes anderm andern anderr anders auch auf aus bei bin bis bist da
      damit dann der den des dem die das daß derselbe derselben denselben desselben
      demselben dieselbe dieselben dasselbe dazu dein deine deinem deinen deiner
      deines denn derer dessen dich die dies diese diesem diesen dieser dieses dir
      doch dort durch ein eine einem einen einer eines einig einige einigem einigen
      einiger einiges einmal er ihn ihm es etwas euer eure eurem euren eurer eures
      für gegen gewesen hab habe haben hat hatte hatten hier hin hinter ich mich mir
      ihr ihre ihrem ihren ihrer ihres euch im in indem ins ist jede jedem jeden
      jeder jedes jene jenem jenen jener jenes jetzt kann kein keine keinem keinen
      keiner keines können könnte machen man manche manchem manchen mancher manches
      mein meine meinem meinen meiner meines mit muss musste nach nicht nichts noch
      nun nur ob oder ohne sehr sein seine seinem seinen seiner seines selbst sich
      sie sind so solche solchem solchen solcher solches soll sollte sondern sonst
      über um und uns unse unsem unsen unser unses unter viel vom von vor während
      war waren warst was weg weil weiter welche welchem welchen welcher welches
      wenn wer werde werden wie wieder will wir wird wirst wo wollen wollte würde
      würden zu zum zur zwar zwischen
    ].freeze

    # Combine title and lead, clean and tokenize
    def self.preprocess(article)
      text = combine_text(article)
      tokens = tokenize(text)
      remove_stopwords(tokens)
    end

    # Combine title and lead into single text
    def self.combine_text(article)
      parts = []
      parts << article.title if article.title.present?
      parts << article.lead if article.lead.present?

      parts.join(' ')
    end

    # Tokenize text into words
    def self.tokenize(text)
      return [] if text.blank?

      # keep only capitalized words

      words = text.scan(/\b[A-Z][a-zA-Z]{2,}\b/)

      words.map(&:downcase)

      # Remove empty strings and very short words (< 3 chars)
      words.reject { |w| w.length < 3 }
    end

    # Remove German stopwords
    def self.remove_stopwords(tokens)
      return [] if tokens.empty?

      tokens.reject { |token| GERMAN_STOPWORDS.include?(token.downcase) }
    end
  end
end
