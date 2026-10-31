class CreateFirms < ActiveRecord::Migration[8.1]
  def change
    create_table :firms do |t|
      t.text :name, null: false
      t.bigint :balance_cents, null: false, default: 0
      t.text :uuid, null: false
      t.timestamps
    end

    add_index :firms, :uuid, unique: true
    add_check_constraint :firms, "balance_cents >= 0", name: "firms_balance_cents_non_negative"
  end
end
