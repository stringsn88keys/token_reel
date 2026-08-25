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
end
