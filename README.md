# CraftBell

Scan trade (and other) chat for crafting requests that match your tracked recipes, then answer with a one-click whisper.

**Continuation of [CraftRadar](https://www.curseforge.com/wow/addons/craftradar)** by Loune-Hyjal after a long period of inactivity — same core idea, new data model and features.

**Current release: v0.1.2**

## Features

- **Track recipes** from the profession UI — single **Track** or **Track All** (expansions, categories, orders-only / learned-only) with informational category filtering
- **Multi-character owners** — several alts can know the same recipe; assign who answers Trade
- **Fees** — per-profession defaults and per-recipe overrides; `{fee}` in templates (compact `2k` / `2m`)
- **Realm-aware** — warn or block when the crafter can’t whisper the requester; optional smart crafter selection
- **History queue** (persisted) — live search, status filters (open/done/rejected/skipped), multi-field sorting, item icons & links, and Whisper offer → **Ready** (mailed) / **Reject** / **Skip** workflow
- **Debug subsystem** — dedicated window (`/cb debugwin`) with live pipeline checklist and synthetic self-test
- **Keyword alerts** — triggers (LF, WTB, …) plus profession–item pairs or free words
- **Configurable channels**, sound, quiet/focus mode, appearance themes
- **Locales** — English, Français, Español
- **Import** — optional one-time migration if `CraftRadarDB` is still present

## Commands

| Command | Action |
|--------|--------|
| `/craftbell` or `/cb` | Open the main window |
| `/cb help` | Full command list |
| `/cb bulk` | Track All (uses expansion checklist) |
| `/cb toast` | Reposition the alert popup |
| `/cb test` | Simulate an alert |
| `/cb debugwin` | Open debug window & pipeline self-test |
| `/cb history clear tests` | Remove synthetic test/debug rows from history |

## Typical multi-alt flow

1. On a trade-watching alt, get an alert → **Whisper** (offer).
2. Switch to the crafter, craft, send mail.
3. Open **History** (still there after char switch) → **Ready** to notify the buyer.
4. If they never accept → **Reject** or **Skip** so the queue stays honest.

## Project layout

```
CraftBell/
├── CraftBell.toc
├── Locales/           -- enUS, frFR, esES
├── Utils/             -- Utils, UITheme
├── Core/              -- Database, History, Debug, Init, Minimap, FocusMode, TextFrame
└── Modules/           -- RecipeTracker, ChatScanner, AlertFrame, MainWindow, UI/*
```

## Data

- SavedVariables: `CraftBellDB` (account-wide)
- Multi-owner `trackedRecipes`, `history` queue, `historyStats`
- Auto-import from `CraftRadarDB` on first run when empty

## License / credit

Based on **CraftRadar** by Loune-Hyjal. CraftBell is an independent continuation, not an official update of the original project.

Recommended license: **MIT** (see project LICENSE when published).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
