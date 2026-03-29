# frozen_string_literal: true

module AuditTail
  # Rails controller concern that sets the thread-local actor before each action
  # and clears it afterward. Include in ApplicationController.
  module ControllerConcern
    extend ActiveSupport::Concern

    included do
      before_action :set_audit_tail_actor
      after_action  :clear_audit_tail_actor
    end

    private

    def set_audit_tail_actor
      AuditTail::Actor.current = audit_tail_actor
    end

    def clear_audit_tail_actor
      AuditTail::Actor.clear!
    end

    # Override in your ApplicationController to provide the actor.
    # Defaults to `current_user` if that method exists.
    def audit_tail_actor
      respond_to?(:current_user, true) ? current_user : nil
    end
  end
end
