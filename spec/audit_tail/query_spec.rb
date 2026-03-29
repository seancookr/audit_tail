# frozen_string_literal: true

require "spec_helper"

RSpec.describe AuditTail::Query do
  let(:alice)           { User.create!(name: "Alice", email: "alice@example.com") }
  let(:bob)             { User.create!(name: "Bob",   email: "bob@example.com") }
  let(:first_invoice)   { Invoice.create!(title: "INV-001", amount: 100, status: "draft") }
  let(:second_invoice)  { Invoice.create!(title: "INV-002", amount: 200, status: "draft") }

  before do
    AuditTail.actor = alice
    first_invoice   # trigger create
    AuditTail.actor = bob
    second_invoice  # trigger create
    AuditTail.log(actor: alice, action: "exported_report", subject: first_invoice)
  end

  describe ".for" do
    it "filters by subject" do
      events = AuditTail.events.for(first_invoice).to_a
      expect(events.map(&:subject_id).uniq).to eq([first_invoice.id])
    end
  end

  describe ".by" do
    it "filters by actor" do
      events = AuditTail.events.by(alice).to_a
      expect(events.map(&:actor_id).uniq).to eq([alice.id])
    end
  end

  describe ".action" do
    it "filters by action string" do
      events = AuditTail.events.action(:exported_report).to_a
      expect(events.length).to eq(1)
      expect(events.first.action).to eq("exported_report")
    end
  end

  describe ".in_last" do
    it "returns events within the time window" do
      events = AuditTail.events.in_last(1.minute).to_a
      expect(events).not_to be_empty
    end

    it "excludes events outside the time window" do
      events = AuditTail.events.in_last(-1.second).to_a
      expect(events).to be_empty
    end
  end

  describe ".chronological" do
    it "orders events ascending" do
      times = AuditTail.events.chronological.map(&:created_at)
      expect(times).to eq(times.sort)
    end
  end

  describe "chaining" do
    it "supports chained scopes" do
      events = AuditTail.events.by(alice).action(:create).to_a
      expect(events.all? { |e| e.actor_id == alice.id && e.action == "create" }).to be true
    end
  end
end
