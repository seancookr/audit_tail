# frozen_string_literal: true

require "spec_helper"

RSpec.describe AuditTail::CloudSync::BatchBuffer do
  let(:api_key)  { "atk_prod_testkey123" }
  let(:sync_url) { "https://app.audittail.dev" }
  let(:buffer)   { described_class.new }

  def stub_events_endpoint
    stub_request(:post, "#{sync_url}/api/v1/events")
      .to_return(status: 201, body: '{"received":1,"errors":[]}',
                 headers: { "Content-Type" => "application/json" })
  end

  before do
    AuditTail.configure do |c|
      c.cloud_api_key           = api_key
      c.cloud_sync_url          = sync_url
      c.cloud_sync_batching     = true
      c.cloud_sync_batch_size   = 3
      c.cloud_sync_flush_interval = 60 # long interval so timer doesn't interfere
      c.cloud_sync_adapter = :inline
    end
    stub_events_endpoint
  end

  after do
    buffer.reset!
    AuditTail.configure do |c|
      c.cloud_api_key           = nil
      c.cloud_sync_url          = nil
      c.cloud_sync_batching     = true
      c.cloud_sync_batch_size   = 25
      c.cloud_sync_flush_interval = 5
      c.cloud_sync_adapter = :inline
    end
  end

  def sample_payload(num = 1)
    { action: "update", actor_type: "User", actor_id: num.to_s, subject_type: "Invoice",
      subject_id: "1", changeset: {}, metadata: {}, occurred_at: Time.now.iso8601 }
  end

  describe "#push" do
    it "accumulates payloads without flushing below batch_size" do
      2.times { |i| buffer.push(sample_payload(i)) }

      expect(buffer.size).to eq(2)
      expect(WebMock).not_to have_requested(:post, "#{sync_url}/api/v1/events")
    end

    it "auto-flushes when batch_size is reached" do
      3.times { |i| buffer.push(sample_payload(i)) }

      expect(buffer.size).to eq(0)
      expect(WebMock).to have_requested(:post, "#{sync_url}/api/v1/events").once
    end

    it "sends all accumulated payloads in a single POST" do
      3.times { |i| buffer.push(sample_payload(i)) }

      expect(WebMock).to(have_requested(:post, "#{sync_url}/api/v1/events").with do |req|
        body = JSON.parse(req.body)
        expect(body["events"].size).to eq(3)
        true
      end)
    end
  end

  describe "#flush" do
    it "sends buffered payloads and clears the queue" do
      2.times { |i| buffer.push(sample_payload(i)) }
      buffer.flush

      expect(buffer.size).to eq(0)
      expect(WebMock).to(have_requested(:post, "#{sync_url}/api/v1/events").with do |req|
        body = JSON.parse(req.body)
        expect(body["events"].size).to eq(2)
        true
      end)
    end

    it "is a no-op when the queue is empty" do
      buffer.flush

      expect(WebMock).not_to have_requested(:post, "#{sync_url}/api/v1/events")
    end
  end

  describe "#shutdown!" do
    it "drains remaining events" do
      2.times { |i| buffer.push(sample_payload(i)) }
      buffer.shutdown!

      expect(buffer.size).to eq(0)
      expect(WebMock).to have_requested(:post, "#{sync_url}/api/v1/events").once
    end
  end

  describe "#reset!" do
    it "clears the queue without flushing" do
      2.times { |i| buffer.push(sample_payload(i)) }
      buffer.reset!

      expect(buffer.size).to eq(0)
      expect(WebMock).not_to have_requested(:post, "#{sync_url}/api/v1/events")
    end
  end

  describe "time-based flush" do
    it "flushes after the configured interval" do
      AuditTail.configuration.cloud_sync_flush_interval = 0.1
      buffer.push(sample_payload)
      sleep 0.25

      expect(buffer.size).to eq(0)
      expect(WebMock).to have_requested(:post, "#{sync_url}/api/v1/events").once
    end
  end

  describe "thread-safety" do
    it "does not lose events under concurrent pushes" do
      AuditTail.configuration.cloud_sync_batch_size = 100 # prevent auto-flush during push

      threads = 10.times.map do |t|
        Thread.new { 10.times { |i| buffer.push(sample_payload((t * 10) + i)) } }
      end
      threads.each(&:join)
      buffer.flush

      expect(WebMock).to(have_requested(:post, "#{sync_url}/api/v1/events").with do |req|
        body = JSON.parse(req.body)
        expect(body["events"].size).to eq(100)
        true
      end)
    end
  end

  describe "error resilience" do
    it "continues accepting events after a flush error" do
      WebMock.reset!
      stub_request(:post, "#{sync_url}/api/v1/events").to_raise(Errno::ECONNREFUSED)

      buffer.push(sample_payload(1))
      buffer.flush # this will fail silently

      stub_events_endpoint
      buffer.push(sample_payload(2))
      expect(buffer.size).to eq(1)
    end
  end

  describe "adapter routing" do
    context "with :active_job adapter" do
      before { AuditTail.configuration.cloud_sync_adapter = :active_job }

      let(:enqueued_jobs) { ActiveJob::Base.queue_adapter.enqueued_jobs }

      it "enqueues a CloudSyncBatchJob on flush" do
        2.times { |i| buffer.push(sample_payload(i)) }
        buffer.flush

        expect(enqueued_jobs.map { |j| j[:job] }).to include(AuditTail::CloudSyncBatchJob)
        expect(WebMock).not_to have_requested(:post, "#{sync_url}/api/v1/events")
      end
    end

    context "with :sidekiq adapter" do
      before { AuditTail.configuration.cloud_sync_adapter = :sidekiq }

      it "pushes to Sidekiq on flush" do
        stub_const("Sidekiq::Client", Class.new)
        allow(Sidekiq::Client).to receive(:push)

        2.times { |i| buffer.push(sample_payload(i)) }
        buffer.flush

        expect(Sidekiq::Client).to have_received(:push).with(
          hash_including("class" => "AuditTail::CloudSyncBatchWorker")
        )
      end
    end
  end
end
