# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle exec rspec                          # run all tests
bundle exec rspec spec/audit_tail/log_spec.rb  # run a single spec file
bundle exec rspec spec/audit_tail/log_spec.rb:42  # run a single example by line
bundle exec rubocop                        # lint
bundle exec rubocop -a                     # auto-fix safe offenses
```

## Architecture

**audit_tail** is a Rails gem that hooks into ActiveRecord to capture lifecycle events into an `audit_events` table.

### Event flow

1. `audit_trail` macro (in `ModelConcern`) adds `after_create`, `after_update`, and `before_destroy` callbacks via `ModelCallbacks`. (`audit_tail` is an alias.)
2. Each callback calls `AuditTail::Event.create!` then `CloudSync.dispatch` — no async queue or middleware unless cloud sync is enabled.
3. The actor (the "who") is fiber-local, stored in `Actor` (`Fiber[:audit_tail_actor]`). Controllers set it via `ControllerConcern` and must clear it after each request. `Fiber[:key]` (Ruby 3.0+) is used instead of `Thread.current` so actor state is correctly isolated on Falcon and other fiber-based servers.
4. Custom events bypass the callback path entirely via `Log.call`, which also resolves the actor from fiber-local if none is passed.

### Key design decisions

- **`backends/active_record.rb` is currently unused** — `ModelCallbacks` and `Log` write directly to `AuditTail::Event` → `CloudSync.dispatch` rather than going through the backend abstraction. The backend class exists as a stub for future pluggability.
- **Cloud sync batching is on by default** — `CloudSync.dispatch` pushes payloads into `CloudSync::BatchBuffer` (a thread-safe Mutex-guarded queue) when `cloud_sync_batching?` is true. The buffer flushes on size threshold (`cloud_sync_batch_size`, default 25), timer interval (`cloud_sync_flush_interval`, default 5s), or process shutdown (`at_exit`). When batching is off, each event dispatches via the configured adapter (inline, ActiveJob, or Sidekiq).
- `Query` is a thin immutable wrapper around an AR scope — each chainable method returns a new `Query` instance. Terminal methods (`to_a`, `count`, etc.) are delegated directly to the underlying scope.
- Field filtering (`only:` / `except:`) is applied at write time, not query time. Global `ignored_attributes` (default: `created_at`, `updated_at`) are excluded before model-level filters run.
- `changeset` and `metadata` are stored as JSON text columns and deserialized via `serialize :column, coder: JSON`.

### Test setup

Tests use an in-memory SQLite database defined entirely in `spec/spec_helper.rb` — no Rails dummy app. `Invoice` and `User` AR models are defined inline there. `DatabaseCleaner` wraps each example in a transaction. Always call `AuditTail.clear_actor!` in `after` hooks (already done globally in `spec_helper`).
