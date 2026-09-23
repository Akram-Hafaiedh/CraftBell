## What does this change?

<!-- One or two sentences. Which module(s) does it touch? -->

## Why?

<!-- Bug fix, new feature, refactor toward the new data structure, etc. -->

## Testing

<!-- WoW addons can't be unit-tested in CI beyond luacheck, so be specific
     about manual testing: -->
- [ ] Loaded in-game without Lua errors (`/console scriptErrors 1`)
- [ ] Tested the specific flow this change affects (describe below)
- [ ] `luacheck .` passes locally

## Data structure impact

<!-- Does this touch `trackedRecipes`, `settings`, or anything else in
     SavedVariables? If so, does `Core/Database.lua`'s migration path
     handle existing saved data correctly, or does old data need a new
     migration step? -->

## Checklist

- [ ] Updated `CHANGELOG.md`
- [ ] Updated `README.md` if this changes setup/usage
- [ ] No copy-pasted logic from the original CraftRadar beyond what's
      already credited — see README's Status section