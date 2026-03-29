# frozen_string_literal: true

require "active_record"
require "active_support/concern"
require "active_support/core_ext/class/attribute"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/module/delegation"

require "audit_tail/version"
require "audit_tail/configuration"
require "audit_tail/actor"
require "audit_tail/event"
require "audit_tail/query"
require "audit_tail/log"
require "audit_tail/model_concern"
require "audit_tail/controller_concern"
require "audit_tail/backends/active_record"

# Main namespace for the AuditTail gem. Provides configuration, actor management,
# custom event logging, and the query entry point.
module AuditTail
  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    # Reader/writer for the current actor (delegates to Actor module)
    def actor
      Actor.current
    end

    def actor=(value)
      Actor.current = value
    end

    def clear_actor!
      Actor.clear!
    end

    # Log a custom event
    def log(action:, actor: nil, subject: nil, metadata: {})
      Log.call(actor: actor, action: action, subject: subject, metadata: metadata)
    end

    # Entry point for the query interface
    def events
      Query.new
    end
  end
end

# Hook into ActiveRecord::Base when Rails is present
ActiveSupport.on_load(:active_record) do
  include AuditTail::ModelConcern
end
