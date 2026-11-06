# Review: lefthook-rubocop-ci

## Round 1 — 2026-11-06T19:51:19Z — 3134c1c

Checks run: all three test files green (77, 3 and 17 runs); `bin/rubocop` exits 0 on 7 files; `ruby generate_themes.rb` leaves `git status` clean; no `rubocop:disable`, `rbs_inline: disabled` or `.rubocop_todo.yml`; `bundle-audit check` finds no vulnerabilities; yamllint has warnings only. No `REVIEW.md` exists, so the default passes ran.

Compliance, each acceptance criterion against its proof (run again by this review in throwaway clones):

- A pull that brings in a changed `themes.yml` regenerates `docs/colors.md` and `docs/slack.md` — holds: `generate-themes` ran, `dist/` exists, both docs show as modified.
- A pull that changes only `README.md` does not run the generator — holds: `generate-themes (skip) no files for inspection`, no `dist/`.
- The same holds for a `pull --rebase` — holds for both cases; `commit --amend` afterwards runs the hook but the `rebase` guard exits before the generator, no `dist/`.
- `rubocop` exits 0 on the repository, locally and in CI — holds locally; CI not yet run.
- A pull request with a RuboCop offense fails the CI lint job — partly holds: see the second Important finding.
- `ruby generate_themes.rb` leaves `git status` clean, and both test files stay green — holds.
- Plan Proof unit tests: `test_writes_every_single_file_output`, `test_writes_one_file_per_variant_and_skips_terminal_without_plutil` and `test_zed_output_is_valid_json_with_four_themes` exist and pass. No test was weakened, skipped or deleted.

- [ ] Important: Both files declare the top-level RBS alias `type str_hash`, so the project's signatures do not load together: `bundle exec rbs-inline --opt-out --output=<dir> generate_themes.rb sign_firefox.rb preview_palette.rb` then `bundle exec rbs -I <dir> validate` raises `RBS::DuplicatedDeclarationError: Duplicated declaration: ::str_hash`. Each file validates alone, and `Style/RbsInline/InvalidTypes` checks one file at a time, so `bin/rubocop` cannot catch it. Declare each alias once, or scope one inside `SignFirefox` — `sign_firefox.rb:7`, `generate_themes.rb:12` → fixed (Scope the str_hash RBS alias to SignFirefox)
- [ ] Important: `Style/StringLiterals` never inspects the three root scripts. The omakase layer of `config/default.yml` limits that cop to `app/`, `config/`, `lib/`, `test/` and `Gemfile`, so a single-quoted string in `generate_themes.rb`, `preview_palette.rb` or `sign_firefox.rb` passes `bin/rubocop` and the CI lint job. The plan's Proof check for this criterion uses exactly that offense: `puts 'single quotes'` in a root `lint_probe.rb` gives "no offenses detected" and exit 0, not the `::error` line and exit 1 the plan expects, so that check cannot have passed as written. Other offenses in root files do fail (a missing RBS annotation gives `::error` and exit 1). It is the only enabled cop that skips the root scripts; they hold no single-quoted string today. Widening the cop's `Include` in `.rubocop.yml` is a cop override that invariant I4 forbids, so the fix (move the scripts, change the gem's config, or allow the override) is Etienne's decision — `.rubocop.yml:3`, `docs/changes/lefthook-rubocop-ci/plan.md:297` → dismissed: the scope of Style/StringLiterals comes from the gem's omakase layer, outside this repo, and the plan forbids a cop override here (invariant I4). The criterion holds for every other cop, and the root scripts hold no single-quoted string. The probe in the plan was wrong, not the setup
- [ ] Nit: `plan.md` no longer matches the diff. `## Files that change` omits `.yamllint`, `sign_firefox.rb` and `test/sign_firefox_test.rb`, which the intent now covers. `### Signatures` lists 15 signatures to add, but `origin/main` already had them; the diff instead adds `@rbs!` type aliases, where the plan said to drop parameter names — `docs/changes/lefthook-rubocop-ci/plan.md:151` → dismissed: plan.md is an in-flight artifact that deliver removes; its deviations are recorded in intent.md and the commit history
- [ ] Nit: The new lint job runs `spinel-coop/setup-rv@main` with `install-gems: true`, a third-party action on a mutable branch that now also installs the bundle. The two existing jobs use the same ref; pinning all three to a release tag or commit SHA, if the action publishes one, removes the drift — `.github/workflows/ci.yml:66` → dismissed: the two existing jobs use the same `@main` ref, so pinning all three is a separate change (playbook rule 21)

## Round 2 — 2026-11-06T20:10:00Z — 724c0ae

Checks run: all three test files green (77, 3 and 17 runs); `bin/rubocop` exits 0 on 7 files; `ruby generate_themes.rb` leaves `git status` clean; `bundle-audit check` finds no vulnerabilities. No `REVIEW.md` exists, so the default passes ran again over the full diff against `origin/main`.

Round 1 fix verified: `bundle exec rbs-inline --opt-out --output=<dir> generate_themes.rb sign_firefox.rb preview_palette.rb` then `bundle exec rbs -I <dir> validate` exits 0. The generated signatures hold `type str_hash` once at the top level (`generate_themes.rbs`) and once as `SignFirefox::str_hash`, so the duplicate declaration is gone.

Bugs, Security, Compliance and Design passes found no new issue in `724c0ae` or the rest of the diff. The lint job inherits the workflow-level `LANG`/`LC_ALL` of `C.UTF-8`. The acceptance criteria hold as round 1 recorded; the `Style/StringLiterals` scope gap stays dismissed.

No findings.
