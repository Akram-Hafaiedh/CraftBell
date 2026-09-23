local addonName, ns = ...

local lookupCache = {}   -- [normalizedRecipeName] = recipeID
local itemIDCache = {}   -- [numericID] = recipeID (language-agnostic matching)
local recentAlerts = {}  -- ["sender:recipeID"] = timestamp (anti-spam)
local COOLDOWN = 30      -- seconds between duplicate alerts

local keywordCache = {
    triggers = {},
    pairs = {},
    freewords = {},
}

----------------------------------------------------------------------
-- Rebuild the lookup cache from tracked recipes
----------------------------------------------------------------------
local function RebuildCache()
    wipe(lookupCache)
    wipe(itemIDCache)
    if not ns.db then return end
    local count = 0
    local muted = ns.db.settings.concentrationMuted or {}
    local globalMute = ns.db.settings.concentrationMutedAll

    for recipeID, data in pairs(ns.db.trackedRecipes) do
        local owner = ns.GetAssignedOwner and ns.GetAssignedOwner(data)
        local charFullName = (owner and owner.fullName)
            or (data.character and data.character.fullName)
            or ""

        local include = true
        if data.needsConcentration then
            local muteKey = charFullName .. ":" .. (data.professionName or "")
            if globalMute or muted[muteKey] then
                ns.Debug("ChatScanner: skipping muted recipe — " .. tostring(data.recipeName))
                include = false
            end
        end

        if include then
            lookupCache[ns.NormalizeString(data.recipeName)] = recipeID
            count = count + 1
            itemIDCache[recipeID] = recipeID
            if data.itemLink then
                for id in pairs(ns.ExtractLinkIDs(data.itemLink)) do
                    itemIDCache[id] = recipeID
                end
            end
        end
    end
    ns.Debug("ChatScanner: cache rebuilt — " .. count .. " recipes")
end

----------------------------------------------------------------------
-- Whole-word match helper (Lua frontier pattern)
----------------------------------------------------------------------
local function FindWholeWord(text, word)
    local pattern = "%f[%a]" .. word:gsub("(%W)", "%%%1") .. "%f[%A]"
    return string.find(text, pattern)
end

local function SplitCSV(str)
    local result = {}
    for word in str:gmatch("[^,]+") do
        local trimmed = ns.StripAccents(word:match("^%s*(.-)%s*$"):lower())
        if trimmed ~= "" then
            table.insert(result, trimmed)
        end
    end
    return result
end

local function RebuildKeywordCache()
    wipe(keywordCache.triggers)
    wipe(keywordCache.pairs)
    wipe(keywordCache.freewords)
    if not ns.db or not ns.db.keywords then return end

    for _, word in ipairs(ns.db.keywords.triggers or {}) do
        table.insert(keywordCache.triggers, ns.StripAccents(word:lower()))
    end
    for _, pair in ipairs(ns.db.keywords.pairs or {}) do
        table.insert(keywordCache.pairs, {
            professions = SplitCSV(pair.professions or ""),
            items = SplitCSV(pair.items or ""),
        })
    end
    for _, word in ipairs(ns.db.keywords.freewords or {}) do
        table.insert(keywordCache.freewords, ns.StripAccents(word:lower()))
    end
    ns.Debug("ChatScanner: keyword cache rebuilt — " .. #keywordCache.triggers .. " triggers, "
        .. #keywordCache.pairs .. " pairs, " .. #keywordCache.freewords .. " freewords")
end

----------------------------------------------------------------------
-- Scan a chat message against tracked recipe names
----------------------------------------------------------------------
local function ScanMessage(message, sender, event)
    if not ns.db or not next(ns.db.trackedRecipes) then return end

    local playerName = UnitName("player")
    if sender and playerName and sender:find(playerName, 1, true) then
        return
    end

    local normalizedMsg = ns.NormalizeString(message)

    if #keywordCache.triggers > 0 then
        local hasTrigger = false
        for _, trigger in ipairs(keywordCache.triggers) do
            if FindWholeWord(normalizedMsg, trigger) then
                hasTrigger = true
                break
            end
        end
        if not hasTrigger then return false end
    end

    local matches = {}
    local matchCount = 0

    -- ID-based matching (language-agnostic), runs on the raw message
    for numericID, linkType in pairs(ns.ExtractLinkIDs(message)) do
        local recipeID = itemIDCache[numericID]
        if recipeID and ns.db.trackedRecipes[recipeID] then
            local spamKey = sender .. ":" .. recipeID
            local now = GetTime()
            if not recentAlerts[spamKey] or (now - recentAlerts[spamKey]) > COOLDOWN then
                recentAlerts[spamKey] = now
                matches[recipeID] = ns.db.trackedRecipes[recipeID]
                matchCount = matchCount + 1
                ns.Debug("ChatScanner: ID match — " .. numericID .. " (" .. linkType .. ") -> recipeID " .. recipeID)
            end
        end
    end

    if matchCount > 0 then
        ns.FireCallback("ALERT_FIRED", sender, message, matches)
        return true
    end

    -- Fallback: plain-text name matching
    for recipeName, recipeID in pairs(lookupCache) do
        if string.find(normalizedMsg, recipeName, 1, true) then
            local spamKey = sender .. ":" .. recipeID
            local now = GetTime()
            if not recentAlerts[spamKey] or (now - recentAlerts[spamKey]) > COOLDOWN then
                recentAlerts[spamKey] = now
                matches[recipeID] = ns.db.trackedRecipes[recipeID]
                matchCount = matchCount + 1
            end
        end
    end

    if matchCount > 0 then
        ns.FireCallback("ALERT_FIRED", sender, message, matches)
        return true
    end
    return false
end

----------------------------------------------------------------------
-- Scan a chat message against keyword lists
----------------------------------------------------------------------
local function ScanKeywords(message, sender, event)
    if not ns.db or not ns.db.settings.keywordScanEnabled then return end
    if #keywordCache.triggers == 0 then return end
    if #keywordCache.pairs == 0 and #keywordCache.freewords == 0 then return end

    local playerName = UnitName("player")
    if sender and playerName and sender:find(playerName, 1, true) then return end

    local normalizedMsg = ns.NormalizeString(message)

    local matchedTriggers = {}
    for _, trigger in ipairs(keywordCache.triggers) do
        if FindWholeWord(normalizedMsg, trigger) then
            table.insert(matchedTriggers, trigger)
        end
    end
    if #matchedTriggers == 0 then return end

    local matchedProfession, matchedItem
    for _, pair in ipairs(keywordCache.pairs) do
        local foundProf, foundItem
        for _, prof in ipairs(pair.professions) do
            if string.find(normalizedMsg, prof, 1, true) then
                foundProf = prof
                break
            end
        end
        if foundProf then
            for _, item in ipairs(pair.items) do
                if string.find(normalizedMsg, item, 1, true) then
                    foundItem = item
                    break
                end
            end
        end
        if foundProf and foundItem then
            matchedProfession, matchedItem = foundProf, foundItem
            break
        end
    end

    local matchedFreeword
    if not matchedProfession then
        for _, word in ipairs(keywordCache.freewords) do
            if string.find(normalizedMsg, word, 1, true) then
                matchedFreeword = word
                break
            end
        end
    end

    if not matchedProfession and not matchedFreeword then return end

    local spamKey = sender .. ":kw"
    local now = GetTime()
    if recentAlerts[spamKey] and (now - recentAlerts[spamKey]) <= COOLDOWN then return end
    recentAlerts[spamKey] = now

    ns.FireCallback("KEYWORD_ALERT_FIRED", sender, message, {
        triggers = matchedTriggers,
        professions = matchedProfession and { matchedProfession } or {},
        items = matchedItem and { matchedItem } or {},
        freewords = matchedFreeword and { matchedFreeword } or {},
    })
end

----------------------------------------------------------------------
-- Chat event handler
----------------------------------------------------------------------
local scanFrame = CreateFrame("Frame")

local function OnChatEvent(self, event, message, sender)
    if ns.db and ns.db.settings.dndEnabled then return end
    if not ScanMessage(message, sender, event) then
        ScanKeywords(message, sender, event)
    end
end

local function StartScanning()
    if not ns.db then return end
    scanFrame:UnregisterAllEvents()
    scanFrame:RegisterEvent("CHAT_MSG_CHANNEL")
    scanFrame:SetScript("OnEvent", OnChatEvent)
    ns.Debug("ChatScanner: scanning started")
end

function ns.RestartScanner()
    StartScanning()
end

----------------------------------------------------------------------
-- Wire up to the event bus
----------------------------------------------------------------------
ns.RegisterCallback("DB_READY", function()
    RebuildCache()
    RebuildKeywordCache()
    StartScanning()
end)

ns.RegisterCallback("RECIPE_TRACKED", RebuildCache)
ns.RegisterCallback("RECIPE_UNTRACKED", RebuildCache)
ns.RegisterCallback("CONCENTRATION_MUTE_CHANGED", RebuildCache)
ns.RegisterCallback("KEYWORDS_CHANGED", RebuildKeywordCache)
