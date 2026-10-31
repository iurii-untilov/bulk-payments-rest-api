class IdempotencyKeyRepository
  class << self
    def find(firm_id:, key:)
      IdempotencyKey.find_by(firm_id:, key:)
    end

    def create!(firm_id:, key:, request_digest:, response_status:, response_body:)
      IdempotencyKey.create!(firm_id:, key:, request_digest:, response_status:, response_body:)
    end
  end
end
