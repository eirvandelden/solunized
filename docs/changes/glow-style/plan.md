# Plan: Solunized style for glow

From `intent.md` (2026-10-13). Status: accepted.

## Design decisions

- One combined output: `applications/glow/configuration.yml` sets `per_theme: false`, `output_dir: dist/glow`, `filename: solunized.json`. The style is the same for every variant, because the terminal palette carries the variant.
- Colours are named, not numbered, in the template. The top of `template.json.erb` holds one ERB hash that maps Selenized names to the ANSI slot Ghostty's Solunized palette gives them (`applications/ghostty/template.config.erb`): `fg_0` 0, `red` 1, `green` 2, `yellow` 3, `blue` 4, `magenta` 5, `cyan` 6, `dim_0` 7, `fg_1` 8, `br_red` 9 … `br_cyan` 14. JSON allows no comments, so the hash is the only place this mapping is written down. The generator (`generate_themes.rb`) does not change.
- Glamour colours are JSON strings (`"color": "4"`), as in glamour's own `dark.json`.
- Element colours:
  - `document`: no colour, so body text uses the terminal foreground (`fg_1` in Ghostty). This is the most readable choice in both modes.
  - `heading` (all levels): `blue`, bold. `h1` gets the prefix `"# "`, because glamour's `dark.json` marks `h1` with a background colour, which this style may not use. `h2`–`h5` keep `dark.json`'s `"## "`… prefixes. `h6`: `dim_0`, not bold.
  - `link`: `cyan`, underlined. `link_text`: `cyan`, bold.
  - `code` (inline): `green`. `code_block`: no `color`, so tokens without a chroma colour use the terminal foreground. Inline `code` gets no `prefix`/`suffix` spaces; those only exist in `dark.json` to pad the background.
  - `image`: `magenta`, underlined. `image_text`: `dim_0`, with `dark.json`'s `"Image: {{.text}} →"` format.
  - `block_quote`, `hr`: `dim_0`.
  - Layout keys without colour (`margin`, `indent`, `level_indent`, `block_prefix`/`block_suffix`, list bullets, task markers, `definition_description`) copy glamour's `dark.json`.
- `code_block` gets a `chroma` block for syntax highlighting, limited to five palette-safe chroma names (decided by Etienne on 2026-10-13, after the planner's "Decision needed"). Glamour v2.0.1 hardcodes chroma's `terminal256` formatter. Probed with glow 3.0.0, only five chroma names land on a palette slot: `#ansidarkred` → `38;5;1`, `#ansidarkgreen` → `38;5;2`, `#ansidarkblue` → `38;5;4`, `#ansipurple` → `38;5;5`, `#ansiteal` → `38;5;6`. Indices 0–15 of the 256-colour table are the terminal's palette slots, so Ghostty swaps them with the variant. Every other `#ansi…` name maps to a fixed index (`#ansibrown` 104, `#ansilightgray` 254, `#ansidarkgray` 240, `#ansiblack` 16, `#ansired` 196, `#ansigreen` 46, `#ansiyellow` 226, `#ansiblue` 21, `#ansifuchsia` 201, `#ansiturquoise` 51, `#ansiwhite` 231) and is forbidden. A misspelt name makes glow panic (`invalid colour`).
  - The template maps Selenized names to these chroma names in a second ERB hash beside the slot hash: `red` → `#ansidarkred`, `green` → `#ansidarkgreen`, `blue` → `#ansidarkblue`, `magenta` → `#ansipurple`, `cyan` → `#ansiteal`.
  - Token colours: keywords and `keyword_type` blue (bold for `keyword`); strings cyan; numbers and constants (`literal_number`, `name_constant`, `keyword_constant`) magenta; `name_function`, `name_class` and `name_builtin` green; `name_tag` and `name_attribute` blue; `generic_inserted` green; `generic_deleted` and `error` red. `comment` gets no colour and italic, because the palette has no dim slot for chroma. `text` and every other token get no colour, so they use the terminal foreground. No `background` key and no `background_color` in `chroma`.
  - This amends acceptance criterion 2 ("every colour is an ANSI number 0–15"): chroma colours are those five names instead of numbers, and the rendered output still uses palette slots only.
- `AGENTS.md` ("What this is") lists the generated apps; add Glow to that list so the repository context stays true. `CLAUDE.md` is a symlink to `AGENTS.md`, so it follows.

## Integration points

- `applications/ghostty/template.config.erb`: the ANSI slot layout the glow style depends on. Not edited. A unit test reads Ghostty's generated palette, so a future reorder of the Ghostty palette fails the glow tests instead of silently miscolouring glow.
- `generate_themes.rb`: `process_all_apps` picks up every `applications/*/configuration.yml` and the single `template.*.erb` beside it. `template.json.erb` matches the existing `template.<ext>.erb` rule. No code change.
- Glow 3.0.0 (Homebrew, `/opt/homebrew/bin/glow`, built on glamour v2). Probed during planning with an ANSI-only style that had no `chroma`: exit 0, output used only SGR `32`, `34;1`, `36;4`. Probed again with the five chroma names above: a Ruby code block emits only `38;5;2`, `38;5;4`, `38;5;6`, `1`, `3` and `0`. A truncated JSON style exits 1 with `Error: unable to create renderer: unexpected end of JSON input`; a missing file exits 1 with `Error: specified style does not exist`.
- Glow blocks when stdin is not a terminal and is left open. Every scripted glow command in this plan redirects `</dev/null`.
- CI: `dist/` is gitignored, so the regenerate-and-diff job sees no new committed file. CI does not install glow; nothing in the test suite calls it.

## Files that change

- `applications/glow/configuration.yml` — new; the glow target.
- `applications/glow/template.json.erb` — new; the slot hash and the glamour style.
- `test/generate_themes_test.rb` — one new assertion in `FullApplicationIntegrationTest#test_generates_real_templates_and_validates_zed_json`, and a new `GlowApplicationTest` class after `NovaApplicationTest`, in the same setup style (real `themes.yml`, real config with `output_dir` redirected to a tmpdir, `process_erb_app`).
- `README.md` — a Glow row in "Supported applications": `[Glow](https://github.com/charmbracelet/glow)` → `applications/glow/configuration.yml`, plus a short note that the style uses the terminal's ANSI palette, so it shows Solunized colours only in a terminal running a Solunized palette.
- `AGENTS.md` — add Glow to the app list in "What this is".

## Order of work

1. Add `assert File.exist?(File.join(@tmpdir, "out", "glow", "solunized.json"))` to `FullApplicationIntegrationTest#test_generates_real_templates_and_validates_zed_json`. Run `ruby test/generate_themes_test.rb -n test_generates_real_templates_and_validates_zed_json`. Watch it fail on the missing file.
2. Add `applications/glow/configuration.yml` and a `template.json.erb` holding the slot hash and `{}`. Run step 1's command again: green.
3. Write `GlowApplicationTest` (see Proof). Run `ruby test/generate_themes_test.rb -n /GlowApplicationTest/`. Watch the colour and slot tests fail against the empty style.
4. Fill in the style per Design decisions. Run step 3's command until green.
5. Run both full suites: `ruby test/generate_themes_test.rb` and `ruby test/preview_palette_test.rb`.
6. Add the README row and note, and the `AGENTS.md` mention.
7. Run the checks in Proof: generate, render with glow, inspect the SGR codes, confirm the README row, confirm `git status --porcelain` shows no change to `docs/`.
8. Re-read the full diff (playbook rule 21) and commit in small steps: tests and generator target, then docs.

## Risks

- Ghostty palette drift: the slot hash duplicates Ghostty's layout. Covered by the slot test in `GlowApplicationTest`.
- Another terminal or palette (Terminal.app, the black and white variants, a non-Solunized palette) shows other colours. ANSI 0 is `fg_0` in Solunized but black elsewhere; the style avoids slot 0 for that reason and leaves body text on the terminal foreground. Out of scope per intent.
- No tinted code background. Accepted in the intent's flagged concern (no `bg_1`/`bg_2` in the palette). Syntax highlighting uses five accents only: no yellow, no dim comments.
- Chroma's name-to-index mapping could change in a later glow/chroma. The recorded SGR check catches it on the installed glow; the unit test pins the template to the five names.
- Glamour key names change between versions. The style copies key names from glamour's current `dark.json`, and the glow render check runs against the installed glow 3.0.0. Unknown keys are ignored by glamour's JSON parser, so a renamed key degrades one element; it does not break the render.
- Rejected: per-variant hex styles (out of scope per intent); chroma `#ansi…` names other than the five above (they map to fixed `38;5;N` indices outside 0–15); adding an `ansi(name)` helper to `ErbContext` (only one template needs it, and the generator stays untouched).
- Rejected: an automated test that shells out to glow. CI has no glow, and a test that skips itself when glow is missing is a skipped test. The glow render stays a recorded check.

## Proof

- Running `ruby generate_themes.rb` writes `dist/glow/solunized.json` → `test/generate_themes_test.rb` `FullApplicationIntegrationTest#test_generates_real_templates_and_validates_zed_json` (new glow assertion); plus check: `ruby generate_themes.rb && test -f dist/glow/solunized.json`.
- Every colour is an ANSI number 0–15, or inside `chroma` one of the five palette-safe names; no hex colours; no background colours → `test/generate_themes_test.rb` `GlowApplicationTest#test_every_colour_outside_chroma_is_an_ansi_number_from_0_to_15`, `#test_every_chroma_colour_is_a_palette_safe_name`, `#test_has_no_hex_colours`, `#test_has_no_background_colours`.
- `glow --style dist/glow/solunized.json README.md` renders without a style error → check: `glow --style dist/glow/solunized.json README.md </dev/null >/dev/null` exits 0 with nothing on stderr; then `CLICOLOR_FORCE=1 glow --style dist/glow/solunized.json README.md </dev/null | grep -o $'\e\[[0-9;]*m' | sort -u` lists only foreground codes 30–37, 90–97 or `38;5;N` with N from 0 to 15, with bold/italic/underline/strike attributes, and no `38;5;N` with N above 15, no `38;2;` and no `48;` sequence. Also render a Markdown file with a Ruby code block and apply the same check, so chroma output is covered.
- Light mode shows headings, links and code in Solunized light accents on cream; dark mode shows them in Solunized dark accents on blue-teal, with no config change → `test/generate_themes_test.rb` `GlowApplicationTest#test_headings_links_and_code_use_the_ghostty_slots_for_blue_cyan_and_green` (both the `light` and `dark` Ghostty palettes put that accent in that slot); plus check: Etienne runs `glow --style dist/glow/solunized.json README.md` in Ghostty once with macOS in light mode and once in dark mode, and confirms readable body text, the accent colours and the code highlighting. Etienne does this before he approves the merge (decided 2026-10-13); the PR body lists both commands.
- The README's supported applications table lists glow → check: `grep -F 'applications/glow/configuration.yml' README.md`.

Per changed file, the unit tests expected, named as behaviour:
- `applications/glow/template.json.erb` (via `GlowApplicationTest`): `writes_one_style_file_named_solunized_json`, `output_is_valid_json`, `every_colour_outside_chroma_is_an_ansi_number_from_0_to_15` (walks the parsed JSON outside `chroma` for every key ending in `color`, asserts each value matches `/\A(?:[0-9]|1[0-5])\z/` and that at least one exists), `every_chroma_colour_is_a_palette_safe_name` (every `color` under `code_block.chroma` is one of `#ansidarkred`, `#ansidarkgreen`, `#ansidarkblue`, `#ansipurple`, `#ansiteal`, and at least one exists), `chroma_comments_are_italic_without_colour`, `has_no_hex_colours` (raw text has no `#` followed by three or six hex digits), `has_no_background_colours` (no `background_color` key at any depth), `headings_links_and_code_use_the_ghostty_slots_for_blue_cyan_and_green`, `body_text_has_no_colour` (`document` has no `color` key).
- `applications/glow/configuration.yml`: covered by the integration assertion.

Test setup: `GlowApplicationTest#setup` loads the real `themes.yml`, runs `process_erb_app` for the real glow config and for the real Ghostty config, each with `output_dir` set to its own `Dir.mktmpdir`, and parses the glow JSON. The slot test reads `palette = N=#hex` lines from the generated `solunized-light` and `solunized-dark` Ghostty files and compares slot N with `themes.yml`'s colour for that name. `teardown` removes both tmpdirs. No fakes.

## Out of scope

- Hex-colour styles per variant.
- Any change to the Ghostty palette or another app's template.
- The black and white variants, and Terminal.app.
- Installing the style or editing `glow.yml`: a separate change in the dotfiles repository.
- Changes to `generate_themes.rb`.

---
Domain skills applied: ruby-style (test and template naming), rails-testing (Minitest conventions only; this is not a Rails app). No conflicts with the playbook.

## Critique

### Round 1 (codex exec -p terra)

- The chroma rationale is wrong: glamour v2.0.1 hardcodes chroma's `terminal256` formatter, so a chroma block emits `38;5;N` codes, not exact RGB. The no-chroma approach still holds. → fixed (Design decisions and Risks now name the `terminal256` formatter and `38;5;N` output; the `38;5;` SGR check stays in Proof)
