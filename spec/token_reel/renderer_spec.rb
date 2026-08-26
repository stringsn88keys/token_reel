# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"

RSpec.describe TokenReel::Renderer do
  have_imagemagick = %w[magick convert].any? { |bin| system("which #{bin} > /dev/null 2>&1") }

  before do
    skip "ImageMagick not installed" unless have_imagemagick
  end

  # Syntax-highlighted code is drawn as several same-line -annotate
  # calls (one per color span) instead of one call for the whole line,
  # so it depends on char_w being the font's true per-character advance
  # width -- get that wrong and spans drift apart, character by
  # character, the further they are into the line. This regression
  # test renders a code line the real way (multiple spans) and the
  # naive way (one plain string) and requires the two images to match
  # almost exactly.
  it "positions syntax-highlighted spans exactly where a single plain string would land" do
    config = TokenReel::Config.new
    config.prompt = "x"
    config.response = "```ruby\ndef sum(n, acc = 0)\n  return acc if n.zero?\nend\n```"
    config.tps = 1000
    config.ttft = 0

    timeline = TokenReel::Timeline.new(config)
    renderer = described_class.new(config, timeline)
    font = renderer.instance_variable_get(:@font)
    palette = TokenReel::Theme.fetch(:dark)

    Dir.mktmpdir do |dir|
      spanned_path = File.join(dir, "spanned.png")
      renderer.render(timeline.final_state, spanned_path)

      out, = Open3.capture3("identify", "-format", "%w %h", spanned_path)
      width, height = out.split.map(&:to_i)

      y = described_class::HEADER_H + described_class::PAD_Y + renderer.char_h -
          (renderer.char_h * 0.28).round + (renderer.char_h * 2) # + the prompt line and the blank separator, same as a real render
      argv = ["-size", "#{width}x#{height}", "xc:#{palette[:bg]}"]
      ["def sum(n, acc = 0)", "  return acc if n.zero?", "end"].each do |line|
        # -annotate trims leading whitespace off whatever text it's
        # given (the same behavior Renderer#annotate_args works around),
        # so this baseline has to strip it and shift x itself too, or
        # an indented line would land 2 characters further left than
        # Renderer actually draws it.
        indent = line[/\A */].length
        argv += ["-fill", palette[:fg], "-font", font, "-pointsize", config.font_size.to_s,
                 "-gravity", "NorthWest", "-annotate", "+#{described_class::PAD_X + renderer.char_w * indent}+#{y}", line.lstrip]
        y += renderer.char_h
      end
      plain_path = File.join(dir, "plain.png")
      Open3.capture3(described_class.convert_binary, *argv, plain_path)

      diff, = Open3.capture3(described_class.convert_binary, spanned_path, plain_path,
                              "-compose", "difference", "-composite", "-colorspace", "gray",
                              "-format", "%[fx:mean*65535]", "info:")
      # Compositing several draw calls instead of one leaves a little
      # antialiasing noise at glyph edges even when positions are exact
      # (observed: ~300 on this scale). A one-character positioning
      # drift -- the bug this test guards against -- measures in the
      # thousands, so this threshold has a wide, non-flaky margin on
      # both sides.
      expect(diff.to_f).to be < 800
    end
  end

  it "sizes the canvas to config.rows, not to how much content there is" do
    short = TokenReel::Config.new
    short.prompt = "x"
    short.response = "one short line"
    short.tps = 1000
    short.ttft = 0

    tall = TokenReel::Config.new
    tall.prompt = "x"
    tall.response = Array.new(40) { |i| "line #{i}" }.join("\n")
    tall.tps = 1000
    tall.ttft = 0

    [short, tall].each do |config|
      timeline = TokenReel::Timeline.new(config)
      renderer = described_class.new(config, timeline)

      expect(renderer.total_lines).to eq(config.rows)
      expect(renderer.instance_variable_get(:@height))
        .to eq(described_class::HEADER_H + described_class::PAD_Y * 2 + config.rows * renderer.char_h)

      Dir.mktmpdir do |dir|
        path = File.join(dir, "frame.png")
        renderer.render(timeline.final_state, path)
        out, = Open3.capture3("identify", "-format", "%h", path)
        expect(out.to_i).to eq(renderer.instance_variable_get(:@height))
      end
    end
  end

  it "scrolls once a frame's content outgrows the console, instead of overflowing it" do
    config = TokenReel::Config.new
    config.prompt = "x"
    config.rows = 6
    config.response = Array.new(20) { |i| "line #{i}" }.join("\n")
    config.tps = 1000
    config.ttft = 0

    timeline = TokenReel::Timeline.new(config)
    renderer = described_class.new(config, timeline)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "frame.png")
      renderer.render(timeline.final_state, path)
      out, = Open3.capture3("identify", "-format", "%h", path)
      expect(out.to_i).to eq(described_class::HEADER_H + described_class::PAD_Y * 2 + config.rows * renderer.char_h)
    end
  end
end
