# Avo adds its 3 MB admin bundle to the app's importmap, and importmap-rails
# emits a modulepreload for every pin on every page. The public map does
# not need the admin: keep the pin, so /avo still resolves it, but do not
# preload it anywhere.
Rails.application.config.after_initialize do
  Rails.application.importmap.pin "avo/application", to: "avo/application.js", preload: false
end
