# An anonymous contributor: a random token in a signed cookie, stored only
# as a digest. Signing up later claims the device's history.
class Device < ApplicationRecord
  belongs_to :user, optional: true
  has_many :contributions, dependent: :restrict_with_error
  has_many :votes, dependent: :restrict_with_error

  validates :token_digest, presence: true, uniqueness: true

  # Mints a token, stores its digest, and returns both. The raw token is
  # shown to the browser once, as the cookie value.
  def self.issue!
    raw = SecureRandom.base58(32)
    device = create!(token_digest: digest(raw), first_seen_at: Time.current, last_seen_at: Time.current)
    [ device, raw ]
  end

  def self.find_by_token(raw)
    return if raw.blank?
    find_by(token_digest: digest(raw))
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end

  def stats
    Badges.stats(contributions: contributions, votes: votes)
  end

  def touch_seen!
    update_column(:last_seen_at, Time.current) if last_seen_at < 1.minute.ago
  end
end
