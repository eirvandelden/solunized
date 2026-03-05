require "minitest/autorun"
require "tmpdir"
require "yaml"
require "base64"

require_relative "../generate_themes"

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

DARK_THEME = {
  "display_name"   => "Test Dark",
  "interface_style" => "dark",
  "accent_color"   => true,
  "colors"         => {
    "bg_0"   => "#001122",
    "fg_1"   => "#aabbcc",
    "blue"   => "#4488ff"
  }
}.freeze

LIGHT_THEME = {
  "display_name"   => "Test Light",
  "interface_style" => "light",
  "accent_color"   => true,
  "colors"         => {
    "bg_0"  => "#ffffff",
    "fg_1"  => "#111111",
    "blue"  => "#0055cc"
  }
}.freeze

THEMES = { "dark" => DARK_THEME, "light" => LIGHT_THEME }.freeze

# ---------------------------------------------------------------------------
# resolve_value
# ---------------------------------------------------------------------------

class ResolveValueTest < Minitest::Test
  def test_resolves_colour_key
    assert_equal "#001122", resolve_value("bg_0", DARK_THEME)
  end

  def test_resolves_metadata_key
    assert_equal "Test Dark", resolve_value("display_name", DARK_THEME)
    assert_equal "dark",      resolve_value("interface_style", DARK_THEME)
  end

  def test_passthrough_for_unknown_key
    assert_equal "rgba(0,0,0,0.5)", resolve_value("rgba(0,0,0,0.5)", DARK_THEME)
  end

  def test_passthrough_for_verbatim_string
    assert_equal "bold",  resolve_value("bold", DARK_THEME)
    assert_equal "italic", resolve_value("italic", DARK_THEME)
  end
end

# ---------------------------------------------------------------------------
# generate_css
# ---------------------------------------------------------------------------

class GenerateCssTest < Minitest::Test
  def test_basic_property_output
    sections = { "body" => { "background" => "bg_0" } }
    css      = generate_css(DARK_THEME, sections)
    assert_match(/body \{/, css)
    assert_match(/background: #001122;/, css)
  end

  def test_quoted_property
    sections          = { "meta" => { "-theme-display-name" => "display_name" } }
    quoted_properties = [ "-theme-display-name" ]
    css               = generate_css(DARK_THEME, sections, quoted_properties)
    assert_match(/-theme-display-name: "Test Dark";/, css)
  end

  def test_unquoted_property_by_default
    sections = { "meta" => { "-theme-display-name" => "display_name" } }
    css      = generate_css(DARK_THEME, sections)
    assert_match(/-theme-display-name: Test Dark;/, css)
  end
end

# ---------------------------------------------------------------------------
# generate_app_themes (Nova CSS path)
# ---------------------------------------------------------------------------

class GenerateAppThemesTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_generates_one_css_file_per_theme
    config = {
      "output_dir"  => @tmpdir,
      "file_suffix" => ".css",
      "sections"    => { "root" => { "background" => "bg_0" } }
    }
    generate_app_themes(THEMES, config)

    assert File.exist?(File.join(@tmpdir, "Test Dark.css"))
    assert File.exist?(File.join(@tmpdir, "Test Light.css"))
  end

  def test_nova_quoted_display_name
    config = {
      "output_dir"             => @tmpdir,
      "file_suffix"            => ".css",
      "quoted_css_properties"  => [ "-theme-display-name" ],
      "sections"               => {
        "meta" => { "-theme-display-name" => "display_name" }
      }
    }
    generate_app_themes(THEMES, config)

    dark_css = File.read(File.join(@tmpdir, "Test Dark.css"))
    assert_match(/-theme-display-name: "Test Dark";/, dark_css)
  end
end

# ---------------------------------------------------------------------------
# application config integration
# ---------------------------------------------------------------------------

class ApplicationConfigIntegrationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_nova_terminal_palette_matches_terminal_semantics
    themes = YAML.load_file(File.expand_path("../themes.yml", __dir__))["themes"]
    config = YAML.load_file(File.expand_path("../applications/nova.yml", __dir__))["nova"]
    config["output_dir"] = @tmpdir

    generate_app_themes(themes, config)

    dark_css = File.read(File.join(@tmpdir, "Solunized Dark.css"))
    dim_0    = themes["dark"]["colors"]["dim_0"]
    fg_1     = themes["dark"]["colors"]["fg_1"]

    assert_includes dark_css, "terminal.white {\n  color: #{dim_0};\n}"
    assert_includes dark_css, "terminal.bright-white {\n  color: #{fg_1};\n}"
  end
end

# ---------------------------------------------------------------------------
# ERB path
# ---------------------------------------------------------------------------

class ProcessErbAppTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_per_theme_creates_one_file_per_variant
    erb_file = File.join(@tmpdir, "test.erb")
    File.write(erb_file, "<%= variant %>: <%= c(variant, 'bg_0') %>\n")

    config = {
      "output_dir"       => File.join(@tmpdir, "out"),
      "per_theme"        => true,
      "filename_pattern" => "theme-%{variant}.txt"
    }
    process_erb_app(THEMES, config, erb_file)

    dark_out = File.read(File.join(@tmpdir, "out", "theme-dark.txt"))
    assert_equal "dark: #001122\n", dark_out

    light_out = File.read(File.join(@tmpdir, "out", "theme-light.txt"))
    assert_equal "light: #ffffff\n", light_out
  end

  def test_single_file_mode_iterates_all_themes
    erb_file = File.join(@tmpdir, "test.erb")
    File.write(erb_file, "<% themes.each do |v, _| -%>\n<%= v %>\n<% end -%>\n")

    config = {
      "output_dir" => File.join(@tmpdir, "out"),
      "per_theme"  => false,
      "filename"   => "all.txt"
    }
    process_erb_app(THEMES, config, erb_file)

    content = File.read(File.join(@tmpdir, "out", "all.txt"))
    assert_match(/dark/, content)
    assert_match(/light/, content)
  end

  def test_appearance_helper
    erb_file = File.join(@tmpdir, "test.erb")
    File.write(erb_file, "<%= appearance(variant) %>\n")

    config = {
      "output_dir"       => File.join(@tmpdir, "out"),
      "per_theme"        => true,
      "filename_pattern" => "%{variant}.txt"
    }
    process_erb_app(THEMES, config, erb_file)

    assert_equal "dark\n",  File.read(File.join(@tmpdir, "out", "dark.txt"))
    assert_equal "light\n", File.read(File.join(@tmpdir, "out", "light.txt"))
  end
end

# ---------------------------------------------------------------------------
# hex_to_term_color round-trip
# ---------------------------------------------------------------------------

class HexToTermColorTest < Minitest::Test
  def test_roundtrip_components
    base64_data = hex_to_term_color("#ff8000")

    binary = Base64.decode64(base64_data)
    xml    = nil
    Tempfile.create([ "rt", ".plist" ]) do |f|
      f.binmode
      f.write(binary)
      f.flush
      xml = `plutil -convert xml1 -o - '#{f.path}'`
    end

    nsrgb_b64 = xml.match(%r{<key>NSRGB</key>\s*<data>([^<]+)</data>}m)[1].strip
    nsrgb_str = Base64.decode64(nsrgb_b64)
    r, g, b   = nsrgb_str.split(" ").map(&:to_f)

    assert_in_delta 1.0,    r, 0.001  # #ff
    assert_in_delta 0.502,  g, 0.002  # #80
    assert_in_delta 0.0,    b, 0.001  # #00
  end

  def test_black_and_white
    # #000000 → all zeros
    xml_black = roundtrip_to_xml("#000000")
    r, g, b   = extract_rgb(xml_black)
    assert_in_delta 0.0, r, 0.001
    assert_in_delta 0.0, g, 0.001
    assert_in_delta 0.0, b, 0.001

    # #ffffff → all ones
    xml_white = roundtrip_to_xml("#ffffff")
    r, g, b   = extract_rgb(xml_white)
    assert_in_delta 1.0, r, 0.001
    assert_in_delta 1.0, g, 0.001
    assert_in_delta 1.0, b, 0.001
  end

  private

  def roundtrip_to_xml(hex)
    binary = Base64.decode64(hex_to_term_color(hex))
    Tempfile.create([ "rt", ".plist" ]) do |f|
      f.binmode
      f.write(binary)
      f.flush
      return `plutil -convert xml1 -o - '#{f.path}'`
    end
  end

  def extract_rgb(xml)
    nsrgb_b64 = xml.match(%r{<key>NSRGB</key>\s*<data>([^<]+)</data>}m)[1].strip
    Base64.decode64(nsrgb_b64).split(" ").map(&:to_f)
  end
end
