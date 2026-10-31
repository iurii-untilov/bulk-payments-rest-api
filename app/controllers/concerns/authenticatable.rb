module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
    attr_reader :current_firm
  end

  private

  def authenticate!
    token, _options = ActionController::HttpAuthentication::Token.token_and_options(request)
    @current_firm = Auth::AuthenticateApiKey.call(token)
  rescue AppError::Unauthorized
    response.headers["WWW-Authenticate"] = 'Bearer realm="bulk-payments"'
    raise
  end

  def authorize_payer!(payer_firm_uuid)
    raise AppError::Forbidden unless current_firm.uuid == payer_firm_uuid
  end
end
