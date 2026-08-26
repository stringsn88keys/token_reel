# frozen_string_literal: true

require "spec_helper"

RSpec.describe TokenReel::Script do
  it "splits a file into prompt/reasoning/response by heading" do
    sections = described_class.parse(<<~MD)
      # Prompt
      Refactor this.

      ## Reasoning
      Thinking about it.

      ## Output
      Here you go.
    MD

    expect(sections).to eq(prompt: "Refactor this.", reasoning: "Thinking about it.", response: "Here you go.")
  end

  it "accepts heading aliases, case-insensitively" do
    sections = described_class.parse(<<~MD)
      # user
      hi
      # THINKING
      hmm
      # Answer
      hello
    MD

    expect(sections).to eq(prompt: "hi", reasoning: "hmm", response: "hello")
  end

  it "omits sections that never appear" do
    sections = described_class.parse("# Prompt\nonly this\n")
    expect(sections).to eq(prompt: "only this")
  end

  it "doesn't mistake a heading-shaped line inside a fenced code block for a section" do
    sections = described_class.parse(<<~MD)
      # Prompt
      p

      # Output
      before
      ```python
      # Output
      x = 1
      ```
      after
    MD

    expect(sections[:response]).to eq("before\n```python\n# Output\nx = 1\n```\nafter")
  end

  it "ignores content before the first recognized heading" do
    sections = described_class.parse("some preamble\n# Prompt\nreal content\n")
    expect(sections).to eq(prompt: "real content")
  end

  describe ".template" do
    it "round-trips through .parse with all three sections present" do
      sections = described_class.parse(described_class.template)
      expect(sections.keys).to contain_exactly(:prompt, :reasoning, :response)
      sections.each_value { |text| expect(text).not_to be_empty }
    end
  end
end
