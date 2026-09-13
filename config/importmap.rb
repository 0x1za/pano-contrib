# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/sync", under: "sync"
pin_all_from "app/javascript/offline", under: "offline"

# MapLibre GL JS 4.7.1, UMD build vendored from jsDelivr (BSD-3). It sets
# window.maplibregl; controllers import it for its side effect.
pin "maplibre-gl" # vendor/javascript/maplibre-gl.js

# pmtiles 4.5.0, UMD build vendored from npm (BSD-3), which bundles fflate
# and sets window.pmtiles: the pmtiles:// protocol that lets MapLibre
# range-read one archive instead of a tile server.
pin "pmtiles" # vendor/javascript/pmtiles.js
