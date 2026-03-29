# frozen_string_literal: true

module AuditTail
  module Backends
    # Default backend — stores events in the audit_events table via ActiveRecord.
    # Satisfies the pluggable backend interface (write, query).
    class ActiveRecord
      def write(event_attrs)
        AuditTail::Event.create!(event_attrs)
      end

      def query
        AuditTail::Event.all
      end
    end
  end
end
