# Rows are never destroyed, only marked. There is deliberately no default
# scope: every query says `kept` on purpose, so a forgotten scope shows up
# in review rather than silently hiding rows.
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(deleted_at: nil) }
    scope :discarded, -> { where.not(deleted_at: nil) }

    before_update { self.version += 1 }
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end
end
