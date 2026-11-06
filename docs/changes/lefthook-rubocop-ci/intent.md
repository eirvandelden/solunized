# Intent: Lefthook post-pull regeneration, RuboCop and CI lint

Author: Etienne van Delden. Status: accepted (2026-11-06). Type: chore. Delivery: autonomous. Codex review: no.

## Problem

After a pull, the committed `docs/colors.md` and `docs/slack.md` can lag behind `themes.yml` until someone runs `ruby generate_themes.rb` by hand. The Ruby code has no RuboCop setup, so the global hook runs stock rules, not the `rubocop-eirvandelden` style. CI never lints.

## Proposed outcome

- A pull that changes `themes.yml` or anything under `applications/` regenerates the themes by itself.
- The repo lints its Ruby with `rubocop-eirvandelden`, locally and in CI.
- All three changes ship in one pull request.

## Affected users and systems

The maintainer's machines (git hooks), the `ci.yml` workflow, and the Ruby files `generate_themes.rb`, `preview_palette.rb` and `test/*.rb`.

## Constraints

- The global `core.hooksPath` scripts already apply the default lefthook config, so the repo adds only a `lefthook-local.yml`. Never run `lefthook install`.
- Adding the `rubocop-eirvandelden` gem and changing `.github/workflows/ci.yml` are approved by the maintainer's request.
- No linter disable comments. Fix the code.
- CI runs on `ubuntu-slim` with `LANG`/`LC_ALL` set to `C.UTF-8`.
- Generated docs must stay in sync with `themes.yml` (CI diff job).

## In scope

- `lefthook-local.yml` with `post-merge` and `post-rewrite` hooks that run `ruby generate_themes.rb` only when `themes.yml` or `applications/**` changed.
- The `journal_administration` setup, minus its Rails parts:
  - A `Gemfile` and `Gemfile.lock` with `rubocop-eirvandelden` from GitHub in the `:development` group.
  - A `.rubocop.yml` that inherits only `config/default.yml`, with `TargetRubyVersion` from `.ruby-version`.
  - A `bin/rubocop` binstub.
- A `lint` job in `.github/workflows/ci.yml`, built like the one in `appkit`'s reusable workflow: `spinel-coop/setup-rv` with `install-gems: true`, a RuboCop cache step, then `bin/rubocop -f github`.
- RuboCop fixes to the existing Ruby files so the new job passes, in separate commits per cop family.
- A weekly `bundler` entry in `.github/dependabot.yml`, with the same 7-day cooldown as `github-actions`.
- `AGENTS.md` updated: it now has a `Gemfile` and a linter.

## Out of scope

- `erb_lint` (the templates are not HTML).
- Any behaviour change to the generator or its output.
- Rails or Capybara RuboCop layers and the custom `Locale/LiteralMessage` cop (this is plain Ruby with no user-facing messages).
- A repo `lefthook.yml` and the `lefthook` gem (`journal_administration` carries both, but its own `lefthook.yml` opts out of the defaults).

## Acceptance criteria

- A pull that brings in a changed `themes.yml` regenerates `docs/colors.md` and `docs/slack.md`.
- A pull that changes only `README.md` does not run the generator.
- The same holds for a `pull --rebase`.
- `rubocop` exits 0 on the repository, locally and in CI.
- A pull request with a RuboCop offense fails the CI lint job.
- `ruby generate_themes.rb` leaves `git status` clean, and both test files stay green.

## Decisions

- Run the generator only when `themes.yml` or `applications/**` changed — faster and quiet.
- Add the `rubocop-eirvandelden` gem — the maintainer's standard RuboCop style for personal projects.
- Add a CI action for the lint — the maintainer asked for it.
- Ship all of it in one pull request — the maintainer asked for it.
- Fix all existing RuboCop offenses in own commits, no todo file — playbook rule 2 forbids linter disables.
- Add `bundler` to Dependabot — the repo now has a `Gemfile`.
- Follow the `journal_administration` setup — the maintainer asked for it. Its own `lefthook.yml` is not copied: the global defaults already cover it, per `new-repo-setup`.
- Autonomous delivery — the maintainer chose it; the maintainer accepts the intent and approves the merge.

## Open questions

None.
