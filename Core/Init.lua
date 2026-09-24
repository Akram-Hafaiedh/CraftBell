local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Main window stub — replaced once MainWindow.lua exists
----------------------------------------------------------------------
function ns.ToggleMainWindow()
    ns.Print(L["MAIN_WINDOW_TODO"] or "Settings window isn't built yet — coming in MainWindow.lua. Try /cb test or /cb dump for now.")
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "CraftBellEventFrame", UIParent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGOUT" then
        if ns.focusModeActive then
            ns.SetFocusMode(false)
        end
    elseif event == "ADDON_LOADED" and arg1 == addonName then
        ns.InitializeDB()
        if ns.UI and ns.UI.ApplyAppearance then
            ns.UI.ApplyAppearance()
        end
        local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
        ns.Print("v" .. version .. " loaded.")
        ns.FireCallback("DB_READY")

    elseif event == "PLAYER_LOGIN" then
        ns.FireCallback("PLAYER_READY")
    end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_CRAFTBELL1 = "/craftbell"
SLASH_CRAFTBELL2 = "/cb"
SlashCmdList["CRAFTBELL"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "test" then
        if not ns.db or not next(ns.db.trackedRecipes) then
            ns.Print(L["NO_RECIPE_TRACKED"] or "No recipes tracked yet — track one from the profession window first.")
            return
        end
        local firstID, firstData
        for id, data in pairs(ns.db.trackedRecipes) do
            firstID, firstData = id, data
            break
        end
        local fakeMessage = string.format(L["TEST_FAKE_MESSAGE"] or "LF someone to craft %s, will pay!",
            firstData.recipeName or "an item")
        ns.Print(L["ALERT_SIMULATION"] or "Simulating an alert...")
        ns.FireCallback("ALERT_FIRED", "Testbuyer", fakeMessage, { [firstID] = firstData })

    elseif msg == "testcross" then
        if not ns.db or not next(ns.db.trackedRecipes) then
            ns.Print(L["NO_RECIPE_TRACKED"] or "No recipes tracked yet — track one from the profession window first.")
            return
        end
        local firstID, firstData
        for id, data in pairs(ns.db.trackedRecipes) do
            firstID, firstData = id, data
            break
        end
        local fakeData = CopyTable(firstData)
        fakeData.character = { name = "TestAlt", realm = "SomeOtherRealm", fullName = "TestAlt-SomeOtherRealm" }
        if fakeData.owners then
            fakeData.owners = { ["TestAlt-SomeOtherRealm"] = fakeData.character }
            fakeData.assignedCharacter = "TestAlt-SomeOtherRealm"
        end
        local fakeMessage = string.format(L["TEST_FAKE_MESSAGE"] or "LF someone to craft %s, will pay!",
            firstData.recipeName or "an item")
        ns.Print(L["ALERT_SIMULATION"] or "Simulating an alert (mismatched realm)...")
        ns.FireCallback("ALERT_FIRED", "Testbuyer", fakeMessage, { [firstID] = fakeData })

    elseif msg == "focus" then
        ns.ToggleFocusMode()

    elseif msg == "toast" then
        if ns.ToggleToastEditMode then
            ns.ToggleToastEditMode()
        else
            ns.Print("Toast edit mode not available.")
        end

    elseif msg == "debug" then
        ns.debugEnabled = not ns.debugEnabled
        ns.Print("Debug mode: " .. (ns.debugEnabled and "ON" or "OFF"))

    elseif msg == "dump" or msg:match("^dump ") then
        ns.HandleDumpCommand(msg)

    elseif msg == "bulk" then
        if ns.BulkTrackCurrentProfession then
            ns.BulkTrackCurrentProfession()
        else
            ns.Print("Bulk track not available — open a profession window and ensure Database.lua is updated.")
        end

    elseif msg == "bulk all" then
        if ns.BulkTrackCurrentProfession then
            ns.BulkTrackCurrentProfession({ forceAll = true })
        else
            ns.Print("Bulk track not available.")
        end

    elseif msg == "bulk current" then
        if ns.BulkTrackCurrentProfession then
            ns.BulkTrackCurrentProfession({ forceCurrent = true })
        else
            ns.Print("Bulk track not available.")
        end

    elseif msg == "bulk orders" or msg == "bulk orders on" then
        if ns.db then
            ns.db.settings.bulkTrackOrdersOnly = true
            ns.Print((L["BULK_OPT_ORDERS"] or "Orders only") .. ": ON")
        end

    elseif msg == "bulk orders off" then
        if ns.db then
            ns.db.settings.bulkTrackOrdersOnly = false
            ns.Print((L["BULK_OPT_ORDERS"] or "Orders only") .. ": OFF")
        end

    elseif msg == "exp" or msg == "exp list" or msg == "expansions" then
        ns.PrintBulkExpansionStatus()

    elseif msg:match("^exp add ") or msg:match("^expansions add ") then
        local arg = msg:match("^exp add%s+(.+)$") or msg:match("^expansions add%s+(.+)$")
        ns.SetBulkExpansion(arg, true)

    elseif msg:match("^exp remove ") or msg:match("^exp rm ") or msg:match("^expansions remove ") then
        local arg = msg:match("^exp remove%s+(.+)$") or msg:match("^exp rm%s+(.+)$")
            or msg:match("^expansions remove%s+(.+)$")
        ns.SetBulkExpansion(arg, false)

    elseif msg == "exp clear" or msg == "expansions clear" then
        ns.ClearBulkExpansions()

    elseif msg == "exp all" or msg == "exp alltrained" or msg == "expansions all" then
        ns.SelectAllTrainedExpansions()

    elseif msg == "clear" or msg == "clear char" or msg == "clear character" then
        ns.ClearCurrentCharacter()

    elseif msg == "clear prof" or msg == "clear profession" then
        ns.ClearCurrentProfession()

    elseif msg == "clear all" then
        ns.ClearAllRecipes()

    elseif msg == "help" or msg == "" then
        if msg == "" then
            ns.ToggleMainWindow()
            return
        end
        ns.Print("CraftBell commands:")
        ns.Print("  /cb bulk — track using expansion checklist (or selected if empty)")
        ns.Print("  /cb bulk current — force currently selected expansion only")
        ns.Print("  /cb bulk all — all trained expansions (one-shot)")
        ns.Print("  /cb bulk orders [on|off] — only Crafting Orders–eligible recipes (default on)")
        ns.Print("  /cb exp list — show expansions + checklist + trained status")
        ns.Print("  /cb exp add <name|id> — check an expansion for bulk track")
        ns.Print("  /cb exp remove <name|id> — uncheck an expansion")
        ns.Print("  /cb exp all — check every trained expansion")
        ns.Print("  /cb exp clear — empty checklist (selected expansion only)")
        ns.Print("  /cb clear | clear prof | clear all — reset tracked recipes")
        ns.Print("  /cb toast — drag alert popup position")
        ns.Print("  /cb test / testcross / focus / debug")
        ns.Print("  /cb dump — summary (no chat flood)")
        ns.Print("  /cb dump 20 | next | owners | search <text> | frame")
        ns.Print("  /cb help — this list")

    else
        ns.Print("Unknown command. Type /cb help")
    end
end

----------------------------------------------------------------------
-- /cb dump — summary, pagination, filters, scrollable frame
----------------------------------------------------------------------
local DUMP_PAGE = 20
ns.dumpState = ns.dumpState or {
    ids = {},
    offset = 0,
    filter = "all",
    search = "",
}

local function DumpFormatLine(id, data)
    local owners = {}
    if data.owners then
        for fullName in pairs(data.owners) do
            table.insert(owners, fullName)
        end
        table.sort(owners)
    end
    local ownerStr = #owners > 0 and table.concat(owners, ", ")
        or tostring(data.character and data.character.fullName or "?")
    return string.format(
        "ID=%s  %s  prof=%s (%s)  assigned=%s  owners=[%s]  fee=%s",
        tostring(id),
        tostring(data.recipeName or "?"),
        tostring(data.professionName or "?"),
        tostring(data.professionID or "?"),
        tostring(data.assignedCharacter or "none"),
        ownerStr,
        tostring(ns.GetRecipeFee and ns.GetRecipeFee(data) or 0)
    )
end

local function DumpCollectIds(filter, search)
    local ids = {}
    if not ns.db or not ns.db.trackedRecipes then return ids end
    local q = (search or ""):lower()
    for id, data in pairs(ns.db.trackedRecipes) do
        local include = true
        if filter == "owners" then
            local n = 0
            if data.owners then for _ in pairs(data.owners) do n = n + 1 end end
            include = n > 1
        elseif filter == "search" and q ~= "" then
            local name = (data.recipeName or ""):lower()
            local prof = (data.professionName or ""):lower()
            local assigned = (data.assignedCharacter or ""):lower()
            include = name:find(q, 1, true) or prof:find(q, 1, true) or assigned:find(q, 1, true)
                or tostring(id):find(q, 1, true)
        end
        if include then
            table.insert(ids, id)
        end
    end
    table.sort(ids, function(a, b)
        local da = ns.db.trackedRecipes[a]
        local db_ = ns.db.trackedRecipes[b]
        return (da.recipeName or "") < (db_.recipeName or "")
    end)
    return ids
end

local function DumpPrintSummary()
    if not ns.db or not next(ns.db.trackedRecipes) then
        ns.Print("No recipes tracked.")
        return
    end
    local total, multi = 0, 0
    local byProf = {}
    for _, data in pairs(ns.db.trackedRecipes) do
        total = total + 1
        local n = 0
        if data.owners then for _ in pairs(data.owners) do n = n + 1 end end
        if n > 1 then multi = multi + 1 end
        local pname = data.professionName or "?"
        byProf[pname] = (byProf[pname] or 0) + 1
    end
    ns.Print(string.format("Tracked: %d recipes | %d multi-owner", total, multi))
    local profs = {}
    for name, count in pairs(byProf) do
        table.insert(profs, { name = name, count = count })
    end
    table.sort(profs, function(a, b) return a.count > b.count end)
    for _, p in ipairs(profs) do
        ns.Print(string.format("  %s: %d", p.name, p.count))
    end
    ns.Print("  /cb dump 20 — first page in chat")
    ns.Print("  /cb dump next — next page")
    ns.Print("  /cb dump owners — multi-owner only")
    ns.Print("  /cb dump search <text> — filter by name/prof/id")
    ns.Print("  /cb dump frame — full list in a scrollable window")
end

local function DumpPrintPage(resetOffset)
    local st = ns.dumpState
    if resetOffset then st.offset = 0 end
    if not st.ids or #st.ids == 0 then
        ns.Print("Nothing to dump for this filter.")
        return
    end
    local from = st.offset + 1
    local to = math.min(st.offset + DUMP_PAGE, #st.ids)
    if from > #st.ids then
        ns.Print(string.format("End of list (%d total). /cb dump to reset, or /cb dump frame.", #st.ids))
        return
    end
    ns.Print(string.format(
        "Dump %d–%d of %d  [%s]%s",
        from, to, #st.ids,
        st.filter or "all",
        (st.filter == "search" and st.search ~= "") and (" \"" .. st.search .. "\"") or ""
    ))
    for i = from, to do
        local id = st.ids[i]
        local data = ns.db.trackedRecipes[id]
        if data then
            ns.Print(DumpFormatLine(id, data))
        end
    end
    st.offset = to
    if to < #st.ids then
        ns.Print(string.format("… %d more — /cb dump next", #st.ids - to))
    else
        ns.Print("(end of list)")
    end
end

local function DumpShowFrame()
    local st = ns.dumpState
    if not st.ids or #st.ids == 0 then
        st.ids = DumpCollectIds("all", "")
        st.filter = "all"
        st.search = ""
    end
    if #st.ids == 0 then
        ns.Print("No recipes tracked.")
        return
    end
    local lines = {
        string.format("CraftBell dump — %d recipes  filter=%s %s",
            #st.ids, st.filter or "all",
            (st.search and st.search ~= "") and ("\"" .. st.search .. "\"") or ""),
        string.rep("-", 72),
    }
    for _, id in ipairs(st.ids) do
        local data = ns.db.trackedRecipes[id]
        if data then
            table.insert(lines, DumpFormatLine(id, data))
        end
    end
    if ns.ShowTextFrame then
        ns.ShowTextFrame(
            "CraftBell dump",
            table.concat(lines, "\n"),
            string.format("%d recipes", #st.ids)
        )
    else
        ns.Print("Text frame not loaded — use /cb dump 20 instead.")
    end
end

function ns.HandleDumpCommand(msg)
    msg = (msg or ""):lower():trim()
    if msg == "dump" then
        DumpPrintSummary()
        return
    end

    local rest = msg:match("^dump%s+(.+)$")
    if not rest then
        DumpPrintSummary()
        return
    end
    rest = rest:match("^%s*(.-)%s*$")

    if rest == "next" or rest == "more" then
        if not ns.dumpState.ids or #ns.dumpState.ids == 0 then
            ns.dumpState.ids = DumpCollectIds("all", "")
            ns.dumpState.filter = "all"
            ns.dumpState.search = ""
            ns.dumpState.offset = 0
        end
        DumpPrintPage(false)
        return
    end

    if rest == "frame" or rest == "ui" or rest == "window" then
        if not ns.dumpState.ids or #ns.dumpState.ids == 0 then
            ns.dumpState.ids = DumpCollectIds(ns.dumpState.filter or "all", ns.dumpState.search or "")
        end
        DumpShowFrame()
        return
    end

    if rest == "owners" or rest == "multi" then
        ns.dumpState.filter = "owners"
        ns.dumpState.search = ""
        ns.dumpState.ids = DumpCollectIds("owners", "")
        ns.dumpState.offset = 0
        ns.Print(string.format("Multi-owner recipes: %d", #ns.dumpState.ids))
        DumpPrintPage(true)
        return
    end

    local searchArg = rest:match("^search%s+(.+)$") or rest:match("^s%s+(.+)$")
    if searchArg then
        searchArg = searchArg:match("^%s*(.-)%s*$")
        ns.dumpState.filter = "search"
        ns.dumpState.search = searchArg
        ns.dumpState.ids = DumpCollectIds("search", searchArg)
        ns.dumpState.offset = 0
        ns.Print(string.format("Search \"%s\": %d match(es)", searchArg, #ns.dumpState.ids))
        DumpPrintPage(true)
        return
    end

    local n = tonumber(rest)
    if n and n > 0 then
        DUMP_PAGE = math.min(math.floor(n), 50)
        ns.dumpState.filter = "all"
        ns.dumpState.search = ""
        ns.dumpState.ids = DumpCollectIds("all", "")
        ns.dumpState.offset = 0
        DumpPrintPage(true)
        return
    end

    ns.dumpState.filter = "search"
    ns.dumpState.search = rest
    ns.dumpState.ids = DumpCollectIds("search", rest)
    ns.dumpState.offset = 0
    ns.Print(string.format("Search \"%s\": %d match(es)", rest, #ns.dumpState.ids))
    DumpPrintPage(true)
end