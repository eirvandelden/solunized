# Intent: Firefox theme add-on

Author: Etienne van Delden. Status: accepted (2026-10-20). Type: feature. Delivery: autonomous

## Problem

Solunized has no Firefox output. Firefox cannot show the Solunized colours, so the browser clashes with the editor and terminal themes.

## Proposed outcome

`ruby generate_themes.rb` writes Firefox theme manifests built from `themes.yml`, using the `theme.colors` keys from the MDN `manifest.json` theme reference. Light and dark share one add-on. Black and white share a second add-on. The generator also zips each add-on. A separate script signs the zips for unlisted self-distribution through `npx web-ext sign`. Only Etienne runs that script.

## Affected users and systems

Etienne's Firefox. The Solunized generator: a new `applications/` entry, its template, tests and the README application table.

## Constraints

- `themes.yml` stays the single source of colours. No hex value is copied into the template.
- Output goes under `dist/`, which is gitignored.
- Firefox release only installs themes signed by Mozilla. `generate_themes.rb` never signs and never uses the network. The zip uses the Ruby standard library.
- Approved by Etienne: `web-ext`, run through `npx`, as the signing tool, with the unlisted channel. It needs Node.js 22 or later. It is not added to the repo as a dependency. No gem, migration or deploy file is needed.
- The AMO API key and secret come from `WEB_EXT_API_KEY` and `WEB_EXT_API_SECRET`, set by Etienne. They never enter the repo, a test or an agent session.
- Agents never run the signing script, because it submits the add-on to Mozilla.
- The generator today writes one file per app, or one file per variant. It must now produce two distinct manifests.

## In scope

- A manifest with `theme` set from the light variant and `dark_theme` set from the dark variant. Firefox picks one by the OS colour scheme.
- A second manifest with `theme` set from white and `dark_theme` set from black.
- Colours only: `theme.colors`, using the full list of current (non-deprecated) keys from the MDN reference. Colour values come from the existing palette names.
- A unique name per add-on, a fixed add-on id and a version, so Firefox accepts the manifest.
- A mapping from palette colours to every current key (frame, toolbar, tabs, URL bar, popup, sidebar, new tab page, buttons), chosen in the plan and checked by Etienne on screen. The nine keys the Firefox Color add-on edits (`toolbar`, `toolbar_text`, `frame`, `tab_background_text`, `toolbar_field`, `toolbar_field_text`, `tab_line`, `popup`, `popup_text`) use the values Etienne enters by hand now.
- A signing script that wraps `npx web-ext sign --channel unlisted` for each zip. It reads the credentials from the environment.
- Tests, and a README entry in the supported applications table.

## Out of scope

- The listed channel and the public Mozilla themes store.
- Running the signing script, in a session, in tests or in CI. Only Etienne runs it.
- Storing or fetching the AMO credentials.
- `userChrome.css`, `user.js` and any other profile file.
- Theme images and `theme.properties`.
- Deprecated keys: `tab_background_separator`, `toolbar_field_separator`.
- New colours in `themes.yml`.

## Acceptance criteria

- Running the generator writes a light+dark manifest and a white+black manifest under `dist/firefox/`.
- In the light+dark manifest, `theme.colors.frame` equals the light background and `dark_theme.colors.frame` equals the dark background.
- In the white+black manifest, the same two keys equal the white and black backgrounds.
- Every manifest is valid JSON. Each of `theme` and `dark_theme` has every current key, and every value is a `#RRGGBB` string from `themes.yml`.
- In the dark variant, `toolbar_text` and `toolbar` are different colours, so the toolbar text stays readable.
- Each manifest names its add-on, so Etienne can tell the two apart in `about:addons`.
- Each add-on also exists as a `.zip` under `dist/firefox/` with `manifest.json` at its root, ready to sign.
- The signing script refuses to run without `WEB_EXT_API_KEY` and `WEB_EXT_API_SECRET`, and says which one is missing. Its tests run without the network and without `npx`.
- The README explains how to get the AMO credentials, run the script and install the signed `.xpi`.
- A temporary load through `about:debugging` applies the dark colours when the OS is in dark mode and the light colours otherwise.
- The README lists Firefox in the supported applications table.

## Decisions

- Light and dark go in one add-on (`theme` plus `dark_theme`) — chosen by Etienne.
- Black and white ship as a second add-on in the same run — recommended default, accepted by Etienne.
- Manifest only, no profile files — chosen by Etienne.
- The generator covers the full key list; the nine Firefox Color keys are only the hand-entry values needed now — "the intent for the generator is the full list".
- Signing is a separate script around `npx web-ext sign --channel unlisted`, run only by Etienne — he approved `web-ext` and asked "can we also do the signing and submitting?"
- The generator zips each add-on and does not sign it — Firefox Color holds one theme, so hand entry cannot switch with dark mode: "applying by hand only allows 1 theme, so i'm stuck in light theme".

## Open questions

None.
