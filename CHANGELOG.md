# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Planned
- Cross-character RelaySystem (optional).
- Keyword ↔ profession pairing UI.
- Category-based bulk assign.

## [0.1.1] — 2026-09-24

### Added
- **Persisted history queue** (account-wide) — survives reload and character switch.
- History actions: **Whisper** (offer), **Ready** (mailed notify from current character),
  **Reject** (declined), **Skip** (someone else took the order).
- Status pipeline: New → Contacted → Done / Rejected / Skipped.
- Light **stats**: completed / rejected / skipped totals and per-profession breakdown.
- Configurable **Ready / mailed** whisper template (`notifyTemplate`).
- Setting: **left-click toast to whisper** (can be disabled).

### Fixed
- Whispers that printed “Message sent” but never appeared in chat when the
  template exceeded 255 bytes (full item/profession links). Long messages now
  fall back to plain text or safe splits.
- Whisper button in the alert panel now uses the addon UI kit (primary style).

### Changed
- Fee display uses compact units without a `g` suffix (`2k`, `2.5k`, `2m`).

## [0.1.0] — 2026-09-24

First usable release. Fork of CraftRadar (Loune-Hyjal), restructured and extended.

### Added
- Multi-owner recipe model (`owners`, `assignedCharacter`) with migration from
  single-character CraftRadar data and one-time import from `CraftRadarDB`.
- Per-profession fees and per-recipe fee overrides; `{fee}` in whisper templates.
- Realm compatibility checks, smart crafter selection, optional block of
  incompatible-realm alerts.
- Trade-chat scanning across configurable channels (Trade, Services, Say, Yell,
  Guild, Party, Raid, Instance, General, LFG).
- Whole-word recipe name matching; item-link (ID) matching across languages.
- Keyword alerts (triggers, profession–item pairs, free words).
- Toast popup with hover details, one-click whisper, size presets, draggable
  position (`/cb toast`).
- Profession UI: Track button on the schematic + **Track All** dialog
  (expansions, categories, orders-only / learned-only).
- Main window: Recipes, Settings, History, Keywords tabs.
- Recipes tab: search, profession/category filter, sort, multi-owner assign,
  fee editor, clear character / profession / all.
- Settings: sound, DND/quiet mode, channels, fees, whisper templates,
  appearance (window size, accent, background, font), import/export.
- Focus / quiet mode (mute game audio except alerts).
- Minimap button; slash commands `/craftbell` and `/cb` (`/cb help`).
- Locales: English, Français, Español.
- Project hygiene: `.luacheckrc`, GitHub Actions luacheck, issue/PR templates.

### Not included
- Cross-character alert relay (CraftRadar RelaySystem) — deferred.
- Keyword ↔ profession pairing UI — placeholder only.
