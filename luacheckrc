-- luacheck config for the CraftBell WoW addon.
-- Run locally with: luacheck .

std = "lua51"

-- WoW's Lua sandbox exposes globals that don't exist in stock Lua.
-- Add to this list as new modules pull in more API surface — luacheck
-- will complain loudly (undefined global) the moment you use something
-- not listed here, which is the point: it catches typos in API names
-- before you alt-tab into the game to find out.
read_globals = {
    -- Core API namespaces used so far
    "C_AddOns",
    "C_TradeSkillUI",
    "C_SpellBook",
    "C_Spell",
    "C_ChatInfo",
    "C_Timer",
    "CopyTable",
    "CreateFrame",
    "UnitName",
    "GetRealmName",
    "GetAutoCompleteRealms",
    "GetLocale",
    "GetTime",
    "GetCVar",
    "SetCVar",
    "PlaySound",
    "SlashCmdList",
    "hooksecurefunc",
    "loadstring",
    "setfenv",
    "wipe",
    "date",
    "GameTooltip",
    "UIParent",
    "Minimap",
    "ProfessionsFrame",
    "ChatFrame_AddMessageEventFilter",
    "SendChatMessage",
    "UISpecialFrames",
    "tinsert",
    "GetCursorPosition",
    "CraftBellMainFrame",

    -- Frame/global names this addon itself registers — declared here so
    -- luacheck doesn't flag them as "unused global" when only read back
    -- from a different file (e.g. Init.lua sets, a module elsewhere reads)
    "CraftBellDB",
    "CraftRadarDB", -- read-only, for the one-time import from the original addon
}

-- Every file starts with `local addonName, ns = ...` — this is the addon's
-- private namespace, not a global, so no entry needed here. If luacheck
-- ever flags `ns` or `addonName` as undefined, it means a file is missing
-- that line, not a config problem.

-- WoW addon convention: event handler signatures are fixed by the API
-- (self, event, ...) even when a given handler ignores most of them.
-- Don't warn on intentionally-unused arguments.
unused_args = false

-- Long files with lots of small local helper functions are normal in this
-- codebase (see Database.lua) — don't cap function count/complexity.
max_cyclomatic_complexity = false

exclude_files = {
    "Locales/*.lua", -- mostly string tables, not worth linting as code
}
