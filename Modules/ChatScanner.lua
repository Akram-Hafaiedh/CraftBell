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
-- Secret Values (WoW 12.0+): chat message/sender can be secret while the
-- player is in a communication-restricted context (dungeon/raid/PvP/etc.).
-- Tainted addon code cannot index or method-call secret strings
-- (e.g. sender:find → "attempt to index local 'sender' (a secret string)").
-- When we cannot read the text, skip scanning silently — trade chat outside
-- those contexts remains fully scannable.
----------------------------------------------------------------------
local function CanAccessChatText(value)
    if value == nil then return false end
    -- issecretvalue / canaccessvalue exist on 12.0+; absent on older clients.
    if issecretvalue and issecretvalue(value) then
        if canaccessvalue then
            return canaccessvalue(value) and true or false
        end
        return false
    end
    return true
end

--- Safe substring search that never method-calls the haystack (secret-safe).
local function SafeFind(haystack, needle, plain)
    if not haystack or not needle or needle == "" then return nil end
    if not CanAccessChatText(haystack) then return nil end
    return string.find(haystack, needle, 1, plain ~= false)
end

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
        local mode = (pair.mode == "or") and "or" or "and"
        table.insert(keywordCache.pairs, {
            professions = SplitCSV(pair.professions or ""),
            items = SplitCSV(pair.items or ""),
            mode = mode,
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
    -- Cannot inspect secret chat payloads under addon taint
    if not CanAccessChatText(message) then
        return
    end

    local playerName = UnitName("player")
    if sender and playerName and CanAccessChatText(sender) then
        if SafeFind(sender, playerName, true) then
            return
        end
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
        if ns.DebugBeginRun then
            ns.DebugBeginRun("live", "ID match from " .. tostring(sender))
            ns.DebugStep("match", true, matchCount .. " recipe(s) via item link")
            ns.DebugStep("callback", true, "FireCallback(ALERT_FIRED)")
        end
        ns.FireCallback("ALERT_FIRED", sender, message, matches)
        return true
    end

    -- Fallback: plain-text name matching (whole-word when enabled)
    local useWholeWord = not ns.db.settings or ns.db.settings.recipeWholeWord ~= false
    for recipeName, recipeID in pairs(lookupCache) do
        local found = useWholeWord
            and FindWholeWord(normalizedMsg, recipeName)
            or string.find(normalizedMsg, recipeName, 1, true)
        if found then
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
        if ns.DebugBeginRun then
            ns.DebugBeginRun("live", "name match from " .. tostring(sender))
            ns.DebugStep("match", true, matchCount .. " recipe(s) via name")
            ns.DebugStep("callback", true, "FireCallback(ALERT_FIRED)")
        end
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
    if not CanAccessChatText(message) then return end

    local playerName = UnitName("player")
    if sender and playerName and CanAccessChatText(sender) then
        if SafeFind(sender, playerName, true) then return end
    end

    local normalizedMsg = ns.NormalizeString(message)

    local matchedTriggers = {}
    for _, trigger in ipairs(keywordCache.triggers) do
        if FindWholeWord(normalizedMsg, trigger) then
            table.insert(matchedTriggers, trigger)
        end
    end
    if #matchedTriggers == 0 then return end

    -- Pair modes: "and" = left+right both required (default); "or" = either side enough
    local matchedProfession, matchedItem
    local pairMatched = false
    for _, pair in ipairs(keywordCache.pairs) do
        local foundProf, foundItem
        for _, prof in ipairs(pair.professions) do
            if string.find(normalizedMsg, prof, 1, true) then
                foundProf = prof
                break
            end
        end
        for _, item in ipairs(pair.items) do
            if string.find(normalizedMsg, item, 1, true) then
                foundItem = item
                break
            end
        end
        local mode = pair.mode or "and"
        local matched
        if mode == "or" then
            matched = foundProf or foundItem
        else
            matched = foundProf and foundItem
        end
        if matched then
            matchedProfession, matchedItem = foundProf, foundItem
            pairMatched = true
            break
        end
    end

    local matchedFreeword
    if not pairMatched then
        for _, word in ipairs(keywordCache.freewords) do
            if string.find(normalizedMsg, word, 1, true) then
                matchedFreeword = word
                break
            end
        end
    end

    if not pairMatched and not matchedFreeword then return end

    local spamKey = sender .. ":kw"
    local now = GetTime()
    if recentAlerts[spamKey] and (now - recentAlerts[spamKey]) <= COOLDOWN then return end
    recentAlerts[spamKey] = now

    if ns.DebugBeginRun then
        ns.DebugBeginRun("live", "keyword match from " .. tostring(sender))
        ns.DebugStep("match", true, "keyword")
        ns.DebugStep("callback", true, "FireCallback(KEYWORD_ALERT_FIRED)")
    end
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

----------------------------------------------------------------------
-- Whisper log (independent of trade scan channel filters)
----------------------------------------------------------------------
local whisperFrame = CreateFrame("Frame")
whisperFrame:RegisterEvent("CHAT_MSG_WHISPER")
whisperFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
whisperFrame:SetScript("OnEvent", function(_, event, message, sender)
    if not ns.RecordWhisper then return end
    if message ~= nil and CanAccessChatText and not CanAccessChatText(message) then return end
    if event == "CHAT_MSG_WHISPER" then
        -- Incoming: other player -> you
        ns.RecordWhisper(sender, message, "in")
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        -- Outgoing: you -> other (sender is the target)
        ns.RecordWhisper(sender, message, "out")
    end
end)


--- Map CHAT_MSG_* / channel base name → settings.chatChannels key
local function ChannelAllowed(event, channelBaseName)
    local ch = ns.db and ns.db.settings and ns.db.settings.chatChannels
    if not ch then
        -- defaults if missing
        ch = { trade = true, services = true, say = true, yell = true }
    end
    if event == "CHAT_MSG_SAY" then return ch.say ~= false end
    if event == "CHAT_MSG_YELL" then return ch.yell ~= false end
    if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_OFFICER" then return ch.guild end
    if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then return ch.party end
    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_RAID_WARNING" then
        return ch.raid
    end
    if event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
        return ch.instance
    end
    if event == "CHAT_MSG_CHANNEL" then
        if channelBaseName and not CanAccessChatText(channelBaseName) then
            -- Secret channel name under lockdown — cannot classify; skip
            return false
        end
        local name = string.lower(channelBaseName or "")
        -- strip "1. " style prefixes sometimes present
        name = string.gsub(name, "^%d+%.%s*", "")
        if string.find(name, "trade", 1, true) then return ch.trade ~= false end
        if string.find(name, "services", 1, true) or string.find(name, "service", 1, true) then
            return ch.services ~= false
        end
        if string.find(name, "general", 1, true) then return ch.general end
        if string.find(name, "lookingforgroup", 1, true)
            or string.find(name, "looking for group", 1, true)
            or name == "lfg" then
            return ch.lookingforgroup
        end
        -- unknown channel: ignore by default
        return false
    end
    return false
end

local function OnChatEvent(self, event, message, sender, ...)
    if ns.db and ns.db.settings.dndEnabled then return end
    -- Secret chat text under communication lockdown: nothing to scan, no error
    if message ~= nil and not CanAccessChatText(message) then
        return
    end
    -- ... = languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName
    local _, channelName, _, _, _, _, channelBase = ...
    if not ChannelAllowed(event, channelBase or channelName) then
        -- No per-message log: high-volume channels would flood chat.
        return
    end
    -- Scan only. Matches log via DebugBeginRun / ID match lines — not every line.
    if not ScanMessage(message, sender, event) then
        ScanKeywords(message, sender, event)
    end
end

local function StartScanning()
    if not ns.db then return end
    scanFrame:UnregisterAllEvents()
    local ch = ns.db.settings.chatChannels or {}
    scanFrame:RegisterEvent("CHAT_MSG_CHANNEL")
    if ch.say ~= false then scanFrame:RegisterEvent("CHAT_MSG_SAY") end
    if ch.yell ~= false then scanFrame:RegisterEvent("CHAT_MSG_YELL") end
    if ch.guild then
        scanFrame:RegisterEvent("CHAT_MSG_GUILD")
        scanFrame:RegisterEvent("CHAT_MSG_OFFICER")
    end
    if ch.party then
        scanFrame:RegisterEvent("CHAT_MSG_PARTY")
        scanFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
    end
    if ch.raid then
        scanFrame:RegisterEvent("CHAT_MSG_RAID")
        scanFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
        scanFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
    end
    if ch.instance then
        scanFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
        scanFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
    end
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