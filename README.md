# Solunized

My higher-contrast variation of [Solarized](https://ethanschoonover.com/solarized/),
inspired by [Selenized](https://github.com/jan-warchol/selenized). Solunized keeps as much
of Solarized intact as it can — the blue-teal dark background, the warm cream light background —
and changes only what readability demands: more contrast between background and foreground text.

## Themes

Four variants are provided, matching the Solarized/Selenized convention:

| Variant | Description |
|---------|-------------|
| **Dark** | Blue-teal dark background (primary theme) |
| **Light** | Warm cream light background |
| **Black** | Near-black background with blue accent |
| **White** | Cool near-white background with blue accent |

All colour values are defined in [`themes.yml`](themes.yml). See [`docs/colors.md`](docs/colors.md)
for a full table of colour names and hex values for each variant.

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

- Ruby (≥ 3.0)
- `plutil` (optional, only needed for Terminal.app profile generation)

### Usage

```sh
ruby generate_themes.rb
```

This reads `themes.yml` and all files in `applications/`, then produces:

- `dist/<app>/` (or another configured `output_dir`) — application-specific theme files
- `docs/colors.md` — AI-readable markdown with colour tables for all variants

When `plutil` is unavailable (common on Linux), Terminal.app generation is skipped and all other outputs are
still generated.

### Adding a new application

1. Create `applications/<appname>/configuration.yml` with:
   - `output_dir` — where to write generated files
   - `per_theme` — `true` for one output file per variant, `false` for one combined file
   - `filename_pattern` (when `per_theme: true`) — e.g. `"solunized-%{variant}.css"`, or
     `filename` (when `per_theme: false`) — e.g. `"colors.md"`
2. Add `applications/<appname>/template.erb` (or `template.<ext>.erb`, e.g. `template.md.erb`,
   when naming the output format helps).
3. In the template, `c(variant, 'colour_name')` resolves a colour to its hex value. A
   `per_theme: true` template also gets `theme_data`, the current variant's metadata hash
   (`display_name`, `interface_style`, `accent_color`); a `per_theme: false` template loops
   over `themes` itself and reads that same hash per iteration.

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
| [Slack](https://slack.com) | [`applications/slack/configuration.yml`](applications/slack/configuration.yml) — generates [`docs/slack.md`](docs/slack.md), a guide to pasting a custom theme in by hand |

## Licence

MIT
