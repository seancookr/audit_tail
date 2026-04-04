# frozen_string_literal: true

module AuditTail
  # Sidekiq worker that posts a batch of pre-built audit payloads to the cloud API.
  # Used by CloudSync::BatchBuffer when cloud_sync_adapter is :sidekiq.
  class CloudSyncBatchWorker
    include Sidekiq::Worker if defined?(Sidekiq::Worker)

    def perform(payloads_json)
      payloads = JSON.parse(payloads_json)
      AuditTail::CloudSync.post_batch(payloads)
    end
  end
end
