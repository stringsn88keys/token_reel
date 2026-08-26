# frozen_string_literal: true

module TokenReel
  # A snapshot of the screen at a given moment: how much of the prompt,
  # reasoning, and response are visible, which "phase" we're in, and
  # whether the cursor happens to be in its "on" blink state.
  State = Struct.new(:phase, :prompt_text, :reasoning_text, :response_text, :cursor_on, :dot_count, keyword_init: true) do
    # Identical signatures render to the identical frame, so the
    # sampler can skip re-rendering and just extend the previous
    # frame's delay instead.
    def signature
      [phase, prompt_text, reasoning_text, response_text, cursor_on, dot_count]
    end
  end

  # Pure function of time -> State. Doesn't touch the filesystem or
  # ImageMagick at all, which makes it cheap to sample as densely as
  # we like when building the frame list.
  class Timeline
    BLINK_HZ = 2.0     # cursor toggles this many times per second
    DOT_INTERVAL = 0.35 # seconds between "thinking..." dot ticks

    attr_reader :prompt_tokens, :reasoning_tokens, :response_tokens,
                :prompt_full, :reasoning_full, :response_full,
                :prompt_done_t, :thinking_end_t, :reasoning_end_t, :stream_end_t, :duration

    def initialize(config)
      @config = config
      @prompt_tokens = Tokenizer.tokenize(config.prompt, config.unit)
      @reasoning_tokens = Tokenizer.tokenize(config.reasoning, config.unit)
      @response_tokens = Tokenizer.tokenize(config.response, config.unit)
      @prompt_full = prompt_tokens.join
      @reasoning_full = reasoning_tokens.join
      @response_full = response_tokens.join

      @prompt_interval = config.prompt_tps.to_f.positive? ? 1.0 / config.prompt_tps : 0
      @reasoning_interval = config.reasoning_tps.to_f.positive? ? 1.0 / config.reasoning_tps : 1.0 / config.tps
      @response_interval = 1.0 / config.tps

      @prompt_done_t = @prompt_interval * prompt_tokens.size
      @thinking_end_t = prompt_done_t + config.ttft.to_f
      @reasoning_end_t = thinking_end_t + @reasoning_interval * reasoning_tokens.size
      @stream_end_t = reasoning_end_t + @response_interval * response_tokens.size
      @duration = stream_end_t + config.hold.to_f
    end

    def state_at(t)
      t = t.clamp(0, duration)

      if t < prompt_done_t
        n = @prompt_interval.positive? ? (t / @prompt_interval).floor : prompt_tokens.size
        State.new(
          phase: :typing_prompt,
          prompt_text: prompt_tokens[0...n].join,
          reasoning_text: "",
          response_text: "",
          cursor_on: blink_on?(t),
          dot_count: 0
        )
      elsif t < thinking_end_t
        elapsed = t - prompt_done_t
        State.new(
          phase: :thinking,
          prompt_text: prompt_full,
          reasoning_text: "",
          response_text: "",
          cursor_on: blink_on?(t),
          dot_count: ((elapsed / DOT_INTERVAL).to_i % 4)
        )
      elsif t < reasoning_end_t
        elapsed = t - thinking_end_t
        n = @reasoning_interval.positive? ? (elapsed / @reasoning_interval).floor : reasoning_tokens.size
        n = n.clamp(0, reasoning_tokens.size)
        State.new(
          phase: :reasoning,
          prompt_text: prompt_full,
          reasoning_text: reasoning_tokens[0...n].join,
          response_text: "",
          cursor_on: blink_on?(t),
          dot_count: 0
        )
      else
        elapsed = t - reasoning_end_t
        n = @response_interval.positive? ? (elapsed / @response_interval).floor : response_tokens.size
        n = n.clamp(0, response_tokens.size)
        done = n >= response_tokens.size
        State.new(
          phase: done ? :done : :streaming,
          prompt_text: prompt_full,
          reasoning_text: "",
          response_text: response_tokens[0...n].join,
          cursor_on: blink_on?(t),
          dot_count: 0
        )
      end
    end

    # The fully-revealed, cursor-off state -- used to size the canvas
    # so every frame in the GIF shares identical dimensions.
    def final_state
      State.new(phase: :done, prompt_text: prompt_full, reasoning_text: "", response_text: response_full,
                 cursor_on: false, dot_count: 0)
    end

    # The reasoning phase in full, cursor off -- used alongside
    # final_state to size the canvas, since the reasoning trace (shown
    # only while streaming, then replaced by the response) can be
    # taller than the finished response.
    def max_reasoning_state
      State.new(phase: :reasoning, prompt_text: prompt_full, reasoning_text: reasoning_full, response_text: "",
                 cursor_on: false, dot_count: 0)
    end

    private

    def blink_on?(t)
      (t * (2 * BLINK_HZ)).to_i.even?
    end
  end
end
