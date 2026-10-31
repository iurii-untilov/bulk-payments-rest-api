class Payment < ApplicationRecord
  belongs_to :payer_firm, class_name: "Firm"
  belongs_to :payee_firm, class_name: "Firm"
end
