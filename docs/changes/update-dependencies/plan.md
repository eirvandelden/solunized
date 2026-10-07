# Plan: Update all dependencies to their latest stable versions

From `intent.md` (2026-10-06). Status: accepted.

## Context

The generator, its tests and CI run on Ruby 4.0.6, pinned in `.ruby-version`. Ruby 4.0.7 is the latest stable release. rv on the maintainer's machine selects Ruby from `.ruby-version`. Both CI jobs read the same file through `spinel-coop/setup-rv@main` with `ruby-version: current`. The bundled gems (minitest, base64, yaml, erb, json) follow the Ruby version; there is no `Gemfile`. `actions/checkout@v7.0.1` is already the latest release. `spinel-coop/setup-rv` stays on `@main` (intent: out of scope).

Planning checks on 2026-10-06:

- `.ruby-version` is the only file in the repository that names a Ruby version. `README.md`, `AGENTS.md` and `docs/` name none.
- rv has Ruby 4.0.7 installed at `~/.local/share/rv/rubies/ruby-4.0.7/bin/ruby`.
- On that Ruby, `test/generate_themes_test.rb` passes (35 runs, 0 failures) and `test/preview_palette_test.rb` passes (3 runs, 0 failures).
- With `-W:deprecated`, neither test file prints a deprecation warning on that Ruby.
- `gh api repos/actions/checkout/releases/latest` returns `v7.0.1`.
- `spinel-coop/setup-rv` has no GitHub releases. Its only tag is `v1`.
- `.github/` holds no pull request template.

## Design decisions

- **The change is one line in one file.** `.ruby-version` goes from `4.0.6` to `4.0.7`. No other file changes. The CI workflow stays unchanged, because `ruby-version: current` already reads `.ruby-version`.
- **Commands prove the change, not a new Minitest test.** The bump adds no behaviour of its own. The existing suites, a regeneration diff and the CI run prove it. Step 1's failing acceptance check is `ruby -v` in the repository, which prints 4.0.6 before the bump. This departs from playbook §7 rule 3 ("never generate code without a corresponding test"). The departure is deliberate: `.ruby-version` is configuration, not code.
- **The plan rejects a guard test that asserts `RUBY_VERSION` equals `.ruby-version`.** It would fail for any run on another installed Ruby. rv and setup-rv already enforce the match.
- **A pull request against `origin` proves the CI criterion.** No pull request template exists, so the body is free-form. The playbook allows the push and pull request to `eirvandelden/solunized` without asking.

## Integration points

- rv on the maintainer's machine: it reads `.ruby-version` on every new shell.
- GitHub Actions: `spinel-coop/setup-rv@main` with `ruby-version: current` reads `.ruby-version` on `ubuntu-slim` in both jobs (`test`, `generated_files_current`).
- `plutil`: the local run generates the Terminal.app output. CI skips it.

## Files that change

- `.ruby-version` — `4.0.6` becomes `4.0.7`.

## Order of work

1. Acceptance check for criterion 1: run `ruby -v` in the worktree root. Watch it print `ruby 4.0.6`, not 4.0.7.
2. Change `.ruby-version` to `4.0.7`. Run `ruby -v` in a fresh shell. It prints `ruby 4.0.7`.
3. Run `ruby -W:deprecated test/generate_themes_test.rb`. Then run `ruby -W:deprecated test/preview_palette_test.rb`. Both report 0 failures and 0 errors, and neither prints a deprecation warning. Conflict: the `dependencies` skill wants any warning fixed in this work, but the intent's scope holds only the version bump. A warning means stop and ask Etienne.
4. Run `ruby generate_themes.rb`. Then run `git status --porcelain`. Only ` M .ruby-version` shows; `dist/` is gitignored.
5. Re-read the diff. Commit `.ruby-version` alone: `Bump Ruby to 4.0.7`.
6. Re-check the action pins. `gh api repos/actions/checkout/releases/latest --jq .tag_name` must print `v7.0.1`. If it prints a newer tag, stop and ask Etienne: the bump then needs a `.github/workflows/ci.yml` edit, and that needs explicit approval.
7. Run `review` (report-only; the pre-push check requires a fresh report for a branch with a change folder). Then push with `git push -u origin HEAD`. Open a pull request against `main` on `origin`.
8. Run `gh pr checks --watch` until both jobs finish. Both are green. In each job's log (`gh run view <run-id> --log`), the "Set up Ruby" step installs Ruby 4.0.7.

## Risks

- rv may have no Ruby 4.0.7 build for the `ubuntu-slim` runner. Then setup-rv fails in both jobs. Step 8 shows this. Stop and report; do not edit the workflow.
- Ruby 4.0.7 may change ERB, YAML or JSON output. Then the committed `docs/colors.md` or `docs/slack.md` would change on regeneration. Step 4 catches this locally before the push. If either changes, stop and report: the intent says regeneration changes no committed file.
- `actions/checkout` may publish a release between the audit and the implementation. Step 6 catches this.
- Rejected: a guard test on `RUBY_VERSION` (see Design decisions).
- Out of scope, per the intent: moving `spinel-coop/setup-rv` off `@main`, pinning any action to a commit SHA, adding a `Gemfile`, changing `.github/dependabot.yml`, any edit under `.github/workflows/`.

## Proof

- A shell in the repository runs Ruby 4.0.7 → `ruby -v` in the repository root prints `ruby 4.0.7`.
- Both test files pass on Ruby 4.0.7 → `ruby test/generate_themes_test.rb` and `ruby test/preview_palette_test.rb`, run after the bump, report 0 failures and 0 errors.
- Regenerating every theme on Ruby 4.0.7 changes no committed file → `ruby generate_themes.rb` followed by `git status --porcelain` shows nothing beyond the committed bump.
- Both CI jobs install Ruby 4.0.7 and pass → the pull request's CI run: `gh pr checks` shows `Tests` and `Generated files match themes.yml` green; each job's "Set up Ruby" log names 4.0.7.
- Every action that the workflow pins to a release is at its latest stable release → `gh api repos/actions/checkout/releases/latest --jq .tag_name` prints `v7.0.1`, the tag in `.github/workflows/ci.yml`.

Per changed file, the unit tests expected:

- `.ruby-version`: none. It is configuration with no behaviour of its own. The two existing test files cover it.

Test setup: none. The existing suites write only to `Dir.mktmpdir`.

---
Domain skills applied: dependencies (no skipped major version; deprecation warnings checked).
