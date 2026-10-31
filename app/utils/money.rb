module Money
  FORMAT = /\A\d+(\.\d{1,2})?\z/
  MAX_CENTS = 10**15

  def self.valid_format?(amount)
    amount.is_a?(String) && FORMAT.match?(amount)
  end

  def self.to_cents(amount)
    raise ArgumentError, "invalid amount format: #{amount.inspect}" unless valid_format?(amount)

    (BigDecimal(amount) * 100).to_i
  end

  def self.from_cents(cents)
    dollars, remainder = cents.divmod(100)
    Kernel.format("%d.%02d", dollars, remainder)
  end
end
