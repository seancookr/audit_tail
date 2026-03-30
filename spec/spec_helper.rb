# frozen_string_literal: true

require "active_record"
require "database_cleaner/active_record"
require "webmock/rspec"
require "audit_tail"
require "audit_tail/test_helpers"

# In-memory SQLite database for tests
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :audit_events, force: true do |t|
    t.string :actor_type
    t.bigint :actor_id
    t.string :action, null: false
    t.string :subject_type
    t.bigint :subject_id
    t.text   :changeset, default: "{}"
    t.text   :metadata,  default: "{}"
    t.datetime :created_at, null: false
  end

  create_table :invoices, force: true do |t|
    t.string  :title
    t.decimal :amount
    t.string  :status
    t.string  :encrypted_password
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.timestamps
  end
end

# rubocop:disable Style/OneClassPerFile
class Invoice < ActiveRecord::Base
  audit_trail except: [:encrypted_password]
end

class InvoiceOnly < ActiveRecord::Base
  self.table_name = "invoices"
  audit_trail only: [:status]
end

class User < ActiveRecord::Base; end
# rubocop:enable Style/OneClassPerFile

RSpec.configure do |config|
  config.include AuditTail::TestHelpers

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  config.after do
    AuditTail.clear_actor!
  end
end
