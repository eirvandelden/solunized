# Intent: herdr-app theme template

Author: Etienne van Delden de la Haije. Status: accepted (2026-11-10). Type: feature. Delivery: autonomous. Codex review: no.

## Problem

Etienne moves from the herdr TUI to herdr-app, the Herdr desktop app. Solunized themes the herdr TUI (`applications/herdr`), but not herdr-app. herdr-app reads its own theme format: a JSON file in its `themes/` folder. Without a generated Solunized file, herdr-app shows its shipped colors, and its terminals do not match Ghostty.

This change is phase 4's first step in the dotfiles intent "Move from herdr TUI to herdr-app" (dotfiles branch `herdr-app-keys`, `docs/changes/herdr-app-keys/intent.md`). Etienne accepted that intent on 2026-11-10. It approves "a pull request in the solunized repository for the herdr-app theme template". This file copies the parts of that intent that concern solunized; the acceptance above is that one.

## Proposed outcome

`ruby generate_themes.rb` writes one herdr-app theme file per Solunized variant. herdr-app loads them from its `themes/` folder. Its terminal colors are the same as Ghostty's Solunized colors, in light and dark. Its panel colors come from the same palette, with a blue accent. A second file per variant has an orange accent, for work spaces.

## Affected users and systems

- Etienne, in herdr-app on macOS and SteamOS.
- The solunized generator: a new `applications/herdr-app` target, its test, and the README application table.
- The dotfiles repository, which links the generated files into herdr-app's home in its own phase 4 pull request. That work is not part of this change.

## Constraints

- herdr-app theme format (herdr-app 0.1.15, its home `AGENTS.md`): `themes/<name>.json` holds `background`, `foreground`, `selection`, `cursor` (optional), `ansi` (16 colors) and `colors` (optional panel color overrides). Every color is `#rrggbb`. herdr-app derives the panel colors it does not get.
- herdr-app follows light and dark with `"theme": {"light": "<name>", "dark": "<name>"}`, so each variant is one file.
- Generated files land in `dist/`, which is gitignored. Only `docs/colors.md` and `docs/slack.md` are committed outputs.
- CI regenerates everything and fails on a `git diff`.
- The existing `applications/herdr` target (the herdr TUI theme) stays unchanged: the herdr TUI stays installed as a fallback.
- No new dependency.

## In scope

- A new application target `applications/herdr-app`: a configuration and a JSON template. Two files per variant, one per accent: `dist/herdr-app/solunized-<variant>-blue.json` and `dist/herdr-app/solunized-<variant>-orange.json`, for dark, light, black and white.
- Terminal colors exactly as the Ghostty template maps them: background, foreground, cursor, selection background, and the 16 palette entries.
- Panel colors (`colors`) from the same variant: an accent in the variant's blue, and backgrounds, borders, text and agent status colors from the palette.
- The orange file is the same as the blue file in every color except the accent, which is the variant's orange.
- Valid JSON output.
- Tests for the new target in `test/generate_themes_test.rb`, next to the herdr TUI target's tests.
- A row in the README application table.

## Out of scope

- Linking the files into herdr-app, the sidebar position, the pane frames, and switching to the orange file when a work space has focus: the dotfiles phase 4 pull request does those.
- Changing `themes.yml` or any existing target.
- herdr-app's selection foreground: its theme format has none.

## Acceptance criteria

- After `ruby generate_themes.rb`, `dist/herdr-app/` holds eight files, `solunized-<variant>-blue.json` and `solunized-<variant>-orange.json` for dark, light, black and white, and each one parses as JSON.
- In `solunized-light-blue.json` and `solunized-light-orange.json`, `background`, `foreground`, `cursor`, `selection` and every `ansi` entry equal Ghostty's light `background`, `foreground`, `cursor-color`, `selection-background` and `palette` 0–15. The same holds for dark, black and white.
- In `solunized-dark-blue.json`, `colors.accent` is the dark variant's blue, `#4191f4`; in `solunized-light-blue.json` it is `#0068c9`.
- `solunized-dark-orange.json` equals `solunized-dark-blue.json` except `colors.accent`, which is the dark variant's orange, `#ea8347`. The same holds for light (`#b05015`), black and white.
- herdr-app with `themes/solunized-light-blue.json` shows a terminal with Ghostty's light background and text colors, and a sidebar in the same palette.

## Decisions

- Phase 4 starts with its own pull request in the solunized repository, before the dotfiles one — the dotfiles intent, "its own pull request there, first".
- Colors follow solunized, light and dark; personal shows a blue accent — Etienne's words in the dotfiles intent.
- Generate the orange-accent files in solunized too — the dotfiles intent says personal blue and work orange, "both from solunized"; a sandbox check on 2026-11-11 showed herdr-app switches the accent only by switching the theme file.
- Plan critiques use Claude (`claude -p --model opus --permission-mode plan`), not Codex — Etienne found the Codex critique too slow.

## Open questions

None.
