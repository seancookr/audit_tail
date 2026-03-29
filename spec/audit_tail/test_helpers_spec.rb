# frozen_string_literal: true

require "spec_helper"

RSpec.describe AuditTail::TestHelpers do
  let(:user)    { User.create!(name: "Dave", email: "dave@example.com") }
  let(:invoice) { Invoice.create!(title: "INV-004", amount: 400, status: "draft") }

  before { AuditTail.actor = user }

  describe "#audit_events_for" do
    it "returns events for a given subject" do
      invoice.update!(status: "paid")
      events = audit_events_for(invoice)
      expect(events.map(&:action)).to include("create", "update")
    end
  end

  describe "#expect_audit_event" do
    it "passes when the event exists" do
      invoice # trigger create
      expect { expect_audit_event(action: :create, subject: invoice) }.not_to raise_error
    end

    it "raises when the event does not exist" do
      expect do
        expect_audit_event(action: :nonexistent_action, subject: invoice)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "checks metadata fields" do
      AuditTail.log(actor: user, action: "exported_report", subject: invoice,
                    metadata: { format: "csv" })
      expect do
        expect_audit_event(action: :exported_report, metadata: { format: "csv" })
      end.not_to raise_error
    end
  end
end
