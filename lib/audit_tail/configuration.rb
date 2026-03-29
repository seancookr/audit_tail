# frozen_string_literal: true

module AuditTail
  # Holds global configuration for the AuditTail gem.
  class Configuration
    attr_accessor :backend, :ignored_attributes

    def initialize
      @backend = :active_record
      @ignored_attributes = %w[created_at updated_at]
    end
  end
end
