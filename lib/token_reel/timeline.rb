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

    # When config.variability is on, each token's delay is independently
    # jittered by a normally-distributed offset, bounded to +/- one of
    # these percentages (picked at random per token) of its base interval.
    JITTER_PCTS = [0.10, 0.20, 0.30].freeze

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

      @rng = config.variability ? Random.new(config.seed || Random.new_seed) : nil

      # Cumulative reveal times per token: offsets[n] is the moment the
      # n-th token has fully appeared. With variability off this is just
      # n * interval; with it on, each step is independently jittered,
      # so the array can't be derived by a plain multiply anymore.
      @prompt_offsets = cumulative_offsets(prompt_tokens.size, @prompt_interval)
      @reasoning_offsets = cumulative_offsets(reasoning_tokens.size, @reasoning_interval)
      @response_offsets = cumulative_offsets(response_tokens.size, @response_interval)

      @prompt_done_t = @prompt_offsets.last
      @thinking_end_t = prompt_done_t + config.ttft.to_f
      @reasoning_end_t = thinking_end_t + @reasoning_offsets.last
      @stream_end_t = reasoning_end_t + @response_offsets.last
      @duration = stream_end_t + config.hold.to_f
    end

    def state_at(t)
      t = t.clamp(0, duration)

      if t < prompt_done_t
        n = @prompt_interval.positive? ? tokens_shown(@prompt_offsets, t) : prompt_tokens.size
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
        n = @reasoning_interval.positive? ? tokens_shown(@reasoning_offsets, elapsed) : reasoning_tokens.size
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
        n = @response_interval.positive? ? tokens_shown(@response_offsets, elapsed) : response_tokens.size
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

    # Builds the cumulative reveal-time array for `count` tokens spaced
    # `interval` seconds apart: offsets[0] == 0, offsets[count] == the
    # total time to reveal them all. With no RNG (variability off) each
    # step is exactly `interval`, matching the un-jittered timeline
    # exactly; with one, each step is independently perturbed.
    def cumulative_offsets(count, interval)
      offsets = [0.0]
      count.times { offsets << offsets.last + jittered_delay(interval) }
      offsets
    end

    def jittered_delay(interval)
      return interval unless @rng

      pct = JITTER_PCTS.sample(random: @rng)
      z = normal_sample.clamp(-1.0, 1.0) # keep the (rare) normal-curve tail within the chosen bound
      [interval * (1.0 + z * pct), 0.0].max
    end

    # Standard normal sample (mean 0, stddev 1) via the Box-Muller transform.
    def normal_sample
      u1 = 1.0 - @rng.rand # (0, 1], avoids log(0)
      u2 = @rng.rand
      Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2 * Math::PI * u2)
    end

    # Number of tokens fully revealed by `elapsed`, given their
    # cumulative reveal-time array (size == token count + 1).
    def tokens_shown(offsets, elapsed)
      idx = offsets.bsearch_index { |offset| offset > elapsed }
      idx.nil? ? offsets.size - 1 : idx - 1
    end

    def blink_on?(t)
      (t * (2 * BLINK_HZ)).to_i.even?
    end
  end
end
