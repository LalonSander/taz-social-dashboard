# app/services/text_similarity/german_preprocessor.rb - ALTERNATIVE WITH BUILT-IN STOPWORDS

module TextSimilarity
  class GermanPreprocessor
    # Common German stopwords and journalism jargon
    GERMAN_STOPWORDS = %w[
      debatte debatten dossier neues empörung kritik aktion krise krisen skandal
      skandale diskussion diskussionen bericht berichte berichten beschluss beschwerde
      analyse analysen hintergrund stadt beschuldigt hintergründe ereignis ereignisse
      vorfall vorfälle thema themen entwicklung entwicklungen situation situationen
      kommentar kommentare meldung meldungen aussage aussagen mitteilung mitteilungen
      information informationen darstellung darstellungen überblick überblicke reaktion
      reaktionen bewertung bewertungen berichterstattung angabe angaben erklärung
      erklärungen diskurs diskurse gespräch gespräche interview interviews streit
      streitigkeiten konflikt konflikte affäre affären auseinandersetzung
      auseinandersetzungen beobachtung beobachtungen feststellung feststellungen
      einschätzung einschätzungen prognose prognosen darlegung darlegungen verlauf
      verläufe anlass anlässe forderung forderungen appell appelle hinweis hinweise
      beschreibung beschreibungen zusammenfassung zusammenfassungen quelle quellen
      botschaft botschaften nachricht nachrichten tendenz tendenzen äußerung äußerungen
      auswertung auswertungen stellungnahme stellungnahmen ankündigung ankündigungen
      entscheidung entscheidungen maßnahme maßnahmen vorgang vorgänge umstand umstände
      aspekt aspekte rahmen kontext detail details einzelheit einzelheiten zusammenhang
      zusammenhänge ausmaß ausmaße bedeutung bedeutungen wirkung wirkungen folge folgen
      auswirkung auswirkungen relevanz sachverhalt sachverhalte sachlage ablauf abläufe
      fazit fazite ergebnis ergebnisse beurteilung beurteilungen gesamtbild tatsache
      tatsachen zusatz erweiterung erweiterungen zustand zustände recherche recherchen
      schilderung schilderungen erörterung erörterungen klarstellung klarstellungen
      übersicht übersichten chronik chroniken aktualität publikation publikationen
      veröffentlichung veröffentlichungen verlautbarung verlautbarungen redaktion
      agentur agenturen korrespondent korrespondenten beitrag beiträge experte experten
      beobachter beobachterin beobachterinnen aber alle allem allen aller alles als
      also am an ander andere anderem anderen anderer anderes anderm andern anderr
      anders anstatt auch auf aus bei bin bis bist da damit dann das dass daß der den
      des dem die derselbe derselben denselben desselben demselben dieselbe dieselben
      dasselbe dazu dein deine deinem deinen deiner deines denn derer dessen dich
      dies diese diesem diesen dieser dieses dir doch dort du durch ein eine einem
      einen einer eines einig einige einigem einigen einiger einiges einmal er es
      etwa etwas euch euer eure eurem euren eurer eures für gegen gewesen hab habe
      haben hat hatte hatten hier hin hinter ich mich mir ihm ihn ihnen ihr ihre
      ihrem ihren ihrer ihres im in indem ins ist ja jede jedem jeden jeder jedes
      jene jenem jenen jener jenes jetzt kann kein keine keinem keinen keiner keines
      können könnte machen man manche manchem manchen mancher manches mein meine
      meinem meinen meiner meines mit muss musste nach nicht nichts noch nun nur ob
      oder ohne sehr sein seine seinem seinen seiner seines selbst seit sich sie
      sind so solche solchem solchen solcher soll sollte sondern sonst sowie über
      um und uns unse unsem unsen unser unsere unses unter viel vom von vor während
      war waren warst was weg weil weiter welche welchem welchen welcher welches
      wem wen wenig wenn wer werde werden wie wieder will wir wird wirst wo wollen
      wollte womit wovon würde würden zu zum zur zwar zwischen
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
