# TokenReel

Render a terminal-style animated GIF of a prompt being answered by an
LLM CLI -- prompt appears, there's a pause for **time to first token**,
then the response streams in at a chosen **tokens/sec** rate. Useful
for READMEs, blog posts, and talks that want a realistic-looking demo
without a real model or a real screen recorder.

Everything is driven by ImageMagick's `convert`/`magick` under the
hood, so that needs to be installed and on `PATH`. Text is always
rendered in a monospace font -- by default TokenReel auto-detects one
from whatever ImageMagick has installed (DejaVu Sans Mono, Menlo,
Consolas, Courier New, ...); pass `--font NAME` with an exact name from
`magick -list font` to pick a specific one. This matters beyond looks:
column wrapping, cursor placement, and code syntax highlighting all
assume every glyph is the same width.

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
  --response $'Sure -- here\'s a tail-recursive version:\n\ndef sum(n, acc = 0)\n  return acc if n.zero?\n  sum(n - 1, acc + n)\nend' \
  --tps 14 --ttft 0.8 --theme matrix -o demo.gif
```

Note the `$'...'` (ANSI-C) quoting -- plain `"..."` leaves `\n` as a literal
backslash-n instead of a real newline.

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

Or write the whole exchange as one Markdown file and pass `-m`/`--markdown`.
Get a starter file with `--init-markdown` (writes `exchange.md` by default,
or pass a path -- it refuses to overwrite an existing file):

```bash
token_reel --init-markdown           # writes ./exchange.md
token_reel --init-markdown demo.md   # writes ./demo.md
```

````markdown
## Prompt

Refactor this method to be tail-recursive.

## Reasoning

The recursive call isn't in tail position because of the addition
after it returns -- an accumulator fixes that.

## Output

Sure -- here's a tail-recursive version:

```ruby
def sum(n, acc = 0)
  return acc if n.zero?
  sum(n - 1, acc + n)
end
```
````

```bash
token_reel -m exchange.md --tps 14 --ttft 0.8 --theme matrix -o demo.gif
```

Headings are case-insensitive and also accept `User`/`Input`/`Question` for
the prompt, `Thinking`/`Thought` for reasoning, and `Response`/`Answer`/
`Assistant` for the output. A heading is only recognized outside of a
fenced code block, so a `# Output`-style comment inside example code
won't be mistaken for a section. The `## Reasoning` section is optional;
when present it streams first (as if the model were thinking out loud)
and is then replaced by the response once real output starts. Code
fences (` ``` `) in any section -- from `-m`, `-r`/`-R`, or `--stdin` --
are syntax-highlighted and rendered without the literal backtick lines.

Run `token_reel --help` for the full flag list. The important ones:

| flag | meaning | default |
|---|---|---|
| `--tps N` | response tokens/sec | `8` |
| `--ttft N` | seconds of "thinking" before the first token | `0.6` |
| `--prompt-tps N` | prompt typing speed, `0` = appears instantly | `0` |
| `--reasoning-tps N` | reasoning typing speed, `0` = same as `--tps` | `0` |
| `--unit word\|char` | stream whole words or single characters | `word` |
| `--theme dark\|matrix\|light\|solarized` | color scheme | `dark` |
| `--cols N` | console width, in characters | `80` |
| `--rows N` | console height, in lines (scrolls once content grows past this) | `25` |
| `--font NAME` | exact ImageMagick font name | auto-detected monospace |
| `--fps N` | GIF frame rate | `12` |
| `--hold N` | seconds to hold on the finished frame | `1.5` |
| `-o, --out PATH` | output GIF path | `token_reel.gif` |

## Ruby API

```ruby
require "token_reel"

TokenReel.generate(
  prompt:    "What's the airspeed velocity of an unladen swallow?",
  reasoning: "This is the classic Monty Python bridgekeeper question.",
  response:  "African or European swallow?",
  tps:       10,
  ttft:      0.4,
  theme:     :dark,
  out:       "swallow.gif"
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
3. If reasoning text was given, it streams in next at `--reasoning-tps`
   tokens/sec (or `--tps` if that's unset), then disappears, replaced by
   the response -- like a chat UI's collapsible thinking trace.
4. The response then streams in one token (word or character,
   per `--unit`) every `1 / --tps` seconds.
5. The final frame holds for `--hold` seconds before the GIF loops.

Frames are sampled at `--fps` and identical consecutive frames are
collapsed into a single frame with a longer delay, so a long `--ttft`
or a slow `--tps` doesn't blow up the frame count or file size.

## Releasing

Version bumps and RubyGems publishing are both automated, driven off
PR labels:

1. Label a PR `major`, `minor`, or `patch` (semver meaning, same as
   the `rake version:*` tasks below) before merging it to `main`.
2. On merge, [`version-bump.yml`](.github/workflows/version-bump.yml)
   bumps `lib/token_reel/version.rb` accordingly, commits it to
   `main`, and pushes a matching `vX.Y.Z` tag.
3. That tag push triggers [`release.yml`](.github/workflows/release.yml),
   which runs the test suite and then publishes the gem to RubyGems
   using [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)
   (OIDC -- no API key stored in this repo).

A PR merged without one of those labels doesn't bump the version or
release anything.

Trusted Publishing needs a one-time setup on rubygems.org, under the
gem's *Trusted Publishers* settings: owner `stringsn88keys`, repository
`token_reel`, workflow filename `release.yml`, environment `release`.

The version can also be bumped locally without releasing:

```bash
rake version         # print the current version
rake version:patch   # x.x.X -- backwards-compatible fixes
rake version:minor   # x.X.0 -- backwards-compatible features
rake version:major   # X.0.0 -- breaking changes
```

## License

MIT
