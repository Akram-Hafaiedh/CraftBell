# Bulk Track + Character Assignment

## Problem

1. Manually tracking recipes across 7–8 alts is painful.
2. Multiple characters can know the **same** recipe with **different specializations**
   (e.g. Mail LW, Leather LW, Profession Equipment LW). Trade whispers need to
   go to the *right* alt, not a random owner.

## Data model (v2)

```lua
trackedRecipes[recipeID] = {
    recipeName, itemLink, tradeSkillLink,
    professionID, professionName,
    needsConcentration,

    -- Who can craft it
    owners = {
        ["MailAlt-Hyjal"]  = { name = "MailAlt",  realm = "Hyjal", fullName = "MailAlt-Hyjal" },
        ["LeatherAlt-Hyjal"] = { ... },
    },

    -- Who should answer Trade requests for this recipe
    assignedCharacter = "MailAlt-Hyjal",  -- or nil
}
```

- **Matching** (ChatScanner) still keys on `recipeID` — one alert per recipe.
- **Whisper** (AlertFrame) resolves `assignedCharacter` via `ns.GetAssignedOwner()`.
- Tracking the same recipe on a second alt **adds** an owner; it does **not** overwrite.

## Bulk track

Open a profession → click **Track All** next to the bell button (or `/cb bulk`).

Uses `C_TradeSkillUI.GetAllRecipeIDs()` while the profession window is open.

Settings (defaults):

| Setting | Default | Meaning |
|---------|---------|---------|
| `bulkTrackLearnedOnly` | true | Skip unlearned recipes |
| `bulkTrackSkipConcentration` | false | Optionally skip conc recipes |
| `bulkTrackAutoAssign` | true | If recipe has no assignment yet, assign current character |

**Important for specialization:**  
Auto-assign only fills *empty* slots. Once Mail LW is assigned to a mail piece,
Leather LW bulk-tracking that same recipe will become an *owner* but will **not**
steal the assignment. You change assignment deliberately in the UI or with
`ns.AssignRecipeCharacter` / `ns.CycleAssignedCharacter`.

## Workflow for your 3 LWs

1. Log **Mail LW** → open Leatherworking → **Track All**  
   → all learned LW recipes owned by Mail LW, assigned to Mail LW (first time).
2. Log **Leather LW** → open LW → **Track All**  
   → same recipes gain a second owner; assignments stay on Mail LW where set.
3. In CraftBell recipe list, for leather-armor recipes: click **Assign** to cycle
   to Leather LW.
4. Repeat for profession-equipment recipes → Profession Equipment LW.

Optional later: category-based bulk assign (“all recipes in category X → Char Y”)
using `C_TradeSkillUI.GetRecipeInfo(id).categoryID`.

## Files changed / added

| File | Role |
|------|------|
| `Core/Database.lua` | Multi-owner schema, migration, `TrackRecipe`, `AssignRecipeCharacter`, `BulkTrackCurrentProfession` |
| `Modules/RecipeTracker.lua` | Bell + **Track All** button on profession UI |
| `Modules/AlertFrame.lua` | Use `GetRecipeCharacterView` for whispers (see patch) |
| `Modules/ChatScanner.lua` | Mute key uses assigned owner (see patch) |
| `Modules/MainWindow.lua` | Show owners + Assign cycle button (TODO integrate) |

## Integration checklist

1. Replace `Core/Database.lua` with the new version.
2. Replace `Modules/RecipeTracker.lua` with the new version.
3. In `AlertFrame.lua`, replace `BuildRecipeWhisper` with the patched version
   (or apply the same logic: call `ns.GetRecipeCharacterView`).
4. In `ChatScanner.lua`, replace `RebuildCache` mute/owner resolution.
5. In `MainWindow` recipe rows, show:
   - `assignedCharacter`
   - owner count
   - button calling `ns.CycleAssignedCharacter(recipeID)`
6. Add slash: `/cb bulk` → `ns.BulkTrackCurrentProfession()`
7. Add locale strings (see `Locales/enUS_bulk.lua` stub).
8. Bump TOC version; test migration from old single-`character` entries.

## What we deliberately did *not* do yet

- Auto-detect specialization trees (`C_ProfSpecs`) to guess mail vs leather.
  Possible later, but assignment is the reliable user-controlled source of truth.
- Category bulk-assign UI.
- Scanning alts without logging them in (not available offline for full recipe lists).
