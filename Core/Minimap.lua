local addonName, ns = ...
local L = ns.L

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "CraftBellMinimapButton", Minimap)
    btn:SetSize(26, 26)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(9)

    local radius = (Minimap:GetWidth() or 140) / 2 + 2
    local isDragging = false

    local function UpdatePosition()
        local angle = math.rad(ns.db.settings.minimapAngle or 225)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bell_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetPoint("CENTER", btn, "CENTER", 10, -10)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function()
        isDragging = true
        btn:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            if angle < 0 then angle = angle + 360 end
            ns.db.settings.minimapAngle = angle
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnDragStop", function()
        isDragging = false
        btn:SetScript("OnUpdate", nil)
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if isDragging then return end
        if button == "RightButton" then
            ns.ToggleFocusMode()
        else
            ns.ToggleMainWindow()
        end
    end)

    local focusDot = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    focusDot:SetSize(8, 8)
    focusDot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
    focusDot:SetTexture("Interface\\Buttons\\WHITE8x8")
    focusDot:SetVertexColor(0, 0.8, 1, 1)
    focusDot:Hide()
    ns.RegisterCallback("FOCUS_MODE_CHANGED", function(enabled)
        focusDot:SetShown(enabled)
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("CraftBell", 0, 0.8, 1)
        GameTooltip:AddLine(L["CLICK_TO_TOGGLE"] or "Left-click: open settings", 1, 1, 1)
        GameTooltip:AddLine(L["FOCUS_RIGHT_CLICK"] or "Right-click: toggle Focus Mode", 0.7, 0.7, 0.7)
        if ns.focusModeActive then
            GameTooltip:AddLine((L["FOCUS_MODE"] or "Focus Mode") .. ": |cff00ff00ON|r", 0, 0.8, 1)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
end

ns.RegisterCallback("DB_READY", CreateMinimapButton)
