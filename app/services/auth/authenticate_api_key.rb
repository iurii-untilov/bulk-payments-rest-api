module Auth
  class AuthenticateApiKey
    def self.call(token)
      raise AppError::Unauthorized if token.blank?

      api_key = ApiKeyRepository.find_active_by_digest(ApiToken.digest(token))
      raise AppError::Unauthorized unless api_key

      api_key.firm
    end
  end
end
