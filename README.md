# Solunized

My higher-contrast variation of [Solarized](https://ethanschoonover.com/solarized/), inspired by [Selenized](https://github.com/jan-warchol/selenized). Solunized keeps as much of Solarized intact as it can — the blue-teal dark background, the warm cream light background — and changes only what readability demands: more contrast between background and foreground text.

## Themes

Four variants are provided, matching the Solarized/Selenized convention:

| Variant | Description |
|---------|-------------|
| **Dark** | Blue-teal dark background (primary theme) |
| **Light** | Warm cream light background |
| **Black** | Near-black background with blue accent |
| **White** | Cool near-white background with blue accent |

All colour values are defined in [`themes.yml`](themes.yml). See [`docs/colors.md`](docs/colors.md) for a full table of colour names and hex values for each variant.

## Colour naming

Colours follow the [Selenized naming convention](https://github.com/jan-warchol/selenized/blob/master/the-values.md):

| Name | Role |
|------|------|
| `bg_0` | Main background |
| `bg_1` | Slightly lighter background (panels, selection) |
| `bg_2` | Even lighter background (borders) |
| `dim_0` | Dimmed text (comments, line numbers) |
| `fg_0` | Normal foreground text |
| `fg_1` | Brighter foreground text |
| `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `orange`, `violet` | Accent colours |
| `br_*` | Bright variants of accent colours |

## Generating application themes

### Requirements

- Ruby (≥ 4.0)
- `plutil` (optional, only needed for Terminal.app profile generation)
- Node.js 22 or later (optional, only needed to sign the Firefox add-ons)

### Usage

```sh
ruby generate_themes.rb
```

This reads `themes.yml` and all files in `applications/`, then produces:

- `dist/<app>/` (or another configured `output_dir`) — application-specific theme files
- `docs/colors.md` — AI-readable markdown with colour tables for all variants
- `docs/slack.md` — a guide to pasting each variant into Slack's custom theme

When `plutil` is unavailable (common on Linux), Terminal.app generation is skipped and all other outputs are still generated.

### Adding a new application

1. Create `applications/<appname>/configuration.yml` with:
   - `output_dir` — where to write generated files
   - `per_theme` — `true` for one output file per variant, `false` for one combined file
   - `add_ons`, `filename` and `version` — instead of `per_theme`, for a Firefox add-on: one entry per add-on, each with `name`, `id`, `theme` and `dark_theme`; the generator writes `<output_dir>/<entry>/<filename>` and `<output_dir>/<entry>.zip` for each
   - `filename_pattern` (when `per_theme: true`) — e.g. `"solunized-%{variant}.css"`, or `filename` (when `per_theme: false`) — e.g. `"colors.md"`
2. Add `applications/<appname>/template.<ext>.erb`, naming the output format, e.g. `template.md.erb` for Markdown, `template.css.erb` for CSS.
3. In the template:
   - `c(variant, 'colour_name')` resolves a colour to its hex value
   - `appearance(variant)` resolves to `"dark"` or `"light"`
   - `hex_to_term_color(hex)` converts a hex colour to the binary NSColor plist data Terminal.app profiles need
   - An `add_ons` template gets `add_on`, the settings of the add-on being rendered (`name`, `id`, `theme`, `dark_theme`, plus the shared `version` and the entry's `slug`)
   - A `per_theme: true` template also gets `theme_data`, the current variant's metadata hash (`display_name`, `interface_style`, `accent_color`); a `per_theme: false` template loops over `themes` itself and reads that same hash per iteration

### Supported applications

| Application | Config file |
|-------------|-------------|
| [Nova](https://nova.app) | [`applications/nova/configuration.yml`](applications/nova/configuration.yml) |
| [Ghostty](https://ghostty.org) | [`applications/ghostty/configuration.yml`](applications/ghostty/configuration.yml) |
| [Neovim](https://neovim.io) | [`applications/nvim/configuration.yml`](applications/nvim/configuration.yml) |
| [Neovim Lualine](https://github.com/nvim-lualine/lualine.nvim) | [`applications/nvim_lualine/configuration.yml`](applications/nvim_lualine/configuration.yml) |
| [Terminal.app](https://support.apple.com/guide/terminal/welcome/mac) | [`applications/terminal/configuration.yml`](applications/terminal/configuration.yml) |
| [Zed](https://zed.dev) | [`applications/zed/configuration.yml`](applications/zed/configuration.yml) |
| Herdr | [`applications/herdr/configuration.yml`](applications/herdr/configuration.yml) |
| [Glow](https://github.com/charmbracelet/glow) | [`applications/glow/configuration.yml`](applications/glow/configuration.yml) — one style that uses only the terminal's ANSI palette, so it shows Solunized colours only in a terminal running a Solunized palette, such as Ghostty |
| [Slack](https://slack.com) | [`applications/slack/configuration.yml`](applications/slack/configuration.yml) — generates [`docs/slack.md`](docs/slack.md), a guide to pasting a custom theme in by hand |
| [Firefox](https://www.mozilla.org/firefox/) | [`applications/firefox/configuration.yml`](applications/firefox/configuration.yml) — two add-ons: light and dark (`theme` and `dark_theme`), white and black; see [Signing the Firefox add-ons](#signing-the-firefox-add-ons) |

### Signing the Firefox add-ons

Firefox release only installs themes that Mozilla has signed. `ruby generate_themes.rb` writes each add-on unpacked (`dist/firefox/<add-on>/manifest.json`) and zipped (`dist/firefox/<add-on>.zip`), but never signs and never uses the network.

For a quick check, open `about:debugging`, choose "This Firefox" → "Load Temporary Add-on", and pick a zip. Switch the macOS appearance and watch the frame colour follow. The add-on goes away when Firefox restarts.

To install permanently:

1. Create an API key and secret on addons.mozilla.org → Developer Hub → Manage API Keys.
2. Export them: `export WEB_EXT_API_KEY=…` and `export WEB_EXT_API_SECRET=…`. Never commit them.
3. Bump `version` in [`applications/firefox/configuration.yml`](applications/firefox/configuration.yml). Mozilla rejects a version it has already signed.
4. Run `ruby generate_themes.rb`, then `ruby sign_firefox.rb`. The script runs `npx web-ext sign --channel unlisted` for each add-on, which submits it to Mozilla, so run it yourself.
5. In Firefox, open `about:addons`, choose the gear → "Install Add-on From File", and pick each `dist/firefox/signed/*.xpi`.

The add-on ids never change after the first signing.

## Licence

MIT
