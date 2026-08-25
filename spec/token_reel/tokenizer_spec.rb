# frozen_string_literal: true

require "spec_helper"

RSpec.describe TokenReel::Tokenizer do
  it "splits on words, keeping trailing whitespace with each word" do
    tokens = described_class.tokenize("hello  world\nfoo", :word)
    expect(tokens.join).to eq("hello  world\nfoo")
    expect(tokens).to eq(["hello  ", "world\n", "foo"])
  end

  it "splits into individual characters" do
    tokens = described_class.tokenize("hi!", :char)
    expect(tokens).to eq(%w[h i !])
    expect(tokens.join).to eq("hi!")
  end

  it "returns an empty array for nil or empty input" do
    expect(described_class.tokenize(nil, :word)).to eq([])
    expect(described_class.tokenize("", :char)).to eq([])
  end

  it "raises on an unknown unit" do
    expect { described_class.tokenize("x", :sentence) }.to raise_error(TokenReel::ConfigError)
  end
end
