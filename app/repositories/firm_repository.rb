class FirmRepository
  class << self
    # Ordered locking keeps concurrent transactions touching the same firms from deadlocking.
    def lock_by_uuids(uuids)
      Firm.where(uuid: uuids.uniq).order(:id).lock.to_a
    end

    def debit!(firm_id, cents)
      Firm.where(id: firm_id).where(balance_cents: cents..)
          .update_all([ "balance_cents = balance_cents - ?, updated_at = ?", cents, Time.current ]) == 1
    end

    def credit!(firm_id, cents)
      Firm.where(id: firm_id)
          .update_all([ "balance_cents = balance_cents + ?, updated_at = ?", cents, Time.current ]) == 1
    end
  end
end
