# lib/tasks/articles.rake - ADD this new task

namespace :articles do
  desc "Link first N posts to articles (specify limit with LIMIT=100)"
  task :link_first_posts, [:limit] => :environment do |t, args|
    limit = (args[:limit] || ENV['LIMIT'] || 100).to_i

    puts "=" * 80
    puts "Linking First #{limit} Posts to Articles"
    puts "=" * 80

    # Get posts ordered by posted_at descending (most recent first)
    # Only posts with external URLs
    posts = Post.with_links.order(posted_at: :desc).limit(limit)

    puts "Selected #{posts.count} posts (most recent with external URLs)\n\n"

    stats = {
      linked: 0,
      already_linked: 0,
      not_taz_link: 0,
      no_msid: 0,
      article_not_found: 0,
      article_created: 0,
      errors: 0
    }

    posts.each_with_index do |post, index|
      print "Processing #{index + 1}/#{limit}: Post ##{post.id}..."

      # Skip if already linked
      if post.article_id.present?
        puts " ✓ Already linked to article #{post.article_id}"
        stats[:already_linked] += 1
        next
      end

      # Skip if no external URL
      unless post.external_url.present?
        puts " - No external URL"
        next
      end

      # Skip if not taz.de link
      unless post.taz_article_link?
        puts " - Not taz.de link"
        stats[:not_taz_link] += 1
        next
      end

      # Extract msid
      msid = post.extract_msid_from_external_url
      unless msid
        puts " ⚠ Could not extract MSID from #{post.external_url}"
        stats[:no_msid] += 1
        next
      end

      # Find or create article
      article = Article.find_by(msid: msid)

      unless article
        print " Creating article #{msid}..."
        article_data = Taz::XmlScraper.scrape_article(msid)

        if article_data
          article = Article.create(article_data)
          if article.persisted?
            stats[:article_created] += 1
            print " created..."
          else
            puts " ✗ Failed to create: #{article.errors.full_messages.join(', ')}"
            stats[:errors] += 1
            next
          end
        else
          puts " ✗ Could not scrape article"
          stats[:article_not_found] += 1
          next
        end
      end

      # Link post to article
      if post.update(article: article)
        puts " ✓ Linked to article #{article.id} (#{article.truncated_title(50)})"
        stats[:linked] += 1
      else
        puts " ✗ Failed to link: #{post.errors.full_messages.join(', ')}"
        stats[:errors] += 1
      end

      # Rate limiting - small delay every 10 posts
      sleep(0.3) if (index + 1) % 10 == 0
    end

    puts "\n" + ("=" * 80)
    puts "RESULTS:"
    puts "  ✓ Newly linked: #{stats[:linked]}"
    puts "  - Already linked: #{stats[:already_linked]}"
    puts "  + Articles created: #{stats[:article_created]}"
    puts "  ⚠ Not taz.de links: #{stats[:not_taz_link]}"
    puts "  ⚠ No MSID found: #{stats[:no_msid]}"
    puts "  ✗ Article not found: #{stats[:article_not_found]}"
    puts "  ✗ Errors: #{stats[:errors]}"
    puts "=" * 80
  end

  desc "Link recent posts (from last N days, specify with DAYS=7)"
  task :link_recent_posts, [:days] => :environment do |t, args|
    days = (args[:days] || ENV['DAYS'] || 30).to_i

    puts "=" * 80
    puts "Linking Posts from Last #{days} Days"
    puts "=" * 80

    posts = Post.with_links
                .where('posted_at > ?', days.days.ago)
                .order(posted_at: :desc)

    total = posts.count
    puts "Found #{total} posts with external URLs from last #{days} days\n\n"

    stats = {
      linked: 0,
      already_linked: 0,
      not_taz_link: 0,
      no_msid: 0,
      article_not_found: 0,
      article_created: 0,
      errors: 0
    }

    posts.find_each.with_index do |post, index|
      print "Processing #{index + 1}/#{total}: Post ##{post.id}..."

      # Skip if already linked
      if post.article_id.present?
        puts " ✓ Already linked"
        stats[:already_linked] += 1
        next
      end

      # Skip if not taz.de
      unless post.taz_article_link?
        puts " - Not taz.de"
        stats[:not_taz_link] += 1
        next
      end

      # Extract and link
      msid = post.extract_msid_from_external_url
      unless msid
        puts " ⚠ No MSID"
        stats[:no_msid] += 1
        next
      end

      article = Article.find_by(msid: msid)

      unless article
        article_data = Taz::XmlScraper.scrape_article(msid)
        if article_data
          article = Article.create(article_data)
          stats[:article_created] += 1 if article.persisted?
        end
      end

      unless article
        puts " ✗ No article"
        stats[:article_not_found] += 1
        next
      end

      if post.update(article: article)
        puts " ✓ Linked"
        stats[:linked] += 1
      else
        puts " ✗ Error"
        stats[:errors] += 1
      end

      sleep(0.3) if (index + 1) % 10 == 0
    end

    puts "\n" + ("=" * 80)
    puts "RESULTS:"
    puts "  ✓ Newly linked: #{stats[:linked]}"
    puts "  - Already linked: #{stats[:already_linked]}"
    puts "  + Articles created: #{stats[:article_created]}"
    puts "  ⚠ Not taz.de links: #{stats[:not_taz_link]}"
    puts "  ⚠ No MSID found: #{stats[:no_msid]}"
    puts "  ✗ Article not found: #{stats[:article_not_found]}"
    puts "  ✗ Errors: #{stats[:errors]}"
    puts "=" * 80
  end

  desc "Link posts in batches (BATCH_SIZE=100 BATCHES=5)"
  task :link_posts_batched, %i[batch_size batches] => :environment do |t, args|
    batch_size = (args[:batch_size] || ENV['BATCH_SIZE'] || 100).to_i
    num_batches = (args[:batches] || ENV['BATCHES'] || 1).to_i

    puts "=" * 80
    puts "Linking Posts in Batches"
    puts "Batch size: #{batch_size}, Number of batches: #{num_batches}"
    puts "=" * 80

    total_stats = {
      linked: 0,
      already_linked: 0,
      not_taz_link: 0,
      no_msid: 0,
      article_not_found: 0,
      article_created: 0,
      errors: 0
    }

    num_batches.times do |batch_num|
      offset = batch_num * batch_size

      puts "\n" + ("-" * 80)
      puts "BATCH #{batch_num + 1}/#{num_batches} (offset: #{offset})"
      puts "-" * 80

      posts = Post.with_links
                  .order(posted_at: :desc)
                  .limit(batch_size)
                  .offset(offset)

      if posts.empty?
        puts "No more posts to process"
        break
      end

      puts "Processing #{posts.count} posts...\n"

      posts.each_with_index do |post, index|
        global_index = offset + index + 1
        print "[#{global_index}] Post ##{post.id}..."

        if post.article_id.present?
          puts " ✓ Already linked"
          total_stats[:already_linked] += 1
          next
        end

        unless post.taz_article_link?
          puts " - Not taz.de"
          total_stats[:not_taz_link] += 1
          next
        end

        msid = post.extract_msid_from_external_url
        unless msid
          puts " ⚠ No MSID"
          total_stats[:no_msid] += 1
          next
        end

        article = Article.find_by(msid: msid)

        unless article
          article_data = Taz::XmlScraper.scrape_article(msid)
          if article_data
            article = Article.create(article_data)
            if article.persisted?
              total_stats[:article_created] += 1
              print " [Created article #{msid}]"
            end
          end
        end

        unless article
          puts " ✗ No article"
          total_stats[:article_not_found] += 1
          next
        end

        if post.update(article: article)
          puts " ✓ Linked to #{article.msid}"
          total_stats[:linked] += 1
        else
          puts " ✗ Error linking"
          total_stats[:errors] += 1
        end

        sleep(0.2) if (index + 1) % 10 == 0
      end

      # Summary for this batch
      puts "\nBatch #{batch_num + 1} complete: #{total_stats[:linked]} linked so far"

      # Longer pause between batches
      sleep(2) if batch_num < num_batches - 1
    end

    puts "\n" + ("=" * 80)
    puts "FINAL RESULTS (All Batches):"
    puts "  ✓ Newly linked: #{total_stats[:linked]}"
    puts "  - Already linked: #{total_stats[:already_linked]}"
    puts "  + Articles created: #{total_stats[:article_created]}"
    puts "  ⚠ Not taz.de links: #{total_stats[:not_taz_link]}"
    puts "  ⚠ No MSID found: #{total_stats[:no_msid]}"
    puts "  ✗ Article not found: #{total_stats[:article_not_found]}"
    puts "  ✗ Errors: #{total_stats[:errors]}"
    puts "=" * 80
  end

  # Keep existing tasks...
  # (link_posts, fetch_cms_ids, refresh_all, full_sync, stats remain the same)
end
