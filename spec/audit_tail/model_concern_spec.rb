# frozen_string_literal: true

require "spec_helper"

RSpec.describe AuditTail::ModelConcern do
  let(:actor) { User.create!(name: "Alice", email: "alice@example.com") }

  before { AuditTail.actor = actor }

  describe "create event" do
    it "records a create event with attributes as changeset" do
      invoice = Invoice.create!(title: "INV-001", amount: 100, status: "draft")
      event = AuditTail::Event.last

      expect(event.action).to eq("create")
      expect(event.subject).to eq(invoice)
      expect(event.actor).to eq(actor)
      expect(event.changeset["title"]).to eq([nil, "INV-001"])
    end
  end

  describe "update event" do
    it "records an update event with before/after changeset" do
      invoice = Invoice.create!(title: "INV-001", amount: 100, status: "draft")
      invoice.update!(status: "paid")

      event = AuditTail::Event.where(action: "update").last
      expect(event.changeset["status"]).to eq(%w[draft paid])
    end

    it "does not record when no tracked fields changed" do
      invoice = Invoice.create!(title: "INV-001", amount: 100, status: "draft")
      count_before = AuditTail::Event.count
      invoice.update!(encrypted_password: "secret")
      expect(AuditTail::Event.count).to eq(count_before)
    end
  end

  describe "destroy event" do
    it "records a destroy event" do
      invoice = Invoice.create!(title: "INV-001", amount: 100, status: "draft")
      invoice.destroy!

      event = AuditTail::Event.where(action: "destroy").last
      expect(event.subject_id).to eq(invoice.id)
    end
  end

  describe "except: filtering" do
    it "omits excluded fields from changeset" do
      Invoice.create!(title: "INV-001", encrypted_password: "hunter2", status: "draft", amount: 10)
      event = AuditTail::Event.last
      expect(event.changeset.keys).not_to include("encrypted_password")
    end
  end

  describe "only: filtering" do
    it "only records specified fields" do
      InvoiceOnly.create!(title: "INV-002", amount: 200, status: "draft")
      event = AuditTail::Event.last
      expect(event.changeset.keys).to eq(["status"])
    end
  end
end
