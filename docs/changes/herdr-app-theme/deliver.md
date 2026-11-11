# Delivery: herdr-app-theme

## Behaviour delivered

- A new `applications/herdr-app` target writes eight herdr-app theme files: `dist/herdr-app/solunized-<variant>-blue.json` and `solunized-<variant>-orange.json` for dark, light, black and white.
- Terminal colors (background, foreground, cursor, selection and the 16 `ansi` entries) are Ghostty's Solunized colors, slot for slot.
- Every one of herdr-app 0.1.15's 23 documented panel colors comes from the Solunized palette; herdr-app derives none of them.
- The blue file's accent is the variant's blue; the orange file is the same except an accent in the variant's orange.
- The generator has a new opt-in `accents` key for per-theme targets. `ErbContext` gets the accent being rendered and names its own output file. Validation refuses accents that would overwrite or misname a file. Every existing target renders unchanged.
- The README and AGENTS.md document the target, the `accents` key and the template's `accent`.

## Evidence

- Sandbox herdr-app 0.1.15 (`HERDR_APP_HOME=/tmp/hac4h`, `HC_SESSION=hac4`, never Etienne's window), 2026-11-11, `herdr-app do app.theme --name solunized-<mode>-blue` and `herdr-app shot`. Pixels sampled with a scratch `Zlib` PNG reader:
  - Dark: terminal `#012b38`, sidebar `#0d3b4a`, selected sidebar row `#012b38`.
  - Light: terminal `#fffbf1`, sidebar `#eeeae0`, selected sidebar row `#fffbf1`.
  - Ghostty's `solunized-dark` and `solunized-light`: background `#012b38` and `#fffbf1`, selection background `#0d3b4a` and `#eeeae0`.
  - The focus border showed blue in both modes; the selected row stands out on the sidebar.
- `solunized-dark-blue.json` accent `#4191f4`, `solunized-dark-orange.json` accent `#ea8347`; all other `colors` equal.

## Check results

- `ruby test/generate_themes_test.rb`: 101 runs, 2804 assertions, 0 failures, 0 errors, 0 skips.
- `ruby test/preview_palette_test.rb`: 3 runs, 0 failures. `ruby test/sign_firefox_test.rb`: 17 runs, 0 failures.
- `bin/rubocop`: no offenses. `erb_lint` (lefthook) clean on the template.
- `ruby generate_themes.rb` writes the eight files and changes nothing under `docs/`, so CI's regenerate-and-diff job stays clean.

## Review outcome

- Plan critique (Claude, opus): 11 findings, all fixed before acceptance.
- Review round 1 (Claude reviewer): 0 Important, 3 Nits, all fixed (explicit hash for `JSON.pretty_generate`, the parse test reads the eight expected files, inline RBS on the shared test helpers).
- Review round 2: no findings. The regenerated files are byte-identical before and after the round 1 fixes.

## Follow-up

- The dotfiles phase 4 pull request (branch `herdr-app-look` in `eirvandelden/dotfiles`) copies the light and dark files into the `herdr-app` package and switches between the blue and orange pair by the focused space's core.
