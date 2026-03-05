require "yaml"
require "fileutils"
require "erb"
require "base64"
require "tempfile"

METADATA_KEYS = %w[display_name interface_style accent_color].freeze

# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def resolve_value(value, theme_data)
  colors = theme_data["colors"]
  return colors[value] if colors.key?(value)
  return theme_data[value] if METADATA_KEYS.include?(value)

  value
end

# ---------------------------------------------------------------------------
# CSS path (Nova)
# ---------------------------------------------------------------------------

def generate_css(theme_data, sections, quoted_properties = [])
  css = ""
  sections.each do |selector, properties|
    css += "#{selector} {\n"
    properties.each do |property, color_ref|
      resolved = resolve_value(color_ref.to_s, theme_data)
      value    = quoted_properties.include?(property) ? "\"#{resolved}\"" : resolved.to_s
      css += "  #{property}: #{value};\n"
    end
    css += "}\n\n"
  end
  css
end

def generate_app_themes(themes, app_config)
  output_dir        = app_config["output_dir"]
  file_suffix       = app_config["file_suffix"] || ".css"
  sections          = app_config["sections"]
  quoted_properties = app_config["quoted_css_properties"] || []

  FileUtils.mkdir_p(output_dir)

  themes.each do |_variant, theme_data|
    display_name = theme_data["display_name"]
    css          = generate_css(theme_data, sections, quoted_properties)
    filename     = File.join(output_dir, "#{display_name}#{file_suffix}")
    File.write(filename, css)
    puts "Generated #{filename}"
  end
end

# ---------------------------------------------------------------------------
# ERB path
# ---------------------------------------------------------------------------

# Converts a hex color to a Base64-encoded binary NSKeyedArchiver NSColor plist
# for embedding in macOS .terminal XML plists.
def hex_to_term_color(hex)
  r, g, b    = hex.match(/#(..)(..)(..)/).captures.map { |c| c.to_i(16) / 255.0 }
  nsrgb_str  = [r, g, b].map { |v| format("%.8g", v) }.join(" ")

  xml = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>$archiver</key>
      <string>NSKeyedArchiver</string>
      <key>$objects</key>
      <array>
        <string>$null</string>
        <dict>
          <key>$class</key>
          <dict><key>CF$UID</key><integer>2</integer></dict>
          <key>NSColorSpace</key>
          <integer>1</integer>
          <key>NSRGB</key>
          <data>#{Base64.strict_encode64(nsrgb_str)}</data>
        </dict>
        <dict>
          <key>$classes</key>
          <array>
            <string>NSColor</string>
            <string>NSObject</string>
          </array>
          <key>$classname</key>
          <string>NSColor</string>
        </dict>
      </array>
      <key>$top</key>
      <dict>
        <key>root</key>
        <dict><key>CF$UID</key><integer>1</integer></dict>
      </dict>
      <key>$version</key>
      <integer>100000</integer>
    </dict>
    </plist>
  XML

  binary = nil
  Tempfile.create(["nscolor", ".plist"]) do |f|
    f.write(xml)
    f.flush
    binary = `plutil -convert binary1 -o - '#{f.path}'`
  end
  Base64.strict_encode64(binary)
end

class ErbContext
  def initialize(themes, variant = nil, theme_data = nil)
    @themes     = themes
    @variant    = variant
    @theme_data = theme_data
  end

  attr_reader :themes, :variant, :theme_data

  # Look up a colour hex value for a given variant and colour key.
  def c(v, name)
    @themes[v.to_s]["colors"][name.to_s]
  end

  # Return the interface style ("dark" or "light") for a given variant.
  def appearance(v)
    @themes[v.to_s]["interface_style"]
  end

  # hex_to_term_color is defined at the top level (Object private method) and is
  # therefore callable from within ErbContext instances without an explicit receiver.

  def get_binding
    binding
  end
end

def process_erb_app(themes, app_config, erb_file)
  output_dir = app_config["output_dir"]
  template   = ERB.new(File.read(erb_file), trim_mode: "-")
  FileUtils.mkdir_p(output_dir)

  if app_config["per_theme"]
    themes.each do |variant, theme_data|
      ctx      = ErbContext.new(themes, variant, theme_data)
      content  = template.result(ctx.get_binding)
      pattern  = app_config["filename_pattern"] || "%{variant}"
      filename = File.join(output_dir, format(pattern, variant: variant, display_name: theme_data["display_name"]))
      File.write(filename, content)
      puts "Generated #{filename}"
    end
  else
    ctx      = ErbContext.new(themes)
    content  = template.result(ctx.get_binding)
    filename = File.join(output_dir, app_config["filename"])
    File.write(filename, content)
    puts "Generated #{filename}"
  end
end

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __FILE__ == $0
  themes_yml = ARGV[0] || "themes.yml"
  apps_dir   = ARGV[1] || "applications"

  themes = YAML.load_file(themes_yml)["themes"]

  Dir.glob(File.join(apps_dir, "*.yml")).sort.each do |app_file|
    app_config = YAML.load_file(app_file)
    app_name   = app_config.keys.first
    puts "Processing application: #{app_name}"

    if app_config[app_name]["format"] == "erb"
      erb_file = app_file.sub(/\.yml$/, ".erb")
      process_erb_app(themes, app_config[app_name], erb_file)
    else
      generate_app_themes(themes, app_config[app_name])
    end
  end
end
