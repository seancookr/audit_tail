# frozen_string_literal: true

require "spec_helper"

RSpec.describe AuditTail::Log do
  let(:user)    { User.create!(name: "Carol", email: "carol@example.com") }
  let(:invoice) { Invoice.create!(title: "INV-003", amount: 300, status: "draft") }

  describe "AuditTail.log" do
    it "creates a custom audit event" do
      AuditTail.log(
        actor: user,
        action: "exported_report",
        subject: invoice,
        metadata: { format: "csv", row_count: 42 }
      )

      event = AuditTail::Event.last
      expect(event.action).to eq("exported_report")
      expect(event.actor).to eq(user)
      expect(event.subject).to eq(invoice)
      expect(event.metadata["format"]).to eq("csv")
      expect(event.metadata["row_count"]).to eq(42)
    end

    it "uses thread-local actor when actor: not provided" do
      AuditTail.actor = user
      AuditTail.log(action: "did_something")

      event = AuditTail::Event.last
      expect(event.actor).to eq(user)
    end
  end
end
