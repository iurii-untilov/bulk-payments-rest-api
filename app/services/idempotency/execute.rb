module Idempotency
  class Execute
    Response = Data.define(:status, :body)

    def self.call(firm_id:, key:, request_digest:, &block)
      new(firm_id:, key:, request_digest:).call(&block)
    end

    def initialize(firm_id:, key:, request_digest:)
      @firm_id = firm_id
      @key = key
      @request_digest = request_digest
    end

    def call
      return yield if @key.nil?

      existing = IdempotencyKeyRepository.find(firm_id: @firm_id, key: @key)
      return replay(existing) if existing

      ApplicationRecord.transaction do
        response = yield
        IdempotencyKeyRepository.create!(
          firm_id: @firm_id, key: @key, request_digest: @request_digest,
          response_status: response.status, response_body: response.body
        )
        response
      end
    rescue ActiveRecord::RecordNotUnique
      record = IdempotencyKeyRepository.find(firm_id: @firm_id, key: @key)
      raise unless record

      replay(record)
    end

    private

    def replay(record)
      raise AppError::IdempotencyConflict unless record.request_digest == @request_digest

      Rails.logger.info("Idempotent replay firm_id=#{@firm_id} key=#{@key}")
      Response.new(status: record.response_status, body: record.response_body)
    end
  end
end
