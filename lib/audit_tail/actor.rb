# frozen_string_literal: true

module AuditTail
  # Manages the current actor via a thread-local variable.
  module Actor
    THREAD_KEY = :audit_tail_actor

    def self.current
      Thread.current[THREAD_KEY]
    end

    def self.current=(actor)
      Thread.current[THREAD_KEY] = actor
    end

    def self.clear!
      Thread.current[THREAD_KEY] = nil
    end
  end
end
