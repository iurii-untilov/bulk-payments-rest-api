class Firm < ApplicationRecord
  has_many :api_keys, dependent: :restrict_with_exception
end
