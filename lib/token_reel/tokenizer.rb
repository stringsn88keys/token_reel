# frozen_string_literal: true

module TokenReel
  # Splits text into the chunks that get revealed one-by-one while
  # streaming. Joining the tokens back together always reproduces the
  # original string exactly.
  module Tokenizer
    def self.tokenize(text, unit)
      return [] if text.nil? || text.empty?

      case unit.to_sym
      when :char
        text.each_char.to_a
      when :word
        # "word" + any trailing whitespace travels together, so a token
        # reveals as a whole word (closer to how LLM tokens/BPE chunks
        # tend to land) instead of one raw character at a time.
        text.scan(/\S+\s*|\s+/)
      else
        raise ConfigError, "unknown unit #{unit.inspect} (valid: word, char)"
      end
    end
  end
end
