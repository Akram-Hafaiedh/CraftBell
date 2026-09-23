# TODO

## Blocking
- [ ] Hear back from Loune-Hyjal (comment sent on CurseForge) — decides
      whether this stays a personal fork, becomes a PR upstream, or gets
      published openly with credit.

## Core feature work
- [ ] Port `RecipeTracker.lua`
  - [ ] Pass `professionID` (`profInfo.parentProfessionID`) through to
        `ns.TrackRecipe` — currently discarded after deriving the display
        name in the original.
- [ ] Port `ChatScanner.lua`
  - [ ] Logic is mostly unaffected by the new struct; mainly needs the
        `data.characterName` references updated to `data.character.fullName`.
- [ ] Port `AlertFrame.lua`
  - [ ] Add `{fee}` placeholder, resolved via `ns.GetRecipeFee(recipeData)`,
        to both `messageTemplate` and `crossCharTemplate` substitution sites.
  - [ ] Add realm-mismatch handling: check `ns.IsRealmCompatible(recipeOwner_realm)`
        before showing the whisper button; respect
        `settings.realmMismatchMode` ("warn" vs "block").
  - [ ] Decide UI treatment for "warn" mode — icon/tooltip vs inline text.
- [ ] Port `MainWindow.lua`
  - [ ] New settings section: per-profession fee table editor
        (`settings.professionFees`).
  - [ ] Surface `character.realm` somewhere in the recipe list (currently
        only `character.fullName` shown via debug dump).
- [ ] Port `RelaySystem.lua` (lower priority — only matters if using
      cross-character relay)

## Data / migration
- [ ] Decide: does `MigrateRecipeEntry` need to also backfill `professionID`
      for old entries that only have `professionName`? Currently just marks
      it `false` (unknown) — those old recipes won't get a fee until
      re-tracked. Acceptable for a personal fork; would need addressing
      before any public release.
- [ ] Test the `CraftRadarDB` → `CraftBellDB` import path against your real
      SavedVariables file, not just a fresh install.

## Polish / hygiene
- [ ] Fill in real locale strings in `Locales/enUS.lua` / `frFR.lua` as each
      module gets ported — don't bulk-copy the original's ~150-string file.
- [ ] Add a `.gitignore` (WoW SavedVariables, `.DS_Store`, editor cruft).
- [ ] Decide on a LICENSE once the author-contact question above resolves.