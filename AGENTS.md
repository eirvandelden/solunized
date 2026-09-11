# Solunized

## What this is

A personal colour theme: a higher-contrast variation of Solarized, inspired by Selenized. This repo is the generator that turns one colour definition into theme files for several apps (Nova, Ghostty, Neovim, Terminal.app, Zed, Herdr) plus a CSS variable file (`mvpa-css`) and a Markdown colour reference (`docs/colors.md`). No runtime service, no users other than the maintainer's own machines.

## Domain

`themes.yml` is the single source of truth: four variants (dark, light, black, white), each with metadata (`display_name`, `interface_style`, `accent_color`) and a `colors` map using the Selenized naming convention (`bg_0/1/2`, `dim_0`, `fg_0/1`, eight accent colours plus their `br_*` bright variants). Each `applications/<app>/theme.yml` describes one consumption target: `output_dir`, and either a CSS-style `sections` map (property → colour name) or, for `format: erb`, a matching `applications/<app>/theme.erb` template plus `per_theme`/`filename`/`filename_pattern`. `generate_themes.rb` reads `themes.yml` and every `applications/*/theme.yml`, resolves colour/metadata names against each theme, and writes one output file per app per variant (or one combined file when `per_theme: false`). Every generated app output lands under `dist/`, which is gitignored, except `applications/docs`, whose output is the committed `docs/colors.md` — that's the one generated file that must stay in sync with `themes.yml` in git.

## Commands

- `ruby generate_themes.rb` — regenerate all outputs from `themes.yml`.
- `ruby preview_palette.rb [variant]` — print one variant's colours as text on its own background, for a readability check in the terminal (default `light`).
- `ruby test/generate_themes_test.rb` and `ruby test/preview_palette_test.rb` — Minitest, run directly with system Ruby; there is no `Gemfile`, so no `bundle exec`.
- No linter is configured in this repo (no `.rubocop.yml`).

## Gotchas

- `plutil` (Terminal.app generation) is macOS-only; CI runs on `ubuntu-slim` and skips that one output, everything else still generates.
- CI sets `LANG`/`LC_ALL` to `C.UTF-8` before running Ruby — the theme files contain non-ASCII characters and the bare runner otherwise defaults to US-ASCII.
- CI's second job regenerates everything and fails on any `git diff` — after editing `themes.yml` or any `applications/*/theme.yml`/`theme.erb`, re-run `ruby generate_themes.rb` and commit the resulting `docs/colors.md` change before pushing.
- The README's application table lists only the apps a person installs a theme into; `applications/docs` and `applications/mvpa-css` are real generation targets too, just not end-user apps.
