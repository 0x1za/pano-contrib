require "flipper"
require "flipper/adapters/active_record"

# Flags live in the app's own database (SQLite, no Redis). Known flags:
#   :signups   — whether the registration form is open (off by default).
Flipper.configure do |config|
  config.adapter { Flipper::Adapters::ActiveRecord.new }
end
