# frozen_string_literal: true

module TokenReel
  # Parses a single Markdown file into the named sections a render
  # needs -- prompt, reasoning, and response -- so a whole exchange can
  # be written and version-controlled as one file instead of juggling
  # separate --prompt/--response flags.
  #
  # Recognized headings (any level, case-insensitive; content before
  # the first recognized heading is ignored):
  #
  #   # Prompt | User | Input | Question
  #   # Reasoning | Thinking | Thought
  #   # Output | Response | Answer | Assistant
  #
  # A heading is only recognized outside of a fenced code block, so a
  # shell/Python comment like "# Output" inside a ```fence``` never
  # gets mistaken for a section header. Fence markers themselves are
  # kept in the extracted section text -- Renderer is what looks for
  # them, so this works the same whether the text came from a Markdown
  # file or a plain --response string.
  #
  # `.template` returns a starter file with all three headings already
  # in place, for `token_reel --init-markdown` to write out.
  module Script
    SECTION_ALIASES = {
      "prompt" => :prompt, "user" => :prompt, "input" => :prompt, "question" => :prompt,
      "reasoning" => :reasoning, "thinking" => :reasoning, "thought" => :reasoning,
      "output" => :response, "response" => :response, "answer" => :response, "assistant" => :response
    }.freeze

    HEADING = /\A\s{0,3}\#{1,6}\s+(.+?)\s*\z/
    FENCE = /\A\s{0,3}(?:```|~~~)/

    TEMPLATE = <<~MD
      ## Prompt

      Replace this with the prompt text (shown as typed input).

      ## Reasoning

      Optional -- delete this whole section if you don't want a "thinking"
      trace. Replace this with the reasoning text; it streams first, then
      is replaced by the response.

      ## Output

      Replace this with the response text (streamed as output). Code
      fences work here too and are syntax-highlighted:

      ```ruby
      def hello
        puts "hi"
      end
      ```
    MD

    # A starter Markdown file with the three recognized headings
    # already in place, ready to fill in and pass to `-m`/`--markdown`.
    def self.template
      TEMPLATE
    end

    # Returns { prompt: "...", reasoning: "...", response: "..." },
    # omitting keys whose section was absent from the file.
    def self.parse(text)
      sections = Hash.new { |h, k| h[k] = +"" }
      current = nil
      in_fence = false

      text.each_line do |line|
        stripped = line.chomp
        in_fence = !in_fence if stripped =~ FENCE

        if !in_fence && (m = HEADING.match(stripped)) && (key = SECTION_ALIASES[m[1].downcase])
          current = key
          next
        end

        sections[current] << line if current
      end

      sections.transform_values(&:strip)
    end
  end
end
