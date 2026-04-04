# frozen_string_literal: true

module AuditTail
  module CloudSync
    # Thread-safe in-memory buffer that accumulates cloud sync payloads
    # and flushes them in batches to reduce HTTP calls.
    #
    # Flush triggers:
    #   1. Size — when the queue reaches +batch_size+
    #   2. Time — a background thread flushes every +flush_interval+ seconds
    #   3. Shutdown — +shutdown!+ drains remaining events on process exit
    class BatchBuffer
      def initialize
        @mutex = Mutex.new
        @queue = []
        @timer_thread = nil
        @shutdown = false
      end

      # Append a pre-built payload hash to the buffer.
      # Triggers a size-based flush when the threshold is reached.
      def push(payload)
        flush_needed = false

        @mutex.synchronize do
          @queue << payload
          flush_needed = @queue.size >= AuditTail.configuration.cloud_sync_batch_size
        end

        ensure_timer_running
        flush if flush_needed
      end

      # Swap the queue under the mutex and send the batch outside the lock.
      def flush
        batch = @mutex.synchronize do
          captured = @queue
          @queue = []
          captured
        end

        return if batch.empty?

        send_batch(batch)
      rescue StandardError
        # Flush failures must not propagate
      end

      # Stop the timer thread and drain any remaining events.
      def shutdown!
        @shutdown = true
        @timer_thread&.join(5)
        flush
      end

      # Clear the queue without flushing (for test cleanup).
      def reset!
        @shutdown = true
        @timer_thread&.join(5)
        @mutex.synchronize { @queue.clear }
        @shutdown = false
        @timer_thread = nil
      end

      def size
        @mutex.synchronize { @queue.size }
      end

      private

      def ensure_timer_running
        return if @timer_thread&.alive?

        @timer_thread = Thread.new do
          interval = AuditTail.configuration.cloud_sync_flush_interval
          loop do
            sleep interval
            break if @shutdown

            flush
          end
        end
        @timer_thread.abort_on_exception = false
      end

      def send_batch(payloads)
        case AuditTail.configuration.cloud_sync_adapter
        when :active_job
          AuditTail::CloudSyncBatchJob.perform_later(JSON.generate(payloads))
        when :sidekiq
          Sidekiq::Client.push(
            "class" => "AuditTail::CloudSyncBatchWorker",
            "args" => [JSON.generate(payloads)]
          )
        else
          AuditTail::CloudSync.post_batch(payloads)
        end
      end
    end
  end
end
