# frozen_string_literal: true

require "spec_helper"

RSpec.describe TokenReel::Config do
  subject(:config) do
    c = described_class.new
    c.prompt = "hi"
    c.response = "hello"
    c
  end

  it "is valid with sane defaults plus a prompt and response" do
    expect { config.validate! }.not_to raise_error
  end

  it "rejects a blank prompt" do
    config.prompt = ""
    expect { config.validate! }.to raise_error(TokenReel::ConfigError, /prompt/)
  end

  it "rejects a non-positive tps" do
    config.tps = 0
    expect { config.validate! }.to raise_error(TokenReel::ConfigError, /tps/)
  end

  it "rejects a negative ttft" do
    config.ttft = -1
    expect { config.validate! }.to raise_error(TokenReel::ConfigError, /ttft/)
  end

  it "rejects too-narrow columns" do
    config.cols = 5
    expect { config.validate! }.to raise_error(TokenReel::ConfigError, /cols/)
  end
end
