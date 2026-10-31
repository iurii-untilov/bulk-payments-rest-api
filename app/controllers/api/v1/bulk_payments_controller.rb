module Api
  module V1
    class BulkPaymentsController < ApplicationController
      IDEMPOTENCY_KEY_FORMAT = /\A[\x21-\x7E]{1,255}\z/

      def create
        payload = validate!(BulkPaymentContract.new, request.request_parameters)
        authorize_payer!(payload[:payer_firm_uuid])

        outcome = Idempotency::Execute.call(
          firm_id: current_firm.id, key: idempotency_key, request_digest: Digest::SHA256.hexdigest(payload.to_json)
        ) do
          result = Payments::CreateBulkPayment.call(payer_uuid: current_firm.uuid, payments: payload[:payments])
          Idempotency::Execute::Response.new(status: 201, body: BulkPaymentSerializer.call(result))
        end

        render json: outcome.body, status: outcome.status
      end

      private

      def idempotency_key
        key = request.headers["Idempotency-Key"]
        return if key.nil?
        return key if IDEMPOTENCY_KEY_FORMAT.match?(key)

        raise AppError::ValidationFailed.new(details: { idempotency_key: [ "must be 1-255 printable ASCII characters" ] })
      end
    end
  end
end
