module Payments
  class CreateBulkPayment
    LOCK_TIMEOUT = "5s"

    Result = Data.define(:payer, :payments, :payer_balance_cents)

    def self.call(payer_uuid:, payments:)
      new(payer_uuid:, payments:).call
    end

    def initialize(payer_uuid:, payments:)
      @payer_uuid = payer_uuid
      @payments = payments.map do |payment|
        { payee_uuid: payment[:payee_firm_uuid], amount_cents: Money.to_cents(payment[:amount]), description: payment[:description] }
      end
    end

    def call
      ApplicationRecord.transaction do
        ApplicationRecord.connection.execute("SET LOCAL lock_timeout = '#{LOCK_TIMEOUT}'")

        firms = FirmRepository.lock_by_uuids([ @payer_uuid, *payee_uuids ]).index_by(&:uuid)
        payer = firms.fetch(@payer_uuid)
        ensure_payees_exist!(firms)
        ensure_sufficient_funds!(payer)

        FirmRepository.debit!(payer.id, total_cents) || raise(AppError::InsufficientFunds)
        credits_by_payee.each { |uuid, cents| FirmRepository.credit!(firms.fetch(uuid).id, cents) }
        created = PaymentRepository.create_many!(payment_rows(payer, firms))

        log_success(payer, created)
        Result.new(payer:, payments: present(created, firms), payer_balance_cents: payer.balance_cents - total_cents)
      end
    rescue ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked => e
      Rails.logger.error("Bulk payment lock failure payer_firm_uuid=#{@payer_uuid}: #{e.class}: #{e.message}")
      raise AppError::ServiceUnavailable
    end

    private

    def payee_uuids
      @payee_uuids ||= @payments.map { |payment| payment[:payee_uuid] }.uniq
    end

    def total_cents
      @total_cents ||= @payments.sum { |payment| payment[:amount_cents] }
    end

    def credits_by_payee
      @payments.group_by { |payment| payment[:payee_uuid] }
               .transform_values { |group| group.sum { |payment| payment[:amount_cents] } }
    end

    def ensure_payees_exist!(firms)
      missing = payee_uuids - firms.keys
      return if missing.empty?

      raise AppError::UnknownPayee.new(details: { payee_firm_uuids: missing })
    end

    def ensure_sufficient_funds!(payer)
      return if payer.balance_cents >= total_cents

      raise AppError::InsufficientFunds.new(
        details: { required: Money.from_cents(total_cents), available: Money.from_cents(payer.balance_cents) }
      )
    end

    def payment_rows(payer, firms)
      @payments.map do |payment|
        {
          payer_firm_id: payer.id,
          payee_firm_id: firms.fetch(payment[:payee_uuid]).id,
          amount_cents: payment[:amount_cents],
          description: payment[:description]
        }
      end
    end

    def present(created, firms)
      uuids_by_id = firms.values.to_h { |firm| [ firm.id, firm.uuid ] }
      created.map do |row|
        {
          id: row["id"],
          payee_firm_uuid: uuids_by_id.fetch(row["payee_firm_id"]),
          amount_cents: row["amount_cents"],
          description: row["description"]
        }
      end
    end

    def log_success(payer, created)
      Rails.logger.info(
        "Bulk payment accepted payer_firm_id=#{payer.id} payments=#{created.size} total_cents=#{total_cents}"
      )
    end
  end
end
