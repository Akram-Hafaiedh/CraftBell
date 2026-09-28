local addonName, ns = ...
ns.UI = ns.UI or {}

local C = ns.UI.colors or {
    accent = { 0.15, 0.75, 0.95, 1 },
    text = { 0.92, 0.93, 0.95, 1 },
    textMuted = { 0.55, 0.58, 0.62, 1 },
}
ns.UI.C = C

----------------------------------------------------------------------
-- Custom scrollbar (RealmDisplay-style) — themed accent, width from settings
----------------------------------------------------------------------
ns.UI._scrollAreas = ns.UI._scrollAreas or {}

local function ScrollBarWidth()
    local key = ns.db and ns.db.settings and ns.db.settings.scrollBarWidth or "normal"
    if key == "thin" then return 4 end
    if key == "wide" then return 8 end
    return 6 -- normal
end

local function AccentRGB()
    local a = (ns.UI.colors and ns.UI.colors.accent) or C.accent or { 0.15, 0.75, 0.95, 1 }
    return a[1] or 0.15, a[2] or 0.75, a[3] or 0.95
end

--- Refresh thumb/track colors + width on every registered scroll area.
function ns.UI.RefreshScrollbars()
    local w = ScrollBarWidth()
    local ar, ag, ab = AccentRGB()
    for _, ref in ipairs(ns.UI._scrollAreas) do
        local scroll = ref.scroll
        if scroll and scroll.track and scroll.thumb then
            scroll.track:SetWidth(w)
            scroll.thumb:SetWidth(w)
            scroll.track:SetBackdropColor(0.08, 0.09, 0.11, 1)
            scroll.track:SetBackdropBorderColor(0.18, 0.20, 0.24, 1)
            scroll.thumb:SetBackdropColor(ar, ag, ab, 0.45)
            scroll.thumb:SetBackdropBorderColor(ar, ag, ab, 0.7)
            scroll._accent = { ar, ag, ab }
            if scroll.UpdateThumb then scroll:UpdateThumb() end
            if scroll.SyncWidth then scroll:SyncWidth() end
        end
    end
end

--- Returns scrollFrame, scrollChild. Custom thin scrollbar (no stock Blizzard bar).
function ns.UI.CreateScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:EnableMouseWheel(true)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)

    local barW = ScrollBarWidth()
    local ar, ag, ab = AccentRGB()

    local track = CreateFrame("Frame", nil, scroll, "BackdropTemplate")
    track:SetWidth(barW)
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 0, 0)
    track:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    track:SetBackdropColor(0.08, 0.09, 0.11, 1)
    track:SetBackdropBorderColor(0.18, 0.20, 0.24, 1)
    scroll.track = track

    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetWidth(barW)
    thumb:SetHeight(40)
    thumb:SetPoint("TOP", track, "TOP", 0, 0)
    thumb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    thumb:SetBackdropColor(ar, ag, ab, 0.45)
    thumb:SetBackdropBorderColor(ar, ag, ab, 0.7)
    thumb:RegisterForDrag("LeftButton")
    thumb:SetMovable(true)
    scroll.thumb = thumb
    scroll._accent = { ar, ag, ab }

    thumb:SetScript("OnEnter", function(self)
        local a = scroll._accent or { ar, ag, ab }
        self:SetBackdropColor(a[1], a[2], a[3], 0.75)
    end)
    thumb:SetScript("OnLeave", function(self)
        local a = scroll._accent or { ar, ag, ab }
        self:SetBackdropColor(a[1], a[2], a[3], 0.45)
    end)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)

    local function UpdateThumb()
        local viewH = scroll:GetHeight() or 1
        local childH = child:GetHeight() or 1
        local maxScroll = math.max(childH - viewH, 0)
        if maxScroll <= 0 then
            track:Hide()
            scroll:SetVerticalScroll(0)
            return
        end
        track:Show()
        local ratio = viewH / math.max(childH, 1)
        local thumbH = math.max(24, viewH * ratio)
        thumb:SetHeight(thumbH)
        local cur = scroll:GetVerticalScroll() or 0
        local trackH = track:GetHeight() or 1
        local y = 0
        if maxScroll > 0 then
            y = -(cur / maxScroll) * (trackH - thumbH)
        end
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, y)
    end
    scroll.UpdateThumb = UpdateThumb

    local function SyncWidth()
        local w = scroll:GetWidth() or 0
        local pad = (ScrollBarWidth() or 6) + 4
        if w > pad + 10 then
            child:SetWidth(w - pad)
        elseif w > 10 then
            child:SetWidth(w)
        end
        UpdateThumb()
    end
    scroll.SyncWidth = SyncWidth

    scroll:SetScript("OnVerticalScroll", function() UpdateThumb() end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local viewH = self:GetHeight() or 1
        local childH = child:GetHeight() or 1
        local maxScroll = math.max(childH - viewH, 0)
        local cur = self:GetVerticalScroll() or 0
        local step = math.max(24, viewH * 0.15)
        local new = math.min(maxScroll, math.max(0, cur - delta * step))
        self:SetVerticalScroll(new)
        UpdateThumb()
    end)
    scroll:SetScript("OnSizeChanged", SyncWidth)
    scroll:HookScript("OnShow", function()
        SyncWidth()
        UpdateThumb()
    end)

    -- Drag thumb (RealmDisplay-style)
    thumb:SetScript("OnDragStart", function(self)
        self.dragging = true
    end)
    thumb:SetScript("OnDragStop", function(self)
        self.dragging = false
    end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local scale = self:GetEffectiveScale() or 1
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / scale
        local top = track:GetTop() or 0
        local trackH = track:GetHeight() or 1
        local thumbH = self:GetHeight() or 24
        local rel = top - cursorY - thumbH / 2
        rel = math.min(math.max(rel, 0), trackH - thumbH)
        local viewH = scroll:GetHeight() or 1
        local childH = child:GetHeight() or 1
        local maxScroll = math.max(childH - viewH, 0)
        local offset = 0
        if trackH > thumbH then
            offset = (rel / (trackH - thumbH)) * maxScroll
        end
        scroll:SetVerticalScroll(offset)
        UpdateThumb()
    end)

    -- Click track to jump
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local scale = track:GetEffectiveScale() or 1
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / scale
        local top = track:GetTop() or 0
        local trackH = track:GetHeight() or 1
        local thumbH = thumb:GetHeight() or 24
        local rel = top - cursorY - thumbH / 2
        rel = math.min(math.max(rel, 0), trackH - thumbH)
        local maxScroll = math.max((child:GetHeight() or 1) - (scroll:GetHeight() or 1), 0)
        local offset = 0
        if trackH > thumbH then
            offset = (rel / (trackH - thumbH)) * maxScroll
        end
        scroll:SetVerticalScroll(offset)
        UpdateThumb()
    end)

    table.insert(ns.UI._scrollAreas, { scroll = scroll, child = child })
    SyncWidth()
    return scroll, child
end

function ns.UI.SyncScrollChildWidth(scroll, child, minHeight)
    if scroll and scroll.SyncWidth then
        scroll:SyncWidth()
    else
        local w = scroll and scroll:GetWidth()
        if w and w > 10 and child then child:SetWidth(w) end
    end
    if minHeight and child then
        child:SetHeight(math.max(minHeight, child:GetHeight() or 1))
    end
    if scroll and scroll.UpdateThumb then scroll:UpdateThumb() end
end

function ns.UI.ClearChildren(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            region:Hide()
            region:SetParent(UIParent)
        end
    end
end

function ns.UI.IsMainWindowShown()
    return CraftBellMainFrame and CraftBellMainFrame:IsShown()
end