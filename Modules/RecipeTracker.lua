local addonName, ns = ...
local L = ns.L

local trackButton = nil
local hookInstalled = false
local currentRecipeID = nil
local isTracked = false

----------------------------------------------------------------------
-- Visuals
----------------------------------------------------------------------
local function UpdateTrackButtonVisual()
    if not trackButton then return end
    if isTracked then
        trackButton.icon:SetDesaturated(false)
        trackButton.icon:SetAlpha(1)
        trackButton.glow:Show()
        trackButton:SetBackdropBorderColor(0, 0.8, 1, 1)
    else
        trackButton.icon:SetDesaturated(true)
        trackButton.icon:SetAlpha(0.4)
        trackButton.glow:Hide()
        trackButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    end
end

----------------------------------------------------------------------
-- Resolve profession identity for the recipe currently open in the
-- crafting form. Returns professionID (stable, locale-independent) and
-- professionName (display only) plus, if available, a tradeskill link.
----------------------------------------------------------------------
local function GetCurrentProfessionInfo()
    local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
    if not profInfo then
        return false, L["UNKNOWN_PROFESSION"] or "Unknown", nil
    end

    local professionID = profInfo.parentProfessionID or false
    local professionName = profInfo.parentProfessionName or profInfo.professionName or (L["UNKNOWN_PROFESSION"] or "Unknown")

    local tradeSkillLink = nil
    if professionID then
        local ok, result = pcall(function()
            local spellSkillIndex = C_SpellBook.GetSkillLineIndexByID(professionID)
            if spellSkillIndex then
                local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(spellSkillIndex)
                if skillLineInfo then
                    local offset = skillLineInfo.itemIndexOffset
                    local _, skillSpellID = C_SpellBook.GetSpellBookItemType(offset + 1, Enum.SpellBookSpellBank.Player)
                    if skillSpellID then
                        return C_Spell.GetSpellTradeSkillLink(skillSpellID)
                    end
                end
            end
        end)
        if ok then
            tradeSkillLink = result
        else
            ns.Error("RecipeTracker: failed getting tradeSkillLink — " .. tostring(result))
        end
    end

    return professionID, professionName, tradeSkillLink
end

----------------------------------------------------------------------
-- Track button
----------------------------------------------------------------------
local function CreateTrackButton()
    if trackButton then return end

    local parent = ProfessionsFrame.CraftingPage.SchematicForm
    trackButton = CreateFrame("Button", "CraftBellTrackButton", parent, "BackdropTemplate")
    trackButton:SetSize(28, 28)
    trackButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -7)

    trackButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    trackButton:SetBackdropColor(0, 0, 0, 0.6)
    trackButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local glow = trackButton:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetSize(34, 34)
    glow:SetPoint("CENTER")
    glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    glow:SetVertexColor(0, 0.8, 1, 0.4)
    glow:Hide()
    trackButton.glow = glow

    local icon = trackButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bell_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    trackButton.icon = icon

    local highlight = trackButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(22, 22)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)

    trackButton:SetScript("OnClick", function()
        if not currentRecipeID then return end

        if not isTracked then
            local recipeInfo = ProfessionsFrame.CraftingPage.SchematicForm:GetRecipeInfo()
            if not recipeInfo then
                ns.Debug("RecipeTracker: GetRecipeInfo returned nil")
                return
            end

            local professionID, professionName, tradeSkillLink = GetCurrentProfessionInfo()
            local itemLink = C_TradeSkillUI.GetRecipeItemLink(currentRecipeID)

            ns.Debug("RecipeTracker: tracking id=" .. tostring(currentRecipeID)
                .. " name=" .. tostring(recipeInfo.name)
                .. " professionID=" .. tostring(professionID))

            ns.TrackRecipe(currentRecipeID, recipeInfo.name, professionID, professionName, itemLink, tradeSkillLink)
            isTracked = true
        else
            ns.UntrackRecipe(currentRecipeID)
            isTracked = false
        end
        UpdateTrackButtonVisual()
    end)

    trackButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if isTracked then
            GameTooltip:AddLine(L["TOOLTIP_UNTRACK"] or "Stop tracking this recipe")
            GameTooltip:AddLine("CraftBell", 0, 0.8, 1)
        else
            GameTooltip:AddLine(L["TOOLTIP_TRACK"] or "Track this recipe")
            GameTooltip:AddLine("CraftBell", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)

    trackButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

----------------------------------------------------------------------
-- Selection handling
----------------------------------------------------------------------
local function OnRecipeSelected()
    local schematicForm = ProfessionsFrame.CraftingPage.SchematicForm
    if not schematicForm:IsShown() then return end

    local recipeInfo = schematicForm:GetRecipeInfo()
    if not recipeInfo or not recipeInfo.recipeID then
        if trackButton then trackButton:Hide() end
        return
    end

    currentRecipeID = recipeInfo.recipeID
    isTracked = ns.IsRecipeTracked(currentRecipeID)
    CreateTrackButton()
    UpdateTrackButtonVisual()
    trackButton:Show()
end

----------------------------------------------------------------------
-- Hook installation
----------------------------------------------------------------------
local function InstallHooks()
    if hookInstalled then return end
    if not ProfessionsFrame or not ProfessionsFrame.CraftingPage then return end

    hooksecurefunc(ProfessionsFrame.CraftingPage, "SelectRecipe", OnRecipeSelected)
    hookInstalled = true

    ProfessionsFrame.CraftingPage.SchematicForm:HookScript("OnHide", function()
        if trackButton then trackButton:Hide() end
        currentRecipeID = nil
    end)
end

local waitFrame = CreateFrame("Frame")
waitFrame:RegisterEvent("TRADE_SKILL_SHOW")
waitFrame:SetScript("OnEvent", function(self, event)
    if event == "TRADE_SKILL_SHOW" then
        InstallHooks()
    end
end)
