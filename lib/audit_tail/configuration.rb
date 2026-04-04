# frozen_string_literal: true

module AuditTail
  # Holds global configuration for the AuditTail gem.
  class Configuration
    attr_accessor :backend, :ignored_attributes, :cloud_api_key, :cloud_sync_url, :cloud_environment,
                  :cloud_sync_adapter, :cloud_sync_batch_size, :cloud_sync_flush_interval, :cloud_sync_batching

    def initialize
      @backend = :active_record
      @ignored_attributes = %w[created_at updated_at]
      @cloud_sync_adapter = :inline
      @cloud_sync_batching = true
      @cloud_sync_batch_size = 25
      @cloud_sync_flush_interval = 5
    end

    def cloud_sync_enabled?
      cloud_api_key.present? && cloud_sync_url.present?
    end

    def cloud_sync_batching?
      cloud_sync_batching && cloud_sync_enabled?
    end
  end
end
