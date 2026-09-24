local addonName, ns = ...
local L = ns.L
local C = ns.UI.C

ns.UI.HistoryTab = ns.UI.HistoryTab or {}

local scroll, child

function ns.UI.HistoryTab.Init(parent)
    scroll, child = ns.UI.CreateScrollArea(parent)
end

function ns.UI.HistoryTab.Refresh()
    if not child then return end
    ns.UI.ClearChildren(child)
    local y = 0
    local rowHeight = 48

    if not ns.alertHistory or #ns.alertHistory == 0 then
        local empty = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -12)
        empty:SetTextColor(unpack(C.textMuted))
        empty:SetText(L["NO_HISTORY"] or "No alerts yet.")
        y = 32
    else
        for _, entry in ipairs(ns.alertHistory) do
            local row = ns.CreateUIRow and ns.CreateUIRow(child, rowHeight - 4)
                or CreateFrame("Frame", nil, child, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", -4, -y)
            if not ns.CreateUIRow and ns.ApplyCardTheme then ns.ApplyCardTheme(row) end

            local top = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            top:SetPoint("TOPLEFT", 12, -8)
            top:SetPoint("RIGHT", row, "RIGHT", -80, 0)
            top:SetJustifyH("LEFT")
            top:SetTextColor(unpack(C.text))
            local countSuffix = entry.count and entry.count > 1 and ("  ×" .. entry.count) or ""
            top:SetText((entry.time or "") .. "   " .. (entry.sender or "") .. countSuffix)

            local bottom = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            bottom:SetPoint("BOTTOMLEFT", 12, 8)
            bottom:SetPoint("RIGHT", row, "RIGHT", -80, 0)
            bottom:SetJustifyH("LEFT")
            bottom:SetTextColor(unpack(C.textMuted))
            bottom:SetText(entry.recipeNames or "")

            local whisperBtn = ns.CreateUIButton and ns.CreateUIButton(row, {
                width = 68, height = 22,
                text = entry.replied and (L["REPLIED"] or "Sent") or (L["WHISPER"] or "Whisper"),
                variant = entry.replied and "ghost" or "primary",
            }) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            whisperBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            if not ns.CreateUIButton then
                whisperBtn:SetSize(68, 22)
                whisperBtn:SetText(entry.replied and "Sent" or "Whisper")
            end
            if whisperBtn.Disable and entry.replied then whisperBtn:Disable() end
            whisperBtn:SetEnabled(not entry.replied)
            whisperBtn:SetScript("OnClick", function()
                if ns.WhisperFromHistory then ns.WhisperFromHistory(entry) end
                ns.UI.HistoryTab.Refresh()
            end)

            y = y + rowHeight
        end
    end

    child:SetSize(scroll:GetWidth(), math.max(y, 1))
end

ns.RegisterCallback("HISTORY_UPDATED", function()
    if ns.UI.IsMainWindowShown() then ns.UI.HistoryTab.Refresh() end
end)
