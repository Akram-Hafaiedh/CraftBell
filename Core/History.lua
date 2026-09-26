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
                -- Preserve first-seen; refresh last-seen
                if not existing.firstTimestamp then
                    existing.firstTimestamp = existing.timestamp or time()
                    existing.firstTime = existing.time or date("%H:%M:%S")
                end
                existing.time = date("%H:%M:%S")
                existing.timestamp = time()
                existing.message = message
                if matches and not existing.itemLink then
                    for _, data in pairs(matches) do
                        if data.itemLink then
                            existing.itemLink = data.itemLink
                            existing.iconID = data.iconID or existing.iconID
                            break
                        end
                    end
                end
                -- Ping timeline (cap to avoid unbounded growth)
                existing.pings = existing.pings or { existing.firstTimestamp }
                table.insert(existing.pings, existing.timestamp)
                while #existing.pings > 30 do
                    table.remove(existing.pings, 1)
                end
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

    local now = time()
    local timeStr = date("%H:%M:%S")
    local entry = {
        id = tostring(now) .. "-" .. tostring(math.random(1000, 9999)),
        time = timeStr,              -- last seen (display)
        timestamp = now,             -- last seen (unix)
        firstTime = timeStr,         -- first seen (display)
        firstTimestamp = now,        -- first seen (unix)
        pings = { now },             -- timeline of each match
        sender = sender,
        message = message,
        recipeNames = recipeNames,
        recipeIDs = recipeIDs,
        matchData = firstMatchData,
        professionName = professionName or "Unknown",
        feeOffered = firstMatchData and ns.GetRecipeFee and ns.GetRecipeFee(firstMatchData) or nil,
        itemLink = firstMatchData and firstMatchData.itemLink or nil,
        iconID = firstMatchData and firstMatchData.iconID or nil,
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

--- Remove synthetic self-test / manual test rows (CBSelfTest-*, TestBuyer*, Testbuyer).
--- plain string.find does NOT treat ^ as start anchor — use prefix checks.
local function IsTestSender(sender)
    if not sender or sender == "" then return false end
    if sender:sub(1, 10) == "CBSelfTest" then return true end
    if sender:sub(1, 9) == "TestBuyer" then return true end
    if sender:sub(1, 9) == "Testbuyer" then return true end
    return false
end

function ns.HistoryClearSelfTests()
    local list = ns.alertHistory
    if not list then return 0 end
    local removed = 0
    for i = #list, 1, -1 do
        if IsTestSender(list[i].sender) then
            table.remove(list, i)
            removed = removed + 1
        end
    end
    if removed > 0 then
        ns.FireCallback("HISTORY_UPDATED")
    end
    return removed
end

--- Reset completed / rejected / skipped counters (does not wipe the queue).
function ns.HistoryClearStats()
    if not ns.db then return end
    ns.db.historyStats = {
        totals = { completed = 0, rejected = 0, skipped = 0 },
        byProfession = {},
    }
    ns.FireCallback("HISTORY_STATS_UPDATED")
    ns.FireCallback("HISTORY_UPDATED")
end


--- Human span between two unix times (e.g. "3m", "1h 12m").
function ns.FormatDuration(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 0 then seconds = 0 end
    if seconds < 60 then
        return string.format("%ds", seconds)
    end
    local m = math.floor(seconds / 60)
    if m < 60 then
        return string.format("%dm", m)
    end
    local h = math.floor(m / 60)
    m = m % 60
    if h < 48 then
        if m > 0 then
            return string.format("%dh %dm", h, m)
        end
        return string.format("%dh", h)
    end
    local d = math.floor(h / 24)
    return string.format("%dd", d)
end

--- Summary for a history entry: count + how long since first ping.
function ns.GetHistoryPingSummary(entry)
    if not entry then return "" end
    local count = entry.count or 1
    local first = entry.firstTimestamp or entry.timestamp
    local last = entry.timestamp or first
    if not first then
        return count > 1 and ("×" .. count) or ""
    end
    local span = (last or first) - first
    if count <= 1 then
        return ""
    end
    if span > 0 then
        return string.format("×%d · %s", count, ns.FormatDuration(span))
    end
    return "×" .. count
end

function ns.GetHistoryStats()
    return EnsureStats()
end

ns.RegisterCallback("DB_READY", function()
    ns.BindHistoryDB()
end)