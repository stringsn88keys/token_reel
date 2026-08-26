# frozen_string_literal: true

module TokenReel
  # A small, dependency-free syntax colorizer for text inside fenced
  # code blocks. It isn't a real per-language grammar -- just enough
  # regex-based token classing (comments, strings, numbers, a shared
  # keyword list spanning a handful of mainstream languages) to make
  # demo code read as code instead of one flat color. The language tag
  # on a fence (```ruby) is cosmetic; every fence is highlighted the
  # same way.
  module Highlight
    KEYWORDS = %w[
      def end class module function fn func return if elif elsif else
      unless while until for do begin rescue ensure raise throw try
      catch except finally break next continue yield case when switch
      match default import export from require include use pub package
      namespace let const var static final public private protected
      abstract new self this super nil null none true false async await
      int float double bool bool8 string char void byte long short
      struct enum interface extends implements typeof instanceof
      in of as with lambda del pass global nonlocal
    ].freeze

    # One token per iteration: a comment to end-of-line, a quoted
    # string (single/double/backtick, backslash-escaped), an integer
    # or float, an identifier/keyword, or a single other character
    # (whitespace, punctuation, operators).
    TOKEN = /
      (?<comment>\#.*\z|\/\/.*\z)
      |(?<string>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)
      |(?<number>\b\d+(?:\.\d+)?\b)
      |(?<word>[A-Za-z_][A-Za-z0-9_]*)
      |(?<other>.)
    /x

    # Splits one line of code into color-tagged spans. Adjacent tokens
    # that land on the same color are merged, so a run of plain text
    # becomes one span instead of one per character.
    def self.spans(line, palette)
      out = []
      line.scan(TOKEN) do
        m = Regexp.last_match
        text, color = classify(m, palette)
        if out.any? && out.last[:color] == color
          out.last[:text] += text
        else
          out << { text: text, color: color }
        end
      end
      out
    end

    def self.classify(m, palette)
      return [m[:comment], palette[:syn_comment]] if m[:comment]
      return [m[:string], palette[:syn_string]] if m[:string]
      return [m[:number], palette[:syn_number]] if m[:number]
      return [m[:word], KEYWORDS.include?(m[:word]) ? palette[:syn_keyword] : palette[:fg]] if m[:word]

      [m[:other], palette[:fg]]
    end
  end
end
