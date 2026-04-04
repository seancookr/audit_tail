# frozen_string_literal: true

require "active_job"

module AuditTail
  # ActiveJob job that posts a batch of pre-built audit payloads to the cloud API.
  # Enqueued by CloudSync::BatchBuffer when cloud_sync_adapter is :active_job.
  class CloudSyncBatchJob < ActiveJob::Base
    queue_as :default

    def perform(payloads_json)
      payloads = JSON.parse(payloads_json)
      AuditTail::CloudSync.post_batch(payloads)
    end
  end
end
