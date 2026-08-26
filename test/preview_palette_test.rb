require "minitest/autorun"

require_relative "../preview_palette"

PREVIEW_COLORS = {
  "bg_0" => "#fffbf1", "bg_1" => "#eeeae0", "bg_2" => "#d5d2c8",
  "dim_0" => "#6a8990", "fg_0" => "#243f47", "fg_1" => "#10232c",
  "red" => "#c51f23", "green" => "#398300", "yellow" => "#906e00", "blue" => "#0068c9",
  "magenta" => "#bc4090", "cyan" => "#00817a", "orange" => "#b05015", "violet" => "#795bc0",
  "br_red" => "#b81a1e", "br_green" => "#337700", "br_yellow" => "#826100", "br_blue" => "#005fc0",
  "br_magenta" => "#b23886", "br_cyan" => "#007770", "br_orange" => "#a44910", "br_violet" => "#6e52b5"
}.freeze

class PreviewPaletteTest < Minitest::Test
  def test_every_accent_appears_in_its_normal_and_bright_form
    output = PreviewPalette.render("light", PREVIEW_COLORS)

    PreviewPalette::ACCENTS.each do |name|
      assert_includes output, PREVIEW_COLORS.fetch(name), "#{name} missing"
      assert_includes output, PREVIEW_COLORS.fetch("br_#{name}"), "bright #{name} missing"
    end
  end

  def test_each_colour_is_drawn_as_text_on_the_variant_background
    output = PreviewPalette.render("light", PREVIEW_COLORS)

    assert_includes output, "\e[48;2;255;251;241m\e[38;2;0;104;201m", "blue not drawn on the background"
  end

  def test_the_variant_background_is_named_in_the_heading
    output = PreviewPalette.render("light", PREVIEW_COLORS)

    assert_includes output, "Solunized Light — colours on background #fffbf1"
  end
end
