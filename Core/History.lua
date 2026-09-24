local addonName, ns = ...

-- Live list: points at ns.db.history after DB_READY (persisted).
-- Before DB is ready, use a temporary table so early alerts still work.
ns.alertHistory = {}

local MAX_HISTORY = 100

local function EnsureStats()
    if not ns.db then return nil end
    ns.db.historyStats = ns.db.historyStats or {
        totals = { completed = 0, rejected = 0, skipped = 0 },
        byProfession = {},
    }
    local s = ns.db.historyStats
    s.totals = s.totals or { completed = 0, rejected = 0, skipped = 0 }
    s.byProfession = s.byProfession or {}
    return s
end

local function ProfessionKey(entry)
    if not entry then return "Unknown" end
    if entry.professionName and entry.professionName ~= "" then
        return entry.professionName
    end
    if entry.matchData and entry.matchData.professionName and entry.matchData.professionName ~= "" then
        return entry.matchData.professionName
    end
    if entry.alertType == "keyword" then
        return "Keywords"
    end
    return "Unknown"
end

local function BumpStat(entry, field)
    local s = EnsureStats()
    if not s or not field then return end
    s.totals[field] = (s.totals[field] or 0) + 1
    local key = ProfessionKey(entry)
    s.byProfession[key] = s.byProfession[key] or { completed = 0, rejected = 0, skipped = 0 }
    s.byProfession[key][field] = (s.byProfession[key][field] or 0) + 1
    ns.FireCallback("HISTORY_STATS_UPDATED")
end

--- Migrate old session-style entries (replied boolean only) → status.
local function NormalizeEntry(e)
    if not e then return end
    if not e.status then
        if e.notified then
            e.status = "done"
        elseif e.replied then
            e.status = "contacted"
        else
            e.status = "new"
        end
    end
    e.professionName = e.professionName or ProfessionKey(e)
    return e
end

function ns.BindHistoryDB()
    if not ns.db then return end
    ns.db.history = ns.db.history or {}
    -- Normalize any legacy rows
    for _, e in ipairs(ns.db.history) do
        NormalizeEntry(e)
    end
    ns.alertHistory = ns.db.history
    EnsureStats()
    ns.FireCallback("HISTORY_UPDATED")
end

----------------------------------------------------------------------
-- Record an alert (merge duplicates from same sender)
----------------------------------------------------------------------
function ns.AddToHistory(sender, message, matches, recipeNames, alertType, keywordMatches)
    if not ns.alertHistory then ns.alertHistory = {} end
    local aType = alertType or "recipe"
    local list = ns.alertHistory

    for _, existing in ipairs(list) do
        if existing.sender == sender and existing.alertType == aType then
            local isDuplicate = (aType == "keyword") or (existing.recipeNames == recipeNames)
            -- Only merge if still open (not done / rejected / skipped)
            local open = not existing.status or existing.status == "new" or existing.status == "contacted"
            if isDuplicate and open then
                existing.count = (existing.count or 1) + 1
                existing.time = date("%H:%M:%S")
                existing.timestamp = time()
                existing.message = message
                ns.FireCallback("HISTORY_UPDATED")
                return existing
            end
        end
    end

    local recipeIDs = {}
    local firstMatchData = nil
    local professionName = nil
    if matches then
        for recipeID, data in pairs(matches) do
            table.insert(recipeIDs, recipeID)
            if not firstMatchData then
                firstMatchData = data
                professionName = data.professionName
            end
        end
    end
    if aType == "keyword" then
        professionName = "Keywords"
    end

    local entry = {
        id = tostring(time()) .. "-" .. tostring(math.random(1000, 9999)),
        time = date("%H:%M:%S"),
        timestamp = time(),
        sender = sender,
        message = message,
        recipeNames = recipeNames,
        recipeIDs = recipeIDs,
        matchData = firstMatchData,
        professionName = professionName or "Unknown",
        feeOffered = firstMatchData and ns.GetRecipeFee and ns.GetRecipeFee(firstMatchData) or nil,
        status = "new",       -- new | contacted | done | rejected | skipped
        replied = false,      -- legacy mirror of contacted+
        notified = false,
        alertType = aType,
        keywordMatches = keywordMatches,
        count = 1,
        characterContacted = nil,
        characterCompleted = nil,
    }
    table.insert(list, 1, entry)
    while #list > MAX_HISTORY do
        table.remove(list)
    end
    ns.FireCallback("HISTORY_UPDATED")
    return entry
end

----------------------------------------------------------------------
-- Status transitions
----------------------------------------------------------------------
function ns.HistoryMarkContacted(entry)
    if not entry then return end
    if entry.status == "done" or entry.status == "rejected" or entry.status == "skipped" then
        -- still allow re-whisper without changing terminal state
        entry.replied = true
        return
    end
    entry.status = "contacted"
    entry.replied = true
    entry.characterContacted = ns.GetPlayerFullName and ns.GetPlayerFullName() or UnitName("player")
    entry.timeContacted = time()
    ns.FireCallback("HISTORY_UPDATED")
end

function ns.HistoryMarkDone(entry)
    if not entry then return end
    if entry.status == "done" then return end
    entry.status = "done"
    entry.notified = true
    entry.replied = true
    entry.characterCompleted = ns.GetPlayerFullName and ns.GetPlayerFullName() or UnitName("player")
    entry.timeCompleted = time()
    BumpStat(entry, "completed")
    ns.FireCallback("HISTORY_UPDATED")
end

--- Declined / not interested
function ns.HistoryMarkRejected(entry)
    if not entry then return end
    if entry.status == "rejected" or entry.status == "done" or entry.status == "skipped" then return end
    entry.status = "rejected"
    entry.timeClosed = time()
    BumpStat(entry, "rejected")
    ns.FireCallback("HISTORY_UPDATED")
end

--- Delayed / someone else took the order
function ns.HistoryMarkSkipped(entry)
    if not entry then return end
    if entry.status == "skipped" or entry.status == "done" or entry.status == "rejected" then return end
    entry.status = "skipped"
    entry.timeClosed = time()
    BumpStat(entry, "skipped")
    ns.FireCallback("HISTORY_UPDATED")
end

function ns.HistoryClear()
    if ns.db then
        wipe(ns.db.history or {})
        ns.alertHistory = ns.db.history
    else
        wipe(ns.alertHistory)
    end
    ns.FireCallback("HISTORY_UPDATED")
end

function ns.GetHistoryStats()
    return EnsureStats()
end

ns.RegisterCallback("DB_READY", function()
    ns.BindHistoryDB()
end)