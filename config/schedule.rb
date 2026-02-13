# config/schedule.rb
# 
# Use this file to define cron jobs for the application
# Learn more: http://github.com/javan/whenever
#
# After making changes, update the crontab with:
#   whenever --update-crontab
#
# To clear the crontab:
#   whenever --clear-crontab

# Set the environment (production, staging, development)
set :environment, ENV.fetch('RAILS_ENV', 'production')

# Set output location for cron logs
set :output, "#{path}/log/cron.log"

# Job type for running Rails jobs through the queue
# This ensures proper Rails environment loading
job_type :runner_job, "cd :path && :environment_variable=:environment bundle exec rails runner -e :environment ':task' :output"

# ============================================================================
# HOURLY ARTICLE IMPORT
# ============================================================================
# Import articles from RSS, refresh from XML, and link to posts
# Runs every hour at 5 minutes past the hour
every 1.hour, at: 5 do
  runner "HourlyArticleImportJob.perform_now"
end

# ============================================================================
# OPTIONAL: Daily cleanup/maintenance tasks
# ============================================================================
# Uncomment these if you want additional scheduled tasks

# Clean up old metrics (keep last 90 days)
# every 1.day, at: '3:00 am' do
#   runner "CleanupOldMetricsJob.perform_now"
# end

# Recalculate baselines for all accounts
# every 1.day, at: '4:00 am' do
#   runner "RecalculateBaselinesJob.perform_now"
# end

# Update article predictions
# every 6.hours do
#   runner "UpdateArticlePredictionsJob.perform_now"
# end
