# frozen_string_literal: true

require "shellwords"

require_relative "token_reel/version"
require_relative "token_reel/errors"
require_relative "token_reel/theme"
require_relative "token_reel/tokenizer"
require_relative "token_reel/script"
require_relative "token_reel/config"
require_relative "token_reel/timeline"
require_relative "token_reel/fonts"
require_relative "token_reel/highlight"
require_relative "token_reel/renderer"
require_relative "token_reel/gif_writer"
require_relative "token_reel/generator"
require_relative "token_reel/cli"

module TokenReel
  # Convenience one-liner: TokenReel.generate(prompt: "...", response: "...", tps: 12)
  def self.generate(**opts)
    config = Config.new
    opts.each do |k, v|
      setter = "#{k}="
      raise ConfigError, "unknown option #{k.inspect}" unless config.respond_to?(setter)

      config.public_send(setter, v)
    end
    Generator.new(config).generate!
  end
end
