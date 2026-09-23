local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Internal event bus (simple callback system to decouple modules)
----------------------------------------------------------------------
local callbacks = {}

function ns.RegisterCallback(event, fn)
    if not callbacks[event] then
        callbacks[event] = {}
    end
    table.insert(callbacks[event], fn)
end

function ns.FireCallback(event, ...)
    if callbacks[event] then
        for _, fn in ipairs(callbacks[event]) do
            fn(...)
        end
    end
end

----------------------------------------------------------------------
-- Alert history (session only — not persisted to SavedVariables)
----------------------------------------------------------------------
ns.alertHistory = {}

function ns.AddToHistory(sender, message, matches, recipeNames, alertType, keywordMatches)
    local aType = alertType or "recipe"

    -- Merge into an existing entry from the same sender + same alert if one
    -- exists, rather than spamming a new toast for every repeated message.
    for _, existing in ipairs(ns.alertHistory) do
        if existing.sender == sender and existing.alertType == aType then
            local isDuplicate
            if aType == "keyword" then
                isDuplicate = true
            else
                isDuplicate = (existing.recipeNames == recipeNames)
            end
            if isDuplicate then
                existing.count = (existing.count or 1) + 1
                existing.time = date("%H:%M:%S")
                existing.message = message
                ns.FireCallback("HISTORY_UPDATED")
                return existing
            end
        end
    end

    local recipeIDs = {}
    local firstMatchData = nil
    if matches then
        for recipeID, data in pairs(matches) do
            table.insert(recipeIDs, recipeID)
            if not firstMatchData then
                firstMatchData = data
            end
        end
    end

    local entry = {
        time = date("%H:%M:%S"),
        sender = sender,
        message = message,
        recipeNames = recipeNames,
        recipeIDs = recipeIDs,
        matchData = firstMatchData,
        replied = false,
        alertType = aType,
        keywordMatches = keywordMatches,
        count = 1,
    }
    table.insert(ns.alertHistory, 1, entry)
    if #ns.alertHistory > 100 then
        table.remove(ns.alertHistory)
    end
    ns.FireCallback("HISTORY_UPDATED")
    return entry
end

----------------------------------------------------------------------
-- SavedVariables schema
--
-- trackedRecipes[recipeID] = {
--     recipeName     = "Fire Resistant Cape",
--     itemLink       = "...",
--     tradeSkillLink = "...",
--     professionID   = 197,          -- stable, locale-independent skill line ID
--     professionName = "Tailoring",  -- display only — NEVER used as a lookup key
--     character = {
--         name     = "Goldok",
--         realm    = "Hyjal",
--         fullName = "Goldok-Hyjal",
--     },
--     needsConcentration = false,
-- }
--
-- settings.professionFees[professionID] = amount
--   Global per-profession fee, resolved at whisper-build time. Kept OUT of
--   the recipe struct so changing your rate doesn't require touching every
--   tracked recipe. A recipe can still override it with feeOverride below.
----------------------------------------------------------------------
local defaults = {
    trackedRecipes = {},
    messageTemplate = nil,       -- set from locale default on first init
    crossCharTemplate = nil,     -- set from locale default on first init
    keywords = {
        triggers = { "LF", "WTB", "Need", "LFC", "Seek" },
        pairs = {},
        freewords = {},
    },
    settings = {
        soundEnabled = true,
        soundID = 11466,
        language = "en",
        minimapAngle = 225,
        keywordScanEnabled = true,
        dndEnabled = false,
        relayEnabled = false,
        relayTargets = {},
        concentrationMuted = {},
        concentrationMutedAll = false,
        toastPoint = "TOPRIGHT",
        toastRelPoint = "TOPRIGHT",
        toastOffsetX = -350,
        toastOffsetY = -120,
        toastSize = "medium",

        -- New: per-profession fee table, keyed by professionID (not name)
        -- Example: { [773] = 50, [164] = 20 }  -- Inscription 50g, Blacksmithing 20g
        professionFees = {},

        -- New: block or just flag whispers to crafters on an incompatible realm
        -- "warn"  -> show the whisper option with a flag
        -- "block" -> hide the whisper option entirely
        realmMismatchMode = "warn",
    },
}

local function DeepCopy(v)
    if type(v) == "table" then
        return CopyTable(v)
    end
    return v
end

local function ApplyDefaults(tbl, defaultTbl)
    for k, v in pairs(defaultTbl) do
        if tbl[k] == nil then
            tbl[k] = DeepCopy(v)
        elseif type(v) == "table" and type(tbl[k]) == "table" then
            ApplyDefaults(tbl[k], v)
        end
    end
end

----------------------------------------------------------------------
-- Migrate a single recipe entry from the old flat schema
-- (characterName = "Name-Realm" string, no professionID) to the new one.
----------------------------------------------------------------------
local function MigrateRecipeEntry(data)
    if not data.character and data.characterName then
        local name, realm = ns.ParseNameRealm(data.characterName)
        data.character = { name = name, realm = realm, fullName = data.characterName }
        data.characterName = nil
    end
    if data.professionID == nil then
        data.professionID = false -- explicit "unknown", distinct from nil/unset
    end
    return data
end

----------------------------------------------------------------------
-- One-time import from the original CraftRadar's SavedVariables, if present
-- and this is a fresh CraftBell install. Keeps you from losing recipes you
-- already tracked before switching over.
----------------------------------------------------------------------
local function ImportFromCraftRadar()
    if not CraftRadarDB or not CraftRadarDB.trackedRecipes then return end
    if next(CraftBellDB.trackedRecipes) then return end -- don't clobber existing data

    local imported = 0
    for recipeID, data in pairs(CraftRadarDB.trackedRecipes) do
        local copy = CopyTable(data)
        MigrateRecipeEntry(copy)
        CraftBellDB.trackedRecipes[recipeID] = copy
        imported = imported + 1
    end
    if imported > 0 then
        ns.Print(string.format(L["IMPORTED_FROM_CRAFTRADAR"] or "Imported %d tracked recipe(s) from CraftRadar.", imported))
    end
end

local function InitializeDB()
    if not CraftBellDB then
        CraftBellDB = {}
    end
    ApplyDefaults(CraftBellDB, defaults)
    ns.db = CraftBellDB

    -- Migrate any recipe entries still in the old flat shape
    for recipeID, data in pairs(ns.db.trackedRecipes) do
        MigrateRecipeEntry(data)
    end

    if ns.db.messageTemplate == nil then
        ns.db.messageTemplate = L["DEFAULT_TEMPLATE"]
    end
    if ns.db.crossCharTemplate == nil then
        ns.db.crossCharTemplate = L["DEFAULT_CROSS_TEMPLATE"]
    end

    ImportFromCraftRadar()

    if not ns.db.messageTemplate then
        ns.db.messageTemplate = L["DEFAULT_TEMPLATE"] or
            "Hi! I saw you're looking for {item}. I can craft it ({profession}). Fee: {fee}. Let me know!"
    end
    if not ns.db.crossCharTemplate then
        ns.db.crossCharTemplate = L["DEFAULT_CROSS_TEMPLATE"] or
            "Hi! My crafting alt {characterName} can make {item} ({profession}). Fee: {fee}. Let me know!"
    end
end

ns.InitializeDB = InitializeDB

----------------------------------------------------------------------
-- Recipe tracking API (new struct: professionID + split character table)
----------------------------------------------------------------------
function ns.TrackRecipe(recipeID, recipeName, professionID, professionName, itemLink, tradeSkillLink)
    local fullName = ns.GetPlayerFullName()
    local name, realm = ns.ParseNameRealm(fullName)

    ns.db.trackedRecipes[recipeID] = {
        recipeName = recipeName,
        itemLink = itemLink,
        tradeSkillLink = tradeSkillLink,
        professionID = professionID or false,
        professionName = professionName,
        character = {
            name = name,
            realm = realm,
            fullName = fullName,
        },
        needsConcentration = false,
    }
    ns.Print((L["RECIPE_TRACKED"] or "Tracking: ") .. (itemLink or recipeName))
    ns.FireCallback("RECIPE_TRACKED", recipeID)
end

function ns.UntrackRecipe(recipeID)
    local data = ns.db.trackedRecipes[recipeID]
    if data then
        ns.Print((L["RECIPE_REMOVED"] or "Removed: ") .. (data.itemLink or data.recipeName))
        ns.db.trackedRecipes[recipeID] = nil
        ns.FireCallback("RECIPE_UNTRACKED", recipeID)
    end
end

function ns.IsRecipeTracked(recipeID)
    return ns.db.trackedRecipes[recipeID] ~= nil
end

----------------------------------------------------------------------
-- Fee lookup: per-recipe override wins, otherwise the global per-profession
-- rate, otherwise 0.
----------------------------------------------------------------------
function ns.GetRecipeFee(recipeData)
    if not recipeData then return 0 end
    if recipeData.feeOverride ~= nil then
        return recipeData.feeOverride
    end
    if recipeData.professionID and ns.db.settings.professionFees then
        return ns.db.settings.professionFees[recipeData.professionID] or 0
    end
    return 0
end
