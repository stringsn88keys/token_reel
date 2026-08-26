# frozen_string_literal: true

require "spec_helper"

RSpec.describe TokenReel::Fonts do
  have_imagemagick = %w[magick convert].any? { |bin| system("which #{bin} > /dev/null 2>&1") }

  before do
    skip "ImageMagick not installed" unless have_imagemagick
  end

  it "auto-detects a font that ImageMagick actually has available" do
    expect(described_class.available).to include(described_class.autodetect)
  end

  it "resolves an explicit font name to itself when ImageMagick knows it" do
    name = described_class.available.find { |f| !f.start_with?(".") }
    skip "no non-hidden font available to test against" unless name

    expect(described_class.resolve!(name)).to eq(name)
  end

  it "resolves nil to the auto-detected font" do
    expect(described_class.resolve!(nil)).to eq(described_class.autodetect)
  end

  it "raises a clear error for a font ImageMagick doesn't know about" do
    expect { described_class.resolve!("Definitely-Not-A-Real-Font-XYZ") }
      .to raise_error(TokenReel::RenderError, /Definitely-Not-A-Real-Font-XYZ/)
  end
end
