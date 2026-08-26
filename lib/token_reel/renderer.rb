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
      @font = Fonts.resolve!(config.font)
      calibrate!
      # The window is a fixed config.rows lines tall, like a real
      # console -- every frame shares this height regardless of how
      # much text it holds.
      @total_lines = @config.rows
      @width = @config.cols * char_w + PAD_X * 2
      @height = HEADER_H + PAD_Y * 2 + total_lines * char_h
    end

    def render(state, out_path)
      lines = wrap_body(state)
      # Once a frame's content outgrows the window, scroll: keep only
      # the most recent total_lines lines, same as a real terminal
      # dropping its oldest lines off the top.
      lines = lines.last(total_lines) if lines.size > total_lines
      pad = [total_lines - lines.size, 0].max
      lines += [{ text: "", color: @palette[:fg] }] * pad

      argv = ["-size", "#{@width}x#{@height}", "xc:#{@palette[:bg]}"]
      argv += header_bar_args
      y = HEADER_H + PAD_Y + char_h - (char_h * 0.28).round
      lines.each do |line|
        argv += line_args(line, y)
        y += char_h
      end
      argv << out_path

      run!(argv)
      out_path
    end

    private

    # Measures the font's per-character advance width, not a single
    # glyph's ink width -- those differ (a glyph is typically narrower
    # than its cell) and only the advance width is what lines up
    # correctly when text is drawn as several separate -annotate calls,
    # as syntax-highlighted spans are. Comparing two label: widths of
    # different lengths and dividing by the difference in length
    # cancels out the fixed left/right bearing "label:" adds around the
    # text, isolating the true per-character advance.
    SHORT_CALIB_LEN = 10
    LONG_CALIB_LEN = 30

    def calibrate!
      Dir.mktmpdir do |dir|
        short = File.join(dir, "short.png")
        long = File.join(dir, "long.png")
        run!(["-background", "none", "-fill", "black", "-font", @font,
              "-pointsize", @config.font_size.to_s, "label:#{'0' * SHORT_CALIB_LEN}", short])
        run!(["-background", "none", "-fill", "black", "-font", @font,
              "-pointsize", @config.font_size.to_s, "label:#{'0' * LONG_CALIB_LEN}", long])
        w_short, h = `identify -format "%w %h" #{Shellwords.escape(short)}`.split.map(&:to_i)
        w_long, = `identify -format "%w %h" #{Shellwords.escape(long)}`.split.map(&:to_i)
        raise RenderError, "could not calibrate font metrics for #{@font.inspect}" if w_short.to_i <= 0 || w_long.to_i <= 0

        @char_w = ((w_long - w_short).to_f / (LONG_CALIB_LEN - SHORT_CALIB_LEN)).round
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
      args += ["-fill", @palette[:muted], "-font", @font, "-pointsize", (@config.font_size * 0.7).round.to_s,
               "-gravity", "North", "-annotate", "+0+#{(HEADER_H - @config.font_size * 0.7) / 2 - 2}", escape_annotate(@config.title),
               "-gravity", "NorthWest"]
      args
    end

    # A line is either a single-color {text:, color:} (prose) or a
    # multi-color {spans: [{text:, color:}, ...]} (a highlighted code
    # line). Spans are drawn as consecutive -annotate calls, each
    # offset by the fixed glyph width times the characters already
    # placed -- exact because the font is monospace.
    def line_args(line, y)
      if line[:spans]
        x = PAD_X
        line[:spans].flat_map do |span|
          args = annotate_args(span[:text], span[:color], x, y)
          x += char_w * span[:text].length
          args
        end
      else
        annotate_args(line[:text], line[:color], PAD_X, y)
      end
    end

    # ImageMagick's -annotate silently trims leading whitespace off the
    # text it's given -- a mixed span like " sum(" would draw as "sum("
    # flush against whatever x we asked for, one glyph closer than
    # intended, colliding with the previous span. Since we position
    # every span explicitly rather than relying on IM's own text flow,
    # the fix is to strip the whitespace ourselves and shift x by
    # however many characters we stripped, so IM never sees (and can't
    # silently eat) leading whitespace in what it draws. A whitespace-
    # only span -- e.g. a code line's leading indent, its own span
    # since it's a different color to what follows -- draws nothing at
    # all, correctly, since the canvas is already blank there.
    def annotate_args(text, color, x, y)
      leading = text[/\A\s*/].length
      visible = text.strip
      return [] if visible.empty?

      ["-fill", color, "-font", @font, "-pointsize", @config.font_size.to_s,
       "-annotate", "+#{x + char_w * leading}+#{y}", escape_annotate(visible)]
    end

    # ImageMagick's -annotate treats a literal backslash in the text as
    # the start of an escape (e.g. a bare "\n" becomes a real line
    # break), independent of our own word-wrap. Text like a shell
    # `"...\n..."` argument that never got interpreted as a real
    # newline would otherwise grow extra lines IM knows about but our
    # canvas-height math (based on real "\n" splits) doesn't -- pushing
    # later lines down until they overflow and overlap. Doubling
    # backslashes makes IM render them literally instead.
    def escape_annotate(text)
      text.gsub("\\") { "\\\\" }
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
      when :reasoning
        body << { text: "", color: @palette[:fg] }
        body << { text: @config.thinking_label, color: @palette[:muted] }
        body += code_aware_lines(state.reasoning_text, @config.cols - 2, @palette[:muted])
                  .map { |l| indent_line(l, "  ") }
        append_cursor!(body, state.cursor_on)
        return body
      else
        body << { text: "", color: @palette[:fg] }
        body += code_aware_lines(state.response_text, @config.cols, @palette[:fg])
        append_cursor!(body, state.cursor_on)
        return body
      end
    end

    def append_cursor!(body, cursor_on)
      return unless cursor_on

      last = body.last
      if last[:spans]
        last[:spans] << { text: @config.cursor_char, color: @palette[:fg] }
      else
        last[:text] = "#{last[:text]}#{@config.cursor_char}"
      end
    end

    def indent_line(line, prefix)
      if line[:spans]
        { spans: [{ text: prefix, color: @palette[:muted] }] + line[:spans] }
      else
        { text: "#{prefix}#{line[:text]}", color: line[:color] }
      end
    end

    def wrap_text(str, cols)
      str.split("\n", -1).flat_map { |para| wrap_paragraph(para, cols) }
    end

    FENCE = /\A\s{0,3}(?:```|~~~)/
    # A trailing line consisting of only 1-2 backticks/tildes could
    # still grow into a real fence marker on the next frame (relevant
    # with --unit char, where streaming can stop mid-marker). Since
    # only the very last line of a partially-revealed text can be
    # incomplete like this, it's held back for a frame rather than
    # guessed at -- guessing wrong either toggles code state a
    # character early or (worse) briefly counts an extra line that the
    # fully-revealed text, which sized the canvas, never has.
    PENDING_FENCE = /\A\s{0,3}(?:`{1,2}|~{1,2})\z/

    # Walks text line by line, toggling in/out of "code" on fence
    # markers (```/~~~). Fence marker lines themselves are dropped from
    # the output -- the fence is how the source marks the block, not
    # something meant to show up in a rendered chat transcript. Prose
    # lines word-wrap and render in a single color, same as before;
    # code lines are split into syntax-highlighted spans. Because this
    # runs on whatever prefix of the text has streamed in so far, an
    # unterminated trailing fence is simply treated as "still in code".
    def code_aware_lines(text, cols, prose_color)
      in_code = false
      out = []
      raw_lines = text.split("\n", -1)
      raw_lines.pop if PENDING_FENCE.match?(raw_lines.last.to_s)

      raw_lines.each do |raw|
        if raw =~ FENCE
          in_code = !in_code
          next
        end

        out.concat(in_code ? wrap_code_line(raw, cols) : wrap_paragraph(raw, cols).map { |l| { text: l, color: prose_color } })
      end

      out << { text: "", color: prose_color } if out.empty?
      out
    end

    def wrap_code_line(raw, cols)
      chunks = raw.empty? ? [""] : raw.chars.each_slice([cols, 1].max).map(&:join)
      chunks.map { |chunk| { spans: Highlight.spans(chunk, @palette) } }
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
