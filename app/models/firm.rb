class Firm < ApplicationRecord
  has_many :api_keys, dependent: :restrict_with_exception
  has_many :outgoing_payments, class_name: "Payment", foreign_key: :payer_firm_id, inverse_of: :payer_firm, dependent: :restrict_with_exception
  has_many :incoming_payments, class_name: "Payment", foreign_key: :payee_firm_id, inverse_of: :payee_firm, dependent: :restrict_with_exception
end
