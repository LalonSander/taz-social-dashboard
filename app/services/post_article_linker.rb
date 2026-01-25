# app/services/post_article_linker.rb

class PostArticleLinker
  class LinkerError < StandardError; end

  # Link a single post to its article
  # Returns true if linked, false if no article found
  def self.link_post(post)
    new.link_post(post)
  end

  # Link all unlinked posts that have taz.de URLs
  def self.link_all_unlinked_posts
    new.link_all_unlinked_posts
  end

  # Link all posts (including re-linking)
  def self.link_all_posts
    new.link_all_posts
  end

  def initialize
    @stats = {
      linked: 0,
      already_linked: 0,
      not_taz_link: 0,
      no_msid: 0,
      article_not_found: 0,
      article_created: 0,
      errors: 0
    }
  end

  # Link a single post
  def link_post(post)
    # Skip if no external URL
    unless post.external_url.present?
      Rails.logger.debug "Post #{post.id} has no external_url"
      return false
    end

    # Skip if not a taz.de link
    unless post.taz_article_link?
      @stats[:not_taz_link] += 1
      Rails.logger.debug "Post #{post.id} external_url is not a taz.de link"
      return false
    end

    # Extract msid from URL
    msid = post.extract_msid_from_external_url

    unless msid
      @stats[:no_msid] += 1
      Rails.logger.warn "Could not extract msid from URL: #{post.external_url}"
      return false
    end

    # Find or create article
    article = find_or_create_article(msid)

    unless article
      @stats[:article_not_found] += 1
      Rails.logger.warn "Could not find or create article for msid: #{msid}"
      return false
    end

    # Link post to article
    if post.article_id == article.id
      @stats[:already_linked] += 1
      Rails.logger.debug "Post #{post.id} already linked to article #{article.id}"
      return true
    end

    if post.update(article: article)
      @stats[:linked] += 1
      Rails.logger.info "Linked post #{post.id} to article #{article.id} (#{article.truncated_title(50)})"
      true
    else
      @stats[:errors] += 1
      Rails.logger.error "Failed to link post #{post.id} to article #{article.id}: #{post.errors.full_messages.join(', ')}"
      false
    end
  rescue StandardError => e
    @stats[:errors] += 1
    Rails.logger.error "Error linking post #{post.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  # Link all unlinked posts
  def link_all_unlinked_posts
    posts = Post.without_articles.with_links

    Rails.logger.info "Linking #{posts.count} unlinked posts..."

    posts.find_each do |post|
      link_post(post)
    end

    log_stats
    @stats
  end

  # Link all posts (including re-linking)
  def link_all_posts
    posts = Post.with_links

    Rails.logger.info "Linking all #{posts.count} posts with external URLs..."

    posts.find_each do |post|
      link_post(post)
    end

    log_stats
    @stats
  end

  private

  # Find existing article or create from XML scraper
  def find_or_create_article(msid)
    # Try to find existing article
    article = Article.find_by(msid: msid)

    return article if article

    # Article doesn't exist, try to fetch from XML
    Rails.logger.info "Article #{msid} not found, attempting to fetch from XML..."

    article_data = Taz::XmlScraper.scrape_article(msid)

    unless article_data
      Rails.logger.error "Failed to scrape article #{msid} from XML"
      return nil
    end

    # Create article from scraped data
    article = Article.new(article_data)

    if article.save
      @stats[:article_created] += 1
      Rails.logger.info "Created article #{msid} from XML: #{article.truncated_title(50)}"
      article
    else
      Rails.logger.error "Failed to save article #{msid}: #{article.errors.full_messages.join(', ')}"
      nil
    end
  end

  # Log statistics summary
  def log_stats
    Rails.logger.info "Post-Article Linking Complete:"
    Rails.logger.info "  - Linked: #{@stats[:linked]}"
    Rails.logger.info "  - Already linked: #{@stats[:already_linked]}"
    Rails.logger.info "  - Articles created from XML: #{@stats[:article_created]}"
    Rails.logger.info "  - Not taz.de links: #{@stats[:not_taz_link]}"
    Rails.logger.info "  - No msid found: #{@stats[:no_msid]}"
    Rails.logger.info "  - Article not found: #{@stats[:article_not_found]}"
    Rails.logger.info "  - Errors: #{@stats[:errors]}"
  end
end
