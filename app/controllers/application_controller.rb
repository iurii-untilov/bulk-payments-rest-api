class ApplicationController < ActionController::API
  include Authenticatable

  wrap_parameters false

  rescue_from StandardError, with: :render_internal_error
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_app_error(AppError::MalformedRequest.new)
  end
  rescue_from AppError, with: :render_app_error

  private

  def validate!(contract, input)
    result = contract.call(input)
    return result.to_h if result.success?

    Rails.logger.debug { "Validation failed: #{result.errors.to_h}" }
    raise AppError::ValidationFailed.new(details: result.errors.to_h)
  end

  def render_app_error(error)
    level = error.status_code >= 500 ? :error : :warn
    Rails.logger.public_send(level, "#{error.class.name} (#{error.status_code}): #{error.message} #{error.details&.to_json}")
    render_error(error.status, error.code, error.message, details: error.details)
  end

  def render_internal_error(error)
    Rails.logger.error(([ "Unhandled #{error.class}: #{error.message}" ] + Array(error.backtrace)).join("\n"))
    render_error(:internal_server_error, "internal_error", "Internal server error")
  end

  def render_error(status, code, message, details: nil)
    render json: { error: { code:, message:, details:, request_id: request.request_id }.compact }, status:
  end
end
