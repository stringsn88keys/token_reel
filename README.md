# TokenReel

Render a terminal-style animated GIF of a prompt being answered by an
LLM CLI -- prompt appears, there's a pause for **time to first token**,
then the response streams in at a chosen **tokens/sec** rate. Useful
for READMEs, blog posts, and talks that want a realistic-looking demo
without a real model or a real screen recorder.

Everything is driven by ImageMagick's `convert`/`magick` under the
hood, so that needs to be installed and on `PATH`.

## Install

```bash
gem install token_reel
# or, in a Gemfile:
gem "token_reel"
```

Requires ImageMagick (`brew install imagemagick` / `apt install imagemagick`).

## CLI

```bash
token_reel \
  --prompt "Refactor this method to be tail-recursive" \
  --response "Sure -- here's a tail-recursive version:\n\ndef sum(n, acc = 0)\n  return acc if n.zero?\n  sum(n - 1, acc + n)\nend" \
  --tps 14 --ttft 0.8 --theme matrix -o demo.gif
```

Read from files instead of inline strings:

```bash
token_reel -P prompt.txt -R response.md --tps 20 -o demo.gif
```

Or pipe both in, separated by a line of `---`:

```bash
cat <<'EOF' | token_reel --stdin -o demo.gif
Explain time-to-first-token in one sentence.
---
Time to first token is the delay between sending a prompt and the
model's first streamed token arriving -- it's latency, not throughput.
EOF
```

Run `token_reel --help` for the full flag list. The important ones:

| flag | meaning | default |
|---|---|---|
| `--tps N` | response tokens/sec | `8` |
| `--ttft N` | seconds of "thinking" before the first token | `0.6` |
| `--prompt-tps N` | prompt typing speed, `0` = appears instantly | `0` |
| `--unit word\|char` | stream whole words or single characters | `word` |
| `--theme dark\|matrix\|light\|solarized` | color scheme | `dark` |
| `--cols N` | wrap width, in characters | `70` |
| `--fps N` | GIF frame rate | `12` |
| `--hold N` | seconds to hold on the finished frame | `1.5` |
| `-o, --out PATH` | output GIF path | `token_reel.gif` |

## Ruby API

```ruby
require "token_reel"

TokenReel.generate(
  prompt:   "What's the airspeed velocity of an unladen swallow?",
  response: "African or European swallow?",
  tps:      10,
  ttft:     0.4,
  theme:    :dark,
  out:      "swallow.gif"
)
```

Or build a `TokenReel::Config` for more control and hand it to
`TokenReel::Generator` directly:

```ruby
config = TokenReel::Config.new
config.prompt   = File.read("prompt.txt")
config.response = File.read("response.md")
config.tps      = 16
config.ttft     = 1.2
config.theme    = :solarized
config.out      = "demo.gif"

TokenReel::Generator.new(config).generate!
```

## How timing works

1. The prompt is shown -- instantly by default, or typed out at
   `--prompt-tps` tokens/sec if you set it.
2. Once the prompt is fully shown, `--ttft` seconds pass with a
   blinking-cursor "thinking..." indicator -- this is your simulated
   time to first token.
3. The response then streams in one token (word or character,
   per `--unit`) every `1 / --tps` seconds.
4. The final frame holds for `--hold` seconds before the GIF loops.

Frames are sampled at `--fps` and identical consecutive frames are
collapsed into a single frame with a longer delay, so a long `--ttft`
or a slow `--tps` doesn't blow up the frame count or file size.

## License

MIT
