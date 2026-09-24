local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Reusable scrollable text frame (dump, logs, future tools)
-- ns.ShowTextFrame(title, text)  — open / refresh
-- ns.HideTextFrame()
----------------------------------------------------------------------

local frame

local function EnsureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "CraftBellTextFrame", UIParent, "BackdropTemplate")
    frame:SetSize(520, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "CraftBellTextFrame")

    if ns.ApplyDarkTheme then
        ns.ApplyDarkTheme(frame)
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.06, 0.07, 0.09, 0.97)
        frame:SetBackdropBorderColor(0.22, 0.24, 0.28, 1)
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 16, -14)
    frame.title:SetTextColor(0.15, 0.75, 0.95)
    frame.title:SetText("CraftBell")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 10, 0)
    frame.subtitle:SetTextColor(0.55, 0.58, 0.62)
    frame.subtitle:SetText("")

    local closeBtn
    if ns.CreateUIButton then
        closeBtn = ns.CreateUIButton(frame, {
            width = 28, height = 28, text = "×", variant = "ghost",
        })
    else
        closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    end
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "CraftBellTextFrameScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -42)
    scroll:SetPoint("BOTTOMRIGHT", -36, 48)

    local edit = CreateFrame("EditBox", "CraftBellTextFrameEdit", scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetWidth(450)
    scroll:SetScrollChild(edit)
    frame.edit = edit
    frame.scroll = scroll

    scroll:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if w and w > 20 then
            edit:SetWidth(w)
        end
    end)

    local copyBtn
    if ns.CreateUIButton then
        copyBtn = ns.CreateUIButton(frame, {
            width = 140, height = 26,
            text = L["COPY_CLIPBOARD"] or "Copy to clipboard",
            variant = "primary",
        })
    else
        copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        copyBtn:SetSize(140, 26)
        copyBtn:SetText(L["COPY_CLIPBOARD"] or "Copy to clipboard")
    end
    copyBtn:SetPoint("BOTTOMLEFT", 16, 12)
    copyBtn:SetScript("OnClick", function()
        local text = edit:GetText() or ""
        if text == "" then return end
        if CopyToClipboard then
            CopyToClipboard(text)
            ns.Print(L["COPIED_CLIPBOARD"] or "Copied to clipboard.")
        else
            edit:SetFocus()
            edit:HighlightText()
            ns.Print(L["COPY_MANUAL"] or "Text selected — press Ctrl+C to copy.")
        end
    end)

    local closeBottom
    if ns.CreateUIButton then
        closeBottom = ns.CreateUIButton(frame, {
            width = 80, height = 26, text = "Close", variant = "ghost",
        })
    else
        closeBottom = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        closeBottom:SetSize(80, 26)
        closeBottom:SetText("Close")
    end
    closeBottom:SetPoint("BOTTOMRIGHT", -16, 12)
    closeBottom:SetScript("OnClick", function() frame:Hide() end)

    return frame
end

--- Open (or refresh) the shared text viewer.
function ns.ShowTextFrame(title, body, subtitle)
    local f = EnsureFrame()
    f.title:SetText(title or "CraftBell")
    f.subtitle:SetText(subtitle or "")
    f.edit:SetText(body or "")
    f.edit:SetCursorPosition(0)
    f.scroll:SetVerticalScroll(0)
    f:Show()
    f:Raise()
end

function ns.HideTextFrame()
    if frame then frame:Hide() end
end