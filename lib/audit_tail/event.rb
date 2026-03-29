# frozen_string_literal: true

module AuditTail
  # ActiveRecord model representing a single audit event.
  class Event < ActiveRecord::Base
    self.table_name = "audit_events"

    belongs_to :actor,   polymorphic: true, optional: true
    belongs_to :subject, polymorphic: true, optional: true

    serialize :changeset, coder: JSON
    serialize :metadata,  coder: JSON

    validates :action, presence: true

    scope :chronological,    -> { order(created_at: :asc) }
    scope :reverse_chrono,   -> { order(created_at: :desc) }
    scope :for_subject,      ->(subject) { where(subject: subject) }
    scope :by_actor,         ->(actor)   { where(actor: actor) }
    scope :with_action,      ->(action)  { where(action: action.to_s) }
    scope :in_last,          ->(duration) { where("created_at >= ?", duration.ago) }
  end
end
