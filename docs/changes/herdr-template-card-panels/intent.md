# Intent: herdr template with the card-panel tokens

Author: Etienne van Delden. Status: accepted. Type: chore. Delivery: autonomous. Codex review: no.

## Problem

`applications/herdr/template.toml.erb` writes a `[theme.custom]` block that no longer matches the herdr look Etienne settled in the dotfiles change `herdr-card-panels`. The dotfiles config hand-copies light values, and dark mode has no source for its values.

## Proposed outcome

The generated `dist/herdr/solunized-<variant>.toml` holds the settled tokens for every variant. The dotfiles change takes its dark-mode values from the generated dark file.

## Affected users and systems

- Etienne's herdr config in `~/Developer/dotfiles` (consumer, separate change).
- `applications/herdr/template.toml.erb`, `generate_themes.rb`, and the herdr checks in `test/generate_themes_test.rb`.

## Constraints

- `dist/` is gitignored. The dotfiles change runs `ruby generate_themes.rb` locally and copies the dark values.
- Every colour comes from `themes.yml` through `c(variant, name)`.
- In Solunized Dark no colour is darker than `bg_0`, so the frame uses the lighter `bg_1` in every variant.

## In scope

- Set these tokens in the herdr template, for every variant:
  - `accent` to `br_orange`.
  - `active_row_bg` to `bg_0`.
  - `panel_bg`, `sidebar_bg` and `surface_dim` to `bg_1`.
  - `overlay0` stays `bg_2`.
- A test that checks the generated herdr tokens for each of the four variants.

## Out of scope

- The dotfiles config, `ui` settings and agent rows: they are not theme tokens.
- Other applications' templates.
- A pane-background token: herdr has none.

## Acceptance criteria

- The generated light file sets `accent` to `#a44910`, `active_row_bg` to `#fffbf1`, and `panel_bg`, `sidebar_bg` and `surface_dim` to `#eeeae0`.
- The generated dark file sets `accent` to `br_orange` `#fa9253`, and `panel_bg`, `sidebar_bg` and `surface_dim` to `#0d3b4a`.
- `ruby test/generate_themes_test.rb` passes, and CI's regenerate-and-diff job stays clean.

## Decisions

- Change solunized so the herdr template is the single source of the dark values — Etienne's choice over copying them by hand.
- The mapping applies to all four variants, black and white included — Etienne's choice, so no variant keeps the old look.
- The frame uses `bg_1` in every variant, light and dark — Etienne chose the lighter `bg_1` for dark mode.

## Open questions

None.
