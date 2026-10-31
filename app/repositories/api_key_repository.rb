class ApiKeyRepository
  class << self
    def find_active_by_digest(token_digest)
      ApiKey.active.includes(:firm).find_by(token_digest:)
    end

    def create!(firm:, token_digest:)
      ApiKey.create!(firm:, token_digest:)
    end
  end
end
