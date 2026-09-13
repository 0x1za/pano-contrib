# Active Storage's tables were created with string ids to match ours (see
# config.generators in application.rb), but its models do not inherit
# ApplicationRecord, so they need the same UUID default on create.
Rails.application.config.to_prepare do
  ActiveStorage::Record.before_create { self.id ||= SecureRandom.uuid }
end
