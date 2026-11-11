# Review: herdr-app-theme

## Round 1 — 2026-11-11T13:20Z — 464377b

Passes: Bugs, Security, Compliance, Design (no `REVIEW.md`, no glossary in the repository: defaults). Suites green before review: `ruby test/generate_themes_test.rb` (101 runs), `ruby test/preview_palette_test.rb`, `ruby test/sign_firefox_test.rb`; `bin/rubocop` clean. No Important findings.

Compliance (acceptance criterion → proof):

- Eight files, each valid JSON → `HerdrAppApplicationTest#test_writes_two_json_files_per_variant`, `#test_each_file_parses_as_json`, `FullApplicationIntegrationTest#test_writes_one_file_per_variant_and_skips_terminal_without_plutil` (count 8).
- Terminal colors equal Ghostty's in every variant and accent → `#test_terminal_colors_equal_the_ghostty_colors`.
- Blue accent `#4191f4` dark, `#0068c9` light → `#test_blue_accent_is_the_variant_blue`.
- Orange file equals blue except the accent, `#ea8347` dark, `#b05015` light, black and white → `#test_orange_file_differs_from_blue_only_in_the_accent`, `#test_orange_accent_is_the_variant_orange`.
- herdr-app shows Ghostty's light colors and a palette sidebar → step 8 check, recorded by the coordinator on 2026-11-11 (sandbox herdr-app 0.1.15: terminal `#fffbf1`/`#012b38`, sidebar `#eeeae0`/`#0d3b4a`, selected row visible, blue focus border).
- Every test named in `plan.md` `## Proof` exists. No existing test is weakened, skipped or deleted: `GlowApplicationTest` and `SlackApplicationTest` now use the shared `GhosttyConfig` and `WcagContrast` modules with the same or stricter checks.

Findings:

- [ ] Nit: The template passes its document to `JSON.pretty_generate` as bare keyword arguments (`**terminal_names.transform_values …, "ansi" => …, "colors" => …`). Ruby turns them into the positional `obj` only because json 3.1's `pretty_generate(obj, opts = nil)` takes no keywords. A json release that accepts keyword options would read the document as options. Explicit braces make the document a plain hash. — `applications/herdr-app/template.json.erb:35` → fixed (Pass the herdr-app document to JSON.pretty_generate as a hash)
- [ ] Nit: `test_each_file_parses_as_json` iterates `Dir.glob`, so it passes when no file exists. Iterating the eight expected files (`each_theme_file`) makes it prove the parse on its own. — `test/generate_themes_test.rb:887` → fixed (Parse each expected herdr-app file, not whatever the glob finds)
- [ ] Nit: `WcagContrast#contrast_ratio` and `GhosttyConfig#ghostty_config` are new public helpers shared across test classes. `### Signatures` does not sign them and they carry no inline RBS; the test file has no RBS anywhere, so this follows its local convention. — `test/generate_themes_test.rb:45`, `test/generate_themes_test.rb:66` → fixed (Sign the shared test helpers with inline RBS)

## Round 2 — 2026-11-11T13:25Z — 4a26a24

Passes: Bugs, Security, Compliance, Design (defaults; no `REVIEW.md`, no glossary). Suites green: `ruby test/generate_themes_test.rb` (101 runs, 2804 assertions), `ruby test/preview_palette_test.rb` (3 runs), `ruby test/sign_firefox_test.rb` (17 runs); `bin/rubocop` clean (7 files).

Round 1 fixes verified:

- 962edf3: the template passes one braced hash to `JSON.pretty_generate`. The eight files rendered with the template at 464377b and at 4a26a24 are byte-identical (`diff -r`), so the round 1 sandbox check still stands.
- 11d786f: `test_each_file_parses_as_json` iterates `each_theme_file`, which reads each of the eight expected names; a missing file now raises `Errno::ENOENT` instead of passing.
- 4a26a24: `WcagContrast#contrast_ratio`, its private helpers and `GhosttyConfig#ghostty_config` carry inline RBS that matches what they return.

Full branch diff re-read (`origin/main...4a26a24`): the compliance mapping of round 1 holds unchanged. No test is weakened, skipped or deleted. No new public method without a signature, no Law of Demeter violation, no query in a loop.

Findings: nothing found.
