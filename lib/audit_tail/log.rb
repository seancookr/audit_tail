# frozen_string_literal: true

module AuditTail
  # Handles writing custom (manually triggered) audit events.
  module Log
    def self.call(action:, actor: nil, subject: nil, metadata: {})
      resolved_actor = actor || AuditTail::Actor.current

      event = AuditTail::Event.create!(
        actor: resolved_actor,
        action: action.to_s,
        subject: subject,
        metadata: metadata,
        changeset: {}
      )
      AuditTail::CloudSync.call(event, actor: resolved_actor, subject: subject)
    end
  end
end
