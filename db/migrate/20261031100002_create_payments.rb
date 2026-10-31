class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :payer_firm, null: false, foreign_key: { to_table: :firms }
      t.references :payee_firm, null: false, foreign_key: { to_table: :firms }
      t.bigint :amount_cents, null: false
      t.text :description, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_check_constraint :payments, "amount_cents > 0", name: "payments_amount_cents_positive"
    add_check_constraint :payments, "payer_firm_id <> payee_firm_id", name: "payments_payer_differs_from_payee"
  end
end
