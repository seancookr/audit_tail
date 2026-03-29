# frozen_string_literal: true

module AuditTail
  # RSpec helper methods for asserting on audit events in tests.
  module TestHelpers
    # Returns all audit events recorded for a given subject.
    def audit_events_for(subject)
      AuditTail::Event.where(subject: subject).order(:created_at)
    end

    # Asserts that an audit event exists matching the given criteria.
    # Accepts: action:, subject:, actor:, metadata: (optional)
    def expect_audit_event(action:, subject: nil, actor: nil, metadata: nil)
      event = find_audit_event(action: action, subject: subject, actor: actor)
      assert_audit_event_found!(event, action)
      assert_audit_metadata!(event, metadata)
      event
    end

    private

    def find_audit_event(action:, subject:, actor:)
      scope = AuditTail::Event.with_action(action)
      scope = scope.for_subject(subject) if subject
      scope = scope.by_actor(actor) if actor
      scope.last
    end

    def assert_audit_event_found!(event, action)
      return if event

      raise RSpec::Expectations::ExpectationNotMetError,
            "Expected audit event with action=#{action.inspect} but none was found.\n" \
            "Recorded events: #{AuditTail::Event.pluck(:action).inspect}"
    end

    def assert_audit_metadata!(event, metadata)
      metadata&.each do |key, value|
        actual = event.metadata[key.to_s]
        next if actual == value

        raise RSpec::Expectations::ExpectationNotMetError,
              "Expected audit event metadata[#{key}] to eq #{value.inspect}, got #{actual.inspect}"
      end
    end
  end
end
