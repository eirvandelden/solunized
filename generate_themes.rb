require "yaml"
require "fileutils"
require "erb"
require "base64"
require "tempfile"
require "open3"

METADATA_KEYS = %w[display_name interface_style accent_color].freeze
HEX_COLOR_PATTERN = /\A#[0-9A-Fa-f]{6}\z/.freeze

class PlutilUnavailableError < RuntimeError; end

# ---------------------------------------------------------------------------
# Core helpers
# ---------------------------------------------------------------------------

def resolve_value(value, theme_data)
  colors = theme_data["colors"]
  return colors[value] if colors.key?(value)
  return theme_data[value] if METADATA_KEYS.include?(value)

  value
end

def load_yaml_hash(path)
  data = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
  return data if data.is_a?(Hash)

  raise RuntimeError, "Invalid YAML in #{path}: expected a top-level mapping"
rescue Psych::Exception => e
  raise RuntimeError, "Invalid YAML in #{path}: #{e.message}"
end

def validate_themes!(themes_yml, themes)
  unless themes.is_a?(Hash) && !themes.empty?
    raise RuntimeError, "#{themes_yml}: top-level 'themes' must be a non-empty mapping"
  end

  themes.each do |variant, theme_data|
    unless theme_data.is_a?(Hash)
      raise RuntimeError, "#{themes_yml}: theme '#{variant}' must map to a hash"
    end

    colors = theme_data["colors"]
    next if colors.is_a?(Hash) && !colors.empty?

    raise RuntimeError, "#{themes_yml}: theme '#{variant}' must include a non-empty colors mapping"
  end
end

def validate_app_config!(app_file, raw_config)
  unless raw_config.is_a?(Hash) && raw_config.size == 1
    raise RuntimeError, "Invalid config in #{app_file}: expected exactly one top-level application key"
  end

  app_name = raw_config.keys.first
  app_config = raw_config[app_name]
  unless app_config.is_a?(Hash)
    raise RuntimeError, "Invalid config in #{app_file}: application '#{app_name}' must map to a hash"
  end

  output_dir = app_config["output_dir"]
  if !output_dir.is_a?(String) || output_dir.strip.empty?
    raise RuntimeError, "Invalid config in #{app_file}: application '#{app_name}' requires output_dir"
  end

  if app_config["format"] == "erb"
    validate_erb_config!(app_file, app_name, app_config)
  else
    validate_css_config!(app_file, app_name, app_config)
  end

  [ app_name, app_config ]
end

def validate_css_config!(app_file, app_name, app_config)
  sections = app_config["sections"]
  return if sections.is_a?(Hash)

  raise RuntimeError, "Invalid config in #{app_file}: application '#{app_name}' requires a sections hash"
end

def validate_erb_config!(app_file, app_name, app_config)
  per_theme = app_config["per_theme"]
  unless per_theme == true || per_theme == false
    raise RuntimeError, "Invalid config in #{app_file}: application '#{app_name}' requires per_theme: true|false"
  end

  if !per_theme && (!app_config["filename"].is_a?(String) || app_config["filename"].strip.empty?)
    raise RuntimeError, "Invalid config in #{app_file}: application '#{app_name}' requires filename"
  end

  erb_file = app_file.sub(/\.yml$/, ".erb")
  return if File.exist?(erb_file)

  raise RuntimeError, "Invalid config in #{app_file}: missing template #{erb_file}"
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

# Converts a hex color to a CSS oklch() string.
def hex_to_oklch(hex)
  unless hex.is_a?(String) && hex.match?(HEX_COLOR_PATTERN)
    raise ArgumentError, "Expected a hex color in #RRGGBB format, got: #{hex.inspect}"
  end

  r, g, b = hex.delete_prefix("#").scan(/../).map { |c| c.to_i(16) / 255.0 }

  # Linearize sRGB
  to_linear = ->(v) { v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
  rl, gl, bl = to_linear.call(r), to_linear.call(g), to_linear.call(b)

  # Linear sRGB → LMS (Oklab M1 matrix)
  l = 0.4122214708 * rl + 0.5363325363 * gl + 0.0514459929 * bl
  m = 0.2119034982 * rl + 0.6806995451 * gl + 0.1073969566 * bl
  s = 0.0883024619 * rl + 0.2817188376 * gl + 0.6299787005 * bl

  # Cube root
  l_ = Math.cbrt(l)
  m_ = Math.cbrt(m)
  s_ = Math.cbrt(s)

  # LMS³ → OKLab (M2 matrix)
  ok_l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
  ok_a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
  ok_b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

  # OKLab → OKLCH
  c = Math.sqrt(ok_a**2 + ok_b**2)
  h = Math.atan2(ok_b, ok_a) * 180.0 / Math::PI
  h += 360.0 if h < 0

  format("oklch(%.2f%% %.4f %.2f)", ok_l * 100.0, c, h)
end

# Converts a hex color to a Base64-encoded binary NSKeyedArchiver NSColor plist
# for embedding in macOS .terminal XML plists.
def hex_to_term_color(hex, plutil_command: "plutil", env: {})
  unless hex.is_a?(String) && hex.match?(HEX_COLOR_PATTERN)
    raise ArgumentError, "Expected a hex color in #RRGGBB format, got: #{hex.inspect}"
  end

  r, g, b    = hex.delete_prefix("#").scan(/../).map { |c| c.to_i(16) / 255.0 }
  nsrgb_str  = [ r, g, b ].map { |v| format("%.8g", v) }.join(" ")

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

  binary = convert_plist_xml_to_binary(xml, plutil_command: plutil_command, env: env)
  Base64.strict_encode64(binary)
end

def convert_plist_xml_to_binary(xml, plutil_command:, env: {})
  Tempfile.create([ "nscolor", ".plist" ]) do |f|
    f.write(xml)
    f.flush

    stdout, stderr, status = Open3.capture3(env, plutil_command, "-convert", "binary1", "-o", "-", f.path)
    return stdout if status.success? && !stdout.empty?

    exit_status = status.exitstatus || "unknown"
    raise RuntimeError, "plutil failed (status #{exit_status}): #{stderr.strip}"
  end
rescue Errno::ENOENT
  raise PlutilUnavailableError, "plutil command not found: #{plutil_command}"
end

class ErbContext
  def initialize(themes, variant = nil, theme_data = nil, plutil_command: "plutil", plutil_env: {})
    @themes     = themes
    @variant    = variant
    @theme_data = theme_data
    @plutil_command = plutil_command
    @plutil_env = plutil_env
  end

  attr_reader :themes, :variant, :theme_data

  # Look up a colour hex value for a given variant and colour key.
  def c(v, name)
    variant_key = v.to_s
    theme = @themes[variant_key]
    unless theme.is_a?(Hash)
      raise RuntimeError, "Unknown theme variant '#{variant_key}'"
    end

    colors = theme["colors"]
    unless colors.is_a?(Hash)
      raise RuntimeError, "Theme '#{variant_key}' has no colors mapping"
    end

    color_key = name.to_s
    return colors[color_key] if colors.key?(color_key)

    raise RuntimeError, "Unknown colour key '#{color_key}' for variant '#{variant_key}'"
  end

  # Return the interface style ("dark" or "light") for a given variant.
  def appearance(v)
    variant_key = v.to_s
    theme = @themes[variant_key]
    unless theme.is_a?(Hash)
      raise RuntimeError, "Unknown theme variant '#{variant_key}'"
    end

    theme["interface_style"]
  end

  # Top-level Ruby methods are private instance methods on Object. Since ErbContext
  # inherits from Object, `super` here walks up to that top-level definition,
  # forwarding our stored plutil configuration. This lets ERB templates call
  # hex_to_term_color(...) without an explicit receiver while still using the
  # ErbContext's injectable plutil_command (needed for testing).
  def hex_to_term_color(hex)
    super(hex, plutil_command: @plutil_command, env: @plutil_env)
  end

  def get_binding
    binding
  end
end

def process_erb_app(themes, app_config, erb_file, plutil_command: "plutil", plutil_env: {})
  output_dir = app_config["output_dir"]
  template   = ERB.new(File.read(erb_file), trim_mode: "-")
  FileUtils.mkdir_p(output_dir)

  if app_config["per_theme"]
    themes.each do |variant, theme_data|
      ctx      = ErbContext.new(
        themes, variant, theme_data, plutil_command: plutil_command, plutil_env: plutil_env
      )
      content  = template.result(ctx.get_binding)
      # Default pattern produces filenames like "dark", "light", etc.
      # Override with e.g. "solunized-%{variant}" or "%{display_name}.terminal".
      pattern  = app_config["filename_pattern"] || "%{variant}"
      filename = File.join(output_dir, format(pattern, variant: variant, display_name: theme_data["display_name"]))
      File.write(filename, content)
      puts "Generated #{filename}"
    end
  else
    ctx      = ErbContext.new(themes, nil, nil, plutil_command: plutil_command, plutil_env: plutil_env)
    content  = template.result(ctx.get_binding)
    filename = File.join(output_dir, app_config["filename"])
    File.write(filename, content)
    puts "Generated #{filename}"
  end
end

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def process_all_apps(themes_yml:, apps_dir:, plutil_command: "plutil", plutil_env: {})
  themes = load_yaml_hash(themes_yml).fetch("themes") do
    raise RuntimeError, "#{themes_yml}: missing top-level 'themes' key"
  end
  validate_themes!(themes_yml, themes)

  Dir.glob(File.join(apps_dir, "**", "theme.yml")).sort.each do |app_file|
    app_name, app_config = validate_app_config!(app_file, load_yaml_hash(app_file))
    puts "Processing application: #{app_name}"

    if app_config["format"] == "erb"
      erb_file = app_file.sub(/\.yml$/, ".erb")
      begin
        process_erb_app(
          themes,
          app_config,
          erb_file,
          plutil_command: plutil_command,
          plutil_env: plutil_env
        )
      rescue PlutilUnavailableError => e
        warn "Skipping #{app_name}: #{e.message}"
      end
    else
      generate_app_themes(themes, app_config)
    end
  end
end

if __FILE__ == $0
  themes_yml = ARGV[0] || "themes.yml"
  apps_dir   = ARGV[1] || "applications"
  process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)
end
