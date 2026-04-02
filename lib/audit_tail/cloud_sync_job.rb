# frozen_string_literal: true

require "active_job"

module AuditTail
  # ActiveJob job that posts a previously-written audit event to the cloud API.
  # Enqueued by CloudSync.dispatch when cloud_sync_adapter is :active_job.
  class CloudSyncJob < ActiveJob::Base
    queue_as :default

    def perform(event_id)
      event = AuditTail::Event.find_by(id: event_id)
      return unless event

      AuditTail::CloudSync.call(event, actor: event.actor, subject: event.subject)
    end
  end
end
