class SeedInitialFirms < ActiveRecord::Migration[8.1]
  # Digests of the demo API tokens listed in README.md (development/demo only).
  DEMO_API_KEY_DIGESTS = {
    1 => "fee7871db403a4e55dc5c07b79643236009691355766f3459b734ab755316f6f",
    2 => "d410f25f5a633d6d5981308cbd92baebaadf19048d1949faf46832ab0c29d0b4",
    3 => "ecf14ad7e73d52239ee9965249a123e7c89ca65cf92175d7727ea773aa4aa304"
  }.freeze

  def up
    execute <<~SQL
      INSERT INTO firms (id, name, balance_cents, uuid, created_at, updated_at)
      VALUES (1, 'Pinecrest CPA Group', 5000000, '3f1c9a2e-7b4d-4c1e-9a55-2d8e6f0b7c41', NOW(), NOW()),
             (2, 'Lopez Bookkeeping', 50000, '8b2e4c71-0d3a-4f6e-b1c9-5a7d2e9f4c10', NOW(), NOW()),
             (3, 'Nair Tax Services', 200000, 'e5f18b3c-2a9d-4c07-8e6b-1d4a7f9c3b25', NOW(), NOW())
    SQL
    execute "SELECT setval(pg_get_serial_sequence('firms', 'id'), (SELECT MAX(id) FROM firms))"

    values = DEMO_API_KEY_DIGESTS.map { |firm_id, digest| "(#{firm_id}, '#{digest}', NOW(), NOW())" }.join(", ")
    execute "INSERT INTO api_keys (firm_id, token_digest, created_at, updated_at) VALUES #{values}"
  end

  def down
    execute "DELETE FROM api_keys WHERE firm_id IN (1, 2, 3)"
    execute "DELETE FROM firms WHERE id IN (1, 2, 3)"
  end
end
