# app/services/taz/xml_scraper.rb

module Taz
  class XmlScraper
    include HTTParty

    base_uri 'https://taz.de'

    class ScraperError < StandardError; end

    # Scrape a single article by msid
    # Returns hash of article data or nil on error
    def self.scrape_article(msid)
      new.scrape_article(msid)
    end

    def scrape_article(msid)
      url = "https://taz.de/!#{msid}/c.xml"

      Rails.logger.info "Scraping article XML: #{url}"

      begin
        response = HTTParty.get(url, timeout: 30)

        unless response.success?
          Rails.logger.error "HTTP #{response.code} error fetching XML for msid #{msid}"
          return nil
        end

        parse_xml(response.body, msid)
      rescue HTTParty::Error => e
        Rails.logger.error "HTTP error scraping msid #{msid}: #{e.message}"
        nil
      rescue StandardError => e
        Rails.logger.error "Error scraping msid #{msid}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        nil
      end
    end

    # Scrape and update an existing article
    def self.refresh_article(article)
      new.refresh_article(article)
    end

    def refresh_article(article)
      data = scrape_article(article.msid)

      return false unless data

      article.update(
        title: data[:title],
        lead: data[:lead],
        published_at: data[:published_at],
        cms_id: data[:cms_id], # ADDED
        last_refreshed_at: Time.current
      )

      Rails.logger.info "Refreshed article #{article.msid} from XML"
      true
    rescue StandardError => e
      Rails.logger.error "Failed to refresh article #{article.msid}: #{e.message}"
      false
    end

    private

    # Parse XML content and extract article data
    def parse_xml(xml_content, msid)
      doc = Nokogiri::XML(xml_content)

      # Extract fields from XML structure
      article_data = {
        msid: msid,
        title: extract_title(doc),
        lead: extract_lead(doc),
        published_at: extract_published_date(doc),
        cms_id: extract_cms_id(doc) # ADDED
      }

      # Validate required fields
      unless article_data[:title].present? && article_data[:published_at].present?
        Rails.logger.error "Missing required fields in XML for msid #{msid}"
        return nil
      end

      article_data
    rescue Nokogiri::XML::SyntaxError => e
      Rails.logger.error "XML parsing error for msid #{msid}: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Error parsing XML for msid #{msid}: #{e.message}"
      nil
    end

    # Extract title (kicker + headline combined)
    def extract_title(doc)
      kicker = doc.at_xpath('//item/kicker')&.text&.strip
      headline = doc.at_xpath('//item/headline')&.text&.strip

      return nil unless headline.present?

      # Combine kicker and headline (matching RSS format)
      if kicker.present?
        "#{kicker}: #{headline}"
      else
        headline
      end
    end

    # Extract lead text
    def extract_lead(doc)
      lead = doc.at_xpath('//item/lead')&.text&.strip
      lead.presence
    end

    # Extract CMS ID
    # XML path: //content/*/meta/id[@scope="cms-obj"]
    def extract_cms_id(doc)
      cms_id_node = doc.at_xpath('//content/*/meta/id[@scope="cms-obj"]')
      cms_id_node&.text&.strip
    end

    # Extract published date
    # XML path: //item/meta/published/dt/date
    def extract_published_date(doc)
      date_node = doc.at_xpath('//item/meta/published/dt/date')

      return nil unless date_node

      date_text = date_node.text.strip

      # Parse date - try multiple formats
      parse_date(date_text)
    end

    # Parse date from various possible formats
    def parse_date(date_string)
      return nil if date_string.blank?

      # Try ISO 8601 format first
      Time.zone.parse(date_string)
    rescue ArgumentError
      # Try other common formats
      begin
        DateTime.parse(date_string)
      rescue ArgumentError => e
        Rails.logger.error "Could not parse date: #{date_string}"
        nil
      end
    end
  end
end
