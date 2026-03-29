# frozen_string_literal: true

require_relative "lib/audit_tail/version"

Gem::Specification.new do |spec|
  spec.name        = "audit_tail"
  spec.version     = AuditTail::VERSION
  spec.authors     = ["AuditTail"]
  spec.summary     = "Automatic activity and audit logging for Rails applications"
  spec.description = "Track who changed what, when, and why — with zero configuration needed to get started."
  spec.homepage    = "https://github.com/audit-tail/audit_tail"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir[
    "lib/**/*",
    "LICENSE",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"

  spec.metadata["rubygems_mfa_required"] = "true"
end
