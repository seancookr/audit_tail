# frozen_string_literal: true

require "net/http"
require "json"

module AuditTail
  # Posts audit events to the AuditTail Cloud API.
  # Failures are silently rescued so cloud sync never breaks local writes.
  module CloudSync
    # Routes the event to the configured adapter. Called from AR callbacks and Log.call.
    def self.dispatch(event, actor: nil, subject: nil)
      return unless AuditTail.configuration.cloud_sync_enabled?

      if AuditTail.configuration.cloud_sync_batching?
        payload = build_payload(event, actor: actor, subject: subject)
        buffer.push(payload)
      else
        case AuditTail.configuration.cloud_sync_adapter
        when :active_job
          AuditTail::CloudSyncJob.perform_later(event.id)
        when :sidekiq
          Sidekiq::Client.push("class" => "AuditTail::CloudSyncWorker", "args" => [event.id])
        else
          call(event, actor: actor, subject: subject)
        end
      end
    rescue StandardError
      # Dispatch failures must not affect local writes
    end

    def self.call(event, actor: nil, subject: nil)
      return unless AuditTail.configuration.cloud_sync_enabled?

      payload = build_payload(event, actor: actor, subject: subject)
      post(payload)
    rescue StandardError
      # Cloud sync failures must not affect local writes
    end

    # Send an array of pre-built payloads in a single HTTP POST.
    def self.post_batch(payloads)
      uri = URI("#{AuditTail.configuration.cloud_sync_url}/api/v1/events")
      http = build_http(uri)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{AuditTail.configuration.cloud_api_key}"
      request.body = JSON.generate({ events: payloads })
      http.request(request)
    end

    def self.buffer
      @buffer ||= CloudSync::BatchBuffer.new
    end

    def self.flush!
      buffer.flush
    end

    def self.shutdown!
      buffer.shutdown!
    end

    def self.reset_buffer!
      @buffer&.reset!
      @buffer = nil
    end

    def self.build_payload(event, actor:, subject:) # rubocop:disable Metrics/AbcSize
      config = AuditTail.configuration
      payload = {
        action: event.action,
        actor_type: event.actor_type,
        actor_id: event.actor_id&.to_s,
        actor_display: actor&.to_s,
        subject_type: event.subject_type,
        subject_id: event.subject_id&.to_s,
        subject_display: subject&.to_s,
        changeset: event.changeset,
        metadata: event.metadata,
        occurred_at: event.created_at.iso8601
      }
      payload[:environment] = config.cloud_environment if config.cloud_environment
      payload
    end

    def self.post(payload)
      uri = URI("#{AuditTail.configuration.cloud_sync_url}/api/v1/events")
      http = build_http(uri)
      request = build_request(uri, payload)
      http.request(request)
    end
    private_class_method :post

    def self.build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10
      http
    end
    private_class_method :build_http

    def self.build_request(uri, payload)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{AuditTail.configuration.cloud_api_key}"
      request.body = JSON.generate({ events: [payload] })
      request
    end
    private_class_method :build_request
  end
end
