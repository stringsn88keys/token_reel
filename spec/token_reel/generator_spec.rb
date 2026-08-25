# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe TokenReel::Generator do
  have_imagemagick = %w[magick convert].any? { |bin| system("which #{bin} > /dev/null 2>&1") }

  before do
    skip "ImageMagick not installed" unless have_imagemagick
  end

  it "renders a real, playable animated GIF" do
    Dir.mktmpdir do |dir|
      out = File.join(dir, "demo.gif")
      config = TokenReel::Config.new
      config.prompt = "why is the sky blue?"
      config.response = "rayleigh scattering of sunlight in the atmosphere"
      config.tps = 20
      config.ttft = 0.2
      config.fps = 10
      config.hold = 0.2
      config.out = out

      result_path = described_class.new(config).generate!

      expect(result_path).to eq(out)
      expect(File).to exist(out)
      expect(File.size(out)).to be > 0

      frame_count = `identify #{out} 2>/dev/null | wc -l`.to_i
      expect(frame_count).to be > 1 # actually animated, not a single static frame
    end
  end
end
