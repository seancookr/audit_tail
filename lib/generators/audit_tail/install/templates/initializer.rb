# frozen_string_literal: true

AuditTail.configure do |config|
  # Default backend: :active_record
  # config.backend = :active_record

  # Attributes always ignored in changesets (applies globally)
  # config.ignored_attributes = %w[created_at updated_at]
end
