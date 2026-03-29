# frozen_string_literal: true

require "spec_helper"

RSpec.describe AuditTail::Actor do
  describe ".current=" do
    it "stores the actor on the current thread" do
      user = User.create!(name: "Alice", email: "alice@example.com")
      described_class.current = user
      expect(described_class.current).to eq(user)
    end
  end

  describe ".clear!" do
    it "removes the actor from the current thread" do
      described_class.current = User.new
      described_class.clear!
      expect(described_class.current).to be_nil
    end
  end

  describe "module-level aliases" do
    it "AuditTail.actor= / AuditTail.actor work" do
      user = User.create!(name: "Bob", email: "bob@example.com")
      AuditTail.actor = user
      expect(AuditTail.actor).to eq(user)
    end
  end
end
