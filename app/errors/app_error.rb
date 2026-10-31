class AppError < StandardError
  class_attribute :status, :code, :default_message

  attr_reader :details

  def initialize(message = default_message, details: nil)
    super(message)
    @details = details
  end

  def status_code
    Rack::Utils.status_code(status)
  end

  class MalformedRequest < AppError
    self.status = :bad_request
    self.code = "malformed_request"
    self.default_message = "Request body must be a valid JSON document"
  end

  class ValidationFailed < AppError
    self.status = :bad_request
    self.code = "validation_failed"
    self.default_message = "Request validation failed"
  end

  class Unauthorized < AppError
    self.status = :unauthorized
    self.code = "unauthorized"
    self.default_message = "A valid API key is required"
  end

  class Forbidden < AppError
    self.status = :forbidden
    self.code = "forbidden"
    self.default_message = "The API key is not allowed to pay on behalf of this firm"
  end

  class IdempotencyConflict < AppError
    self.status = :conflict
    self.code = "idempotency_key_conflict"
    self.default_message = "Idempotency-Key was already used with a different request"
  end

  class UnknownPayee < AppError
    self.status = :unprocessable_content
    self.code = "unknown_payee"
    self.default_message = "One or more payee firms do not exist"
  end

  class InsufficientFunds < AppError
    self.status = :unprocessable_content
    self.code = "insufficient_funds"
    self.default_message = "The payer firm does not have enough funds for all payments"
  end

  class ServiceUnavailable < AppError
    self.status = :service_unavailable
    self.code = "service_unavailable"
    self.default_message = "The service is temporarily unavailable, please retry"
  end
end
