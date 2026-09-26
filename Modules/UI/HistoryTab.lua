local addonName, ns = ...
local L = ns.L
local C = ns.UI and ns.UI.C or {
    text = { 0.92, 0.93, 0.95, 1 },
    textMuted = { 0.55, 0.58, 0.62, 1 },
    accent = { 0.15, 0.75, 0.95, 1 },
}

ns.UI.HistoryTab = ns.UI.HistoryTab or {}

local parentFrame, toolbar, scroll, child
local searchBox, statusBtn, sortBtn, statsChip
local searchText = ""
local statusFilter = "all"  -- all | open | done | rejected | skipped
local sortMode = "time"     -- time | sender | status | fee

local STATUS_LABEL = {
    new = "HISTORY_STATUS_NEW",
    contacted = "HISTORY_STATUS_CONTACTED",
    done = "HISTORY_STATUS_DONE",
    rejected = "HISTORY_STATUS_REJECTED",
    skipped = "HISTORY_STATUS_SKIPPED",
}

local STATUS_COLOR = {
    new       = { 0.55, 0.58, 0.62 },
    contacted = { 0.15, 0.75, 0.95 },
    done      = { 0.30, 0.85, 0.45 },
    rejected  = { 0.90, 0.35, 0.35 },
    skipped   = { 0.85, 0.65, 0.25 },
}

local STATUS_FILTER_LABELS = {
    all      = "HISTORY_FILTER_ALL",
    open     = "HISTORY_FILTER_OPEN",
    done     = "HISTORY_FILTER_DONE",
    rejected = "HISTORY_FILTER_REJECTED",
    skipped  = "HISTORY_FILTER_SKIPPED",
}

local SORT_LABELS = {
    time   = "HISTORY_SORT_TIME",
    sender = "HISTORY_SORT_SENDER",
    status = "HISTORY_SORT_STATUS",
    fee    = "HISTORY_SORT_FEE",
}

local STATUS_ORDER = { new = 1, contacted = 2, done = 3, rejected = 4, skipped = 5 }

local function EntryStatus(entry)
    return (entry and entry.status) or (entry and entry.replied and "contacted") or "new"
end

local function StatusText(entry)
    local st = EntryStatus(entry)
    local key = STATUS_LABEL[st] or STATUS_LABEL.new
    return L[key] or st
end

local HISTORY_ICON_SIZE = 28

local function ResolveHistoryIcon(entry)
    if not entry then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    if entry.iconID then return entry.iconID end
    local link = entry.itemLink
    if not link and entry.recipeIDs and ns.db and ns.db.trackedRecipes then
        for _, rid in ipairs(entry.recipeIDs) do
            local data = ns.db.trackedRecipes[rid]
            if data then
                if data.iconID then return data.iconID end
                link = data.itemLink
                if link then break end
            end
        end
    end
    if link then
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then
            if C_Item and C_Item.GetItemIconByID then
                local icon = C_Item.GetItemIconByID(itemID)
                if icon then return icon end
            end
            if GetItemIcon then
                local icon = GetItemIcon(itemID)
                if icon then return icon end
            end
        end
    end
    if entry.alertType == "keyword" then
        return "Interface\\Icons\\INV_Misc_Note_01"
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ResolveHistoryItemLink(entry)
    if entry.itemLink then return entry.itemLink end
    if entry.recipeIDs and ns.db and ns.db.trackedRecipes then
        for _, rid in ipairs(entry.recipeIDs) do
            local data = ns.db.trackedRecipes[rid]
            if data and data.itemLink then return data.itemLink end
        end
    end
    -- recipeNames may already contain a colored link
    local names = entry.recipeNames or ""
    local link = names:match("(|c%x+|H.-|h.-|h|r)")
    return link
end



local historyActionMenu

local function HideHistoryActionMenu()
    if historyActionMenu then historyActionMenu:Hide() end
end

local function ClearMenuChildren(frame)
    for _, c in ipairs({ frame:GetChildren() }) do
        c:Hide()
        c:SetParent(nil)
    end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then
            r:Hide()
        end
    end
end

local function ShowHistoryActionMenu(anchor, entry)
    HideHistoryActionMenu()
    if not historyActionMenu then
        historyActionMenu = CreateFrame("Frame", "CraftBellHistoryActionMenu", UIParent, "BackdropTemplate")
        historyActionMenu:SetFrameStrata("TOOLTIP")
        historyActionMenu:SetClampedToScreen(true)
        if ns.ApplyDarkTheme then ns.ApplyDarkTheme(historyActionMenu) end
        historyActionMenu:EnableMouse(true)
        historyActionMenu:SetScript("OnLeave", function(self)
            C_Timer.After(0.12, function()
                if self:IsShown() and not self:IsMouseOver() then
                    self:Hide()
                end
            end)
        end)
    end

    ClearMenuChildren(historyActionMenu)

    local st = EntryStatus(entry)
    local terminal = (st == "done" or st == "rejected" or st == "skipped")
    local width = 160
    local y = 8

    local title = historyActionMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetTextColor(unpack(C.accent))
    title:SetText(L["ACTIONS"] or "Actions")
    y = 26

    local function AddAction(label, variant, onClick, disabled)
        local btn = ns.CreateUIButton and ns.CreateUIButton(historyActionMenu, {
            width = width - 16, height = 24,
            text = label,
            variant = variant or "ghost",
        }) or CreateFrame("Button", nil, historyActionMenu, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", 8, -y)
        if not ns.CreateUIButton then
            btn:SetSize(width - 16, 24)
            btn:SetText(label)
        end
        if disabled then
            if btn.SetEnabled then btn:SetEnabled(false) end
            if btn.Disable then btn:Disable() end
        else
            btn:SetScript("OnClick", function()
                HideHistoryActionMenu()
                onClick()
                ns.UI.HistoryTab.Refresh()
            end)
        end
        y = y + 28
        return btn
    end

    AddAction(L["WHISPER"] or "Whisper", terminal and "ghost" or "primary", function()
        if ns.WhisperFromHistory then ns.WhisperFromHistory(entry) end
    end, false)

    AddAction(L["HISTORY_READY"] or "Ready", "primary", function()
        if ns.NotifyFromHistory then ns.NotifyFromHistory(entry) end
    end, st == "done")

    AddAction(L["HISTORY_REJECT"] or "Reject", "ghost", function()
        if ns.HistoryMarkRejected then ns.HistoryMarkRejected(entry) end
    end, terminal)

    AddAction(L["HISTORY_SKIP"] or "Skip", "ghost", function()
        if ns.HistoryMarkSkipped then ns.HistoryMarkSkipped(entry) end
    end, terminal)

    historyActionMenu:SetSize(width, y + 8)
    historyActionMenu:ClearAllPoints()
    historyActionMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    historyActionMenu:Show()
    historyActionMenu:Raise()
end


local function MatchesStatusFilter(entry)
    local st = EntryStatus(entry)
    if statusFilter == "all" then return true end
    if statusFilter == "open" then
        return st == "new" or st == "contacted"
    end
    return st == statusFilter
end

local function MatchesSearch(entry)
    local q = (searchText or ""):lower()
    q = q:gsub("^%s+", ""):gsub("%s+$", "")
    if q == "" then return true end
    local hay = table.concat({
        tostring(entry.sender or ""),
        tostring(entry.recipeNames or ""),
        tostring(entry.message or ""),
        tostring(entry.professionName or ""),
        StatusText(entry),
    }, " "):lower()
    return hay:find(q, 1, true) ~= nil
end

local function ShowStatsTooltip(owner)
    local stats = ns.GetHistoryStats and ns.GetHistoryStats()
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L["HISTORY_STATS_TITLE"] or "History stats (lifetime)", 0.15, 0.75, 0.95)
    if not stats or not stats.totals then
        GameTooltip:AddLine(L["HISTORY_STATS_EMPTY"] or "No stats yet.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end
    local t = stats.totals
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(
        L["HISTORY_STATUS_DONE"] or "Done",
        tostring(t.completed or 0),
        0.30, 0.85, 0.45, 1, 1, 1)
    GameTooltip:AddDoubleLine(
        L["HISTORY_STATUS_REJECTED"] or "Rejected",
        tostring(t.rejected or 0),
        0.90, 0.35, 0.35, 1, 1, 1)
    GameTooltip:AddDoubleLine(
        L["HISTORY_STATUS_SKIPPED"] or "Skipped",
        tostring(t.skipped or 0),
        0.85, 0.65, 0.25, 1, 1, 1)

    if stats.byProfession and next(stats.byProfession) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["HISTORY_STATS_BY_PROF"] or "By profession (done/rej/skip):", 0.7, 0.7, 0.7)
        local parts = {}
        for prof, c in pairs(stats.byProfession) do
            table.insert(parts, {
                name = prof,
                completed = c.completed or 0,
                rejected = c.rejected or 0,
                skipped = c.skipped or 0,
            })
        end
        table.sort(parts, function(a, b) return a.name < b.name end)
        for _, p in ipairs(parts) do
            local total = p.completed + p.rejected + p.skipped
            if total > 0 then
                GameTooltip:AddDoubleLine(
                    p.name,
                    string.format("%d / %d / %d", p.completed, p.rejected, p.skipped),
                    0.92, 0.93, 0.95, 0.75, 0.75, 0.78)
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["HISTORY_STATS_TIP"] or "Lifetime totals — not limited to the current queue.", 0.5, 0.5, 0.55, true)
    GameTooltip:Show()
end

function ns.UI.HistoryTab.Init(parent)
    parentFrame = parent

    toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", 0, 0)
    toolbar:SetHeight(36)

    -- Sort (right) — same layout as Recipes tab
    if ns.CreateUIDropdown then
        sortBtn = ns.CreateUIDropdown(toolbar, {
            width = 120, height = 26,
            placeholder = L[SORT_LABELS.time] or "Sort: Time",
            onSelect = function(value)
                sortMode = value or "time"
                ns.UI.HistoryTab.Refresh()
            end,
        })
        sortBtn:SetOptions({
            { value = "time",   label = L[SORT_LABELS.time] or "Sort: Time" },
            { value = "sender", label = L[SORT_LABELS.sender] or "Sort: Sender" },
            { value = "status", label = L[SORT_LABELS.status] or "Sort: Status" },
            { value = "fee",    label = L[SORT_LABELS.fee] or "Sort: Fee" },
        })
        sortBtn:SetValue(sortMode, true)
    else
        sortBtn = ns.CreateUIButton and ns.CreateUIButton(toolbar, {
            width = 120, height = 26,
            text = L[SORT_LABELS.time] or "Sort: Time",
            variant = "ghost",
        }) or CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
        local cycle = { "time", "sender", "status", "fee" }
        sortBtn:SetScript("OnClick", function()
            local idx = 1
            for i, m in ipairs(cycle) do
                if m == sortMode then idx = i; break end
            end
            sortMode = cycle[(idx % #cycle) + 1]
            if sortBtn.SetText then
                sortBtn:SetText(L[SORT_LABELS[sortMode]] or sortMode)
            end
            ns.UI.HistoryTab.Refresh()
        end)
    end
    sortBtn:SetPoint("TOPRIGHT", 0, -2)

    -- Status filter (left of sort)
    if ns.CreateUIDropdown then
        statusBtn = ns.CreateUIDropdown(toolbar, {
            width = 130, height = 26,
            placeholder = L[STATUS_FILTER_LABELS.all] or "All",
            onSelect = function(value)
                statusFilter = value or "all"
                ns.UI.HistoryTab.Refresh()
            end,
        })
        statusBtn:SetOptions({
            { value = "all",      label = L[STATUS_FILTER_LABELS.all] or "All" },
            { value = "open",     label = L[STATUS_FILTER_LABELS.open] or "Open" },
            { value = "done",     label = L[STATUS_FILTER_LABELS.done] or "Done" },
            { value = "rejected", label = L[STATUS_FILTER_LABELS.rejected] or "Rejected" },
            { value = "skipped",  label = L[STATUS_FILTER_LABELS.skipped] or "Skipped" },
        })
        statusBtn:SetValue(statusFilter, true)
    else
        statusBtn = ns.CreateUIButton and ns.CreateUIButton(toolbar, {
            width = 130, height = 26,
            text = L[STATUS_FILTER_LABELS.all] or "All",
            variant = "ghost",
        }) or CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    end
    statusBtn:SetPoint("RIGHT", sortBtn, "LEFT", -6, 0)

    -- Stats chip — lifetime totals on hover
    statsChip = ns.CreateUIButton and ns.CreateUIButton(toolbar, {
        width = 52, height = 26,
        text = L["HISTORY_STATS_CHIP"] or "Stats",
        variant = "ghost",
    }) or CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    statsChip:SetPoint("RIGHT", statusBtn, "LEFT", -6, 0)
    if not ns.CreateUIButton then
        statsChip:SetSize(52, 26)
        statsChip:SetText("Stats")
    end
    statsChip:SetScript("OnEnter", function(self) ShowStatsTooltip(self) end)
    statsChip:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Search fills remaining space
    searchBox = ns.CreateUIEditBox and ns.CreateUIEditBox(toolbar, {
        name = "CraftBellHistorySearch", height = 26,
    }) or CreateFrame("EditBox", "CraftBellHistorySearch", toolbar, "InputBoxTemplate")
    searchBox:SetHeight(26)
    searchBox:SetPoint("TOPLEFT", 0, -2)
    searchBox:SetPoint("RIGHT", statsChip, "LEFT", -8, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(60)
    if searchBox.SetTextColor then searchBox:SetTextColor(unpack(C.text)) end

    local searchHint = toolbar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchBox, "LEFT", 10, 0)
    searchHint:SetText(L["HISTORY_SEARCH_HINT"] or "Search sender, recipe…")
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        searchHint:SetShown(searchText == "")
        ns.UI.HistoryTab.Refresh()
    end)
    searchBox:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then searchHint:Show() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        searchText = ""
        searchHint:Show()
        self:ClearFocus()
        ns.UI.HistoryTab.Refresh()
    end)

    -- Scroll area below toolbar
    scroll, child = ns.UI.CreateScrollArea(parent)
    if scroll then
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
        scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    end
end

function ns.UI.HistoryTab.Refresh()
    if not child then return end
    ns.UI.ClearChildren(child)
    local y = 0

    -- Hint + clear actions
    local hint = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 8, -y)
    hint:SetPoint("RIGHT", -220, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(unpack(C.textMuted))
    hint:SetText(L["HISTORY_HINT"] or "Whisper = offer · Ready = mailed · Reject = declined · Skip = someone else took it")

    local clearAllBtn = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 100, height = 22,
        text = L["HISTORY_CLEAR"] or "Clear all",
        variant = "danger",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    clearAllBtn:SetPoint("TOPRIGHT", -4, -y + 2)
    if not ns.CreateUIButton then
        clearAllBtn:SetSize(100, 22)
        clearAllBtn:SetText("Clear all")
    end
    clearAllBtn:SetScript("OnClick", function()
        if ns.HistoryClear then
            ns.HistoryClear()
            ns.Print(L["HISTORY_CLEARED"] or "History cleared.")
        end
        ns.UI.HistoryTab.Refresh()
    end)

    local clearTestBtn = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 110, height = 22,
        text = L["HISTORY_CLEAR_TESTS"] or "Clear tests",
        variant = "ghost",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    clearTestBtn:SetPoint("RIGHT", clearAllBtn, "LEFT", -6, 0)
    if not ns.CreateUIButton then
        clearTestBtn:SetSize(110, 22)
        clearTestBtn:SetText("Clear tests")
    end
    clearTestBtn:SetScript("OnClick", function()
        local n = ns.HistoryClearSelfTests and ns.HistoryClearSelfTests() or 0
        ns.Print(string.format(L["HISTORY_CLEARED_TESTS"] or "Removed %d self-test / test row(s).", n))
        ns.UI.HistoryTab.Refresh()
    end)
    clearTestBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["HISTORY_CLEAR_TESTS_TIP"] or "Remove CBSelfTest / TestBuyer rows only", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearTestBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    y = y + 28

    local list = ns.alertHistory
    if not list or #list == 0 then
        local empty = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -y)
        empty:SetTextColor(unpack(C.textMuted))
        empty:SetText(L["NO_HISTORY"] or "No alerts yet.")
        y = y + 32
        child:SetSize(scroll:GetWidth(), math.max(y, 1))
        return
    end

    local view = {}
    for i, entry in ipairs(list) do
        if MatchesStatusFilter(entry) and MatchesSearch(entry) then
            table.insert(view, { entry = entry, index = i })
        end
    end

    table.sort(view, function(a, b)
        local ea, eb = a.entry, b.entry
        if sortMode == "sender" then
            local sa = (ea.sender or ""):lower()
            local sb = (eb.sender or ""):lower()
            if sa ~= sb then return sa < sb end
        elseif sortMode == "status" then
            local oa = STATUS_ORDER[EntryStatus(ea)] or 99
            local ob = STATUS_ORDER[EntryStatus(eb)] or 99
            if oa ~= ob then return oa < ob end
        elseif sortMode == "fee" then
            local fa = ea.feeOffered or 0
            local fb = eb.feeOffered or 0
            if fa ~= fb then return fa > fb end
        end
        -- time (default) and tie-break: original list order (newest first if list is prepended)
        return a.index < b.index
    end)

    if #view == 0 then
        local empty = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -y)
        empty:SetTextColor(unpack(C.textMuted))
        empty:SetText(L["HISTORY_FILTER_EMPTY"] or "No entries for this filter.")
        y = y + 32
        child:SetSize(scroll:GetWidth(), math.max(y, 1))
        return
    end

    local rowHeight = 56
    for _, item in ipairs(view) do
        local entry = item.entry
        local st = EntryStatus(entry)
        local terminal = (st == "done" or st == "rejected" or st == "skipped")

        local row = ns.CreateUIRow and ns.CreateUIRow(child, rowHeight - 4)
            or CreateFrame("Frame", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", -4, -y)
        if not ns.CreateUIRow and ns.ApplyCardTheme then ns.ApplyCardTheme(row) end

        -- Actions menu (right)
        local actionsBtn = ns.CreateUIButton and ns.CreateUIButton(row, {
            width = 72, height = 22,
            text = L["ACTIONS"] or "Actions",
            variant = "ghost",
        }) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        actionsBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        if not ns.CreateUIButton then
            actionsBtn:SetSize(72, 22)
            actionsBtn:SetText("Actions")
        end
        actionsBtn:SetScript("OnClick", function(self)
            if historyActionMenu and historyActionMenu:IsShown() then
                HideHistoryActionMenu()
            else
                ShowHistoryActionMenu(self, entry)
            end
        end)

        -- Item icon (left), same spirit as Recipes list
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(HISTORY_ICON_SIZE, HISTORY_ICON_SIZE)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture(ResolveHistoryIcon(entry))
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local iconBg = row:CreateTexture(nil, "BACKGROUND")
        iconBg:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
        iconBg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
        iconBg:SetColorTexture(0.15, 0.16, 0.18, 0.9)

        local iconHit = CreateFrame("Button", nil, row)
        iconHit:SetAllPoints(icon)
        iconHit:EnableMouse(true)
        iconHit:SetScript("OnEnter", function(self)
            local link = ResolveHistoryItemLink(entry)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local shown = false
            if link then
                local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
                shown = ok
            end
            if not shown then
                GameTooltip:SetText(entry.recipeNames or "?", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        iconHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Time (hover = full timesheet) + sender + badge
        local timeBtn = CreateFrame("Button", nil, row)
        timeBtn:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 6)
        timeBtn:SetHeight(16)
        timeBtn:SetWidth(56)
        timeBtn:EnableMouse(true)

        local timeFS = timeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        timeFS:SetAllPoints()
        timeFS:SetJustifyH("LEFT")
        timeFS:SetTextColor(unpack(C.textMuted))
        timeFS:SetText(entry.time or "")

        timeBtn:SetScript("OnEnter", function(self)
            timeFS:SetTextColor(unpack(C.accent))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(L["HISTORY_TIMESHEET"] or "Timesheet", 0.15, 0.75, 0.95)
            local count = entry.count or 1
            local firstT = entry.firstTime or entry.time or "?"
            local lastT = entry.time or "?"
            GameTooltip:AddDoubleLine(L["HISTORY_FIRST_SEEN"] or "First seen", firstT, 0.7, 0.7, 0.7, 1, 1, 1)
            if count > 1 then
                GameTooltip:AddDoubleLine(L["HISTORY_LAST_SEEN"] or "Last seen", lastT, 0.7, 0.7, 0.7, 1, 1, 1)
            end
            GameTooltip:AddDoubleLine(L["HISTORY_PING_COUNT"] or "Messages", tostring(count), 0.7, 0.7, 0.7, 1, 1, 1)
            local first = entry.firstTimestamp or entry.timestamp
            local last = entry.timestamp or first
            if first and last and last > first and ns.FormatDuration then
                GameTooltip:AddDoubleLine(
                    L["HISTORY_SPAN"] or "Span",
                    ns.FormatDuration(last - first),
                    0.7, 0.7, 0.7, 1, 1, 1)
            end
            local pings = entry.pings
            if pings and #pings > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["HISTORY_PING_TIMES"] or "Ping times", 0.55, 0.58, 0.62)
                -- Full timesheet (cap display to last 20 for tooltip height)
                local start = math.max(1, #pings - 19)
                for i = start, #pings do
                    local ts = pings[i]
                    local label = "#" .. i
                    if i == 1 then label = L["HISTORY_FIRST_SEEN"] or "First" end
                    if i == #pings and #pings > 1 then label = L["HISTORY_LAST_SEEN"] or "Last" end
                    local delta = ""
                    if i > 1 and pings[1] then
                        local d = ts - pings[1]
                        if d > 0 and ns.FormatDuration then
                            delta = "  (+" .. ns.FormatDuration(d) .. ")"
                        end
                    end
                    GameTooltip:AddDoubleLine(
                        label,
                        date("%H:%M:%S", ts) .. delta,
                        0.75, 0.75, 0.78, 0.9, 0.9, 0.9)
                end
            elseif entry.message and entry.message ~= "" then
                GameTooltip:AddLine(" ")
                local msg = entry.message
                if #msg > 120 then msg = msg:sub(1, 117) .. "..." end
                GameTooltip:AddLine(msg, 0.65, 0.68, 0.72, true)
            end
            GameTooltip:Show()
        end)
        timeBtn:SetScript("OnLeave", function()
            timeFS:SetTextColor(unpack(C.textMuted))
            GameTooltip:Hide()
        end)

        local senderFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        senderFS:SetPoint("LEFT", timeBtn, "RIGHT", 6, 0)
        senderFS:SetJustifyH("LEFT")
        senderFS:SetTextColor(unpack(C.text))
        local pingBit = ""
        if ns.GetHistoryPingSummary then
            local s = ns.GetHistoryPingSummary(entry)
            if s and s ~= "" then pingBit = "  " .. s end
        elseif entry.count and entry.count > 1 then
            pingBit = "  ×" .. entry.count
        end
        senderFS:SetText((entry.sender or "") .. pingBit)

        local variantMap = {
            new = "neutral",
            contacted = "info",
            done = "success",
            rejected = "danger",
            skipped = "warning",
        }
        if ns.CreateUIBadge then
            local badge = ns.CreateUIBadge(row, {
                text = StatusText(entry),
                variant = variantMap[st] or "neutral",
                height = 16,
            })
            badge:SetPoint("LEFT", senderFS, "RIGHT", 8, 0)
        else
            local statusFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            statusFS:SetPoint("LEFT", senderFS, "RIGHT", 8, 0)
            statusFS:SetTextColor(unpack(STATUS_COLOR[st] or STATUS_COLOR.new))
            statusFS:SetText(StatusText(entry))
        end

        -- Recipe name with item tooltip (like Recipes list)
        local nameBtn = CreateFrame("Button", nil, row)
        nameBtn:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, -2)
        nameBtn:SetPoint("RIGHT", actionsBtn, "LEFT", -10, 0)
        nameBtn:SetHeight(16)
        nameBtn:EnableMouse(true)

        local nameFS = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetAllPoints()
        nameFS:SetJustifyH("LEFT")
        nameFS:SetTextColor(unpack(C.textMuted))
        local feeBit = ""
        if entry.feeOffered and entry.feeOffered > 0 and ns.FormatFee then
            feeBit = "  ·  " .. ns.FormatFee(entry.feeOffered, { plain = true })
        end
        local displayName = entry.recipeNames or ""
        local link = ResolveHistoryItemLink(entry)
        if link and (displayName == "" or not displayName:find("|H")) then
            displayName = link
        end
        nameFS:SetText(displayName .. feeBit)

        nameBtn:SetScript("OnEnter", function(self)
            nameFS:SetTextColor(unpack(C.accent))
            local itemLink = ResolveHistoryItemLink(entry)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local shown = false
            if itemLink then
                local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, itemLink)
                shown = ok
            end
            if not shown then
                GameTooltip:SetText(entry.recipeNames or "?", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        nameBtn:SetScript("OnLeave", function()
            nameFS:SetTextColor(unpack(C.textMuted))
            GameTooltip:Hide()
        end)

        y = y + rowHeight
    end

    child:SetSize(scroll:GetWidth(), math.max(y, 1))
end

ns.RegisterCallback("HISTORY_UPDATED", function()
    if ns.UI.IsMainWindowShown and ns.UI.IsMainWindowShown() then
        ns.UI.HistoryTab.Refresh()
    end
end)