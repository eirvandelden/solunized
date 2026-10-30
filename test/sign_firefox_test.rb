require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "yaml"

require_relative "../sign_firefox"

class SignFirefoxTest < Minitest::Test
  CREDENTIALS = { "WEB_EXT_API_KEY" => "test-key", "WEB_EXT_API_SECRET" => "test-secret" }.freeze

  def setup
    @tmpdir = Dir.mktmpdir
    @dist = File.join(@tmpdir, "firefox")
    @calls = []
    @runner = ->(env, command) { @calls << [ env, command ]; true }
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_refuses_without_the_api_key_and_names_it
    error = assert_raises(SignFirefox::MissingCredentialsError) do
      SignFirefox.sign([ add_on("one") ], env: CREDENTIALS.except("WEB_EXT_API_KEY"), runner: @runner)
    end

    assert_match(/WEB_EXT_API_KEY/, error.message)
    refute_match(/WEB_EXT_API_SECRET/, error.message)
  end

  def test_refuses_without_the_api_secret_and_names_it
    error = assert_raises(SignFirefox::MissingCredentialsError) do
      SignFirefox.sign([ add_on("one") ], env: CREDENTIALS.except("WEB_EXT_API_SECRET"), runner: @runner)
    end

    assert_match(/WEB_EXT_API_SECRET/, error.message)
    refute_match(/WEB_EXT_API_KEY/, error.message)
  end

  def test_treats_an_empty_credential_as_missing
    assert_raises(SignFirefox::MissingCredentialsError) do
      SignFirefox.sign([ add_on("one") ], env: CREDENTIALS.merge("WEB_EXT_API_KEY" => " "), runner: @runner)
    end
  end

  def test_runs_no_command_while_a_credential_is_missing
    assert_raises(SignFirefox::MissingCredentialsError) do
      SignFirefox.sign([ add_on("one"), add_on("two") ], env: {}, runner: @runner)
    end

    assert_empty @calls
  end

  def test_signs_each_add_on_directory_on_the_unlisted_channel
    dirs = [ add_on("one"), add_on("two") ]

    SignFirefox.sign(dirs, env: CREDENTIALS, runner: @runner, artifacts_dir: "out/signed")

    assert_equal 2, @calls.size
    dirs.zip(@calls).each do |dir, (_, command)|
      assert_equal %w[npx --yes web-ext@10], command.first(3)
      assert_equal "unlisted", command[command.index("--channel") + 1]
      assert_equal dir, command[command.index("--source-dir") + 1]
      assert_equal "out/signed", command[command.index("--artifacts-dir") + 1]
      assert_includes command, "sign"
    end
  end

  def test_passes_no_config_discovery
    SignFirefox.sign([ add_on("one") ], env: CREDENTIALS, runner: @runner)

    assert_includes @calls.first.last, "--no-config-discovery"
  end

  def test_keeps_the_credentials_out_of_the_command
    SignFirefox.sign([ add_on("one") ], env: CREDENTIALS, runner: @runner)

    env, command = @calls.first
    assert_equal "test-key", env.fetch("WEB_EXT_API_KEY")
    assert_equal "test-secret", env.fetch("WEB_EXT_API_SECRET")
    CREDENTIALS.each_value { |value| refute(command.any? { |argument| argument.include?(value) }) }
  end

  def test_raises_when_a_signing_run_fails
    failing = ->(_env, _command) { false }

    error = assert_raises(SignFirefox::SigningFailedError) do
      SignFirefox.sign([ add_on("one") ], env: CREDENTIALS, runner: failing)
    end

    assert_match(/one/, error.message)
  end

  def test_a_runner_that_cannot_start_the_command_counts_as_a_failure
    unstartable = ->(_env, _command) { nil }

    assert_raises(SignFirefox::SigningFailedError) do
      SignFirefox.sign([ add_on("one") ], env: CREDENTIALS, runner: unstartable)
    end
  end

  def test_lists_each_configured_add_on
    add_on("one")
    add_on("two")

    assert_equal [ File.join(@dist, "one"), File.join(@dist, "two") ], SignFirefox.add_on_dirs(@dist, slugs: %w[one two])
  end

  def test_skips_a_directory_that_is_no_longer_configured
    add_on("one")
    add_on("removed")

    assert_equal [ File.join(@dist, "one") ], SignFirefox.add_on_dirs(@dist, slugs: %w[one])
  end

  def test_skips_the_signed_directory
    add_on("one")
    FileUtils.mkdir_p(File.join(@dist, "signed"))
    File.write(File.join(@dist, "signed", "one.xpi"), "x")

    assert_equal [ File.join(@dist, "one") ], SignFirefox.add_on_dirs(@dist, slugs: %w[one])
  end

  def test_refuses_when_a_configured_add_on_was_not_generated
    add_on("one")

    error = assert_raises(SignFirefox::SigningFailedError) { SignFirefox.add_on_dirs(@dist, slugs: %w[one two]) }

    assert_match(/two.*generate_themes\.rb/, error.message)
  end

  def test_refuses_when_no_add_on_was_generated
    error = assert_raises(SignFirefox::SigningFailedError) { SignFirefox.add_on_dirs(@dist, slugs: %w[one]) }

    assert_match(/generate_themes\.rb/, error.message)
  end

  def test_reads_the_slugs_from_the_firefox_configuration
    slugs = YAML.safe_load_file(File.expand_path("../applications/firefox/configuration.yml", __dir__))
      .fetch("firefox").fetch("add_ons").keys
    slugs.each { |slug| add_on(slug) }

    assert_equal slugs.sort.map { |slug| File.join(@dist, slug) }, SignFirefox.add_on_dirs(@dist)
  end

  private

  def add_on(slug)
    dir = File.join(@dist, slug)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "manifest.json"), "{}\n")
    dir
  end
end
