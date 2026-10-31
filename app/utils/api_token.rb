module ApiToken
  PREFIX = "bp_"

  def self.generate
    PREFIX + SecureRandom.hex(32)
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end
end
