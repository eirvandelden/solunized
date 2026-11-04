# Plan: herdr template with the card-panel tokens

From `intent.md` (2026-11-04). Status: accepted.

## Design

### Domain terms

- Frame: the darker colour shared by the herdr tab bar and sidebar, set through `panel_bg`, `sidebar_bg` and `surface_dim`.
- Card: a pane on the terminal background, lighter than the frame in light mode.
- Variant: one of `dark`, `light`, `black`, `white` in `themes.yml`.

These are working terms. Etienne has not agreed them for the glossary.

### Diagrams

Not affected: one ERB template changes. No object model changes.

### Signatures

Not affected: no Ruby class or method changes, only `applications/herdr/template.toml.erb` and one test class.

Not checked: this project has no Steep and no RBS.

### Complexity

Not affected: the generator renders one small template per variant, as before.

### Invariants

- Every colour in the generated file comes from `themes.yml` through `c(variant, name)`. A missing key already raises `RuntimeError` in the generator.

### Alternatives

- Leave the template as it is and copy the dark values by hand into the dotfiles config. Rejected by Etienne: two sources of the dark values.

## Design decisions

- The mapping is the same for all four variants, as `intent.md` decides. `bg_1` is the frame in light, dark, black and white.
- `surface0` and `surface1` stay as they are. herdr 0.9.5 uses `surface0` for the inactive tab and `surface1` elsewhere, and the settled look did not change them.
- `overlay0`, `overlay1`, `text`, `subtext0` and the named colours stay as they are.

## Integration points

- The dotfiles change `herdr-card-panels` reads the generated dark values from `dist/herdr/solunized-dark.toml`. `dist/` is gitignored, so that change runs `ruby generate_themes.rb` locally after this one merges.
- `docs/colors.md` and `docs/slack.md` come from `themes.yml`. They do not change.

## Files that change

- `applications/herdr/template.toml.erb`: three existing lines change (`panel_bg`, `accent`, `surface_dim`) and two keys are added (`active_row_bg`, `sidebar_bg`).
- `test/generate_themes_test.rb`: a new `HerdrApplicationTest` class, in the style of `MvpaCssApplicationTest`.

## Order of work

1. Add `HerdrApplicationTest` to `test/generate_themes_test.rb`. Run `ruby test/generate_themes_test.rb -n /Herdr/` and watch it fail.
2. Edit `applications/herdr/template.toml.erb`: `accent` to `br_orange`, `panel_bg`, `sidebar_bg` and `surface_dim` to `bg_1`, and add `active_row_bg` as `bg_0`.
3. Run the narrow test again, then the full `ruby test/generate_themes_test.rb` and `ruby test/preview_palette_test.rb`.
4. Run `ruby generate_themes.rb` and check `git status`. Only `dist/` changes, and it is ignored.
5. Re-read the diff. Every hunk must be required by the task.

## Risks

- herdr 0.9.5 may treat `surface_dim` as a seam colour in a way that hides something in dark mode. The dotfiles change checks the look in a test session before it delivers.
- In dark mode `bg_1` is lighter than the panes, so the contrast flips against light mode. Etienne chose this.
- A token name typo passes `herdr config check` only if it is a known key. The test asserts each key by name, and the dotfiles change runs `herdr config check`.

## Proof

- The generated light file sets `accent` to `#a44910`, `active_row_bg` to `#fffbf1`, and `panel_bg`, `sidebar_bg` and `surface_dim` to `#eeeae0` → `test/generate_themes_test.rb` `test_light_variant_sets_the_card_panel_tokens`
- The generated dark file sets `accent` to `#fa9253`, and `panel_bg`, `sidebar_bg` and `surface_dim` to `#0d3b4a` → `test/generate_themes_test.rb` `test_dark_variant_sets_the_card_panel_tokens`
- `overlay0` stays `bg_2` in every variant → `test/generate_themes_test.rb` `test_every_variant_keeps_overlay0_on_bg_2`
- All four variants share the mapping → `test/generate_themes_test.rb` `test_every_variant_maps_the_card_panel_tokens_to_the_same_palette_names`
- `ruby test/generate_themes_test.rb` passes, and CI's regenerate-and-diff job stays clean → check: `ruby test/generate_themes_test.rb && ruby generate_themes.rb && git status --short` shows no tracked change.

Per changed file, the unit tests expected, named as behaviour:
- `applications/herdr/template.toml.erb`: `sets the card-panel tokens for light`, `sets them for dark`, `maps the same palette names in every variant`, `keeps overlay0 on bg_2`.

Test setup: the test generates the real herdr template into a temporary directory from the real `themes.yml`, as `MvpaCssApplicationTest` does, then reads each generated file.

---
Domain skills applied: None.

## Critique

### Round 1 (Codex)

- The plan's Proof does not verify that `overlay0` stays `bg_2` → fixed (added `test_every_variant_keeps_overlay0_on_bg_2` to Proof and the unit test list)
- The files-that-change entry miscounts the edits as five changed lines and two additions → fixed (reworded to three changed lines and two added keys)
- The invariant says a missing palette key raises `ArgumentError`, but `ErbContext#c` raises `RuntimeError` → fixed (invariant now names `RuntimeError`)
