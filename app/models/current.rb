class Current < ActiveSupport::CurrentAttributes
  attribute :session, :device
  delegate :user, to: :session, allow_nil: true
end
