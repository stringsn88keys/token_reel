# frozen_string_literal: true

require "spec_helper"

RSpec.describe TokenReel::Highlight do
  let(:palette) do
    { fg: "FG", syn_keyword: "KW", syn_string: "STR", syn_number: "NUM", syn_comment: "CMT" }
  end

  def spans(line)
    described_class.spans(line, palette)
  end

  it "reassembles to the original line exactly" do
    line = %q{  return "done" if n.zero? # 1 base case}
    expect(spans(line).map { |s| s[:text] }.join).to eq(line)
  end

  it "colors a keyword" do
    expect(spans("def")).to eq([{ text: "def", color: "KW" }])
  end

  it "colors a double-quoted string, backslash-escapes included" do
    expect(spans(%q{"a\"b"})).to eq([{ text: %q{"a\"b"}, color: "STR" }])
  end

  it "colors an integer and a float" do
    expect(spans("42")).to eq([{ text: "42", color: "NUM" }])
    expect(spans("3.14")).to eq([{ text: "3.14", color: "NUM" }])
  end

  it "colors a trailing # comment" do
    expect(spans("x # note")).to eq([{ text: "x ", color: "FG" }, { text: "# note", color: "CMT" }])
  end

  it "merges adjacent same-colored tokens into one span" do
    expect(spans("foo bar")).to eq([{ text: "foo bar", color: "FG" }])
  end

  it "leaves a plain identifier in the default color" do
    expect(spans("some_var")).to eq([{ text: "some_var", color: "FG" }])
  end
end
