# Solunized

My higher-contrast variation of [Solarized](https://ethanschoonover.com/solarized/),
inspired by [Selenized](https://github.com/jan-warchol/selenized). Solunized keeps
Solarized's distinctive blue-teal background tint while increasing the contrast between
background and foreground text for improved readability.

## Themes

Four variants are provided, matching the Solarized/Selenized convention:

| Variant | Description |
|---------|-------------|
| **Dark** | Blue-teal dark background (primary theme) |
| **Light** | Blue-tinted light background |
| **Black** | Near-black background with blue accent |
| **White** | Pure white background with blue accent |

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

### Usage

```sh
ruby generate_themes.rb
```

This reads `themes.yml` and all files in `applications/`, then produces:

- `dist/<app>/` (or another configured `output_dir`) — application-specific theme files
- `docs/colors.md` — AI-readable markdown with colour tables for all variants

### Adding a new application

1. Create `applications/<appname>.yml` with:
   - `output_dir` — where to write generated files
   - `file_suffix` — file extension for output files (e.g. `.css`)
   - `sections` — a map of CSS selectors (or equivalent) to property→colour-name mappings
2. Colour name values resolve against `themes.yml`:
   - A colour key (e.g. `bg_1`) is replaced with its hex value
   - A metadata key (`display_name`, `interface_style`, `accent_color`) is replaced with that theme attribute
   - Any other string is used verbatim (e.g. `italic`, `rgba(...)`)

### Supported applications

| Application | Config file |
|-------------|-------------|
| [Nova](https://nova.app) | [`applications/nova.yml`](applications/nova.yml) |

## Licence

MIT
