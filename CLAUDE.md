# Instructions for Claude Code

## Keep the README demo GIF in sync

Whenever code in this repo changes (anything under `lib/`, `exe/`, or the
CLI's rendering behavior), regenerate the demo GIF from `demo/exchange.md`
and make sure it's embedded in `README.md`:

```bash
bundle exec exe/token_reel -m demo/exchange.md --tps 14 --ttft 0.8 -o demo/token_reel.gif
```

- Input: `demo/exchange.md` (the sample prompt/reasoning/response exchange).
- Output: `demo/token_reel.gif`, overwritten in place.
- `README.md` embeds it in the `## Demo` section via
  `![TokenReel demo](demo/token_reel.gif)` -- that section and the command
  above should stay in sync with each other.
- Commit the regenerated GIF alongside the code change that caused it to
  change (it's a binary asset checked into git, not gitignored).
