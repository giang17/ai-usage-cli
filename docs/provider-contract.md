# Provider data contract (schema version 1)

The display layer gets all of its provider data from a single backend:

```
provider backend (Python, stdlib only)             aiusage/
  - credential discovery, HTTP, local-data reads     aiusage/providers/, http.py
  - normalization                                    aiusage/normalize/
                 │
                 ▼  thin bash launcher, execs into the package above
  bin/get-ai-usage
                 │
          stable JSON model
                 │
                 ▼
          terminal frontend
          aiusage/render.py
```

This document is inherited from the upstream project
([Muddyblack/kde-ai-usage](https://github.com/Muddyblack/kde-ai-usage)), where
the same model additionally feeds a KDE Plasma widget and a Hyprland/Quickshell
shell. It is kept here because the contract is what makes the backend reusable,
and because staying compatible with it is what keeps upstream fixes cheap to
pull in. Fields only the graphical frontends consume — `chartWindows`,
`historyValues`, `icon`, `accent`, `slots` — are still produced and documented
for that reason, even though the terminal frontend ignores them.

No frontend performs a provider network request, parses a provider response, or
computes a quota percentage or reset window. They map the fields below onto
their own widgets — or columns — and nothing else.

## Invoking the backend

```bash
get-ai-usage --provider claude            # one provider
get-ai-usage --provider claude,openai     # several (KDE: active tab + pins)
get-ai-usage --all                        # every enabled provider (Hyprland)
get-ai-usage --normalize < envelope.json  # replay a raw envelope, no network
get-ai-usage --list                       # known provider ids
```

The terminal frontend renders that same model, either fetching it itself or
reading an envelope on stdin:

```bash
ai-usage-cli                        # table of every enabled provider
ai-usage-cli --compact              # one line, for status bars
get-ai-usage --all | ai-usage-cli   # render a fetched envelope, no second fetch
```

`--all` respects the provider toggles in the shared settings file
(`$XDG_CONFIG_HOME/ai-usage-widget/hyprland-settings.json`, overridable with
`AI_USAGE_CONFIG`). `--provider` fetches exactly what was asked for, because the
graphical frontends upstream keep their own toggles.

API keys come from `WIDGET_*` environment variables (the name is upstream's) or from
the `keys` object of the settings file (what the Hyprland settings page writes).
The environment always wins.

## Envelope

```json
{
  "schemaVersion": 1,
  "updatedAt": 1785000000,
  "active": "claude",
  "providers": [ { "…provider result…" } ]
}
```

`active` is the first healthy provider, used by the Hyprland shell to pick a tab
when its remembered one disappears.

## Provider result

```json
{
  "id": "claude",
  "label": "Claude",
  "accent": "#cc785c",
  "icon": "claude-color.svg",
  "ok": true,
  "stale": false,
  "error": "",
  "updatedAt": 1785000000,
  "summary":       { "pct": 23, "text": "23%", "detail": "max", "hasChart": true },
  "quotaWindows":  [ { "…window…" } ],
  "slots":         [ { "…panel pill…" } ],
  "historyValues": { "s": 23, "w": 61 },
  "details":       { "…provider specific…" }
}
```

| field | meaning |
| --- | --- |
| `icon` | brand logo filename under `contents/icons/`, `""` when the provider has no artwork yet (frontends fall back to an `accent` dot). Bare filename, not a path — the two frontends sit at different depths and each resolves the directory itself |
| `ok` | the provider produced usable data |
| `stale` | data is missing or older than this refresh |
| `error` | human-readable failure, `""` when healthy. Well-known values: `offline`, `rate limited`, `token expired`, `access denied`, `err <http status>`, `python3 missing` (unlike the others, not retried — see the bash launcher in `bin/get-ai-usage`; the string is fixed vocabulary and means "no Python 3 interpreter could be resolved by `bin/python-interp.sh`", not that the literal `python3` binary is absent) |
| `updatedAt` | epoch seconds when the data was collected |
| `summary.pct` | headline percentage (0–100) |
| `summary.text` | headline string, already formatted (`"23%"`, `"$12.5"`, `"CLI"`) |
| `summary.detail` | plan / account line |
| `summary.hasChart` | false when the provider has no series worth charting |
| `quotaWindows[]` | ordered rows: `key`, `label`, `pct`, `available`, `resetAt`, `resetText`, `detail`, `showMeter`, and optionally `separatorBefore` |
| `separatorBefore` | present and true where a row stops being a quota window (a consumption total, a balance), so a frontend can rule the two apart. Optional — a frontend that ignores it lists the row exactly as before |
| `chartWindows[]` | chart ranges — see below. Empty when the provider has no chartable series |
| `slots[]` | compact panel pills: `pct`, `color`, `text` (null → show the meter), `tooltip` |
| `historyValues` | series keys this provider contributes to the shared usage history |
| `details` | everything the detailed KDE tabs render |

All timestamps are **epoch seconds**, `0` meaning "no reset known".
`resetText` is a preformatted local-time string for frontends that do not want
to format it themselves, and what the RESET column shows.

### Chart windows

Which history series a provider contributes, and what each chart range means.
A frontend renders the list it is handed rather than keeping its own copy of the
table, so a provider's ranges are defined in exactly one place. The terminal
frontend draws no charts and ignores this section; it is documented because the
backend still emits it.

| field | meaning |
| --- | --- |
| `id` | range identifier, persisted as the user's selection (`session`, `codex_weekly`, `kiro`, …) |
| `key` | which `historyValues` series it plots |
| `label` | button text (`5H`, `24H`, `7D`, `30D`) |
| `size` | how much time the chart shows, in ms |
| `granularity` | `5h` / `24h` / `7d`, or `""` for a provider with a single fixed range. Frontends carry it across tabs so switching services keeps the range |
| `raw` | the series holds absolute money rather than percentages, so the chart auto-scales it to its own maximum |
| `resets` | the underlying quota empties periodically |
| `periodMs` | how often it empties (0 when `resets` is false) |
| `resetAt` | epoch seconds of the *next* reset, which anchors every earlier one |

`size` and `periodMs` differ for the 24H range: it plots the five-hour series
over a wider span. `periodMs` and `resetAt` are what let a frontend redraw a
reset that happened while the machine was asleep at the moment it really
happened, instead of sloping from the last pre-sleep sample to the first sample
after wake-up (`UsageHistory.withResets`).

### History series keys

| key | series |
| --- | --- |
| `s` / `w` | Claude 5-hour / 7-day |
| `cp` / `cw` | Codex 5-hour / weekly |
| `ag` | Antigravity average |
| `kr` | Kiro credits |
| `or` | OpenRouter credit usage |
| `mv` | Mistral vibe spend (absolute USD, auto-scaled by the chart) |
| `gr` | Grok credits |
| `za` | Z.AI tokens |
| `gh` | Copilot premium requests |
| `ds` | DeepSeek balance (absolute) |

### Credentials

Credentials and access tokens are **never** part of a result. The backend
exposes presence only: `details.hasKey` and `details.keyValid` for
single-credential providers, and the specific `details.hasOAuth` /
`details.hasAdminKey` / `details.hasApiKey` / `details.codexLoggedIn` for the
two that accept more than one. A contract test asserts that no fixture secret
can appear anywhere in a result.

Most helpers now report presence rather than echoing the credential back, so a
token never crosses a process boundary at all. The exceptions are
`get-openai-usage` and `get-grok-usage`, whose credentials the backend itself
needs in order to call the plan endpoints.

## `details` per provider

**claude** — `hasOAuth`, `hasAdminKey`, `subscriptionType`, `rateLimitTier`,
`organizationUuid`, `effortLevel`, `autoDream`, `session`/`weekly`
(`available`, `pct`, `resetAt`, `tokensUsed`, `tokenLimit`), `scopedWeekly`
(one entry per `weekly_scoped` limit — a narrower week that runs alongside the
all-models one, such as Fable; `key`, `label`, `model`, `available`, `pct`,
`resetAt`, and a matching `quotaWindows` row), `extraTokens`,
`extraUsage` (`enabled`, `limit`, `used`, `pct`, `currency`),
`organizationUsage` (`models` keyed by model with `input_tokens`,
`output_tokens`, `cost_usd`, `priced`, plus `totalInputTokens`,
`totalOutputTokens`, `totalCostUSD`), `stats`, `status`.

**openai** — `hasApiKey`, `codexLoggedIn`, `email`, `planType`, `orgId`,
`accountId`, `authMode`, `codex` (`available`, `limitReached`, `session`,
`weekly`, `additional[]` with `name`, `limitReached`, `session`, `weekly`),
`organizationUsage`, `stats` (plus `model` and `effortLevel` from the newest
rollout), `status`.

**antigravity** — `email`, `planType`, `promptCreditsMonthly`,
`promptCreditsAvailable`, `pct`, `googlePct`, `externalPct`, `resetAt`,
`models` keyed by model id (`displayName`, `usedPct`, `resetTime`, `resetAt`,
`isExhausted`, `hasQuota`), `groups[]` (`key`, `label`, `usedPct`, `resetAt`,
`isExhausted`, `models`).

**kiro** — `available`, `planType`, `displayName`, `displayNamePlural`,
`currentUsage`, `usageLimit`, `pct`, `remaining`, `currentOverages`,
`overageCap`, `overageCharges`, `overageRate`, `currencyCode`,
`currencySymbol`, `resetAt`.

**mistral** — `hasKey`, `keyValid`, `availableModels`, `vibe` (`sessionCount`,
`totalCost`, `totalTokens`, `promptTokens`, `completionTokens`, `totalSteps`,
`toolOk`, `toolFail`, `activeModel`, `recent`), `status`.

**openrouter** — `hasKey`, `keyValid`, `label`, `usageUSD`, `limitUSD`
(null = unlimited), `limitRemainingUSD`, `isFreeTier`, `rateLimit`, `status`.

**grok** — `hasKey`, `loggedIn`, `pct`, `used`, `monthlyLimit`, `email`,
`teamName`, `tierId`, `billingPeriodEnd`, `sessionCount`, `totalTokens`,
`totalToolCalls`, `hasBilling`, `quotaKind`, `quotaWindow`, `quotaExhausted`,
`billingError`.

**zai** — `hasKey`, `keyValid`, `level`, `token` (`pct`, `used`, `limit`,
`resetAt`), `tokenLong` (`pct`, `resetAt`), `tools` (`pct`, `remaining`,
`resetAt`), `models`, `today` (`available`, `date`, `rollsOverAt`, `tokens`,
`calls`, `models[]` with `name`/`tokens`, `tools` with `search`/`reader`/
`zread`).

`today` comes from two further monitor endpoints, `model-usage` and
`tool-usage`, both taking `startTime`/`endTime` in `yyyy-MM-dd HH:mm:ss` —
they reject ISO-8601 with a `T`. The bounds are the plain **local calendar
date**, sent without timezone conversion, because that is what the vendor's
dashboard does and matching it is the whole point of the figure (verified
digit-for-digit against a live account). The service applies those bounds on
its own clock, which runs ahead of Europe, so the day being summed is shifted
and the total stops growing before local midnight; `rollsOverAt` carries the
date change so a total that has stopped moving does not read as stuck. Neither
call can fail the provider: the quota windows are the point, and a missing
statistic must not cost them.

**copilot** — `hasKey`, `keyValid`, `username`, `used`, `quota`, `pct`,
`resetAt`.

**deepseek** — `hasKey`, `keyValid`, `isAvailable`, `balances`,
`primaryCurrency`, `primaryTotal`, `primaryGranted`, `primaryToppedUp`,
`currency`, `symbol`.

### Shared sub-objects

`stats` (Claude Code and Codex CLI): `available`, `totalMessages`,
`totalSessions`, `totalTokens`, `totalToolCalls`, `favoriteModel`, `firstDate`,
`computedDate`, `activeDays`, `spanDays`, `currentStreak`, `longestStreak`,
`longestSessionMs`, `longestSessionMessages`, `peakHour`, `models`,
`dailyTokens[]` (`date`, `total`). Claude adds `version`, `totalCostUSD` and
`totalWebSearches`; Codex adds `model` and `effortLevel`.

`status` (Statuspage summary): `indicator`, `description`, `components[]`,
`incidents[]`, `latestUpdate`. Status pages are cached on disk for
`AI_USAGE_STATUS_TTL` seconds (default 300) so a fast poll interval does not
hammer them.

## Usage history

Upstream's graphical frontends accumulate `historyValues` over time into
`~/.local/share/ai-usage-widget/usage-history-latest.json` and plot it. The
terminal frontend keeps no history at all — it renders one envelope and exits —
so nothing here writes that file. The `historyValues` and `chartWindows` fields
are still emitted, unchanged, so a recorded envelope stays interchangeable
between the two projects.

## Testing

`tests/get-ai-usage.test.sh` replays `tests/fixtures/*.json` — raw envelopes for
success, missing credentials, malformed responses, offline and rate-limited
states — through `--normalize`, so the whole provider matrix is covered without
network access. It also runs the real backend end to end against the providers'
own fixture hooks (`*_RESPONSE_FILE`, honoured by `fetch_json` in
`aiusage/http.py`) to check settings toggles, key plumbing and the outer
envelope.

`tests/ai-usage-cli.test.sh` renders each of those fixtures through the terminal
frontend, asserting among other things that a provider which cannot report still
produces a row — a state the graphical frontends show as a tab or a pill, and
which a table could silently drop instead.

`tests/python-interp.test.sh` covers interpreter resolution, and the two codex
helper tests cover the local-stats readers. Run them all with `make test`; none
of them touch the network.

## Changing the contract

Adding a field is backwards compatible. Removing or repurposing one is not:
bump `SCHEMA_VERSION` in `aiusage/contract.py`, update
this document, and keep the renderer in step. A change made here should go
upstream too, or the two projects drift.
