#!/usr/bin/env ruby

require "yaml"

# Prints each colour of a Solunized variant as foreground text on that variant's own background,
# so a colour can be judged the way it will actually be used rather than as a filled square.
module PreviewPalette
  ACCENTS = %w[red green yellow blue magenta cyan orange violet].freeze
  NEUTRALS = %w[bg_1 bg_2 dim_0 fg_0 fg_1].freeze
  SAMPLE = "agent · tab"

  class << self
    def render(variant, colors)
      background = colors.fetch("bg_0")

      lines = ["", "  Solunized #{variant.capitalize} — colours on background #{background}", ""]
      lines << format("  %-9s %-34s %s", "", "normal", "bright")
      ACCENTS.each { |name| lines << accent_line(name, colors, background) }
      lines << ""
      lines << "  Neutrals:"
      NEUTRALS.each { |name| lines << format("  %-9s %s", name, swatch(colors.fetch(name), background)) }
      lines << ""
      lines.join("\n")
    end

    def colors_for(variant, path)
      YAML.load_file(path).fetch("themes").fetch(variant).fetch("colors")
    end

    private

    def accent_line(name, colors, background)
      format(
        "  %-9s %-34s %s",
        name,
        swatch(colors.fetch(name), background),
        swatch(colors.fetch("br_#{name}"), background)
      )
    end

    def swatch(hex, background)
      red, green, blue = channels(hex)
      back_red, back_green, back_blue = channels(background)

      "\e[48;2;#{back_red};#{back_green};#{back_blue}m\e[38;2;#{red};#{green};#{blue}m" \
        " #{hex}  ▌ #{SAMPLE} \e[0m"
    end

    def channels(hex)
      hex.delete("#").scan(/../).map { |pair| pair.to_i(16) }
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  variant = ARGV.fetch(0, "light")
  themes = File.join(__dir__, "themes.yml")
  puts PreviewPalette.render(variant, PreviewPalette.colors_for(variant, themes))
end
