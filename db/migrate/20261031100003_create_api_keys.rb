class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.references :firm, null: false, foreign_key: true
      t.text :token_digest, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :api_keys, :token_digest, unique: true
  end
end
