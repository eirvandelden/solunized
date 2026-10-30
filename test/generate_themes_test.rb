require "minitest/autorun"
require "tmpdir"
require "yaml"
require "base64"
require "json"
require "zlib"
require "stringio"

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
# Nova application
# ---------------------------------------------------------------------------

class NovaApplicationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @workspace_root = File.expand_path("..", __dir__)
    @themes = YAML.load_file(File.join(@workspace_root, "themes.yml"))["themes"]

    config = YAML.load_file(File.join(@workspace_root, "applications/nova/configuration.yml"))["nova"]
    config["output_dir"] = @tmpdir
    erb_file = File.join(@workspace_root, "applications/nova/template.css.erb")

    process_erb_app(@themes, config, erb_file)

    @dark_css = File.read(File.join(@tmpdir, "Solunized Dark.css"), encoding: "UTF-8")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_generates_one_css_file_per_variant
    assert_equal @themes.size, Dir.glob(File.join(@tmpdir, "*.css")).size
  end

  def test_terminal_palette_matches_terminal_semantics
    dim_0 = @themes["dark"]["colors"]["dim_0"]
    fg_1  = @themes["dark"]["colors"]["fg_1"]

    assert_includes @dark_css, "terminal.white {\n  color: #{dim_0};\n}"
    assert_includes @dark_css, "terminal.bright-white {\n  color: #{fg_1};\n}"
  end

  def test_quotes_the_display_name
    assert_includes @dark_css, %(-theme-display-name: "Solunized Dark";)
  end
end

# ---------------------------------------------------------------------------
# Glow application
# ---------------------------------------------------------------------------

class GlowApplicationTest < Minitest::Test
  CHROMA_SLOTS = {
    "#ansidarkred" => 1, "#ansidarkgreen" => 2, "#ansidarkblue" => 4, "#ansipurple" => 5, "#ansiteal" => 6
  }.freeze
  PALETTE_SAFE_CHROMA = CHROMA_SLOTS.keys.freeze
  GHOSTTY_SLOTS = { "red" => 1, "green" => 2, "blue" => 4, "magenta" => 5, "cyan" => 6, "dim_0" => 7 }.freeze

  def setup
    @glow_dir = Dir.mktmpdir
    @ghostty_dir = Dir.mktmpdir
    @workspace_root = File.expand_path("..", __dir__)
    @themes = YAML.load_file(File.join(@workspace_root, "themes.yml"))["themes"]

    generate("glow", "template.json.erb", @glow_dir)
    generate("ghostty", "template.config.erb", @ghostty_dir)

    @raw = File.read(File.join(@glow_dir, "solunized.json"), encoding: "UTF-8")
    @style = JSON.parse(@raw)
  end

  def teardown
    FileUtils.rm_rf(@glow_dir)
    FileUtils.rm_rf(@ghostty_dir)
  end

  def test_writes_one_style_file_named_solunized_json
    assert_equal [ "solunized.json" ], Dir.children(@glow_dir)
  end

  def test_output_is_valid_json
    assert_kind_of Hash, @style
  end

  def test_every_colour_outside_chroma_is_an_ansi_number_from_0_to_15
    colours = colours_in(@style.reject { |key, _| key == "code_block" }) +
      colours_in(@style.fetch("code_block").reject { |key, _| key == "chroma" })

    refute_empty colours
    colours.each { |colour| assert_match(/\A(?:[0-9]|1[0-5])\z/, colour) }
  end

  def test_every_chroma_colour_is_a_palette_safe_name
    colours = colours_in(@style.fetch("code_block").fetch("chroma"))

    refute_empty colours
    colours.each { |colour| assert_includes PALETTE_SAFE_CHROMA, colour }
  end

  def test_chroma_comments_are_italic_without_colour
    comment = @style.fetch("code_block").fetch("chroma").fetch("comment")

    assert_equal true, comment.fetch("italic")
    refute comment.key?("color")
  end

  def test_has_no_hex_colours
    refute_match(/#(?:\h{8}|\h{6}|\h{4}|\h{3})\b/, @raw)
  end

  def test_has_no_background_colours
    refute_includes key_names(@style), "background_color"
    refute_includes key_names(@style), "background"
  end

  def test_headings_links_and_code_use_the_ghostty_slots_for_blue_cyan_and_green
    assert_equal slot("blue"), @style.fetch("heading").fetch("color")
    assert_equal slot("cyan"), @style.fetch("link").fetch("color")
    assert_equal slot("green"), @style.fetch("code").fetch("color")
    assert_ghostty_palette_matches_slots
  end

  def test_every_slot_the_style_uses_is_checked_against_the_ghostty_palette
    used = colours_in(@style).map { |colour| CHROMA_SLOTS.fetch(colour) { Integer(colour) } }.uniq

    used.each { |index| assert_includes GHOSTTY_SLOTS.values, index, "slot #{index} is not checked" }
    assert_ghostty_palette_matches_slots
  end

  def test_body_text_has_no_colour
    refute @style.fetch("document").key?("color")
  end

  private

  def generate(app, template, output_dir)
    config = YAML.load_file(File.join(@workspace_root, "applications/#{app}/configuration.yml")).fetch(app)
    config["output_dir"] = output_dir
    process_erb_app(@themes, config, File.join(@workspace_root, "applications/#{app}/#{template}"))
  end

  def slot(name)
    GHOSTTY_SLOTS.fetch(name).to_s
  end

  def assert_ghostty_palette_matches_slots
    @themes.each_key do |variant|
      palette = ghostty_palette(variant)
      GHOSTTY_SLOTS.each do |name, index|
        assert_equal @themes[variant]["colors"][name], palette[index], "#{variant} #{name} slot #{index}"
      end
    end
  end

  def ghostty_palette(variant)
    File.read(File.join(@ghostty_dir, "solunized-#{variant}"), encoding: "UTF-8")
      .scan(/^palette = (\d+)=(#\h+)$/)
      .to_h { |index, hex| [ index.to_i, hex ] }
  end

  def colours_in(node)
    case node
    when Hash then node.flat_map { |key, value| key.end_with?("color") ? [ value ] : colours_in(value) }
    when Array then node.flat_map { |value| colours_in(value) }
    else []
    end
  end

  def key_names(node)
    case node
    when Hash then node.keys + node.values.flat_map { |value| key_names(value) }
    when Array then node.flat_map { |value| key_names(value) }
    else []
    end
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

    dark_out = File.read(File.join(@tmpdir, "out", "theme-dark.txt"), encoding: "UTF-8")
    assert_equal "dark: #001122\n", dark_out

    light_out = File.read(File.join(@tmpdir, "out", "theme-light.txt"), encoding: "UTF-8")
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

    content = File.read(File.join(@tmpdir, "out", "all.txt"), encoding: "UTF-8")
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

    assert_equal "dark\n",  File.read(File.join(@tmpdir, "out", "dark.txt"), encoding: "UTF-8")
    assert_equal "light\n", File.read(File.join(@tmpdir, "out", "light.txt"), encoding: "UTF-8")
  end

  def test_raises_for_unknown_colour_key_in_erb_template
    erb_file = File.join(@tmpdir, "test.erb")
    File.write(erb_file, "<%= c(variant, 'missing_colour') %>\n")

    config = {
      "output_dir"       => File.join(@tmpdir, "out"),
      "per_theme"        => true,
      "filename_pattern" => "%{variant}.txt"
    }

    error = assert_raises(RuntimeError) do
      process_erb_app(THEMES, config, erb_file)
    end

    assert_match(/Unknown colour key/, error.message)
  end
end

# ---------------------------------------------------------------------------
# process_all_apps
# ---------------------------------------------------------------------------

class ProcessAllAppsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_skips_terminal_template_when_plutil_is_unavailable
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "themes" => THEMES }))

    apps_dir = File.join(@tmpdir, "apps")
    FileUtils.mkdir_p(apps_dir)

    docs_output_dir = File.join(@tmpdir, "out", "docs")
    terminal_output_dir = File.join(@tmpdir, "out", "terminal")

    docs_dir = File.join(apps_dir, "docs")
    terminal_dir = File.join(apps_dir, "terminal")
    FileUtils.mkdir_p(docs_dir)
    FileUtils.mkdir_p(terminal_dir)

    File.write(File.join(docs_dir, "configuration.yml"), <<~YAML)
      docs:
        output_dir: #{docs_output_dir}
        per_theme: false
        filename: colors.md
    YAML
    File.write(File.join(docs_dir, "template.md.erb"), "<%= themes.keys.join(',') %>\n")

    File.write(File.join(terminal_dir, "configuration.yml"), <<~YAML)
      terminal:
        output_dir: #{terminal_output_dir}
        per_theme: true
        filename_pattern: "%{variant}.terminal"
    YAML
    File.write(File.join(terminal_dir, "template.terminal.erb"), "<%= hex_to_term_color(c(variant, 'bg_0')) %>\n")

    process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir, plutil_command: "missing-plutil-command")

    assert File.exist?(File.join(docs_output_dir, "colors.md"))
    assert_equal [], Dir.glob(File.join(terminal_output_dir, "*"))
  end

  def test_raises_when_themes_key_is_missing
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "wrong_key" => {} }))

    apps_dir = File.join(@tmpdir, "apps")
    FileUtils.mkdir_p(apps_dir)

    error = assert_raises(RuntimeError) do
      process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)
    end

    assert_match(/missing top-level 'themes' key/, error.message)
  end

  def test_raises_when_themes_is_not_a_hash
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "themes" => [] }))

    apps_dir = File.join(@tmpdir, "apps")
    FileUtils.mkdir_p(apps_dir)

    error = assert_raises(RuntimeError) do
      process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)
    end

    assert_match(/'themes' must be a non-empty mapping/, error.message)
  end

  def test_raises_when_a_theme_has_no_colors_mapping
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "themes" => { "dark" => { "display_name" => "Broken" } } }))

    apps_dir = File.join(@tmpdir, "apps")
    FileUtils.mkdir_p(apps_dir)

    error = assert_raises(RuntimeError) do
      process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)
    end

    assert_match(/must include a non-empty colors mapping/, error.message)
  end

  def test_rejects_unsafe_yaml_tags
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, <<~YAML)
      --- !ruby/object:OpenStruct
      table:
        themes: {}
    YAML

    apps_dir = File.join(@tmpdir, "apps")
    FileUtils.mkdir_p(apps_dir)

    error = assert_raises(RuntimeError) do
      process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)
    end

    assert_match(/Invalid YAML/, error.message)
  end

  def test_ignores_non_configuration_yaml_files
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "themes" => THEMES }))

    apps_dir = File.join(@tmpdir, "apps")
    docs_dir = File.join(apps_dir, "docs")
    FileUtils.mkdir_p(docs_dir)

    File.write(File.join(docs_dir, "configuration.yml"), <<~YAML)
      docs:
        output_dir: #{@tmpdir}/out/docs
        per_theme: false
        filename: colors.md
    YAML
    File.write(File.join(docs_dir, "template.md.erb"), "ok\n")
    File.write(File.join(docs_dir, "notes.yml"), "foo: bar\n")

    process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)

    assert File.exist?(File.join(@tmpdir, "out", "docs", "colors.md"))
  end

  def test_finds_a_template_named_after_the_output_extension
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "themes" => THEMES }))

    apps_dir = File.join(@tmpdir, "apps")
    guide_dir = File.join(apps_dir, "guide")
    FileUtils.mkdir_p(guide_dir)

    File.write(File.join(guide_dir, "configuration.yml"), <<~YAML)
      guide:
        output_dir: #{@tmpdir}/out/guide
        per_theme: false
        filename: guide.md
    YAML
    File.write(File.join(guide_dir, "template.md.erb"), "ok\n")

    process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)

    assert_equal "ok\n", File.read(File.join(@tmpdir, "out", "guide", "guide.md"), encoding: "UTF-8")
  end

  def test_rejects_a_template_with_no_extension
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "themes" => THEMES }))

    apps_dir = File.join(@tmpdir, "apps")
    guide_dir = File.join(apps_dir, "guide")
    FileUtils.mkdir_p(guide_dir)

    File.write(File.join(guide_dir, "configuration.yml"), <<~YAML)
      guide:
        output_dir: #{@tmpdir}/out/guide
        per_theme: false
        filename: guide.md
    YAML
    File.write(File.join(guide_dir, "template.erb"), "ok\n")

    error = assert_raises(RuntimeError) do
      process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)
    end

    assert_match(/missing template/, error.message)
  end

  def test_raises_when_more_than_one_template_matches
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "themes" => THEMES }))

    apps_dir = File.join(@tmpdir, "apps")
    guide_dir = File.join(apps_dir, "guide")
    FileUtils.mkdir_p(guide_dir)

    File.write(File.join(guide_dir, "configuration.yml"), <<~YAML)
      guide:
        output_dir: #{@tmpdir}/out/guide
        per_theme: false
        filename: guide.md
    YAML
    File.write(File.join(guide_dir, "template.md.erb"), "ok\n")
    File.write(File.join(guide_dir, "template.txt.erb"), "ok\n")

    error = assert_raises(RuntimeError) do
      process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)
    end

    assert_match(/multiple templates/, error.message)
  end

  def test_rejects_invalid_app_config
    themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(themes_yml, YAML.dump({ "themes" => THEMES }))

    apps_dir = File.join(@tmpdir, "apps")
    invalid_dir = File.join(apps_dir, "invalid")
    FileUtils.mkdir_p(invalid_dir)

    File.write(File.join(invalid_dir, "configuration.yml"), <<~YAML)
      invalid:
        output_dir: #{@tmpdir}/out/invalid
    YAML

    error = assert_raises(RuntimeError) do
      process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir)
    end

    assert_match(/Invalid config/, error.message)
  end
end

# ---------------------------------------------------------------------------
# hex_to_oklch
# ---------------------------------------------------------------------------

class HexToOklchTest < Minitest::Test
  def test_black_produces_zero_lightness_and_chroma
    l, c, _h = parse_oklch(hex_to_oklch("#000000"))
    assert_in_delta 0.0,   l, 0.01
    assert_in_delta 0.0,   c, 0.0001
  end

  def test_white_produces_full_lightness_and_zero_chroma
    l, c, _h = parse_oklch(hex_to_oklch("#ffffff"))
    assert_in_delta 100.0, l, 0.01
    assert_in_delta 0.0,   c, 0.0001
  end

  def test_output_is_valid_css_oklch_format
    assert_match(/\Aoklch\(\d+\.\d+% \d+\.\d+ \d+\.\d+\)\z/, hex_to_oklch("#4191f4"))
  end

  def test_raises_argument_error_for_invalid_hex
    error = assert_raises(ArgumentError) { hex_to_oklch("not-a-hex") }
    assert_match(/Expected a hex color/, error.message)
  end

  private

  def parse_oklch(str)
    m = str.match(/oklch\((\d+\.\d+)% (\d+\.\d+) (\d+\.\d+)\)/)
    [ m[1].to_f, m[2].to_f, m[3].to_f ]
  end
end

# ---------------------------------------------------------------------------
# mvpa-css application
# ---------------------------------------------------------------------------

class MvpaCssApplicationTest < Minitest::Test
  EXPECTED_VARIABLES = %w[
    --color-bg-0 --color-bg-1 --color-bg-2
    --color-dim-0 --color-fg-0 --color-fg-1
    --color-red --color-green --color-yellow --color-blue
    --color-magenta --color-cyan --color-orange --color-violet
    --color-br-red --color-br-green --color-br-yellow --color-br-blue
    --color-br-magenta --color-br-cyan --color-br-orange --color-br-violet
  ].freeze

  def setup
    @tmpdir = Dir.mktmpdir
    @workspace_root = File.expand_path("..", __dir__)
    @themes = YAML.load_file(File.join(@workspace_root, "themes.yml"))["themes"]

    config = YAML.load_file(File.join(@workspace_root, "applications/mvpa-css/configuration.yml"))["mvpa_css"]
    config["output_dir"] = @tmpdir
    erb_file = File.join(@workspace_root, "applications/mvpa-css/template.css.erb")

    process_erb_app(@themes, config, erb_file)

    @css_by_variant = @themes.keys.to_h do |variant|
      [ variant, File.read(File.join(@tmpdir, "solunized-#{variant}.css"), encoding: "UTF-8") ]
    end
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_generates_one_file_per_variant
    assert_equal @themes.size, Dir.glob(File.join(@tmpdir, "solunized-*.css")).size
  end

  def test_each_file_has_exactly_22_variables
    @themes.each_key do |variant|
      assert_equal EXPECTED_VARIABLES.size, css_variable_lines(@css_by_variant[variant]).size,
        "Expected #{EXPECTED_VARIABLES.size} variables in solunized-#{variant}.css"
    end
  end

  def test_all_variants_define_the_same_variable_names
    variable_names_per_variant = @themes.keys.map do |variant|
      css_variable_lines(@css_by_variant[variant]).map { |l| l.match(/(--color-[\w-]+)/)[1] }.sort
    end

    assert_equal 1, variable_names_per_variant.uniq.size, "Variable names differ across variants"
  end

  def test_all_expected_variables_are_present
    EXPECTED_VARIABLES.each do |variable|
      assert_includes @css_by_variant["dark"], variable
    end
  end

  def test_selector_uses_data_theme_attribute
    @themes.each_key do |variant|
      assert_match(/\[data-theme="solunized-#{variant}"\]/, @css_by_variant[variant])
    end
  end

  def test_values_match_themes_yml
    @themes.each do |variant, theme_data|
      css = @css_by_variant[variant]
      assert_includes css, "--color-bg-0: #{hex_to_oklch(theme_data['colors']['bg_0'])};"
      assert_includes css, "--color-red: #{hex_to_oklch(theme_data['colors']['red'])};"
      assert_includes css, "--color-br-violet: #{hex_to_oklch(theme_data['colors']['br_violet'])};"
    end
  end

  private

  def css_variable_lines(css)
    css.lines.grep(/^\s+--color-/)
  end
end

# ---------------------------------------------------------------------------
# slack application
# ---------------------------------------------------------------------------

class SlackApplicationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @workspace_root = File.expand_path("..", __dir__)
    @themes = YAML.load_file(File.join(@workspace_root, "themes.yml"))["themes"]

    config = YAML.load_file(File.join(@workspace_root, "applications/slack/configuration.yml"))["slack"]
    config["output_dir"] = @tmpdir
    erb_file = File.join(@workspace_root, "applications/slack/template.md.erb")

    process_erb_app(@themes, config, erb_file)

    @content = File.read(File.join(@tmpdir, "slack.md"), encoding: "UTF-8")
    @theme_strings = @content.scan(/```\n(#[0-9a-f]{6}(?:,#[0-9a-f]{6}){7})\n```/).flatten
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_generates_one_eight_colour_theme_string_per_variant
    assert_equal @themes.size, @theme_strings.size
  end

  def test_active_item_text_is_readable_against_active_item
    @theme_strings.each do |string|
      active_item, active_item_text = string.split(",").values_at(2, 3)

      assert_operator contrast_ratio(active_item, active_item_text), :>=, 4.5,
        "Active Item Text #{active_item_text} on Active Item #{active_item} fails WCAG AA"
    end
  end

  def test_explains_the_sidebar_only_limitation
    assert_match(/sidebar/i, @content)
  end

  private

  def contrast_ratio(hex_a, hex_b)
    lighter, darker = [ relative_luminance(hex_a), relative_luminance(hex_b) ].sort.reverse
    (lighter + 0.05) / (darker + 0.05)
  end

  def relative_luminance(hex)
    r, g, b = hex.delete_prefix("#").scan(/../).map { |c| linearize(c.to_i(16) / 255.0) }
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  def linearize(channel)
    channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
  end
end

# ---------------------------------------------------------------------------
# Firefox add-ons
# ---------------------------------------------------------------------------

# Reads a zip back through its central directory, with no unzip tool.
# Returns { name => { data:, crc_ok: } }.
def read_zip(path)
  bytes = File.binread(path)
  eocd = bytes.rindex([ 0x06054b50 ].pack("V"))
  total, = bytes.byteslice(eocd + 10, 2).unpack("v")
  offset, = bytes.byteslice(eocd + 16, 4).unpack("V")
  entries = {}
  total.times do
    crc, size, _, name_len, extra_len, comment_len = bytes.byteslice(offset + 16, 18).unpack("VVVvvv")
    local_offset, = bytes.byteslice(offset + 42, 4).unpack("V")
    name = bytes.byteslice(offset + 46, name_len)
    local_name_len, local_extra_len = bytes.byteslice(local_offset + 26, 4).unpack("vv")
    data = bytes.byteslice(local_offset + 30 + local_name_len + local_extra_len, size)
    entries[name] = { data: data, crc_ok: Zlib.crc32(data) == crc }
    offset += 46 + name_len + extra_len + comment_len
  end
  entries
end

class WriteZipTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @path = File.join(@tmpdir, "out.zip")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_writes_each_entry_at_the_archive_root_with_a_matching_crc
    write_zip(@path, { "manifest.json" => "{\"a\": 1}\n", "note.txt" => "café\n" })

    entries = read_zip(@path)

    assert_equal %w[manifest.json note.txt], entries.keys.sort
    assert_equal "{\"a\": 1}\n", entries.fetch("manifest.json").fetch(:data)
    assert_equal "café\n".b, entries.fetch("note.txt").fetch(:data)
    assert entries.values.all? { |entry| entry.fetch(:crc_ok) }
  end

  def test_gives_the_same_bytes_on_every_run
    write_zip(@path, { "manifest.json" => "{}\n" })
    first = File.binread(@path)
    sleep 0.01
    write_zip(@path, { "manifest.json" => "{}\n" })

    assert_equal first, File.binread(@path)
  end

  def test_returns_the_path
    assert_equal @path, write_zip(@path, { "a" => "b" })
  end
end

class AddOnProcessingTest < Minitest::Test
  TEMPLATE = <<~ERB.freeze
    <%= add_on["name"] %>|<%= add_on["id"] %>|<%= add_on["version"] %>|<%= add_on["slug"] %>|<%= c(add_on["theme"], "bg_0") %>|<%= c(add_on["dark_theme"], "bg_0") %>
  ERB

  def setup
    @tmpdir = Dir.mktmpdir
    @erb_file = File.join(@tmpdir, "template.json.erb")
    File.write(@erb_file, TEMPLATE)
    @config = {
      "output_dir" => File.join(@tmpdir, "out"),
      "filename"   => "manifest.json",
      "version"    => "2.3.4",
      "add_ons"    => {
        "pair-one" => { "name" => "Pair One", "id" => "one@example.test", "theme" => "light", "dark_theme" => "dark" }
      }
    }
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_writes_one_directory_and_one_zip_per_add_on
    @config["add_ons"]["pair-two"] = { "name" => "Pair Two", "id" => "two@example.test", "theme" => "dark", "dark_theme" => "light" }

    process_erb_app(THEMES, @config, @erb_file)

    assert File.file?(File.join(@tmpdir, "out", "pair-one", "manifest.json"))
    assert File.file?(File.join(@tmpdir, "out", "pair-two", "manifest.json"))
    assert File.file?(File.join(@tmpdir, "out", "pair-one.zip"))
    assert File.file?(File.join(@tmpdir, "out", "pair-two.zip"))
  end

  def test_the_template_sees_its_add_on_settings_and_the_shared_version
    process_erb_app(THEMES, @config, @erb_file)

    manifest = File.read(File.join(@tmpdir, "out", "pair-one", "manifest.json"), encoding: "UTF-8")

    assert_equal "Pair One|one@example.test|2.3.4|pair-one|#ffffff|#001122\n", manifest
  end

  def test_add_on_zip_holds_the_same_manifest_as_its_directory
    process_erb_app(THEMES, @config, @erb_file)

    manifest = File.binread(File.join(@tmpdir, "out", "pair-one", "manifest.json"))
    entries = read_zip(File.join(@tmpdir, "out", "pair-one.zip"))

    assert_equal [ "manifest.json" ], entries.keys
    assert_equal manifest, entries.fetch("manifest.json").fetch(:data)
  end

  def test_regenerating_gives_identical_zip_bytes
    process_erb_app(THEMES, @config, @erb_file)
    first = File.binread(File.join(@tmpdir, "out", "pair-one.zip"))
    process_erb_app(THEMES, @config, @erb_file)

    assert_equal first, File.binread(File.join(@tmpdir, "out", "pair-one.zip"))
  end

  def test_an_unknown_variant_in_an_add_on_raises
    @config["add_ons"]["pair-one"]["theme"] = "missing"

    error = assert_raises(RuntimeError) { process_erb_app(THEMES, @config, @erb_file) }

    assert_match(/Unknown theme variant 'missing'/, error.message)
  end
end

class AddOnConfigValidationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @themes_yml = File.join(@tmpdir, "themes.yml")
    File.write(@themes_yml, YAML.dump({ "themes" => THEMES }))
    @apps_dir = File.join(@tmpdir, "apps")
    @app_dir = File.join(@apps_dir, "browser")
    FileUtils.mkdir_p(@app_dir)
    File.write(File.join(@app_dir, "template.json.erb"), "<%= add_on['name'] %>\n")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_accepts_add_ons_without_per_theme
    write_config(version: '"1.0.0"', add_on_id: "a@example.test")

    process_all_apps(themes_yml: @themes_yml, apps_dir: @apps_dir)

    assert File.file?(File.join(@tmpdir, "out", "pair", "manifest.json"))
  end

  def test_rejects_an_add_on_without_an_id
    write_config(version: '"1.0.0"', add_on_id: '""')

    error = assert_raises(RuntimeError) { process_all_apps(themes_yml: @themes_yml, apps_dir: @apps_dir) }

    assert_match(/Invalid config.*pair.*id/, error.message)
  end

  def test_rejects_add_ons_without_a_version
    write_config(version: '""', add_on_id: "a@example.test")

    error = assert_raises(RuntimeError) { process_all_apps(themes_yml: @themes_yml, apps_dir: @apps_dir) }

    assert_match(/Invalid config.*version/, error.message)
  end

  def test_rejects_an_empty_add_ons_mapping
    File.write(File.join(@app_dir, "configuration.yml"), <<~YAML)
      browser:
        output_dir: #{@tmpdir}/out
        filename: manifest.json
        version: "1.0.0"
        add_ons: {}
    YAML

    error = assert_raises(RuntimeError) { process_all_apps(themes_yml: @themes_yml, apps_dir: @apps_dir) }

    assert_match(/Invalid config.*add_ons/, error.message)
  end

  def test_rejects_add_ons_without_a_filename
    File.write(File.join(@app_dir, "configuration.yml"), <<~YAML)
      browser:
        output_dir: #{@tmpdir}/out
        version: "1.0.0"
        add_ons:
          pair: { name: Pair, id: a@example.test, theme: light, dark_theme: dark }
    YAML

    error = assert_raises(RuntimeError) { process_all_apps(themes_yml: @themes_yml, apps_dir: @apps_dir) }

    assert_match(/Invalid config.*filename/, error.message)
  end

  private

  def write_config(version:, add_on_id:)
    File.write(File.join(@app_dir, "configuration.yml"), <<~YAML)
      browser:
        output_dir: #{@tmpdir}/out
        filename: manifest.json
        version: #{version}
        add_ons:
          pair:
            name: Pair
            id: #{add_on_id}
            theme: light
            dark_theme: dark
    YAML
  end
end

class FirefoxApplicationTest < Minitest::Test
  # The 38 current MDN theme.colors keys, kept here independently of the template.
  FIREFOX_COLOR_KEYS = %w[
    bookmark_text button_background_active button_background_hover frame frame_inactive icons icons_attention
    ntp_background ntp_card_background ntp_text popup popup_border popup_highlight popup_highlight_text popup_text
    sidebar sidebar_border sidebar_highlight sidebar_highlight_text sidebar_text tab_background_text tab_line
    tab_loading tab_selected tab_text toolbar toolbar_bottom_separator toolbar_field toolbar_field_border
    toolbar_field_border_focus toolbar_field_focus toolbar_field_highlight toolbar_field_highlight_text
    toolbar_field_text toolbar_field_text_focus toolbar_text toolbar_top_separator toolbar_vertical_separator
  ].freeze

  DEPRECATED_KEYS = %w[tab_background_separator toolbar_field_separator].freeze

  def setup
    @tmpdir = Dir.mktmpdir
    @themes = load_yaml_hash(File.expand_path("../themes.yml", __dir__)).fetch("themes")
    apps_dir = File.join(@tmpdir, "apps")
    FileUtils.mkdir_p(apps_dir)
    FileUtils.cp_r(File.expand_path("../applications/firefox", __dir__), apps_dir)
    config_file = File.join(apps_dir, "firefox", "configuration.yml")
    config = YAML.load_file(config_file)
    config.fetch("firefox")["output_dir"] = File.join(@tmpdir, "out")
    File.write(config_file, YAML.dump(config))

    process_all_apps(themes_yml: File.expand_path("../themes.yml", __dir__), apps_dir: apps_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_has_thirty_eight_keys_in_the_test_list
    assert_equal 38, FIREFOX_COLOR_KEYS.uniq.size
  end

  def test_writes_a_manifest_per_add_on
    assert_equal %w[solunized-light-dark solunized-white-black],
      Dir.glob(File.join(@tmpdir, "out", "*", "manifest.json")).map { |path| File.basename(File.dirname(path)) }.sort
  end

  def test_light_dark_frames_use_the_light_and_dark_backgrounds
    manifest = manifest_for("solunized-light-dark")

    assert_equal @themes.dig("light", "colors", "bg_0"), manifest.dig("theme", "colors", "frame")
    assert_equal @themes.dig("dark", "colors", "bg_0"), manifest.dig("dark_theme", "colors", "frame")
  end

  def test_white_black_frames_use_the_white_and_black_backgrounds
    manifest = manifest_for("solunized-white-black")

    assert_equal @themes.dig("white", "colors", "bg_0"), manifest.dig("theme", "colors", "frame")
    assert_equal @themes.dig("black", "colors", "bg_0"), manifest.dig("dark_theme", "colors", "frame")
  end

  def test_every_current_key_has_a_colour_of_its_variant
    {
      "solunized-light-dark" => { "theme" => "light", "dark_theme" => "dark" },
      "solunized-white-black" => { "theme" => "white", "dark_theme" => "black" }
    }.each do |add_on, sections|
      manifest = manifest_for(add_on)
      sections.each do |section, variant|
        colors = manifest.fetch(section).fetch("colors")
        palette = @themes.fetch(variant).fetch("colors").values

        assert_equal FIREFOX_COLOR_KEYS.sort, colors.keys.sort, "#{add_on} #{section}"
        colors.each_value do |value|
          assert_match(HEX_COLOR_PATTERN, value)
          assert_includes palette, value, "#{add_on} #{section}"
        end
      end
    end
  end

  def test_has_no_deprecated_keys
    Dir.glob(File.join(@tmpdir, "out", "*", "manifest.json")).each do |path|
      manifest = JSON.parse(File.read(path, encoding: "UTF-8"))
      %w[theme dark_theme].each do |section|
        assert_empty DEPRECATED_KEYS & manifest.fetch(section).fetch("colors").keys
      end
    end
  end

  def test_dark_toolbar_text_differs_from_toolbar
    colors = manifest_for("solunized-light-dark").fetch("dark_theme").fetch("colors")

    refute_equal colors.fetch("toolbar"), colors.fetch("toolbar_text")
  end

  def test_each_add_on_has_its_own_name_and_id
    light_dark = manifest_for("solunized-light-dark")
    white_black = manifest_for("solunized-white-black")

    assert_equal "Solunized Light & Dark", light_dark.fetch("name")
    assert_equal "solunized-light-dark@eirvandelden.github.io", light_dark.dig("browser_specific_settings", "gecko", "id")
    assert_equal "Solunized White & Black", white_black.fetch("name")
    assert_equal "solunized-white-black@eirvandelden.github.io", white_black.dig("browser_specific_settings", "gecko", "id")
    assert_match(/\A\d+\.\d+\.\d+\z/, light_dark.fetch("version"))
  end

  def test_each_add_on_zip_holds_its_manifest_at_the_root
    %w[solunized-light-dark solunized-white-black].each do |add_on|
      entries = read_zip(File.join(@tmpdir, "out", "#{add_on}.zip"))

      assert_equal [ "manifest.json" ], entries.keys
      assert_equal File.binread(File.join(@tmpdir, "out", add_on, "manifest.json")), entries.fetch("manifest.json").fetch(:data)
    end
  end

  def test_the_template_holds_no_hex_colour
    template = File.read(File.expand_path("../applications/firefox/template.json.erb", __dir__), encoding: "UTF-8")

    refute_match(/#[0-9A-Fa-f]{6}/, template)
  end

  private

  def manifest_for(add_on)
    JSON.parse(File.read(File.join(@tmpdir, "out", add_on, "manifest.json"), encoding: "UTF-8"))
  end
end

# ---------------------------------------------------------------------------
# full application integration
# ---------------------------------------------------------------------------

class FullApplicationIntegrationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @workspace_root = File.expand_path("..", __dir__)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_generates_real_templates_and_validates_zed_json
    themes_yml = File.join(@workspace_root, "themes.yml")
    apps_dir = copy_apps_with_tmp_outputs

    process_all_apps(themes_yml: themes_yml, apps_dir: apps_dir, plutil_command: "missing-plutil-command")

    assert File.exist?(File.join(@tmpdir, "out", "docs", "colors.md"))
    assert File.exist?(File.join(@tmpdir, "out", "docs", "slack.md"))
    assert File.exist?(File.join(@tmpdir, "out", "nvim", "colors", "solunized.lua"))
    assert File.exist?(File.join(@tmpdir, "out", "nvim", "lua", "lualine", "themes", "solunized.lua"))
    assert File.exist?(File.join(@tmpdir, "out", "zed", "solunized-theme.json"))
    assert File.exist?(File.join(@tmpdir, "out", "glow", "solunized.json"))
    assert_equal 4, Dir.glob(File.join(@tmpdir, "out", "ghostty", "*")).size
    assert_equal 4, Dir.glob(File.join(@tmpdir, "out", "nova", "Themes", "*.css")).size
    assert_equal 4, Dir.glob(File.join(@tmpdir, "out", "mvpa-css", "*.css")).size
    assert_equal 4, Dir.glob(File.join(@tmpdir, "out", "herdr", "*.toml")).size
    assert_equal [], Dir.glob(File.join(@tmpdir, "out", "terminal", "*"))
    assert File.file?(File.join(@tmpdir, "out", "firefox", "solunized-light-dark", "manifest.json"))
    assert File.file?(File.join(@tmpdir, "out", "firefox", "solunized-white-black.zip"))

    zed_json = File.read(File.join(@tmpdir, "out", "zed", "solunized-theme.json"), encoding: "UTF-8")
    parsed = JSON.parse(zed_json)
    assert_equal "Solunized", parsed.fetch("name")
    assert_equal 4, parsed.fetch("themes").size
  end

  private

  def copy_apps_with_tmp_outputs
    src_apps = File.join(@workspace_root, "applications")
    dest_apps = File.join(@tmpdir, "apps")
    FileUtils.cp_r(src_apps, dest_apps)

    Dir.glob(File.join(dest_apps, "**", "configuration.yml")).each do |config_file|
      config = YAML.load_file(config_file)
      app_name = config.keys.fetch(0)
      app_config = config.fetch(app_name)
      app_config["output_dir"] = redirected_output_dir(app_config.fetch("output_dir"))
      File.write(config_file, YAML.dump(config))
    end

    dest_apps
  end

  def redirected_output_dir(configured_dir)
    File.join(@tmpdir, "out", configured_dir.delete_prefix("dist/"))
  end
end

# ---------------------------------------------------------------------------
# hex_to_term_color round-trip
# ---------------------------------------------------------------------------

class HexToTermColorTest < Minitest::Test
  def test_raises_argument_error_for_invalid_hex
    error = assert_raises(ArgumentError) do
      hex_to_term_color("invalid-color")
    end

    assert_match(/Expected a hex color/, error.message)
  end

  def test_roundtrip_components
    require_plutil!

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
    require_plutil!

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

  def test_raises_clear_error_when_plutil_is_missing
    error = assert_raises(RuntimeError) do
      hex_to_term_color("#ff8000", plutil_command: "missing-plutil-command")
    end

    assert_match(/plutil/, error.message)
  end

  private

  def require_plutil!
    return if system("command -v plutil >/dev/null 2>&1")

    skip "plutil is not available"
  end

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
