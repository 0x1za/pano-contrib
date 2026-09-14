# Avo adds its 3 MB admin bundle to the app's importmap, and importmap-rails
# emits a modulepreload for every pin on every page. The public map does
# not need the admin. Avo's importmap file is taken out of the paths and
# the pin lives in config/importmap.rb with preload off, which survives
# the redraws development does when importmap.rb changes.
Rails.application.config.after_initialize do
  Rails.application.config.importmap.paths.delete_if { |p| p.to_s.include?("/avo-") }
end

Rails.application.initializer "pano.avo_importmap", after: "avo.assets-importmaps", before: "importmap" do |app|
  app.config.importmap.paths.delete_if { |p| p.to_s.include?("/avo-") }
end
