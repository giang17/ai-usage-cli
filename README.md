# ai-usage-cli

Your AI API quota, in the terminal. Claude, OpenAI/Codex, Z.AI, Kimi, GitHub
Copilot, Antigravity, Kiro, Mistral, OpenRouter, Grok and DeepSeek — one table,
no desktop environment required.

```
PROVIDER  PLAN          WINDOW             USAGE                NOTE                      RESET
────────────────────────────────────────────────────────────────────────────────────────────────────────
Claude    max           5-hour session     [██░░░░░░░░]  23%    120000 / 500000 tokens    Jul 19, 17:00
Claude    max           7-day window       [██████░░░░]  61%    3000000 / 5000000 tokens  Jul 25, 17:00
────────────────────────────────────────────────────────────────────────────────────────────────────────
Z.AI      pro           5-hour tokens      [██░░░░░░░░]  25%    250 / 1000 tokens         Jul 25, 20:20
Z.AI      pro           Monthly tools      [████░░░░░░]  40%    60 remaining              Jul 25, 21:20
────────────────────────────────────────────────────────────────────────────────────────────────────────
Kimi      Moonshot API  Available balance  $49.59
────────────────────────────────────────────────────────────────────────────────────────────────────────
Copilot   —             —                  Copilot: no token configured
```

```console
$ ai-usage-cli --compact
Claude 23%  Z.AI 25%  Kimi $49.59  Copilot —
```

**Only `python3` is required.** No pip dependencies, no Qt, no Node, no desktop
session — the whole thing is standard library. It works over SSH, in a status
bar, in a shell prompt, and on any desktop.

## Install

```bash
git clone https://github.com/giang17/ai-usage-cli.git
cd ai-usage-cli
make install-links        # symlinks both tools into ~/.local/bin
```

Or with pipx, if you prefer an installed package:

```bash
pipx install git+https://github.com/giang17/ai-usage-cli.git
```

Or not at all — `./bin/ai-usage-cli` runs straight from the checkout.

## Configure

One file, `~/.config/ai-usage-widget/hyprland-settings.json` (the name is
inherited from upstream — see [NOTICE.md](NOTICE.md) — and is kept identical so
the two projects share a config):

```json
{
  "providers": { "claude": true, "zai": true, "kimi": true, "openai": false },
  "keys": { "zai": "…", "moonshot": "…" }
}
```

Providers you do not list default to on, so switch off what you do not use.
`chmod 600` it if you put credentials in there — or leave `keys` out entirely
and export the `WIDGET_*` environment variables instead, which take precedence.
`AI_USAGE_CONFIG` overrides the file path.

**Claude needs no key at all** — a local Claude Code login is enough. What each
of the others reads:

| Provider | What you need |
|---|---|
| Claude | Claude Code, signed in locally |
| OpenAI | An API key for organization usage; a Codex CLI login adds plan limits |
| Antigravity | Node.js 18+, the `antigravity-usage` CLI, a Google account with access |
| Kiro | Kiro IDE, signed in at least once |
| Mistral | An API key; the vibe CLI optionally adds local session stats |
| OpenRouter | An API key |
| Grok | Grok CLI authenticated with `grok --oauth`; an xAI key is optional |
| Z.AI | A Z.AI token (`keys.zai`, `$ZAI_TOKEN`, or `~/.config/zai/token`) |
| GitHub Copilot | A GitHub token with **Plan: read**; personal billing only |
| DeepSeek | A DeepSeek API key |
| Kimi / Moonshot | A Moonshot **platform API key** — not the Kimi CLI OAuth login |

## Use

```bash
ai-usage-cli                        # every enabled provider
ai-usage-cli --provider claude,zai  # a subset, ignoring the toggles
ai-usage-cli --compact              # one line, for status bars
ai-usage-cli --json                 # the raw envelope, for your own scripts
watch -n 300 ai-usage-cli           # refresh in place
```

| Flag | |
|---|---|
| `--all` / `--provider <ids>` | what to fetch (`--list` prints the ids) |
| `--compact` | one line per run instead of a table |
| `--json` | print the envelope instead of rendering it |
| `--color auto\|always\|never` | `auto` follows the terminal and `NO_COLOR` |
| `--ascii` | ASCII bars and rules for non-UTF-8 terminals |

Colour uses amber from 70% and red from 90%, and turns itself off when the
output is not a terminal — so piping into a file or `grep` gives clean text.
Columns that no row fills are dropped rather than printed empty.

**A provider that cannot report keeps its row and says why** (`no token
configured`, `offline`, `rate limited`). This is deliberate: a tool that hides
broken providers makes a missing key look like a service you never enabled.

`get-ai-usage` is installed alongside and prints the raw JSON, so you can build
your own readouts:

```bash
get-ai-usage --provider claude | jq -r '.providers[0].quotaWindows[] | "\(.label) \(.pct)%"'
get-ai-usage --all | ai-usage-cli --compact     # fetch once, render separately
```

### Status bars

`--compact` is meant for this. waybar, for example:

```json
{ "custom/ai": { "exec": "ai-usage-cli --compact", "interval": 300 } }
```

Keep the interval at a few minutes; several providers rate-limit aggressively,
and the backend caches status pages on disk for `AI_USAGE_STATUS_TTL` seconds
(default 300) for the same reason.

## How it works

`get-ai-usage` does everything that involves a provider — credential discovery,
API requests, response parsing, quota maths, reset timestamps, error and stale
state — and emits one versioned JSON envelope. `ai-usage-cli` renders that
envelope and nothing else: it performs no request and computes no percentage.

That separation is why `get-ai-usage --all | ai-usage-cli` works, and why the
whole provider matrix can be tested offline by replaying recorded responses
through `--normalize`. The schema is documented in
[`docs/provider-contract.md`](docs/provider-contract.md).

```bash
make test    # 5 suites, no network access
make lint    # ruff check + format check
```

## Credits

The provider backend — the hard part, eleven integrations against mostly
undocumented endpoints — comes from
**[Muddyblack/kde-ai-usage](https://github.com/Muddyblack/kde-ai-usage)**, a KDE
Plasma 6 panel widget whose author built the data layer as a standalone,
frontend-neutral component. This project is that backend plus a terminal
frontend, for people who want the numbers without installing a desktop widget.

If you run Plasma 6 or Hyprland, use the original: it has charts, burn-rate
estimates, per-model breakdowns and a proper settings UI.

See [NOTICE.md](NOTICE.md) for what came from where and how this tracks upstream
changes. MIT licensed, as is upstream.
