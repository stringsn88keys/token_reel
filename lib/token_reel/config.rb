# frozen_string_literal: true

module TokenReel
  # All the knobs that control a render. Build one directly, or via
  # TokenReel::CLI.parse(ARGV).
  class Config
    attr_accessor :prompt, :response, :reasoning,
                  :tps, :ttft, :prompt_tps, :reasoning_tps, :unit,
                  :cols, :rows, :font, :font_size, :fps,
                  :theme, :hold, :loop_count,
                  :label, :thinking_label, :title, :cursor_char,
                  :out, :keep_frames

    def initialize
      @prompt         = ""
      @response       = ""
      @reasoning      = ""      # optional; shown streaming during the "thinking" pause, then replaced by the response
      @tps            = 8.0     # response tokens revealed per second
      @ttft           = 0.6     # seconds of "thinking" before first token
      @prompt_tps     = 0       # 0 = prompt appears instantly, fully typed
      @reasoning_tps  = 0       # 0 = same rate as tps
      @unit           = :word   # :word or :char
      @cols           = 80      # console width, in characters (classic terminal default: 80x25)
      @rows           = 25      # console height, in lines -- once content grows past this, the
                                 # window scrolls (oldest lines drop off the top), like a real terminal
      @font           = nil     # nil = auto-detect an available monospace font, see Fonts
      @font_size      = 20
      @fps            = 12
      @theme          = :dark
      @hold           = 1.5     # seconds to hold the final frame
      @loop_count     = 0       # 0 = loop forever
      @label          = "\u276F " # "❯ "
      @thinking_label = "thinking"
      @title          = "assistant"
      @cursor_char    = "\u258A" # "▊"
      @out            = "token_reel.gif"
      @keep_frames    = false
    end

    def validate!
      raise ConfigError, "prompt can't be blank" if prompt.to_s.empty?
      raise ConfigError, "response can't be blank" if response.to_s.empty?
      raise ConfigError, "tps must be > 0" unless tps.to_f.positive?
      raise ConfigError, "ttft can't be negative" if ttft.to_f.negative?
      raise ConfigError, "prompt_tps can't be negative" if prompt_tps.to_f.negative?
      raise ConfigError, "reasoning_tps can't be negative" if reasoning_tps.to_f.negative?
      raise ConfigError, "cols must be >= 20" if cols.to_i < 20
      raise ConfigError, "rows must be >= 3" if rows.to_i < 3
      raise ConfigError, "fps must be between 1 and 50" unless (1..50).cover?(fps.to_i)
      raise ConfigError, "font_size must be >= 8" if font_size.to_i < 8
      raise ConfigError, "hold can't be negative" if hold.to_f.negative?

      self
    end
  end
end
