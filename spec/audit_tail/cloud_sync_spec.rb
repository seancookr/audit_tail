# frozen_string_literal: true

require "spec_helper"

RSpec.describe AuditTail::CloudSync do
  let(:api_key) { "atk_prod_testkey123" }
  let(:sync_url) { "https://app.audittail.dev" }

  def stub_events_endpoint
    stub_request(:post, "#{sync_url}/api/v1/events")
      .to_return(status: 201, body: '{"received":1,"errors":[]}',
                 headers: { "Content-Type" => "application/json" })
  end

  before do
    AuditTail.configure do |c|
      c.cloud_api_key  = api_key
      c.cloud_sync_url = sync_url
    end
  end

  after do
    AuditTail.configure do |c|
      c.cloud_api_key       = nil
      c.cloud_sync_url      = nil
      c.cloud_environment   = nil
      c.cloud_sync_adapter  = :inline
    end
  end

  describe ".call" do
    let(:user)    { User.create!(name: "Alice", email: "alice@example.com") }
    let(:invoice) { Invoice.create!(title: "INV-1", amount: 100) }

    before do
      stub_events_endpoint
      user    # force AR creation (no audit_trail, no sync)
      invoice # force AR creation — fires a create sync
      WebMock.reset!
      stub_events_endpoint
    end

    it "does nothing when cloud sync is not configured" do
      AuditTail.configure { |c| c.cloud_api_key = nil }
      AuditTail.actor = user
      invoice.update!(status: "sent")

      expect(WebMock).not_to have_requested(:post, "#{sync_url}/api/v1/events")
    end

    it "POSTs to /api/v1/events after a model update" do
      AuditTail.actor = user
      invoice.update!(status: "sent")

      expect(WebMock).to have_requested(:post, "#{sync_url}/api/v1/events")
        .with(headers: { "Authorization" => "Bearer #{api_key}", "Content-Type" => "application/json" })
    end

    it "POSTs to /api/v1/events after a model destroy" do
      AuditTail.actor = user
      invoice.destroy

      expect(WebMock).to have_requested(:post, "#{sync_url}/api/v1/events")
    end

    it "POSTs to /api/v1/events after a model create" do
      AuditTail.actor = user
      Invoice.create!(title: "INV-2", amount: 50)

      expect(WebMock).to have_requested(:post, "#{sync_url}/api/v1/events")
    end

    it "sends the correct payload shape", :aggregate_failures do
      AuditTail.actor = user
      invoice.update!(status: "sent")

      expect(WebMock).to(have_requested(:post, "#{sync_url}/api/v1/events").with do |req|
        body = JSON.parse(req.body)
        e = body["events"].first
        expect(e["action"]).to eq("update")
        expect(e["actor_type"]).to eq("User")
        expect(e["actor_id"]).to eq(user.id.to_s)
        expect(e["subject_type"]).to eq("Invoice")
        expect(e["subject_id"]).to eq(invoice.id.to_s)
        expect(e["changeset"]).to include("status")
        expect(e["occurred_at"]).to be_present
        true
      end)
    end

    it "includes environment when configured" do
      AuditTail.configure { |c| c.cloud_environment = "production" }
      AuditTail.actor = user
      invoice.update!(status: "sent")

      expect(WebMock).to(have_requested(:post, "#{sync_url}/api/v1/events").with do |req|
        body = JSON.parse(req.body)
        expect(body["events"].first["environment"]).to eq("production")
        true
      end)
    end

    it "omits environment when not configured" do
      AuditTail.actor = user
      invoice.update!(status: "sent")

      expect(WebMock).to(have_requested(:post, "#{sync_url}/api/v1/events").with do |req|
        body = JSON.parse(req.body)
        expect(body["events"].first).not_to have_key("environment")
        true
      end)
    end

    it "does not raise when the cloud endpoint is unreachable" do
      WebMock.reset!
      stub_request(:post, "#{sync_url}/api/v1/events").to_raise(Errno::ECONNREFUSED)
      AuditTail.actor = user

      expect { invoice.update!(status: "sent") }.not_to raise_error
    end

    it "does not raise when the cloud returns an error status" do
      WebMock.reset!
      stub_request(:post, "#{sync_url}/api/v1/events").to_return(status: 500, body: "Internal Server Error")
      AuditTail.actor = user

      expect { invoice.update!(status: "sent") }.not_to raise_error
    end
  end

  describe "adapter routing" do
    let(:user)    { User.create!(name: "Alice", email: "alice@example.com") }
    let(:invoice) { Invoice.create!(title: "INV-1", amount: 100) }

    before do
      stub_events_endpoint
      user
      invoice
      WebMock.reset!
      stub_events_endpoint
    end

    context "when adapter is :active_job" do
      before { AuditTail.configure { |c| c.cloud_sync_adapter = :active_job } }

      let(:enqueued_jobs) { ActiveJob::Base.queue_adapter.enqueued_jobs }

      it "enqueues CloudSyncJob instead of posting synchronously" do
        AuditTail.actor = user
        invoice.update!(status: "sent")

        expect(enqueued_jobs.map { |j| j[:job] }).to include(AuditTail::CloudSyncJob)
        expect(WebMock).not_to have_requested(:post, "#{sync_url}/api/v1/events")
      end

      it "enqueues the job with the event id" do
        AuditTail.actor = user
        invoice.update!(status: "sent")

        event = AuditTail::Event.last
        job = enqueued_jobs.find { |j| j[:job] == AuditTail::CloudSyncJob }
        expect(job[:args]).to eq([event.id])
      end
    end

    context "when adapter is :sidekiq" do
      before { AuditTail.configure { |c| c.cloud_sync_adapter = :sidekiq } }

      it "pushes to Sidekiq instead of posting synchronously" do
        stub_const("Sidekiq::Client", Class.new)
        allow(Sidekiq::Client).to receive(:push)

        AuditTail.actor = user
        invoice.update!(status: "sent")

        event = AuditTail::Event.last
        expect(Sidekiq::Client).to have_received(:push).with(
          "class" => "AuditTail::CloudSyncWorker",
          "args"  => [event.id]
        )
        expect(WebMock).not_to have_requested(:post, "#{sync_url}/api/v1/events")
      end
    end
  end

  describe "CloudSyncJob" do
    let(:user)    { User.create!(name: "Alice", email: "alice@example.com") }
    let(:invoice) { Invoice.create!(title: "INV-1", amount: 100) }

    before { stub_events_endpoint }

    it "posts the event when performed" do
      AuditTail.actor = user
      invoice.update!(status: "sent")
      event = AuditTail::Event.last

      WebMock.reset!
      stub_events_endpoint

      AuditTail::CloudSyncJob.new.perform(event.id)

      expect(WebMock).to have_requested(:post, "#{sync_url}/api/v1/events")
    end

    it "does nothing for a missing event id" do
      expect { AuditTail::CloudSyncJob.new.perform(999_999) }.not_to raise_error
      expect(WebMock).not_to have_requested(:post, "#{sync_url}/api/v1/events")
    end
  end

  describe "Log.call integration" do
    before { stub_events_endpoint }

    it "syncs custom log events to the cloud" do
      user = User.create!(name: "Bob")
      AuditTail.log(action: "export.csv", subject: user, metadata: { rows: 42 })

      expect(WebMock).to(have_requested(:post, "#{sync_url}/api/v1/events").with do |req|
        body = JSON.parse(req.body)
        e = body["events"].first
        expect(e["action"]).to eq("export.csv")
        expect(e["subject_type"]).to eq("User")
        expect(e["metadata"]).to eq("rows" => 42)
        true
      end)
    end
  end
end
