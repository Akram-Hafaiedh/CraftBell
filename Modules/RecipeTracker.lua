local addonName, ns = ...
local L = ns.L

local trackButton = nil
local bulkButton = nil
local hookInstalled = false
local currentRecipeID = nil
local isTracked = false

----------------------------------------------------------------------
-- Visuals for single-recipe track button
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
-- Profession identity for the open crafting form
----------------------------------------------------------------------
local function GetCurrentProfessionInfo()
    local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
    if not profInfo then
        return false, L["UNKNOWN_PROFESSION"] or "Unknown", nil
    end

    local professionID = profInfo.parentProfessionID or false
    local professionName = profInfo.parentProfessionName or profInfo.professionName
        or (L["UNKNOWN_PROFESSION"] or "Unknown")

    local tradeSkillLink = nil
    if professionID then
        local ok, result = pcall(function()
            local spellSkillIndex = C_SpellBook.GetSkillLineIndexByID(professionID)
            if spellSkillIndex then
                local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(spellSkillIndex)
                if skillLineInfo then
                    local offset = skillLineInfo.itemIndexOffset
                    local _, skillSpellID = C_SpellBook.GetSpellBookItemType(
                        offset + 1, Enum.SpellBookSpellBank.Player)
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
-- Single-recipe track button
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
            if not recipeInfo then return end

            local professionID, professionName, tradeSkillLink = GetCurrentProfessionInfo()
            local itemLink = C_TradeSkillUI.GetRecipeItemLink(currentRecipeID)

            ns.TrackRecipe(currentRecipeID, recipeInfo.name, professionID, professionName,
                itemLink, tradeSkillLink, { autoAssign = true })
            isTracked = true
        else
            -- Untrack only this character as owner
            ns.UntrackRecipe(currentRecipeID)
            isTracked = ns.DoesCharacterOwnRecipe(currentRecipeID)
        end
        UpdateTrackButtonVisual()
    end)

    trackButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if isTracked then
            GameTooltip:AddLine(L["TOOLTIP_UNTRACK"] or "Stop tracking this recipe (this character)")
        else
            GameTooltip:AddLine(L["TOOLTIP_TRACK"] or "Track this recipe on this character")
        end
        GameTooltip:AddLine("CraftBell", 0, 0.8, 1)
        GameTooltip:Show()
    end)
    trackButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

----------------------------------------------------------------------
-- Bulk track button ("Track All" for the open profession)
----------------------------------------------------------------------
local function CreateBulkButton()
    if bulkButton then return end

    local parent = ProfessionsFrame.CraftingPage.SchematicForm
    bulkButton = CreateFrame("Button", "CraftBellBulkTrackButton", parent, "UIPanelButtonTemplate")
    bulkButton:SetSize(90, 22)
    -- Sit to the right of the single-track bell
    bulkButton:SetPoint("LEFT", trackButton or parent, trackButton and "RIGHT" or "TOPLEFT",
        trackButton and 6 or 40, trackButton and 0 or -8)
    bulkButton:SetText(L["BULK_TRACK"] or "Track All")

    bulkButton:SetScript("OnClick", function()
        -- Right-click could open options later; left-click runs bulk track
        ns.BulkTrackCurrentProfession()
        -- Refresh single-button state if a recipe is selected
        if currentRecipeID then
            isTracked = ns.DoesCharacterOwnRecipe(currentRecipeID)
            UpdateTrackButtonVisual()
        end
    end)

    bulkButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["BULK_TRACK"] or "Track All", 0, 0.8, 1)
        GameTooltip:AddLine(L["BULK_TRACK_TIP"] or
            "Adds every learned recipe in this profession to CraftBell for the current character.\n\n" ..
            "If a recipe is already tracked by another alt, this character is added as an additional owner.\n" ..
            "Assignment (who answers trade requests) is only set when none exists yet.",
            1, 1, 1, true)
        local s = ns.db and ns.db.settings
        if s then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("|cffaaaaaa%s: %s|r",
                L["BULK_OPT_LEARNED"] or "Learned only",
                s.bulkTrackLearnedOnly and "ON" or "OFF"))
            GameTooltip:AddLine(string.format("|cffaaaaaa%s: %s|r",
                L["BULK_OPT_SKIP_CONC"] or "Skip Concentration",
                s.bulkTrackSkipConcentration and "ON" or "OFF"))
            GameTooltip:AddLine(string.format("|cffaaaaaa%s: %s|r",
                L["BULK_OPT_AUTO_ASSIGN"] or "Auto-assign if unset",
                s.bulkTrackAutoAssign and "ON" or "OFF"))
        end
        GameTooltip:Show()
    end)
    bulkButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    isTracked = ns.DoesCharacterOwnRecipe(currentRecipeID)
    CreateTrackButton()
    CreateBulkButton()
    -- Re-anchor bulk next to track once both exist
    if bulkButton and trackButton then
        bulkButton:ClearAllPoints()
        bulkButton:SetPoint("LEFT", trackButton, "RIGHT", 6, 0)
    end
    UpdateTrackButtonVisual()
    trackButton:Show()
    bulkButton:Show()
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
        if bulkButton then bulkButton:Hide() end
        currentRecipeID = nil
    end)

    -- Also show bulk button when the profession page is shown (even before a recipe is selected)
    if ProfessionsFrame.CraftingPage.HookScript then
        ProfessionsFrame.CraftingPage:HookScript("OnShow", function()
            CreateTrackButton()
            CreateBulkButton()
            if bulkButton and trackButton then
                bulkButton:ClearAllPoints()
                bulkButton:SetPoint("LEFT", trackButton, "RIGHT", 6, 0)
                bulkButton:Show()
            end
        end)
    end
end

local waitFrame = CreateFrame("Frame")
waitFrame:RegisterEvent("TRADE_SKILL_SHOW")
waitFrame:SetScript("OnEvent", function(self, event)
    if event == "TRADE_SKILL_SHOW" then
        InstallHooks()
        -- Profession just opened — ensure bulk button is available
        C_Timer.After(0.15, function()
            if ProfessionsFrame and ProfessionsFrame.CraftingPage
                and ProfessionsFrame.CraftingPage:IsShown() then
                CreateTrackButton()
                CreateBulkButton()
                if bulkButton and trackButton then
                    bulkButton:ClearAllPoints()
                    bulkButton:SetPoint("LEFT", trackButton, "RIGHT", 6, 0)
                    bulkButton:Show()
                    trackButton:Show()
                end
            end
        end)
    end
end)

-- Slash helper for testing without UI
ns.RegisterCallback("DB_READY", function()
    -- /cb bulk is registered from Init; expose the function only
end)