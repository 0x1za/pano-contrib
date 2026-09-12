namespace :pano do
  desc "Import a published gazetteer directory, e.g. bin/rails pano:import[../pano/gazetteer/v0.1.0]"
  task :import, [ :dir ] => :environment do |_, args|
    dir = args[:dir] or abort "usage: bin/rails pano:import[DIR]"
    version = GazetteerImport.new(dir).call
    puts "imported v#{version.version} (#{version.sha256[0, 12]}): #{version.units_count} units, #{version.buildings_count} buildings"
  end
end
