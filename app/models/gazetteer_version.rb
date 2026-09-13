# One published gazetteer, imported from its directory. Contributions are
# pinned to the version they were made against, so a re-cut never orphans
# them and the churn report can say what became of each.
class GazetteerVersion < ApplicationRecord
  has_many :places, dependent: :delete_all
  has_many :buildings, dependent: :delete_all
  has_many :contributions, dependent: :restrict_with_error
  has_many :changesets, dependent: :restrict_with_error
  has_many :surveys, dependent: :restrict_with_error

  validates :version, :sha256, :area, :imported_at, presence: true
  validates :version, :sha256, uniqueness: true
  validates :sha256, format: { with: /\A\h{64}\z/ }

  def self.current
    order(imported_at: :desc).first
  end

  def district_name(code)
    names[code]
  end
end
