# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Project scaffold: `.toc`, folder structure (`Core/`, `Utils/`, `Modules/`,
  `Locales/`), README, this changelog.
- New `trackedRecipes` data structure: `professionID` (stable, locale-
  independent) replaces keying anything off the display `professionName`;
  `character` split into `{name, realm, fullName}` instead of one
  concatenated string.
- `settings.professionFees[professionID]` — global per-profession fee table,
  resolved at whisper-build time rather than stored per recipe.
- `ns.GetRecipeFee(recipeData)` — resolves fee with optional per-recipe
  `feeOverride` taking priority over the global table.
- `ns.ParseNameRealm` / `ns.IsRealmCompatible` in `Utils.lua` — realm-suffix
  parsing (splits on the last hyphen, so hyphenated realm names don't break)
  and a `GetAutoCompleteRealms()`-based compatibility check.
- One-time import: on first load, if `CraftRadarDB` exists and this addon
  has no tracked recipes yet, migrates them into the new structure.
- `.luacheckrc`, GitHub Actions luacheck workflow, PR template, bug report
  issue template.

### Not yet ported
- `Modules/RecipeTracker.lua` — schematic-form track button.
- `Modules/ChatScanner.lua` — trade chat scanning.
- `Modules/AlertFrame.lua` — toast/whisper UI, `{fee}` template placeholder,
  realm-mismatch warn/block behavior.
- `Modules/MainWindow.lua` — settings UI, fee table editor.
- `Modules/RelaySystem.lua` — cross-character relay.
- Full locale strings (only a handful of keys stubbed in so far).

## [0.1.0] — scaffold

- Initial fork of CraftRadar by Loune-Hyjal, restructured per the plan
  above. No feature parity with the original yet — this version only boots,
  initializes its SavedVariables, and imports old data.
