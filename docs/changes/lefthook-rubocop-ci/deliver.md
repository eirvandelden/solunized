# Delivery account: lefthook-rubocop-ci

## Behaviour delivered

- A pull or `pull --rebase` that changes `themes.yml` or `applications/**` runs `ruby generate_themes.rb` (`lefthook-local.yml`, `post-merge` and `post-rewrite`). `commit --amend` and README-only pulls do not.
- `rubocop-eirvandelden` lints the Ruby: `Gemfile`, `Gemfile.lock`, `.rubocop.yml` (default layer only), `bin/rubocop`.
- CI has a `lint` job that runs `bin/rubocop -f github` with a RuboCop cache.
- Dependabot watches `bundler` weekly, with a 7-day cooldown.
- A repo `.yamllint` allows the aligned colons in `themes.yml`, so the global yamllint hook accepts commits that touch it.
- The existing Ruby files had 38 offenses; all are fixed in separate commits per cop family, with no disable comments and no todo file.

## Evidence

- Throwaway clones: a `themes.yml` change regenerates on `pull` and `pull --rebase`; a README change does not; `commit --amend` does not. The reviewer reran these in round 1.
- `bin/rubocop` exits 0 on 7 files. `rbs-inline` plus `rbs validate` exits 0 across the three Ruby files.
- `yamllint` exits 0 on every tracked YAML file.

## Checks

- `ruby test/generate_themes_test.rb`: 77 runs, 0 failures. `ruby test/preview_palette_test.rb`: 3 runs, 0 failures. `ruby test/sign_firefox_test.rb`: 17 runs, 0 failures.
- `ruby generate_themes.rb` leaves `git status` clean.
- `bundle-audit check` finds no vulnerabilities. Brakeman does not apply: no Rails application.

## Review outcome

- Round 1 (Claude reviewer): 2 Important, 2 Nit. One Important fixed (duplicate `str_hash` RBS alias). One Important dismissed (`Style/StringLiterals` skips the root scripts because of the gem's own config). Both Nits dismissed (plan drift, `setup-rv@main` pin), each with a reason.
- Round 2: no findings. Codex review was off.

## Open items for the maintainer

- `Style/StringLiterals` skips `generate_themes.rb`, `preview_palette.rb` and `sign_firefox.rb` in the `rubocop-eirvandelden` omakase layer. A gem change would close it.
- The three `spinel-coop/setup-rv@main` refs in `ci.yml` could be pinned in one separate change.
