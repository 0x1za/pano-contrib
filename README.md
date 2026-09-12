# pano-contrib

Where people improve [pano](https://github.com/0x1za/pano), the addressing
scheme for Lusaka: confirm or dispute an address, name a place, leave a
delivery note. Contributions are reviewed, batched into changesets, and
consumed by the next gazetteer cut. The plan is in the pano repo under
`docs/contributions-plan.md`; this is phase 1.

Rails 8.1, SQLite, Solid Queue, importmap, Hotwire, Rails 8 auth, in the
style of span.

## Run it

```
bin/setup
bin/rails pano:import[../pano/gazetteer/v0.1.0]   # a published gazetteer directory
PANO_API_URL=http://127.0.0.1:8080 bin/dev         # the pano API must be running
```

Then open http://localhost:3000. Tap a building: "This is my address",
"Something is wrong", or a delivery note. Tap a district at city zoom to
confirm or rename it. Nobody has to sign in; each browser gets a device
token in a signed cookie and rack-attack throttles by device and by
address.

## Review

Anyone can agree or disagree with a pending contribution, once per device
and once per account, never with their own. The rules that turn votes
into acceptance are one pure module, `Acceptance`, with a table test; votes
only ever accept, and the four kinds the plan reserves for moderators
(disputes, missing buildings, boundary moves) wait for one. A nightly job
settles delivery notes unopposed for thirty days.

Accounts are optional. Signing in or up claims the device and everything
it contributed, so one person voting from two phones is still one vote.
Signups open with the `:signups` flag. Roles are contributor, moderator
and admin; reputation is a counter that only changes who is asked first.

- `/review`, moderators: the queue, moderator-only kinds first, oldest
  first. `j` and `k` move, `a` accepts, `r` rejects, `n` writes a note.
- `/avo` and `/flipper`, admins: the back office and the flags. Both 404
  for anyone else.

## Changesets

Accepted contributions reach the map through a changeset. `/changesets`
(moderators) drafts one from everything accepted and unassigned, refreshes
it until it is exported, and freezes it as `changes.json` on export. A
nightly job keeps the draft current. Then, in the pano repo:

```
aspect zone -- --changes changes.json --version 0.2.0
aspect validate -- --gazetteer gazetteer/v0.2.0
aspect diff -- gazetteer/v0.1.0 gazetteer/v0.2.0 --json > churn.json
```

and back here `bin/rails "pano:applied[CHANGESET_ID,0.2.0,churn.json]"`
stores the churn against the changeset, which its page then shows.

To make the first admin: `bin/rails runner 'User.find_by!(email_address: "you@example.com").role_admin!'`.

## Contract with pano

- `GazetteerImport` reads a gazetteer directory and, like the Rust
  reader, refuses it unless every file's SHA-256 matches `SHA256SUMS`.
  Places and buildings are imported per version and never edited.
- `PanoApi` calls the pano API for lookups; the map page talks to it
  directly from the browser.
- Changesets export `changes.json` for zoning: accepted names, reported
  buildings, homes inside shared buildings, and disputed cells. See below.

## Development

`bin/rails test`, `bin/rubocop`, `bin/brakeman`. `lefthook install` wires
the hooks. `/styleguide` renders every CSS primitive.
