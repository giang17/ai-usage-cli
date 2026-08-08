# Provenance

`ai-usage-cli` is a terminal-only distribution of the provider backend from
**[Muddyblack/kde-ai-usage](https://github.com/Muddyblack/kde-ai-usage)** (MIT).

That project is a KDE Plasma 6 panel widget with a Hyprland/Quickshell frontend.
Its author designed the data layer as a standalone, frontend-neutral backend —
a standard-library-only Python package emitting versioned JSON, documented in
[`docs/provider-contract.md`](docs/provider-contract.md). That design is what
makes this repository possible at all, and the credit for the hard part — eleven
provider integrations against mostly undocumented endpoints — belongs there.

## What came from upstream

Everything that knows about a provider:

```
aiusage/providers/     credential discovery and API requests, 11 providers
aiusage/normalize/     provider responses → the contract
aiusage/collect.py     the IO half: credentials, requests, on-disk stats
aiusage/config.py      settings file and WIDGET_* environment resolution
aiusage/contract.py    normalization primitives, schema version
aiusage/http.py        fetch, error vocabulary, credential resolution
aiusage/billing.py     pricing tables
aiusage/stats.py       Claude Code / Codex CLI local activity stats
aiusage/__main__.py    the get-ai-usage CLI
bin/get-ai-usage       launcher
bin/python-interp.sh   interpreter resolution
tests/fixtures/        recorded provider responses
tests/*.test.sh        backend contract tests (paths adjusted)
docs/                  the contract document (trimmed to what applies here)
```

## What is added here

```
aiusage/cli.py         argument handling for the terminal frontend
aiusage/render.py      table and compact rendering
aiusage/envelope.py    envelope assembly, factored out of __main__
bin/ai-usage-cli       launcher
tests/ai-usage-cli.test.sh
```

`cli.py`, `render.py`, `envelope.py` and the tests were written for upstream
first and offered there as
[PR #10](https://github.com/Muddyblack/kde-ai-usage/pull/10). This repository
exists because the widget requires Plasma 6, while the backend requires nothing
but `python3` — so people on Plasma 5, GNOME, XFCE, a status bar or an SSH
session can use the numbers without installing a desktop widget.

## Staying in sync

The backend is deliberately kept close to upstream so fixes can be pulled in
cheaply. `UPSTREAM` records the commit this tree is based on; `make
upstream-log` lists what has changed upstream in the files we carry since then.
Upstream is stable in this area — over the 90 days before this repository was
created, 4 of 69 upstream commits touched provider or normalize code.

Changes that would benefit both projects should go upstream first.
