# AuditTail

[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.0-red)](https://www.ruby-lang.org)
[![Gem Version](https://badge.fury.io/rb/audit_tail.svg)](https://rubygems.org/gems/audit_tail)
[![Build Status](https://github.com/audit-tail/audit_tail/actions/workflows/ci.yml/badge.svg)](https://github.com/audit-tail/audit_tail/actions)

Zero-config audit logging for Rails. Track who changed what, when, and why — with a single macro on any ActiveRecord model.

---

## Overview

Keeping an audit trail is essential for compliance, debugging, and user trust — but wiring up callbacks, serialization, and a query interface from scratch is tedious. AuditTail gives you a production-ready activity log in minutes:

- One-line opt-in per model (`audit_trail`)
- Automatic `create`, `update`, and `destroy` event capture with before/after changesets
- Polymorphic actor and subject — works with any model as the "who" and "what"
- Thread-local actor propagation so controllers stay clean
- `AuditTail.log()` for custom, hand-crafted events
- Chainable query interface
- RSpec test helpers included

---

## Installation

Add to your `Gemfile`:

```ruby
gem "audit_tail"
```

Then run:

```bash
bundle install
rails generate audit_tail:install
rails db:migrate
```

The generator creates:
- `db/migrate/<timestamp>_create_audit_events.rb`
- `config/initializers/audit_tail.rb`

---

## Quick Start

```ruby
class Invoice < ApplicationRecord
  audit_trail
end

AuditTail.actor = current_user          # set once per request (or use the controller concern)
invoice = Invoice.create!(title: "INV-001", amount: 500)
invoice.update!(status: "paid")
AuditTail.events.for(invoice).count     # => 2
```

---

## Usage

### `audit_trail` macro

Add `audit_trail` to any ActiveRecord model to start recording events:

```ruby
class Article < ApplicationRecord
  audit_trail
end
```

Three lifecycle events are captured automatically:

| Event | When | Changeset |
|---|---|---|
| `"create"` | `after_create` | All tracked attributes as `[nil, new_value]` pairs |
| `"update"` | `after_update` | Changed attributes as `[old_value, new_value]` pairs |
| `"destroy"` | `before_destroy` | Empty hash `{}` |

Timestamps (`created_at`, `updated_at`) are excluded from changesets by default.

#### `only:` — track a subset of fields

```ruby
class Order < ApplicationRecord
  audit_trail only: [:status, :total]
end
```

Only changes to `status` and `total` are recorded. Other fields are silently ignored.

#### `except:` — exclude sensitive fields

```ruby
class User < ApplicationRecord
  audit_trail except: [:password_digest, :remember_token]
end
```

All fields are tracked except the ones listed.

---

### Actor setup

AuditTail tracks the actor (the "who") via a thread-local variable. The recommended approach is to include `AuditTail::ControllerConcern` in `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  include AuditTail::ControllerConcern
end
```

This concern automatically:
1. Calls `AuditTail.actor = audit_tail_actor` before each action
2. Clears the actor after each action

By default, `audit_tail_actor` returns `current_user` if that method exists. Override it to customize:

```ruby
class ApplicationController < ActionController::Base
  include AuditTail::ControllerConcern

  private

  def audit_tail_actor
    Current.user
  end
end
```

You can also set the actor manually anywhere:

```ruby
AuditTail.actor = user     # set
AuditTail.actor            # read
AuditTail.clear_actor!     # clear
```

---

### `AuditTail.log()` — custom events

Log arbitrary events that are not tied to a model lifecycle:

```ruby
AuditTail.log(
  actor:    current_user,
  action:   "exported_report",
  subject:  @report,
  metadata: { format: "csv", row_count: 1_234 }
)
```

| Parameter | Type | Description |
|---|---|---|
| `action:` | String (required) | A label for the event (e.g. `"exported_report"`) |
| `actor:` | ActiveRecord instance (optional) | Defaults to `AuditTail.actor` (thread-local) |
| `subject:` | ActiveRecord instance (optional) | The record the event pertains to |
| `metadata:` | Hash (optional) | Arbitrary key-value context, stored as JSON |

---

### Query interface

`AuditTail.events` returns a chainable query object backed by `AuditTail::Event`:

```ruby
# All events for a record
AuditTail.events.for(invoice)

# All events by an actor
AuditTail.events.by(current_user)

# Filter by action
AuditTail.events.action("update")

# Events in the last 24 hours
AuditTail.events.in_last(24.hours)

# Chain everything together
AuditTail.events
         .for(invoice)
         .by(current_user)
         .action("update")
         .in_last(7.days)
         .chronological
         .to_a
```

The query object delegates `to_a`, `each`, `count`, `first`, `last`, `pluck`, `map`, `where`, `order`, `limit`, `offset`, `includes`, and `to_sql` directly to the underlying ActiveRecord relation.

---

## Configuration

The generator creates `config/initializers/audit_tail.rb`. Available options:

```ruby
AuditTail.configure do |config|
  # Storage backend. Currently only :active_record is supported.
  config.backend = :active_record

  # Attributes excluded from all changesets, regardless of model-level filters.
  # Defaults to %w[created_at updated_at].
  config.ignored_attributes = %w[created_at updated_at]
end
```

---

## Test Helpers

Include `AuditTail::TestHelpers` in your RSpec configuration:

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.include AuditTail::TestHelpers
end
```

### `audit_events_for(subject)`

Returns all audit events for a record, ordered by `created_at`:

```ruby
events = audit_events_for(invoice)
expect(events.map(&:action)).to eq(%w[create update])
```

### `expect_audit_event`

Asserts that a matching event exists. Raises `RSpec::Expectations::ExpectationNotMetError` if not found:

```ruby
expect_audit_event(
  action:   "exported_report",
  subject:  @report,
  actor:    current_user,
  metadata: { format: "csv" }
)
```

| Parameter | Required | Description |
|---|---|---|
| `action:` | Yes | The event action to match |
| `subject:` | No | Filter by subject record |
| `actor:` | No | Filter by actor record |
| `metadata:` | No | Assert specific metadata key-value pairs |

---

## Database Schema

The migration creates an `audit_events` table:

| Column | Type | Notes |
|---|---|---|
| `actor_type` | string | Polymorphic actor class name |
| `actor_id` | bigint | Polymorphic actor ID |
| `action` | string | Event label, NOT NULL |
| `subject_type` | string | Polymorphic subject class name |
| `subject_id` | bigint | Polymorphic subject ID |
| `changeset` | text | JSON — before/after attribute pairs |
| `metadata` | text | JSON — arbitrary context hash |
| `created_at` | datetime | NOT NULL |

Indexes are created on `(actor_type, actor_id)`, `(subject_type, subject_id)`, `action`, and `created_at`.

---

## Contributing

1. Fork the repo
2. Create a feature branch: `git checkout -b my-feature`
3. Run the test suite: `bundle exec rspec`
4. Run the linter: `bundle exec rubocop`
5. Commit your changes and open a pull request

Please keep PRs focused and include tests for any new behavior.

---

## License

AuditTail is released under the [MIT License](LICENSE).
