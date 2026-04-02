# frozen_string_literal: true

module AuditTail
  # ActiveSupport::Concern that adds the `audit_trail` class macro to ActiveRecord models.
  module ModelConcern
    extend ActiveSupport::Concern

    # Class-level methods mixed into every ActiveRecord model.
    module ClassMethods
      def audit_trail(only: nil, except: nil)
        class_attribute :_audit_only_fields,   default: only&.map(&:to_s)
        class_attribute :_audit_except_fields, default: (except || []).map(&:to_s)

        include AuditTail::ModelCallbacks
      end
    end
  end

  # ActiveRecord callbacks that write audit events on create, update, and destroy.
  module ModelCallbacks
    extend ActiveSupport::Concern

    included do
      after_create  :_audit_tail_record_create
      after_update  :_audit_tail_record_update
      before_destroy :_audit_tail_record_destroy
    end

    private

    def _audit_tail_record_create
      _audit_tail_write("create", _audit_tail_full_attributes)
    end

    def _audit_tail_record_update
      diff = _audit_tail_filter_changes(saved_changes)
      return if diff.empty?

      _audit_tail_write("update", diff)
    end

    def _audit_tail_record_destroy
      _audit_tail_write("destroy", {})
    end

    def _audit_tail_write(action, changeset)
      actor = AuditTail::Actor.current
      event = AuditTail::Event.create!(
        actor: actor,
        action: action,
        subject: self,
        changeset: changeset,
        metadata: {}
      )
      AuditTail::CloudSync.dispatch(event, actor: actor, subject: self)
    end

    def _audit_tail_full_attributes
      attrs = attributes.except(*_audit_tail_globally_ignored)
      attrs = _audit_tail_apply_field_filters(attrs)
      attrs.transform_values { |v| [nil, v] }
    end

    def _audit_tail_filter_changes(changes)
      filtered = changes.except(*_audit_tail_globally_ignored)
      _audit_tail_apply_field_filters(filtered)
    end

    def _audit_tail_apply_field_filters(hash)
      if _audit_only_fields.present?
        hash.slice(*_audit_only_fields)
      elsif _audit_except_fields.present?
        hash.except(*_audit_except_fields)
      else
        hash
      end
    end

    def _audit_tail_globally_ignored
      AuditTail.configuration.ignored_attributes
    end
  end
end
