# frozen_string_literal: true

module AuditTail
  # Manages the current actor via a fiber-local variable.
  module Actor
    FIBER_KEY = :audit_tail_actor

    def self.current
      Fiber[FIBER_KEY]
    end

    def self.current=(actor)
      Fiber[FIBER_KEY] = actor
    end

    def self.clear!
      Fiber[FIBER_KEY] = nil
    end
  end
end
