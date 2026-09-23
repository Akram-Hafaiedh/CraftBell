# CraftBell

A continuation of [CraftRadar](https://www.curseforge.com/wow/addons/craftradar) by **Loune-Hyjal**,
picked up after ~6 months of inactivity. Same core idea (scan trade chat for
crafting requests matching your tracked recipes, auto-suggest a whisper reply),
extended with:

- **Realm compatibility check** — flags or hides the whisper option when the
  requester is on a realm your crafting character can't actually message.
- **Per-profession pricing** — the auto-whisper can include a fee that varies
  by profession (e.g. Inscription vs Blacksmithing), instead of one flat
  message for everything.

## Status

- Reached out to the original author (comment on the CurseForge page) to ask
  if the project is still maintained — no response yet.
- This is currently a **personal fork**, not published. The original has no
  license file, so it defaults to All Rights Reserved; this repo exists to
  build and test the new features, not to redistribute.
- If the author responds: happy to upstream these features as a PR instead
  of maintaining a separate fork.
- If no response after a reasonable wait: intend to publish openly with
  clear credit, per CurseForge's guidance for continuing inactive projects.

## Structure

```
CraftBell/
├── CraftBell.toc
├── Locales/          -- enUS.lua, frFR.lua
├── Utils/            -- Utils.lua (string/realm helpers)
├── Core/
│   ├── Database.lua  -- event bus, SavedVariables schema, migration
│   └── Init.lua       -- addon lifecycle, slash commands
└── Modules/           -- (empty for now — see Next steps)
```

## Data structure

Recipes are now stored with a split character/realm field and a stable
profession ID instead of a locale-dependent display string, so both new
features have something reliable to key off of:

```lua
trackedRecipes[recipeID] = {
    recipeName, itemLink, tradeSkillLink,
    professionID,     -- stable, locale-independent
    professionName,   -- display only
    character = { name, realm, fullName },
    needsConcentration,
}

settings.professionFees = { [professionID] = amount }
```

On first load, if `CraftRadarDB` exists (i.e. the original addon is also
installed) and this addon has no tracked recipes yet, it auto-imports and
migrates them into the new shape — see `ImportFromCraftRadar()` in
`Core/Database.lua`.

## Next steps

Not ported yet — these are straight rewrites of the original modules against
the new struct, not copy-paste:

- `Modules/RecipeTracker.lua` — the schematic-form track button, now passing
  `professionID` through to `TrackRecipe`.
- `Modules/ChatScanner.lua` — trade chat scanning (mostly unchanged logic).
- `Modules/AlertFrame.lua` — toast/whisper UI, adding the `{fee}` template
  placeholder and the realm-mismatch flag/block behavior.
- `Modules/MainWindow.lua` — settings UI, adding a per-profession fee table
  editor.
- `Modules/RelaySystem.lua` — cross-character relay (optional, port later).
