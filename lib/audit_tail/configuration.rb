# frozen_string_literal: true

module AuditTail
  # Holds global configuration for the AuditTail gem.
  class Configuration
    attr_accessor :backend, :ignored_attributes, :cloud_api_key, :cloud_sync_url, :cloud_environment

    def initialize
      @backend = :active_record
      @ignored_attributes = %w[created_at updated_at]
    end

    def cloud_sync_enabled?
      cloud_api_key.present? && cloud_sync_url.present?
    end
  end
end
