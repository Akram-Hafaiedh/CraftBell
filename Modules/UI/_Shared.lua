local addonName, ns = ...
ns.UI = ns.UI or {}

local C = ns.UI.colors or {
    accent = { 0.15, 0.75, 0.95, 1 },
    text = { 0.92, 0.93, 0.95, 1 },
    textMuted = { 0.55, 0.58, 0.62, 1 },
}
ns.UI.C = C

function ns.UI.CreateScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    local function SyncWidth()
        local w = scroll:GetWidth()
        if w and w > 10 then child:SetWidth(w) end
    end
    scroll:SetScript("OnSizeChanged", SyncWidth)
    scroll:HookScript("OnShow", SyncWidth)
    return scroll, child
end

function ns.UI.SyncScrollChildWidth(scroll, child, minHeight)
    local w = scroll:GetWidth()
    if w and w > 10 then child:SetWidth(w) end
    if minHeight then
        child:SetHeight(math.max(minHeight, child:GetHeight() or 1))
    end
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
