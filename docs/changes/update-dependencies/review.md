# Review: update-dependencies

## Round 1 — 2026-10-07T19:34:26Z — b4e2cab

- [ ] Nit: The plan's planning check says `.ruby-version` is the only file that names a Ruby version and that `README.md` names none. `README.md:41` states the requirement `Ruby (≥ 3.0)`. It is a floor, not a pin, so the bump does not make it wrong and no edit is required. The planning claim is inaccurate, and CI only runs the `.ruby-version` Ruby, so nothing tests the 3.0 floor. — `docs/changes/update-dependencies/plan.md:11` →

Passes: Bugs: nothing found. The code diff is one line, `.ruby-version` `4.0.6` → `4.0.7`, with the trailing newline kept. Security: nothing found. No code, workflow or dependency source changed.

Compliance, from `intent.md` acceptance criteria. The plan deliberately proves them with commands, not new Minitest tests.

- A shell in the repository runs Ruby 4.0.7 → `rv ruby find` in the worktree resolves `ruby-4.0.7`. After `eval "$(rv shell env zsh)"`, `ruby -v` prints `ruby 4.0.7 (2026-09-15 revision 229531a6cf)`.
- Both test files pass on Ruby 4.0.7 → `ruby -W:deprecated test/generate_themes_test.rb`: 35 runs, 0 failures, 0 errors. `ruby -W:deprecated test/preview_palette_test.rb`: 3 runs, 0 failures, 0 errors. No deprecation warnings.
- Regenerating every theme on Ruby 4.0.7 changes no committed file → `ruby generate_themes.rb` exits 0. `git status --porcelain` is empty afterwards.
- Both CI jobs install Ruby 4.0.7 and pass → pending. The branch head is not pushed and no pull request exists yet. Plan steps 7–8 run after this review. `spinel-coop/rv-ruby` release `20260929` ships `ruby-4.0.7.x86_64_linux.tar.gz`, so the plan's "no build for `ubuntu-slim`" risk is unlikely.
- Every action that the workflow pins to a release is at its latest stable release → `gh api repos/actions/checkout/releases/latest` returns `v7.0.1`, the tag in `.github/workflows/ci.yml`. `spinel-coop/setup-rv` has 0 releases and only the tag `v1`; the intent puts it out of scope.

Plan `## Proof` tests: `test/generate_themes_test.rb` and `test/preview_palette_test.rb` both exist. The diff adds, weakens, skips or deletes no test. Scope: the commit touches only `.ruby-version`. `.github/` is unchanged, as the intent requires. Ruby 4.0.7 is the newest upstream release (`ruby/ruby` releases list `v4.0.7` first).
