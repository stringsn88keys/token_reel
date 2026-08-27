# frozen_string_literal: true

require_relative "lib/token_reel/version"

Gem::Specification.new do |spec|
  spec.name        = "token_reel"
  spec.version     = TokenReel::VERSION
  spec.authors     = ["Thomas Powell"]
  spec.email       = ["twilliampowell@gmail.com"]
  spec.summary     = "Render terminal-style GIFs of an LLM prompt/response, streamed at a chosen tokens/sec and time-to-first-token"
  spec.description = <<~DESC
    token_reel renders a "CLI demo"-style animated GIF of a prompt being
    answered: the prompt appears, there's a configurable pause (time to
    first token), and the response streams in word-by-word or
    character-by-character at a configurable tokens/sec rate -- handy for
    READMEs, blog posts, and talks that want to show off an LLM CLI
    without shelling out to a real model (or a real screen recorder).
  DESC
  spec.homepage    = "https://github.com/stringsn88keys/token_reel"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    if system("git rev-parse --git-dir > /dev/null 2>&1")
      `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
    else
      Dir.glob("{lib,exe}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) } +
        %w[README.md token_reel.gemspec]
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
