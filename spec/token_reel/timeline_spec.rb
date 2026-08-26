# frozen_string_literal: true

require "spec_helper"

RSpec.describe TokenReel::Timeline do
  let(:config) do
    c = TokenReel::Config.new
    c.prompt = "hi there"
    c.response = "one two three"
    c.tps = 2.0        # 0.5s per token
    c.ttft = 1.0
    c.prompt_tps = 0   # instant prompt
    c.hold = 0.5
    c
  end

  subject(:timeline) { described_class.new(config) }

  it "shows the full prompt immediately when prompt_tps is 0" do
    state = timeline.state_at(0.0)
    expect(state.prompt_text).to eq("hi there")
    expect(timeline.prompt_done_t).to eq(0)
  end

  it "sits in the thinking phase for ttft seconds after the prompt is shown" do
    state = timeline.state_at(0.5)
    expect(state.phase).to eq(:thinking)
    expect(state.response_text).to eq("")
  end

  it "starts streaming only after prompt_done + ttft" do
    just_before = timeline.state_at(timeline.thinking_end_t - 0.01)
    just_after = timeline.state_at(timeline.thinking_end_t + 0.01)

    expect(just_before.phase).to eq(:thinking)
    expect(just_after.phase).to eq(:streaming)
    expect(just_after.response_text).to eq("")
  end

  it "reveals response tokens one at a time at the configured tps" do
    t = timeline.thinking_end_t + 0.5 + 0.01 # just after the 1st token's interval
    state = timeline.state_at(t)
    expect(state.response_text).to eq("one ")
  end

  it "reaches :done once every response token has streamed" do
    state = timeline.state_at(timeline.stream_end_t)
    expect(state.phase).to eq(:done)
    expect(state.response_text).to eq(timeline.response_full)
  end

  it "holds the final state for `hold` seconds before duration ends" do
    expect(timeline.duration).to eq(timeline.stream_end_t + config.hold)
  end

  it "never returns a state past the fully-revealed response" do
    state = timeline.state_at(timeline.duration + 100)
    expect(state.response_text).to eq(timeline.response_full)
  end

  context "with no reasoning text configured" do
    it "goes straight from thinking to streaming, matching the pre-reasoning timeline" do
      expect(timeline.reasoning_end_t).to eq(timeline.thinking_end_t)
    end
  end

  context "with reasoning text configured" do
    let(:config) do
      c = TokenReel::Config.new
      c.prompt = "hi there"
      c.reasoning = "hmm well"
      c.response = "one two three"
      c.tps = 2.0
      c.ttft = 1.0
      c.reasoning_tps = 4.0 # 0.25s per token
      c.prompt_tps = 0
      c.hold = 0.5
      c
    end

    it "streams reasoning tokens between the thinking pause and the response" do
      state = timeline.state_at(timeline.thinking_end_t + 0.26) # just after the 1st token's 0.25s interval
      expect(state.phase).to eq(:reasoning)
      expect(state.reasoning_text).to eq("hmm ")
      expect(state.response_text).to eq("")
    end

    it "switches to streaming, with the reasoning text gone, once reasoning finishes" do
      state = timeline.state_at(timeline.reasoning_end_t + 0.01)
      expect(state.phase).to eq(:streaming)
      expect(state.reasoning_text).to eq("")
    end

    it "excludes the reasoning trace from the fully-revealed final_state" do
      expect(timeline.final_state.reasoning_text).to eq("")
      expect(timeline.final_state.response_text).to eq(timeline.response_full)
    end

    it "exposes the fully-revealed reasoning trace via max_reasoning_state, for canvas sizing" do
      expect(timeline.max_reasoning_state.reasoning_text).to eq(timeline.reasoning_full)
    end
  end
end
