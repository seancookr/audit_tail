# frozen_string_literal: true

AuditTail.configure do |config|
  # Default backend: :active_record
  # config.backend = :active_record

  # Attributes always ignored in changesets (applies globally)
  # config.ignored_attributes = %w[created_at updated_at]

  # Cloud sync — mirror events to AuditTail Cloud (https://audittail.dev).
  # Sync is disabled when api_key or sync_url is blank.
  # config.cloud_api_key      = ENV["AUDIT_TAIL_API_KEY"]
  # config.cloud_sync_url     = "https://app.audittail.dev"
  # config.cloud_environment  = Rails.env

  # Adapter for cloud sync dispatch. Default: :inline (synchronous, on request thread).
  # Use :active_job or :sidekiq to move sync off the request thread in production.
  # config.cloud_sync_adapter = :inline  # :inline | :active_job | :sidekiq

  # Batching — reduce HTTP calls by grouping events into a single POST.
  # config.cloud_sync_batching       = true   # set false to revert to one-event-per-POST
  # config.cloud_sync_batch_size     = 25     # flush after N events
  # config.cloud_sync_flush_interval = 5      # flush after N seconds even if batch isn't full
end
