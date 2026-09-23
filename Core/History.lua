local addonName, ns = ...

-- Session only — never written to SavedVariables. A restart clears it,
-- same as the original.
ns.alertHistory = {}

----------------------------------------------------------------------
-- Record an alert, merging into an existing entry if it's a repeat from
-- the same sender rather than spamming a new history row per message.
----------------------------------------------------------------------
function ns.AddToHistory(sender, message, matches, recipeNames, alertType, keywordMatches)
    local aType = alertType or "recipe"

    for _, existing in ipairs(ns.alertHistory) do
        if existing.sender == sender and existing.alertType == aType then
            local isDuplicate = (aType == "keyword") or (existing.recipeNames == recipeNames)
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
        matchData = firstMatchData, -- used to rebuild the whisper if replied to later
        replied = false,
        alertType = aType,
        keywordMatches = keywordMatches,
        count = 1,
    }
    table.insert(ns.alertHistory, 1, entry) -- newest first
    if #ns.alertHistory > 100 then
        table.remove(ns.alertHistory)
    end
    ns.FireCallback("HISTORY_UPDATED")
    return entry
end
