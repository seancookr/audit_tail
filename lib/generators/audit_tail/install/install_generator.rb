# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module AuditTail
  module Generators
    # Rails generator that creates the AuditTail migration and initializer.
    class InstallGenerator < ::Rails::Generators::Base
      include ::ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates an AuditTail initializer and migration in your application."

      def create_migration
        migration_template "migration.rb.tt", "db/migrate/create_audit_events.rb",
                           migration_version: migration_version
      end

      def create_initializer
        template "initializer.rb", "config/initializers/audit_tail.rb"
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
