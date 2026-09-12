class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # String UUID primary keys on every table, assigned in Ruby so a client
  # working offline can mint an id and replay the record later.
  before_create { self.id ||= SecureRandom.uuid }
end
