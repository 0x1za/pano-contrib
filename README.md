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
confirm or rename it. Nobody signs in; each browser gets a device token in
a signed cookie and rack-attack throttles by device and by address.

## Contract with pano

- `GazetteerImport` reads a gazetteer directory and, like the Rust
  reader, refuses it unless every file's SHA-256 matches `SHA256SUMS`.
  Places and buildings are imported per version and never edited.
- `PanoApi` calls the pano API for lookups; the map page talks to it
  directly from the browser.
- Changesets export `changes.json` for zoning (phase 3).

## Development

`bin/rails test`, `bin/rubocop`, `bin/brakeman`. `lefthook install` wires
the hooks. `/styleguide` renders every CSS primitive.
