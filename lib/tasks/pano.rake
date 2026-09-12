namespace :pano do
  desc "Import a published gazetteer directory, e.g. bin/rails pano:import[../pano/gazetteer/v0.1.0]"
  task :import, [ :dir ] => :environment do |_, args|
    dir = args[:dir] or abort "usage: bin/rails pano:import[DIR]"
    version = GazetteerImport.new(dir).call
    puts "imported v#{version.version} (#{version.sha256[0, 12]}): #{version.units_count} units, #{version.buildings_count} buildings"
  end

  desc "Write a changeset's changes.json: pano:export[CHANGESET_ID,path]"
  task :export, [ :changeset_id, :path ] => :environment do |_, args|
    changeset = Changeset.find(args.fetch(:changeset_id))
    File.write(args.fetch(:path), changeset.to_json_file)
    puts "wrote #{args[:path]} (#{changeset.status})"
  end

  desc "Record that a changeset was applied in a cut: pano:applied[CHANGESET_ID,VERSION,churn.json]"
  task :applied, [ :changeset_id, :version, :churn ] => :environment do |_, args|
    changeset = Changeset.find(args.fetch(:changeset_id))
    churn = JSON.parse(File.read(args.fetch(:churn)))
    changeset.applied!(version: args.fetch(:version), churn: churn)
    total = churn["total"] || {}
    puts "changeset #{changeset.id.first(8)} applied in v#{args[:version]}: #{total["same_address"]} of #{total["buildings"]} addresses kept"
  end
end
