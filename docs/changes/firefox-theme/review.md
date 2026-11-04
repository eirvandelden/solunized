# Review: firefox-theme

## Round 1 — 2026-10-30T10:13Z — 166f4c9

- [ ] Nit: Stale add-on directories get signed. `add_on_dirs` signs every `dist/firefox/*/manifest.json`, and the generator never removes a directory whose slug left `configuration.yml`, so a rename or removal later submits the old add-on to Mozilla too — `sign_firefox.rb:15` → fixed (Sign only the add-ons named in the Firefox configuration)
- [ ] Nit: The new `generate_themes.rb` methods carry no inline `#:` RBS signature, although `### Signatures` writes one for `ErbContext#initialize`, `add_on`, `process_add_ons` and `write_zip`; `validate_per_theme!` and `present_string?` are not in `### Signatures` at all. `sign_firefox.rb` has them — `generate_themes.rb:316` → fixed (Shorten the add-on methods, annotate them and drop the skipped unzip test)
- [ ] Nit: New conditional skip. `test_is_accepted_by_unzip_when_it_is_installed` skips when `unzip` is absent (possible on `ubuntu-slim`), and §7a forbids adding a skipped test; `read_zip` already proves the archive format without the tool — `test/generate_themes_test.rb:742` → fixed (Shorten the add-on methods, annotate them and drop the skipped unzip test)
- [ ] Nit: Proof names `ProcessErbAppTest#test_add_on_zip_holds_the_same_manifest_as_its_directory`, but the test is `AddOnProcessingTest#test_add_on_zip_holds_the_same_manifest_as_its_directory`; the plan's add-on tests in `ProcessErbAppTest`/`ProcessAllAppsTest` became the new classes `AddOnProcessingTest` and `AddOnConfigValidationTest` — `test/generate_themes_test.rb:792` → fixed (Name the add-on zip test by its real class in the plan)
- [ ] Nit: `write_zip` (15 lines) and `validate_add_ons!` (17 lines) exceed the 10-line method limit, and `write_zip` reassigns its block parameter (`name = name.b`) — `generate_themes.rb:333` → fixed (Shorten the add-on methods, annotate them and drop the skipped unzip test)

Checks run: `ruby test/generate_themes_test.rb` (69 runs, 0 failures), `ruby test/preview_palette_test.rb` (3 runs, 0 failures), `ruby test/sign_firefox_test.rb` (12 runs, 0 failures). Generated both add-ons into a scratch directory: `unzip -t` passes, and `npx --yes web-ext@10 --no-config-discovery lint` reports 0 errors, 0 warnings, 0 notices for each. No linter is configured in this repository. No existing test was weakened, skipped or deleted.

Security: credentials reach `npx` through the environment only (`system(env, *command)`, no shell), never on the command line or in an error message. `generate_themes.rb` does not require `sign_firefox.rb` and starts no subprocess on the add-on path. Nothing found.

Compliance, acceptance criterion → proof:

- Light+dark and white+black manifests under `dist/firefox/` → `FirefoxApplicationTest#test_writes_a_manifest_per_add_on`
- Light+dark `frame` values → `FirefoxApplicationTest#test_light_dark_frames_use_the_light_and_dark_backgrounds`
- White+black `frame` values → `FirefoxApplicationTest#test_white_black_frames_use_the_white_and_black_backgrounds`
- Valid JSON, every current key, every value a `#RRGGBB` from `themes.yml` → `FirefoxApplicationTest#test_every_current_key_has_a_colour_of_its_variant`
- Dark `toolbar_text` differs from `toolbar` → `FirefoxApplicationTest#test_dark_toolbar_text_differs_from_toolbar`
- Each manifest names its add-on → `FirefoxApplicationTest#test_each_add_on_has_its_own_name_and_id`
- Each add-on zip has `manifest.json` at its root → `FirefoxApplicationTest#test_each_add_on_zip_holds_its_manifest_at_the_root`
- Signing refuses without each credential and names it; no network, no `npx` → `SignFirefoxTest#test_refuses_without_the_api_key_and_names_it`, `#test_refuses_without_the_api_secret_and_names_it`, `#test_runs_no_command_while_a_credential_is_missing`
- README explains credentials, script and `.xpi` install → check: "Signing the Firefox add-ons" in `README.md` covers all three
- `about:debugging` temporary load follows the OS appearance → manual check by Etienne, still to do
- README lists Firefox in the supported applications table → check: row present in `README.md`

Every other test named in `## Proof` exists under its planned name.

## Round 2 — 2026-10-30T10:35Z — 18b5ebb

- [ ] Nit: `process_add_ons` has a 12-line body, over the 10-line method limit, and does four things per add-on: render the manifest, write the directory, write the zip and print both paths. Round 1 shortened `write_zip` and `validate_add_ons!` on the same rule — `generate_themes.rb:334` → fixed (Split the add-on directory and zip writing out of process_add_ons)
- [ ] Nit: `### Signatures` still signs neither `validate_per_theme!`, `validate_add_on!` and `present_string?` nor the zip helpers `zip_archive`, `zip_entry`, `zip_local_header`, `zip_central_header` and `zip_end_record`; all are public top-level methods. Round 1's fix added inline `#:` signatures to the code, but the plan half of that finding stayed open — `docs/changes/firefox-theme/plan.md:77` → fixed (Sign the zip and validation helpers in the plan)

Checks run: `ruby test/generate_themes_test.rb` (68 runs, 0 failures), `ruby test/preview_palette_test.rb` (3 runs, 0 failures), `ruby test/sign_firefox_test.rb` (15 runs, 0 failures). `rubocop --force-exclusion` on the four changed Ruby files (the global lefthook config): no offenses. `ruby generate_themes.rb` in a scratch copy of `HEAD`: no change to `docs/colors.md` or `docs/slack.md`; `unzip -l` lists `manifest.json` at the root of each zip, dated 1980-01-01. The only `skip` in the suite (`plutil is not available`) predates this branch. No existing test was weakened, skipped or deleted.

Security: credentials reach `npx` through the `env` hash only (`system(env, *command)`, no shell), never in a command argument or an error message; `test_keeps_the_credentials_out_of_the_command` proves it. `generate_themes.rb` does not require `sign_firefox.rb` and starts no subprocess on the add-on path. Nothing found.

Compliance, acceptance criterion → proof:

- Light+dark and white+black manifests under `dist/firefox/` → `FirefoxApplicationTest#test_writes_a_manifest_per_add_on`
- Light+dark `frame` values → `FirefoxApplicationTest#test_light_dark_frames_use_the_light_and_dark_backgrounds`
- White+black `frame` values → `FirefoxApplicationTest#test_white_black_frames_use_the_white_and_black_backgrounds`
- Valid JSON, every current key, every value a `#RRGGBB` from `themes.yml` → `FirefoxApplicationTest#test_every_current_key_has_a_colour_of_its_variant` (the test's own 38-key list matches the current MDN key set)
- Dark `toolbar_text` differs from `toolbar` → `FirefoxApplicationTest#test_dark_toolbar_text_differs_from_toolbar`
- Each manifest names its add-on → `FirefoxApplicationTest#test_each_add_on_has_its_own_name_and_id`
- Each add-on zip has `manifest.json` at its root → `FirefoxApplicationTest#test_each_add_on_zip_holds_its_manifest_at_the_root`
- Signing refuses without each credential and names it; no network, no `npx` → `SignFirefoxTest#test_refuses_without_the_api_key_and_names_it`, `#test_refuses_without_the_api_secret_and_names_it`, `#test_runs_no_command_while_a_credential_is_missing`
- README explains credentials, script and `.xpi` install → check: "Signing the Firefox add-ons" in `README.md` covers all three
- `about:debugging` temporary load follows the OS appearance → manual check by Etienne, still to do
- README lists Firefox in the supported applications table → check: row present in `README.md`

Every test named in `## Proof` exists under its planned name. Design: no Law of Demeter chain through objects, no query loop, no glossary (`GLOSSARY.md` does not exist yet).

## Round 3 — 2026-10-30T10:46Z — d4edf64

- [ ] Nit: `### Signatures` still signs `SignFirefox.add_on_dirs` as `(?String dist_dir) -> Array[String]`, and the line under it says it globs `<dist_dir>/*/manifest.json`. Round 1's fix changed the code to `(?String dist_dir, ?slugs: Array[String])`, which reads the slugs from `configuration.yml` and raises for each one not generated — `docs/changes/firefox-theme/plan.md:156` → fixed (Bring the plan's signing signatures in line with the code)
- [ ] Nit: `validate_add_ons!` is a public top-level method in the diff that `### Signatures` does not sign; it appears only in the prose below the block. Round 2 signed its siblings `validate_per_theme!`, `validate_add_on!` and `present_string?` — `docs/changes/firefox-theme/plan.md:133` → fixed (Bring the plan's signing signatures in line with the code)

Checks run: `ruby test/generate_themes_test.rb` (68 runs, 0 failures, 0 skips), `ruby test/preview_palette_test.rb` (3 runs, 0 failures), `ruby test/sign_firefox_test.rb` (15 runs, 0 failures). `rubocop --force-exclusion` on the four changed Ruby files: no offenses. No existing test was weakened, skipped or deleted.

Bugs: the `write_add_on` split since round 2 keeps the same behaviour; `process_add_ons` passes one rendered manifest string to both the directory and the zip. Nothing found.

Security: no change since round 2. Credentials reach `npx` through the `env` hash only; `generate_themes.rb` starts no subprocess on the add-on path. Nothing found.

Compliance, acceptance criterion → proof: unchanged from round 2, every criterion is proved by the same test or check. `about:debugging` temporary load is still a manual check by Etienne. Every test named in `## Proof` exists under its planned name.

Design: `write_add_on` has an inline `#:` signature and is in `### Signatures`. No Law of Demeter chain, no query loop, no glossary (`GLOSSARY.md` does not exist yet).

## Round 4 — 2026-11-04T00:00Z — 2e86e36

- [ ] Nit: Two new lines in `validate_add_ons!` run to 122 and 125 characters (the `raise ... unless` guard and the `%w[filename version].each` line), over the ~120 limit; `SignFirefox.add_on_dirs` has the same at 125 (`raise SigningFailedError, ...`) — `generate_themes.rb:95` → fixed (Keep the add-on validation lines under 120 characters)
- [ ] Nit: `SignFirefox` mixes path bases. `CONFIGURATION` resolves from `__dir__`, but the default `dist_dir` (`dist/firefox`) and `artifacts_dir` (`dist/firefox/signed`) are relative to the current directory. Run from another directory, `ruby /path/sign_firefox.rb` reads the right slugs, then fails with "No add-on found" and, with generated output elsewhere, would write `signed/` into that directory. README and AGENTS.md say to run it from the repository root, so this is low impact — `sign_firefox.rb:22` → fixed (Resolve the signing script's default directories from the repository root)

Checks run: `ruby test/generate_themes_test.rb` (68 runs, 0 failures, 0 skips), `ruby test/preview_palette_test.rb` (3 runs, 0 failures), `ruby test/sign_firefox_test.rb` (15 runs, 0 failures). `rubocop --force-exclusion` on the four changed Ruby files: no offenses. No existing test was weakened, skipped or deleted.

Bugs: nothing found beyond the nits. Commits since round 3 change only `plan.md`; the code is the same as the code reviewed in round 3.

Security: credentials reach `npx` through the `env` hash only; `generate_themes.rb` starts no subprocess on the add-on path. Nothing found.

Compliance, acceptance criterion → proof: unchanged from round 2; every criterion has the same test or check. `about:debugging` temporary load is still a manual check by Etienne. Every test named in `## Proof` exists. The `### Signatures` block now signs every public method in the diff.

Design: no Law of Demeter chain, no query loop, no glossary (`GLOSSARY.md` does not exist yet).

## Round 5 — 2026-11-04T12:00Z — 3471abe

Nothing found.

Checks run: all three test files (88 runs, 1054 assertions, 0 failures, 0 skips). `rubocop` reports offenses only in `preview_palette.rb`, which this branch does not touch; the four changed Ruby files are clean. Lines over 120 characters in the code are `#:` signature comments only.

Round 4 fixes verified: `SignFirefox` defaults resolve from `__dir__`, and the validation lines are within the limit.

Bugs, Security, Design: unchanged since round 4. Compliance: every criterion keeps its proof; `about:debugging` temporary load is still a manual check by Etienne.
