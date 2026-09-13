require "flipper"
require "flipper/adapters/active_record"

# Flags live in the app's own database (SQLite, no Redis). Known flags:
#   :signups      — whether the registration form is open (off by default).
#   :offline_map  — the saved-map path: service worker, tiles archive and
#                   "Save the map on this phone". Off by default while it
#                   settles; off, the page unregisters any worker it left
#                   behind and clears its caches.
Flipper.configure do |config|
  config.adapter { Flipper::Adapters::ActiveRecord.new }
end
