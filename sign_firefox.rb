#!/usr/bin/env ruby

# Signs each unpacked Firefox add-on through web-ext on the unlisted channel; refuses without AMO credentials.
# Only Etienne runs this: signing submits the add-on to Mozilla. generate_themes.rb never calls it.
require "yaml"

module SignFirefox
  CONFIGURATION = File.expand_path("applications/firefox/configuration.yml", __dir__)
  CREDENTIALS = %w[WEB_EXT_API_KEY WEB_EXT_API_SECRET].freeze
  WEB_EXT = %w[npx --yes web-ext@10 --no-config-discovery].freeze

  class MissingCredentialsError < RuntimeError; end
  class SigningFailedError < RuntimeError; end

  class << self
    # The generated directory of each add-on in configuration.yml, so a directory left over from a removed
    # add-on is never signed; raises when one is missing.
    #: (?String dist_dir, ?slugs: Array[String]) -> Array[String]
    def add_on_dirs(dist_dir = "dist/firefox", slugs: configured_slugs)
      dirs = slugs.sort.to_h { |slug| [ slug, File.join(dist_dir, slug) ] }
      missing = dirs.reject { |_slug, dir| File.exist?(File.join(dir, "manifest.json")) }.keys
      return dirs.values if missing.empty?

      raise SigningFailedError, "No add-on found for #{missing.join(', ')} in #{dist_dir}; run ruby generate_themes.rb first"
    end

    # Raises MissingCredentialsError naming each missing variable before any command runs; else signs each directory.
    #: (Array[String] add_on_dirs, ?env: Hash[String, String], ?runner: ^(Hash[String, String], Array[String]) -> bool?, ?artifacts_dir: String) -> void
    def sign(add_on_dirs, env: ENV.to_h, runner: ->(env, command) { system(env, *command) }, artifacts_dir: "dist/firefox/signed")
      require_credentials!(env)

      add_on_dirs.each do |dir|
        next if runner.call(env, command_for(dir, artifacts_dir)) == true

        raise SigningFailedError, "Signing failed for #{dir}"
      end
    end

    private

    def configured_slugs
      YAML.safe_load_file(CONFIGURATION).fetch("firefox").fetch("add_ons").keys
    end

    def require_credentials!(env)
      missing = CREDENTIALS.select { |name| env[name].to_s.strip.empty? }
      return if missing.empty?

      raise MissingCredentialsError, "Set #{missing.join(' and ')} before signing"
    end

    def command_for(dir, artifacts_dir)
      WEB_EXT + [ "sign", "--channel", "unlisted", "--source-dir", dir, "--artifacts-dir", artifacts_dir ]
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    SignFirefox.sign(SignFirefox.add_on_dirs)
  rescue SignFirefox::MissingCredentialsError, SignFirefox::SigningFailedError => error
    abort(error.message)
  end
end
