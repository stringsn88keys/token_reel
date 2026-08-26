# frozen_string_literal: true

require "optparse"

module TokenReel
  module CLI
    # Parses ARGV into a Config. Returns nil if the parser already
    # handled the request itself (e.g. --help, --version).
    def self.parse(argv)
      config = Config.new
      prompt_file = nil
      response_file = nil
      reasoning_file = nil
      markdown_file = nil
      stdin_mode = false

      parser = OptionParser.new do |o|
        o.banner = "Usage: token_reel [options]\n\n" \
                    "Renders a terminal-style GIF of a prompt being answered, streamed\n" \
                    "token-by-token at a chosen speed with a simulated time-to-first-token.\n\n"

        o.on("-p", "--prompt TEXT", "Prompt text (shown as typed input)") { |v| config.prompt = v }
        o.on("-P", "--prompt-file PATH", "Read the prompt from a file") { |v| prompt_file = v }
        o.on("-r", "--response TEXT", "Response text (streamed as output)") { |v| config.response = v }
        o.on("-R", "--response-file PATH", "Read the response from a file") { |v| response_file = v }
        o.on("--reasoning TEXT", "Reasoning/thinking text, streamed then replaced by the response") { |v| config.reasoning = v }
        o.on("--reasoning-file PATH", "Read the reasoning text from a file") { |v| reasoning_file = v }
        o.on("-m", "--markdown PATH", "Read prompt/reasoning/response from one Markdown file " \
                                       "(## Prompt / ## Reasoning / ## Output headings; overrides -p/-P/-r/-R/--reasoning[-file])") { |v| markdown_file = v }
        o.on("--init-markdown [PATH]", "Write a starter Markdown template for -m/--markdown, then exit " \
                                        "(default path: exchange.md)") do |v|
          path = v || "exchange.md"
          if File.exist?(path)
            warn "token_reel: #{path} already exists, not overwriting"
            exit(1)
          end
          File.write(path, Script.template)
          puts "Wrote #{path}"
          exit(0)
        end
        o.on("--stdin", "Read prompt and response from STDIN, separated by a line of '---'") { stdin_mode = true }

        o.separator ""
        o.separator "Timing:"
        o.on("--tps N", Float, "Response tokens revealed per second (default: #{config.tps})") { |v| config.tps = v }
        o.on("--ttft N", Float, "Time to first token, in seconds (default: #{config.ttft})") { |v| config.ttft = v }
        o.on("--prompt-tps N", Float, "Prompt typing speed in tokens/sec, 0 = instant (default: #{config.prompt_tps})") { |v| config.prompt_tps = v }
        o.on("--reasoning-tps N", Float, "Reasoning typing speed in tokens/sec, 0 = same as --tps (default: #{config.reasoning_tps})") { |v| config.reasoning_tps = v }
        o.on("--unit UNIT", %w[word char], "Streaming unit: word or char (default: #{config.unit})") { |v| config.unit = v.to_sym }
        o.on("--hold N", Float, "Seconds to hold the final frame (default: #{config.hold})") { |v| config.hold = v }
        o.on("--fps N", Integer, "GIF frame rate (default: #{config.fps})") { |v| config.fps = v }
        o.on("--loop N", Integer, "GIF loop count, 0 = forever (default: #{config.loop_count})") { |v| config.loop_count = v }

        o.separator ""
        o.separator "Look:"
        o.on("--theme THEME", %w[dark matrix light solarized], "Color theme (default: #{config.theme})") { |v| config.theme = v.to_sym }
        o.on("--cols N", Integer, "Terminal width in characters (default: #{config.cols})") { |v| config.cols = v }
        o.on("--font-size N", Integer, "Font point size (default: #{config.font_size})") { |v| config.font_size = v }
        o.on("--font NAME", "ImageMagick font name (default: auto-detect a monospace font)") { |v| config.font = v }
        o.on("--label STRING", "Prompt prefix (default: #{config.label.inspect})") { |v| config.label = v }
        o.on("--title STRING", "Window title bar text (default: #{config.title.inspect})") { |v| config.title = v }
        o.on("--cursor CHAR", "Cursor glyph (default: #{config.cursor_char.inspect})") { |v| config.cursor_char = v }

        o.separator ""
        o.separator "Output:"
        o.on("-o", "--out PATH", "Output GIF path (default: #{config.out})") { |v| config.out = v }
        o.on("--keep-frames", "Keep the intermediate PNG frames on disk") { config.keep_frames = true }

        o.separator ""
        o.on("-v", "--version", "Print the version and exit") do
          puts TokenReel::VERSION
          exit(0)
        end
        o.on("-h", "--help", "Print this help and exit") do
          puts o
          exit(0)
        end
      end

      parser.parse!(argv)

      config.prompt = File.read(prompt_file) if prompt_file
      config.response = File.read(response_file) if response_file
      config.reasoning = File.read(reasoning_file) if reasoning_file

      if markdown_file
        sections = Script.parse(File.read(markdown_file))
        config.prompt = sections[:prompt] if sections.key?(:prompt)
        config.reasoning = sections[:reasoning] if sections.key?(:reasoning)
        config.response = sections[:response] if sections.key?(:response)
      end

      if stdin_mode
        prompt, response = $stdin.read.split(/^---\s*$/, 2)
        config.prompt = prompt.to_s.strip
        config.response = response.to_s.strip
      end

      config
    rescue OptionParser::InvalidOption, OptionParser::InvalidArgument, OptionParser::MissingArgument => e
      warn "token_reel: #{e.message}"
      warn parser
      exit(1)
    end

    def self.run(argv)
      config = parse(argv)
      path = Generator.new(config).generate!
      puts "Wrote #{path}"
      0
    rescue Error => e
      warn "token_reel: #{e.message}"
      1
    end
  end
end
