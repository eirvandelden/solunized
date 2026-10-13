# Intent: Solunized style for glow

Author: Etienne van Delden de la Haije. Status: accepted (2026-10-13). Type: feature. Delivery: autonomous.

## Problem

Glow renders Markdown with glamour's built-in `dark` or `light` style. Those colours do not match Solunized, so Markdown in the terminal looks out of place next to every other themed app. Glow's `style: auto` only chooses between the built-in styles, so it cannot pair two custom styles with the system appearance.

## Proposed outcome

The generator produces one glamour style for glow. The style uses only ANSI colour numbers (0–15). Ghostty already swaps between the `solunized-light` and `solunized-dark` palettes with the macOS appearance, so glow shows Solunized light in light mode and Solunized dark in dark mode, with no switching code.

## Affected users and systems

- The maintainer, reading Markdown with glow in Ghostty on macOS.
- This repository's generator (`generate_themes.rb`, `applications/`), its tests and its README.
- The dotfiles repository, in a separate follow-up change that installs the style (see Out of scope).

## Constraints

- Glamour's style format: https://github.com/charmbracelet/glamour/tree/master/styles. Glow 3.0.0 must accept the file.
- The style is valid only in a terminal that runs a Solunized palette. Ghostty's palette maps ANSI 0–15 to `fg_0`, `fg_1`, `dim_0`, the eight accents except orange and violet, and their bright variants.
- The output lands in `dist/`, which is gitignored. CI's regenerate-and-diff job must stay green.
- No new dependencies.
- Approved permission: the dotfiles follow-up may create a new `glow` stow package (rule 12). It still does not run `stow`.

## In scope

- `applications/glow/configuration.yml` and `applications/glow/template.json.erb`, so `ruby generate_themes.rb` writes `dist/glow/solunized.json`.
- Tests for the generated style.
- A README row for glow in the supported applications table.

## Out of scope

- Hex-colour styles per variant.
- Changes to the Ghostty palette or any other app's template.
- Checking the style with the black and white variants, or in Terminal.app.
- Installing the style or editing `glow.yml`. A separate intent in the dotfiles repository covers that.

## Acceptance criteria

- Running `ruby generate_themes.rb` writes `dist/glow/solunized.json`.
- Every colour in that style is an ANSI colour number from 0 to 15. The style has no hex colours and no background colours.
- `glow --style dist/glow/solunized.json README.md` renders the README without a style error.
- In Ghostty with macOS in light mode, that command shows headings, links and code in Solunized light accent colours on the cream background, and body text is readable.
- After a switch to dark mode, the same command, with no config change, shows the same elements in Solunized dark colours on the blue-teal background.
- The README's supported applications table lists glow.

## Flagged concerns

- Exact colours versus automatic switching. The ANSI palette has no `bg_1`/`bg_2`, orange or violet, so code blocks get no tinted background. Hex styles would give exact colours but need switching code outside glow. Chosen side: the ANSI-palette style; the gap is accepted.

## Open questions

None.
