redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  # Sidekiq's own default concurrency (10 threads) has nothing to do with
  # this process's ActiveRecord pool, which config/database.yml sizes from
  # RAILS_MAX_THREADS — reusing that same variable here (Kamal gives the
  # worker role its own value, see config/deploy.yml) keeps "how many
  # threads this process runs" and "how many DB connections it can hold"
  # from drifting apart. Without this, jobs beyond the pool size block on
  # ActiveRecord::ConnectionTimeoutError instead of just queueing.
  config.concurrency = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))

  # Load the recurring schedule once the worker boots. Wrapped so a broken
  # YAML file can't take the whole worker down.
  config.on(:startup) do
    schedule_file = Rails.root.join("config/sidekiq_cron.yml")
    if schedule_file.exist?
      schedule = YAML.safe_load(ERB.new(schedule_file.read).result, permitted_classes: [], aliases: true) || {}
      Sidekiq::Cron::Job.load_from_hash!(schedule) if schedule.any?
    end
  rescue => e
    Rails.logger.error("[sidekiq-cron] failed to load schedule: #{e.class}: #{e.message}")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
