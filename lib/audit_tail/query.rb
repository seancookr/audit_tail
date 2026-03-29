# frozen_string_literal: true

module AuditTail
  # Chainable query interface wrapping AuditTail::Event scopes.
  class Query
    def initialize(scope = AuditTail::Event.all)
      @scope = scope
    end

    def for(subject)
      self.class.new(@scope.for_subject(subject))
    end

    def by(actor)
      self.class.new(@scope.by_actor(actor))
    end

    def action(action)
      self.class.new(@scope.with_action(action))
    end

    def in_last(duration)
      self.class.new(@scope.in_last(duration))
    end

    def chronological
      self.class.new(@scope.chronological)
    end

    # Delegate AR relation methods so callers can use .to_a, .each, .count, etc.
    delegate :to_a, :each, :count, :first, :last, :pluck, :map,
             :where, :order, :limit, :offset, :includes, :to_sql,
             to: :@scope
  end
end
