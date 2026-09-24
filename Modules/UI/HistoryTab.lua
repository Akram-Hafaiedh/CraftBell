local addonName, ns = ...
local L = ns.L
local C = ns.UI and ns.UI.C or {
    text = { 0.92, 0.93, 0.95, 1 },
    textMuted = { 0.55, 0.58, 0.62, 1 },
    accent = { 0.15, 0.75, 0.95, 1 },
}

ns.UI.HistoryTab = ns.UI.HistoryTab or {}

local scroll, child

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

function ns.UI.HistoryTab.Init(parent)
    scroll, child = ns.UI.CreateScrollArea(parent)
end

local function StatusText(entry)
    local st = (entry and entry.status) or "new"
    local key = STATUS_LABEL[st] or STATUS_LABEL.new
    return L[key] or st
end

function ns.UI.HistoryTab.Refresh()
    if not child then return end
    ns.UI.ClearChildren(child)
    local y = 0

    -- Stats strip
    local stats = ns.GetHistoryStats and ns.GetHistoryStats()
    local totals = stats and stats.totals or {}
    local done = totals.completed or 0
    local rej = totals.rejected or 0
    local skip = totals.skipped or 0

    local statsFS = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsFS:SetPoint("TOPLEFT", 8, -y)
    statsFS:SetPoint("RIGHT", -8, 0)
    statsFS:SetJustifyH("LEFT")
    statsFS:SetTextColor(unpack(C.accent))
    statsFS:SetText(string.format(
        L["HISTORY_STATS_LINE"] or "Completed: %d  ·  Rejected: %d  ·  Skipped: %d",
        done, rej, skip
    ))
    y = y + 22

    -- Per-profession breakdown (compact, only if any)
    if stats and stats.byProfession and next(stats.byProfession) then
        local parts = {}
        for prof, c in pairs(stats.byProfession) do
            local t = (c.completed or 0) + (c.rejected or 0) + (c.skipped or 0)
            if t > 0 then
                table.insert(parts, {
                    name = prof,
                    text = string.format("%s %d/%d/%d", prof, c.completed or 0, c.rejected or 0, c.skipped or 0),
                })
            end
        end
        table.sort(parts, function(a, b) return a.name < b.name end)
        if #parts > 0 then
            local line = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            line:SetPoint("TOPLEFT", 8, -y)
            line:SetPoint("RIGHT", -8, 0)
            line:SetJustifyH("LEFT")
            line:SetTextColor(unpack(C.textMuted))
            local buf = {}
            for _, p in ipairs(parts) do table.insert(buf, p.text) end
            line:SetText((L["HISTORY_STATS_BY_PROF"] or "By profession (done/rej/skip): ") .. table.concat(buf, "  ·  "))
            y = y + 18
        end
    end

    local hint = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 8, -y)
    hint:SetPoint("RIGHT", -8, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(unpack(C.textMuted))
    hint:SetText(L["HISTORY_HINT"] or "Whisper = offer · Ready = mailed · Reject = declined · Skip = someone else took it")
    y = y + 20

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

    local rowHeight = 56
    for _, entry in ipairs(list) do
        local st = entry.status or (entry.replied and "contacted" or "new")
        local terminal = (st == "done" or st == "rejected" or st == "skipped")

        local row = ns.CreateUIRow and ns.CreateUIRow(child, rowHeight - 4)
            or CreateFrame("Frame", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", -4, -y)
        if not ns.CreateUIRow and ns.ApplyCardTheme then ns.ApplyCardTheme(row) end

        local top = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        top:SetPoint("TOPLEFT", 12, -6)
        top:SetPoint("RIGHT", row, "RIGHT", -200, 0)
        top:SetJustifyH("LEFT")
        top:SetTextColor(unpack(C.text))
        local countSuffix = entry.count and entry.count > 1 and ("  ×" .. entry.count) or ""
        top:SetText((entry.time or "") .. "  " .. (entry.sender or "") .. countSuffix)

        local statusFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusFS:SetPoint("LEFT", top, "RIGHT", 8, 0)
        statusFS:SetTextColor(unpack(STATUS_COLOR[st] or STATUS_COLOR.new))
        statusFS:SetText(StatusText(entry))

        local bottom = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bottom:SetPoint("BOTTOMLEFT", 12, 8)
        bottom:SetPoint("RIGHT", row, "RIGHT", -200, 0)
        bottom:SetJustifyH("LEFT")
        bottom:SetTextColor(unpack(C.textMuted))
        local feeBit = ""
        if entry.feeOffered and entry.feeOffered > 0 and ns.FormatFee then
            feeBit = "  ·  " .. ns.FormatFee(entry.feeOffered, { plain = true })
        end
        bottom:SetText((entry.recipeNames or "") .. feeBit)

        -- Buttons: right-aligned cluster  Skip | Reject | Ready | Whisper
        local prev
        local function AddBtn(label, variant, onClick, disabled)
            local btn = ns.CreateUIButton and ns.CreateUIButton(row, {
                width = 58, height = 22, text = label, variant = variant or "ghost",
            }) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            if prev then
                btn:SetPoint("RIGHT", prev, "LEFT", -4, 0)
            else
                btn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            end
            if not ns.CreateUIButton then
                btn:SetSize(58, 22)
                btn:SetText(label)
            end
            if disabled then
                if btn.SetEnabled then btn:SetEnabled(false) end
                if btn.Disable then btn:Disable() end
            else
                btn:SetScript("OnClick", function()
                    onClick()
                    ns.UI.HistoryTab.Refresh()
                end)
            end
            prev = btn
            return btn
        end

        -- Whisper always available (resend offer) unless we want to lock terminal — keep enabled
        AddBtn(L["WHISPER"] or "Whisper", terminal and "ghost" or "primary", function()
            if ns.WhisperFromHistory then ns.WhisperFromHistory(entry) end
        end, false)

        AddBtn(L["HISTORY_READY"] or "Ready", "primary", function()
            if ns.NotifyFromHistory then ns.NotifyFromHistory(entry) end
        end, st == "done")

        AddBtn(L["HISTORY_REJECT"] or "Reject", "ghost", function()
            if ns.HistoryMarkRejected then ns.HistoryMarkRejected(entry) end
        end, terminal)

        AddBtn(L["HISTORY_SKIP"] or "Skip", "ghost", function()
            if ns.HistoryMarkSkipped then ns.HistoryMarkSkipped(entry) end
        end, terminal)

        y = y + rowHeight
    end

    child:SetSize(scroll:GetWidth(), math.max(y, 1))
end

ns.RegisterCallback("HISTORY_UPDATED", function()
    if ns.UI.IsMainWindowShown and ns.UI.IsMainWindowShown() then
        ns.UI.HistoryTab.Refresh()
    end
end)

ns.RegisterCallback("HISTORY_STATS_UPDATED", function()
    if ns.UI.IsMainWindowShown and ns.UI.IsMainWindowShown() then
        ns.UI.HistoryTab.Refresh()
    end
end)