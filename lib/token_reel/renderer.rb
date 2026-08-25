# frozen_string_literal: true

require "open3"

module TokenReel
  # Turns a Timeline::State into a terminal-window PNG. Text layout is
  # done in Ruby (word wrap, cursor placement); ImageMagick just draws
  # the rectangles and glyphs we tell it to.
  class Renderer
    HEADER_H = 40
    PAD_X = 18
    PAD_Y = 14
    DOT_R = 6

    attr_reader :char_w, :char_h, :total_lines

    def self.convert_binary
      @convert_binary ||= %w[magick convert].find { |bin| system("which #{bin} > /dev/null 2>&1") } ||
                           raise(RenderError, "ImageMagick not found: install `imagemagick` (needs `convert` or `magick` on PATH)")
    end

    def initialize(config, timeline)
      @config = config
      @timeline = timeline
      @palette = Theme.fetch(config.theme)
      calibrate!
      @total_lines = wrap_body(timeline.final_state).size
      @width = @config.cols * char_w + PAD_X * 2
      @height = HEADER_H + PAD_Y * 2 + total_lines * char_h
    end

    def render(state, out_path)
      lines = wrap_body(state)
      lines += [{ text: "", color: @palette[:fg] }] * (total_lines - lines.size)

      argv = ["-size", "#{@width}x#{@height}", "xc:#{@palette[:bg]}"]
      argv += header_bar_args
      y = HEADER_H + PAD_Y + char_h - (char_h * 0.28).round
      lines.each do |line|
        argv += annotate_args(line[:text], line[:color], PAD_X, y) unless line[:text].empty?
        y += char_h
      end
      argv << out_path

      run!(argv)
      out_path
    end

    private

    def calibrate!
      Dir.mktmpdir do |dir|
        path = File.join(dir, "calib.png")
        run!(["-background", "none", "-fill", "black", "-font", @config.font,
              "-pointsize", @config.font_size.to_s, "label:0", path])
        w, h = `identify -format "%w %h" #{Shellwords.escape(path)}`.split.map(&:to_i)
        raise RenderError, "could not calibrate font metrics for #{@config.font.inspect}" if w.to_i <= 0

        @char_w = w
        @char_h = (h * 1.35).round
      end
    end

    def header_bar_args
      args = ["-fill", @palette[:header], "-draw", "rectangle 0,0 #{@width},#{HEADER_H}"]
      cx = PAD_X
      cy = HEADER_H / 2
      [@palette[:dot_red], @palette[:dot_yellow], @palette[:dot_green]].each do |color|
        args += ["-fill", color, "-draw", "circle #{cx},#{cy} #{cx + DOT_R},#{cy}"]
        cx += DOT_R * 3
      end
      args += ["-fill", @palette[:muted], "-font", @config.font, "-pointsize", (@config.font_size * 0.7).round.to_s,
               "-gravity", "North", "-annotate", "+0+#{(HEADER_H - @config.font_size * 0.7) / 2 - 2}", @config.title,
               "-gravity", "NorthWest"]
      args
    end

    def annotate_args(text, color, x, y)
      ["-fill", color, "-font", @config.font, "-pointsize", @config.font_size.to_s,
       "-annotate", "+#{x}+#{y}", text]
    end

    # Builds the wrapped, cursor-annotated lines for a state, without
    # the trailing pad-to-total_lines step (callers that need a fixed
    # canvas height add that themselves).
    def wrap_body(state)
      body = wrap_text("#{@config.label}#{state.prompt_text}", @config.cols)
                .map { |l| { text: l, color: @palette[:prompt] } }

      case state.phase
      when :typing_prompt
        append_cursor!(body, state.cursor_on)
        return body
      when :thinking
        body << { text: "", color: @palette[:fg] }
        dots = "." * state.dot_count
        body << { text: "#{@config.thinking_label}#{dots}", color: @palette[:muted] }
        append_cursor!(body, state.cursor_on)
        return body
      else
        body << { text: "", color: @palette[:fg] }
        resp_lines = wrap_text(state.response_text, @config.cols)
        resp_lines = [""] if resp_lines.empty?
        body += resp_lines.map { |l| { text: l, color: @palette[:fg] } }
        append_cursor!(body, state.cursor_on)
        return body
      end
    end

    def append_cursor!(body, cursor_on)
      return unless cursor_on

      last = body.last
      last[:text] = "#{last[:text]}#{@config.cursor_char}"
    end

    def wrap_text(str, cols)
      str.split("\n", -1).flat_map { |para| wrap_paragraph(para, cols) }
    end

    def wrap_paragraph(line, cols)
      return [""] if line.empty?

      words = line.scan(/\S+\s*|\s+/)
      lines = []
      current = +""
      words.each do |w|
        if !current.empty? && (current.length + w.length) > cols
          lines << current.rstrip
          current = w.lstrip
        else
          current << w
        end
      end
      lines << current.rstrip unless current.empty?
      lines
    end

    def run!(argv)
      _out, err, status = Open3.capture3(self.class.convert_binary, *argv)
      raise RenderError, "ImageMagick failed: #{err}" unless status.success?
    end
  end
end
