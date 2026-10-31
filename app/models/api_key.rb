class ApiKey < ApplicationRecord
  belongs_to :firm

  scope :active, -> { where(revoked_at: nil) }
end
