# frozen_string_literal: true

module TokenReel
  # Picks and validates the monospace font ImageMagick renders text
  # with. This matters more than it sounds: the whole layout (column
  # wrapping, cursor placement, and the per-span x-offsets syntax
  # highlighting draws at) assumes every glyph is the same width, which
  # is only true if the font actually resolves to a real monospace
  # font. ImageMagick silently falls back to *some* default font (and
  # only warns on stderr, without failing) when asked for a font name
  # it doesn't know -- so guessing a hardcoded name and trusting it
  # works is how you end up with misaligned, overlapping text.
  module Fonts
    # Common monospace font names, in priority order, as ImageMagick
    # tends to expose them across Linux/macOS/Windows installs.
    CANDIDATES = %w[
      DejaVu-Sans-Mono Menlo-Regular Consolas Liberation-Mono
      Courier-New Monaco Andale-Mono PT-Mono Noto-Sans-Mono
      Ubuntu-Mono Cascadia-Mono JetBrains-Mono JetBrainsMono-Regular
      Fira-Code FiraCode-Regular Hack-Regular Courier fixed
    ].freeze

    def self.available
      @available ||= `#{Shellwords.escape(Renderer.convert_binary)} -list font 2>/dev/null`
                     .scan(/^\s*Font:\s*(\S+)/).flatten
    end

    # name == nil means "pick one for me". A name the caller passed in
    # explicitly is validated against what ImageMagick actually knows,
    # rather than trusted -- see the module comment for why.
    def self.resolve!(name)
      return autodetect if name.nil?
      return name if available.include?(name)

      raise RenderError,
            "font #{name.inspect} not found via `#{Renderer.convert_binary} -list font` " \
            "(pass --font with an exact name from that list, or omit --font to auto-detect)"
    end

    def self.autodetect
      CANDIDATES.find { |name| available.include?(name) } ||
        raise(RenderError,
              "no monospace font found on this system; install one of " \
              "#{CANDIDATES.first(4).join(', ')}, etc., or pass --font NAME " \
              "with an exact name from `#{Renderer.convert_binary} -list font`")
    end
  end
end
