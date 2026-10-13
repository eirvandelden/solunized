# Review: glow-style

## Round 1 — 2026-10-13T13:21Z — d2e1a41

Reviewer: Claude `reviewer` agent. No `REVIEW.md` in the repository, so the default passes apply (Bugs, Security, Compliance).

Checks run: `ruby test/generate_themes_test.rb` (44 runs, 0 failures), `ruby test/preview_palette_test.rb` (3 runs, 0 failures). No linter is configured. The glow style was generated into a scratch directory and rendered with glow 3.0.0 against `README.md` and a Markdown file with a Ruby code block: exit 0, empty stderr. The SGR codes were only `1`, `3`, `4`, `32`, `34;1`, `35;4`, `36;1`, `36;4`, `37`, `38;5;2`, `38;5;4`, `38;5;5`, `38;5;6` and resets. There was no `38;5;N` with N above 15, no `38;2;` and no `48;`.

Compliance (intent acceptance criteria, as amended by plan.md):

- `generate_themes.rb` writes `dist/glow/solunized.json` → `FullApplicationIntegrationTest#test_generates_real_templates_and_validates_zed_json` (new glow assertion), plus `GlowApplicationTest#test_writes_one_style_file_named_solunized_json`.
- Every colour is ANSI 0–15, or one of the five palette-safe names in `chroma`; no hex; no background → `GlowApplicationTest#test_every_colour_outside_chroma_is_an_ansi_number_from_0_to_15`, `#test_every_chroma_colour_is_a_palette_safe_name`, `#test_has_no_hex_colours`, `#test_has_no_background_colours`.
- glow renders the README without a style error → recorded check only (by design, per plan); re-run in this review and it passed.
- Light mode shows Solunized light accents → `GlowApplicationTest#test_headings_links_and_code_use_the_ghostty_slots_for_blue_cyan_and_green`, plus Etienne's manual Ghostty check before merge (still pending).
- Dark mode shows Solunized dark accents with no config change → the same test (it checks every variant's Ghostty palette), plus the same manual check (still pending).
- The README table lists glow → no test (by design, per plan); the `grep -F 'applications/glow/configuration.yml' README.md` check passes.

Every test named in plan.md's `## Proof` exists. No existing test was weakened, skipped or deleted.

- [ ] Nit: The slot test checks only blue, cyan and green against Ghostty's palette. The template also uses `dim_0` (slot 7, for `block_quote`, `hr`, `h6` and `image_text`) and `magenta` (slot 5, for `image`). A Ghostty reorder of those slots does not make any test fail, but the plan's Risks section says palette drift "is covered by the slot test". `GHOSTTY_SLOTS` also copies the template's slot hash, so the test never reads the template's own mapping. — `test/generate_themes_test.rb:84` → fixed (Check every Ghostty slot the glow style uses)
- [ ] Nit: The plan says the template's slot hash maps every Selenized name to its slot (`fg_0` 0 … `br_cyan` 14) and is "the only place this mapping is written down". The hash holds only `red` to `dim_0` (slots 1–7), so the written record of the mapping is incomplete. — `applications/glow/template.json.erb:3` →
- [ ] Nit: The no-hex regex `/#\h{6}\b|#\h{3}\b/` does not match an 8-digit hex colour such as `#aabbccdd`, because no word boundary follows the sixth digit. — `test/generate_themes_test.rb:135` → fixed (Match 4- and 8-digit hex colours in the glow style test)

## Round 1 — 2026-10-13T13:20Z — d2e1a41 (codex)

Reviewer: `codex review --base origin/main`. It ran both test suites, generated the style, and rendered `README.md` and a Markdown sample with a Ruby code block through glow 3.0.0: exit 0, empty stderr, SGR codes only `0`, `1`, `32`, `34;1`, `36;1`, `36;4`, `38;5;2`, `38;5;4`, `38;5;6`.

No findings.
