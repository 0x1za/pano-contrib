# Nightly: keep a draft changeset current for the latest gazetteer, so a
# moderator opening /changesets always sees what the next cut would take.
class DraftChangesetJob < ApplicationJob
  queue_as :background

  def perform
    version = GazetteerVersion.current or return
    Changeset.draft!(version)
  end
end
