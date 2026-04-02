# frozen_string_literal: true

module AuditTail
  # Sidekiq worker that posts a previously-written audit event to the cloud API.
  # Used when cloud_sync_adapter is :sidekiq (bypasses ActiveJob entirely).
  # Sidekiq must be available in the host application.
  class CloudSyncWorker
    include Sidekiq::Worker if defined?(Sidekiq::Worker)

    def perform(event_id)
      event = AuditTail::Event.find_by(id: event_id)
      return unless event

      AuditTail::CloudSync.call(event, actor: event.actor, subject: event.subject)
    end
  end
end
