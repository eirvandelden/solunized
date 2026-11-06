# Intent: herdr template emits mode tables

Author: Etienne van Delden. Status: accepted (2026-11-06). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

herdr 0.9.5 reads only the dotfiles `config.toml`, with no include and no theme files. The generated `dist/herdr/solunized-<variant>.toml` files cannot load.

The dotfiles config holds hand-copied `[theme.custom.light]` and `[theme.custom.dark]` tables. The generated files use a plain `[theme.custom]` header, so they cannot be copied into the config as they are.

The template also emits 18 tokens, while the config holds six. A copy would change colours.

## Proposed outcome

The light and dark herdr files carry the mode headers herdr expects, and hold only the six card-panel tokens. A later dotfiles change can copy their content into the config with no colour change.

## Affected users and systems

- `applications/herdr/template.toml.erb` and `test/generate_themes_test.rb` (`HerdrApplicationTest`) in solunized.
- The dotfiles repository, which later syncs from `dist/herdr/` (a separate intent).

## Constraints

- Solunized palette colours only, from `themes.yml`.
- `dist/` stays gitignored. CI regenerates it and diffs.
- The six tokens keep the card-panel mapping from PR #21: `panel_bg`, `sidebar_bg` and `surface_dim` = `bg_1`; `active_row_bg` = `bg_0`; `accent` = `br_orange`; `overlay0` = `bg_2`.
- No permission is needed: no gem, tool, migration or deploy file.

## In scope

- Header `[theme.custom.light]` for variant `light`, `[theme.custom.dark]` for variant `dark`.
- Cut the template to the six tokens above.
- Update `HerdrApplicationTest` for the new headers and token set.

## Out of scope

- The dotfiles sync script, markers and drift test (second intent).
- Black and white variants: they keep the `[theme.custom]` header. Their token set follows the template cut.
- Any colour change, and any new colour.

## Acceptance criteria

- `dist/herdr/solunized-light.toml` starts with `[theme.custom.light]` and holds exactly `accent`, `active_row_bg`, `overlay0`, `panel_bg`, `sidebar_bg`, `surface_dim`.
- `dist/herdr/solunized-dark.toml` starts with `[theme.custom.dark]` and holds the same six tokens.
- The light values are `#a44910`, `#fffbf1`, `#d5d2c8`, `#eeeae0`, `#eeeae0`, `#eeeae0` and the dark values are `#fa9253`, `#012b38`, `#2a5d6e`, `#0d3b4a`, `#0d3b4a`, `#0d3b4a`, in the token order above. They equal the dotfiles config today.
- `solunized-black.toml` and `solunized-white.toml` still start with `[theme.custom]`.
- The solunized tests pass.

## Decisions

- Light and dark only get mode tables, chosen by variant name — Etienne needs only light and dark, not black and white.
- Cut the template to the six card-panel tokens — the sync must not change any colour value.
- Deliver autonomously, Claude review only — Etienne's choice in the intent interview, no reason given.

## Open questions

None.
