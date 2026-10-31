class CreateIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :idempotency_keys do |t|
      t.references :firm, null: false, foreign_key: true, index: false
      t.text :key, null: false
      t.text :request_digest, null: false
      t.integer :response_status, null: false
      t.jsonb :response_body, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :idempotency_keys, [ :firm_id, :key ], unique: true
  end
end
