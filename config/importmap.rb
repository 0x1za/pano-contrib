# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# MapLibre GL JS 4.7.1, UMD build vendored from jsDelivr (BSD-3). It sets
# window.maplibregl; controllers import it for its side effect.
pin "maplibre-gl" # vendor/javascript/maplibre-gl.js
