local addonName, ns = ...
local L = ns.L

local trackButton = nil
local bulkButton = nil
local hookInstalled = false
local currentRecipeID = nil
local isTracked = false

----------------------------------------------------------------------
-- Visuals for single-recipe track button (labeled, on the schematic)
----------------------------------------------------------------------
local function UpdateTrackButtonVisual()
    if not trackButton then return end
    if isTracked then
        if trackButton.SetText then
            trackButton:SetText(L["TRACKED_BTN"] or "Tracked")
        end
        if trackButton.SetVariant then
            trackButton:SetVariant("primary")
        elseif trackButton.SetBackdropBorderColor then
            trackButton:SetBackdropBorderColor(0.15, 0.75, 0.95, 1)
        end
        if trackButton.icon then
            trackButton.icon:SetDesaturated(false)
            trackButton.icon:SetAlpha(1)
        end
    else
        if trackButton.SetText then
            trackButton:SetText(L["TRACK_BTN"] or "Track")
        end
        if trackButton.SetVariant then
            trackButton:SetVariant("ghost")
        elseif trackButton.SetBackdropBorderColor then
            trackButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        end
        if trackButton.icon then
            trackButton.icon:SetDesaturated(true)
            trackButton.icon:SetAlpha(0.55)
        end
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
-- Single-recipe track — on the schematic (selected recipe detail panel)
----------------------------------------------------------------------
local function CreateTrackButton()
    if trackButton then return end

    local parent = ProfessionsFrame.CraftingPage.SchematicForm
    if ns.CreateUIButton then
        trackButton = ns.CreateUIButton(parent, {
            name = "CraftBellTrackButton",
            width = 88,
            height = 26,
            text = L["TRACK_BTN"] or "Track",
            variant = "ghost",
        })
    else
        trackButton = CreateFrame("Button", "CraftBellTrackButton", parent, "UIPanelButtonTemplate")
        trackButton:SetSize(88, 26)
        trackButton:SetText(L["TRACK_BTN"] or "Track")
    end

    -- Top-left of the recipe detail panel (where the old tiny bell sat)
    trackButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -6)
    trackButton:SetFrameStrata("HIGH")
    trackButton:SetFrameLevel((parent:GetFrameLevel() or 100) + 20)

    trackButton:SetScript("OnClick", function()
        if not currentRecipeID then return end

        if not isTracked then
            local recipeInfo = ProfessionsFrame.CraftingPage.SchematicForm:GetRecipeInfo()
            if not recipeInfo then return end

            local professionID, professionName, tradeSkillLink = GetCurrentProfessionInfo()
            local itemLink = C_TradeSkillUI.GetRecipeItemLink
                and C_TradeSkillUI.GetRecipeItemLink(currentRecipeID)

            ns.TrackRecipe(currentRecipeID, recipeInfo.name, professionID, professionName,
                itemLink, tradeSkillLink, { autoAssign = true })
            isTracked = true
        else
            -- Drop only this character as owner (multi-owner recipes stay for other alts)
            ns.UntrackRecipe(currentRecipeID)
            isTracked = ns.DoesCharacterOwnRecipe(currentRecipeID)
        end
        UpdateTrackButtonVisual()
    end)

    trackButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if isTracked then
            GameTooltip:AddLine(L["TOOLTIP_UNTRACK"] or "Stop tracking this recipe (this character)", 1, 1, 1)
        else
            GameTooltip:AddLine(L["TOOLTIP_TRACK"] or "Track this recipe on this character", 1, 1, 1)
        end
        GameTooltip:AddLine("CraftBell", 0.15, 0.75, 0.95)
        GameTooltip:Show()
    end)
    trackButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

----------------------------------------------------------------------
-- Bulk track — on the LEFT recipe-list side, never on the schematic
----------------------------------------------------------------------
local function PositionBulkButton()
    if not bulkButton then return end
    bulkButton:ClearAllPoints()

    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not page then return end

    local recipeList = page.RecipeList
        or page.RecipeListContainer
        or page.RecipesList

    local searchBox = recipeList and (
        recipeList.SearchBox
        or recipeList.SearchBoxContainer
        or recipeList.searchBox
    )
    local filterBtn = recipeList and (
        recipeList.FilterButton
        or recipeList.FilterDropdown
        or recipeList.FilterDropdownContainer
        or recipeList.filterButton
    )

    -- Prefer bottom of the recipe list (always visible, not tied to a recipe)
    if recipeList then
        bulkButton:SetPoint("BOTTOMLEFT", recipeList, "BOTTOMLEFT", 8, 8)
    elseif searchBox then
        bulkButton:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -6)
    elseif filterBtn then
        bulkButton:SetPoint("LEFT", filterBtn, "RIGHT", 8, 0)
    else
        -- Far left of the crafting page, clear of the detail panel
        bulkButton:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 16, 16)
    end

    bulkButton:SetFrameStrata("HIGH")
    local baseLevel = (recipeList and recipeList.GetFrameLevel and recipeList:GetFrameLevel())
        or (page.GetFrameLevel and page:GetFrameLevel())
        or 100
    bulkButton:SetFrameLevel(baseLevel + 50)
end

local function CreateBulkButton()
    if bulkButton then return end
    if not ProfessionsFrame or not ProfessionsFrame.CraftingPage then return end

    local parent = ProfessionsFrame.CraftingPage

    if ns.CreateUIButton then
        bulkButton = ns.CreateUIButton(parent, {
            name = "CraftBellBulkTrackButton",
            width = 100,
            height = 26,
            text = L["BULK_TRACK"] or "Track All",
            variant = "primary",
        })
    else
        bulkButton = CreateFrame("Button", "CraftBellBulkTrackButton", parent, "UIPanelButtonTemplate")
        bulkButton:SetSize(100, 26)
        bulkButton:SetText(L["BULK_TRACK"] or "Track All")
    end

    PositionBulkButton()

    bulkButton:SetScript("OnClick", function()
        if ns.ShowBulkTrackDialog then
            ns.ShowBulkTrackDialog()
        else
            ns.BulkTrackCurrentProfession()
        end
        if currentRecipeID then
            isTracked = ns.DoesCharacterOwnRecipe(currentRecipeID)
            UpdateTrackButtonVisual()
        end
    end)

    bulkButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["BULK_TRACK"] or "Track All", 0.15, 0.75, 0.95)
        GameTooltip:AddLine(L["BULK_TRACK_TIP"] or
            "Opens a dialog to choose expansions and categories, then tracks matching recipes.\n\n" ..
            "Only selected categories are added — no more stripping extras by hand.",
            1, 1, 1, true)
        local s = ns.db and ns.db.settings
        if s then
            GameTooltip:AddLine(" ")
            local n = 0
            for _, v in pairs(s.bulkTrackExpansions or {}) do
                if v then n = n + 1 end
            end
            local scopeText = (n > 0)
                and (n .. " expansion(s) checked")
                or "selected expansion only"
            GameTooltip:AddLine(string.format("|cffaaaaaa%s: %s|r",
                L["BULK_OPT_SCOPE"] or "Scope", scopeText))
            GameTooltip:AddLine(string.format("|cffaaaaaa%s: %s|r",
                L["BULK_OPT_ORDERS"] or "Orders only",
                (s.bulkTrackOrdersOnly ~= false) and "ON" or "OFF"))
            GameTooltip:AddLine(string.format("|cffaaaaaa%s: %s|r",
                L["BULK_OPT_LEARNED"] or "Learned only",
                s.bulkTrackLearnedOnly and "ON" or "OFF"))
            GameTooltip:AddLine(string.format("|cffaaaaaa%s: %s|r",
                L["BULK_OPT_AUTO_ASSIGN"] or "Auto-assign if unset",
                s.bulkTrackAutoAssign and "ON" or "OFF"))
        end
        GameTooltip:Show()
    end)
    bulkButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    bulkButton:Hide()
end


local function ShowBulkButton()
    CreateBulkButton()
    if not bulkButton then return end
    PositionBulkButton()
    bulkButton:Show()
end

local INFO_ONLY_CATEGORY_PATTERNS = {
    "appendix",
    "^terms$",
    "^stats$",
    "glossary",
    "lore",
}

function ns.IsInformationalCategory(name)
    if not name then return false end
    local lower = name:lower()
    for _, pattern in ipairs(INFO_ONLY_CATEGORY_PATTERNS) do
        if lower:find(pattern) then
            return true
        end
    end
    return false
end

----------------------------------------------------------------------
-- Track All dialog — pick expansions + categories before scanning
----------------------------------------------------------------------
local bulkDialog

--- Build expansion → categories tree for the open profession.
--- Categories are unique *within* an expansion (same name across expansions
--- stays separate so the player sees which expansion they belong to).
--- Returns: {
---   { skillLineID, name, trained, categories = { { name, ids={...} }, ... } },
---   ...
--- }
local function CollectCategoriesByExpansion()
    local tree = {}
    local bySkill = {} -- skillLineID -> { byName = { [lower]= { name, ids } } }

    local expansions = ns.GetAvailableProfessionExpansions and ns.GetAvailableProfessionExpansions() or {}
    for _, node in pairs(bySkill) do
        local cats = {}
        for _, entry in pairs(node.byName) do
            if not ns.IsInformationalCategory(entry.name) then
                local idList = {}
                for id in pairs(entry.ids) do table.insert(idList, id) end
                table.insert(cats, { name = entry.name, ids = idList })
            end
        end
        table.sort(cats, function(a, b) return a.name < b.name end)
        node.categories = cats
        node.byName = nil
        table.insert(tree, node)
    end

    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs then
        for _, node in pairs(bySkill) do
            node.categories = {}
            table.insert(tree, node)
        end
        return tree
    end

    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs() or {}
    for _, recipeID in ipairs(recipeIDs) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if info and info.categoryID and info.categoryID > 0 then
            local skillLineID
            if C_TradeSkillUI.GetTradeSkillLineForRecipe then
                local ok, tsID = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)
                if ok and tsID and tsID > 0 then skillLineID = tsID end
            end
            if not skillLineID then
                -- Fallback: dump into first expansion node if any
                for id in pairs(bySkill) do
                    skillLineID = id
                    break
                end
            end
            if skillLineID then
                if not bySkill[skillLineID] then
                    bySkill[skillLineID] = {
                        skillLineID = skillLineID,
                        name = "SkillLine " .. tostring(skillLineID),
                        trained = true,
                        byName = {},
                    }
                end
                local catName
                if C_TradeSkillUI.GetCategoryInfo then
                    local cat = C_TradeSkillUI.GetCategoryInfo(info.categoryID)
                    if cat and cat.name and cat.name ~= "" then catName = cat.name end
                end
                catName = catName or ("Category " .. tostring(info.categoryID))
                local key = catName:lower()
                local node = bySkill[skillLineID]
                local entry = node.byName[key]
                if not entry then
                    entry = { name = catName, ids = {} }
                    node.byName[key] = entry
                end
                entry.ids[info.categoryID] = true
            end
        end
    end

    for _, node in pairs(bySkill) do
        local cats = {}
        for _, entry in pairs(node.byName) do
            local idList = {}
            for id in pairs(entry.ids) do table.insert(idList, id) end
            table.insert(cats, { name = entry.name, ids = idList })
        end
        table.sort(cats, function(a, b) return a.name < b.name end)
        node.categories = cats
        node.byName = nil
        table.insert(tree, node)
    end
    table.sort(tree, function(a, b)
        return (a.skillLineID or 0) > (b.skillLineID or 0)
    end)
    return tree
end

function ns.ShowBulkTrackDialog()
    if not C_TradeSkillUI then
        ns.Print(L["BULK_NO_API"] or "Open a profession window first.")
        return
    end

    if not bulkDialog then
        bulkDialog = CreateFrame("Frame", "CraftBellBulkDialog", UIParent, "BackdropTemplate")
        bulkDialog:SetSize(420, 480)
        bulkDialog:SetPoint("CENTER")
        bulkDialog:SetFrameStrata("DIALOG")
        bulkDialog:SetClampedToScreen(true)
        bulkDialog:SetMovable(true)
        bulkDialog:EnableMouse(true)
        bulkDialog:RegisterForDrag("LeftButton")
        bulkDialog:SetScript("OnDragStart", bulkDialog.StartMoving)
        bulkDialog:SetScript("OnDragStop", bulkDialog.StopMovingOrSizing)
        tinsert(UISpecialFrames, "CraftBellBulkDialog")
        if ns.ApplyDarkTheme then ns.ApplyDarkTheme(bulkDialog) end

        local title = bulkDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        title:SetTextColor(0.15, 0.75, 0.95)
        title:SetText(L["BULK_DIALOG_TITLE"] or "Track All — choose what to add")
        bulkDialog.title = title

        local close = ns.CreateUIButton and ns.CreateUIButton(bulkDialog, {
            width = 28, height = 28, text = "×", variant = "ghost",
        }) or CreateFrame("Button", nil, bulkDialog, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -8, -8)
        close:SetScript("OnClick", function() bulkDialog:Hide() end)

        local hint = bulkDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 16, -38)
        hint:SetPoint("RIGHT", -16, 0)
        hint:SetJustifyH("LEFT")
        hint:SetTextColor(0.55, 0.58, 0.62)
        hint:SetText(L["BULK_DIALOG_HINT"] or "Select expansions and categories. Only matching recipes are tracked for this character.")
        bulkDialog.hint = hint

        -- Scroll body
        local body = CreateFrame("Frame", nil, bulkDialog)
        body:SetPoint("TOPLEFT", 12, -60)
        body:SetPoint("BOTTOMRIGHT", -12, 52)
        bulkDialog.body = body

        local scroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -24, 0)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(360, 1)
        scroll:SetScrollChild(content)
        bulkDialog.scroll = scroll
        bulkDialog.content = content

        -- Footer
        local startBtn = ns.CreateUIButton and ns.CreateUIButton(bulkDialog, {
            width = 140, height = 28,
            text = L["BULK_DIALOG_START"] or "Start tracking",
            variant = "primary",
        }) or CreateFrame("Button", nil, bulkDialog, "UIPanelButtonTemplate")
        startBtn:SetPoint("BOTTOMRIGHT", -16, 14)
        if not ns.CreateUIButton then startBtn:SetSize(140, 28); startBtn:SetText("Start tracking") end
        bulkDialog.startBtn = startBtn

        local cancelBtn = ns.CreateUIButton and ns.CreateUIButton(bulkDialog, {
            width = 90, height = 28, text = CANCEL or "Cancel", variant = "ghost",
        }) or CreateFrame("Button", nil, bulkDialog, "UIPanelButtonTemplate")
        cancelBtn:SetPoint("RIGHT", startBtn, "LEFT", -8, 0)
        if not ns.CreateUIButton then cancelBtn:SetSize(90, 28); cancelBtn:SetText("Cancel") end
        cancelBtn:SetScript("OnClick", function() bulkDialog:Hide() end)
    end

    -- Rebuild content each open
    local content = bulkDialog.content
    for _, c in ipairs({ content:GetChildren() }) do
        c:Hide()
        c:SetParent(nil)
    end
    for _, r in ipairs({ content:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then r:Hide() end
    end

    local y = 4
    local selectedExp = {}
    local selectedCat = {}

    local function Section(text)
        local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 4, -y)
        h:SetTextColor(0.15, 0.75, 0.95)
        h:SetText(text)
        y = y + 20
        return h
    end

    --- xOffset: indent for nested category rows under an expansion
    local function AddToggle(label, defaultOn, onChange, xOffset)
        xOffset = xOffset or 4
        local row
        if ns.CreateUIToggle then
            row = ns.CreateUIToggle(content, {
                label = label,
                labelOnRight = true,
                checked = defaultOn,
                onChange = onChange,
            })
            row:SetPoint("TOPLEFT", xOffset, -y)
        else
            row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
            row:SetPoint("TOPLEFT", xOffset, -y)
            row:SetChecked(defaultOn)
            local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("LEFT", row, "RIGHT", 4, 0)
            fs:SetText(label)
            row:SetScript("OnClick", function(self) onChange(self:GetChecked()) end)
            row.labelFS = fs
        end
        y = y + 28
        return row
    end

    -- Options
    Section(L["BULK_DIALOG_OPTS"] or "Options")
    local ordersOnly = ns.db and ns.db.settings.bulkTrackOrdersOnly ~= false
    local learnedOnly = ns.db and ns.db.settings.bulkTrackLearnedOnly
    AddToggle(L["BULK_OPT_ORDERS"] or "Orders only", ordersOnly, function(v)
        ordersOnly = v
        if ns.db then ns.db.settings.bulkTrackOrdersOnly = v end
    end)
    AddToggle(L["BULK_OPT_LEARNED"] or "Learned only", learnedOnly, function(v)
        learnedOnly = v
        if ns.db then ns.db.settings.bulkTrackLearnedOnly = v end
    end)

    y = y + 8
    Section(L["BULK_DIALOG_EXP"] or "Expansions & categories")
    local tree = CollectCategoriesByExpansion()
    local checkedExp = ns.db and ns.db.settings.bulkTrackExpansions or {}
    local expNodes = {} -- { skillLineID, expRow, catRows={ {row, cat} }, setEnabled }

    local function SetCatSelected(c, on)
        for _, id in ipairs(c.ids) do
            selectedCat[id] = on and true or nil
        end
    end

    local function SetExpansionEnabled(node, enabled)
        selectedExp[node.skillLineID] = enabled and true or nil
        for _, entry in ipairs(node.catRows) do
            if entry.row then
                if entry.row.SetEnabled then
                    entry.row:SetEnabled(enabled)
                else
                    entry.row:SetAlpha(enabled and 1 or 0.4)
                    if entry.row.EnableMouse then entry.row:EnableMouse(enabled) end
                end
                if not enabled then
                    -- Visual only: keep selection state but grey out
                    entry.row:SetAlpha(0.4)
                else
                    entry.row:SetAlpha(1)
                end
            end
        end
    end

    if #tree == 0 then
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 8, -y)
        fs:SetTextColor(0.55, 0.58, 0.62)
        fs:SetText(L["BULK_NO_EXP"] or "Open the profession to list expansions.")
        y = y + 22
    else
        for _, exp in ipairs(tree) do
            local id = exp.skillLineID
            local name = exp.name or ("#" .. tostring(id))
            local defaultOn = checkedExp[id] and true or false
            if not next(checkedExp) and exp.trained ~= false then
                defaultOn = true
            end
            if defaultOn then selectedExp[id] = true end

            local node = { skillLineID = id, catRows = {} }

            local expRow = AddToggle(name, defaultOn, function(v)
                SetExpansionEnabled(node, v and true or false)
            end, 4)

            -- Nested categories under this expansion
            if exp.categories and #exp.categories > 0 then
                for _, c in ipairs(exp.categories) do
                    if defaultOn then SetCatSelected(c, true) end
                    local catRow = AddToggle("  " .. c.name, defaultOn, function(v)
                        if not selectedExp[id] then return end
                        SetCatSelected(c, v)
                    end, 24)
                    table.insert(node.catRows, { row = catRow, cat = c })
                end
            else
                local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("TOPLEFT", 28, -y)
                fs:SetTextColor(0.45, 0.48, 0.52)
                fs:SetText(L["BULK_NO_CAT_UNDER"] or "  (no categories found)")
                y = y + 20
            end

            -- Initial disabled state if expansion off
            if not defaultOn then
                SetExpansionEnabled(node, false)
            end

            table.insert(expNodes, node)
            y = y + 6 -- gap between expansion blocks
        end
    end

    content:SetHeight(math.max(y + 20, 1))

    bulkDialog.startBtn:SetScript("OnClick", function()
        if ns.db then
            ns.db.settings.bulkTrackExpansions = ns.db.settings.bulkTrackExpansions or {}
            wipe(ns.db.settings.bulkTrackExpansions)
            for id, on in pairs(selectedExp) do
                if on then ns.db.settings.bulkTrackExpansions[id] = true end
            end
        end

        -- Only categories under *selected* expansions count
        local catFilter = nil
        local nOn, nTotal = 0, 0
        for _, node in ipairs(expNodes) do
            if selectedExp[node.skillLineID] then
                for _, entry in ipairs(node.catRows) do
                    for _, id in ipairs(entry.cat.ids) do
                        nTotal = nTotal + 1
                        if selectedCat[id] then
                            catFilter = catFilter or {}
                            catFilter[id] = true
                            nOn = nOn + 1
                        end
                    end
                end
            end
        end
        if catFilter and nTotal > 0 and nOn >= nTotal then
            catFilter = nil -- all selected under active expansions
        end

        bulkDialog:Hide()
        ns.BulkTrackCurrentProfession({
            ordersOnly = ordersOnly,
            learnedOnly = learnedOnly,
            categoryIDs = catFilter,
        })
        if currentRecipeID then
            isTracked = ns.DoesCharacterOwnRecipe(currentRecipeID)
            UpdateTrackButtonVisual()
        end
    end)

    bulkDialog:Show()
    bulkDialog:Raise()
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
    UpdateTrackButtonVisual()
    trackButton:Show()
    -- Bulk button is independent — ensure it stays visible on the list side
    ShowBulkButton()
end

----------------------------------------------------------------------
-- Hook installation
----------------------------------------------------------------------
local function InstallHooks()
    if hookInstalled then return end
    if not ProfessionsFrame or not ProfessionsFrame.CraftingPage then return end

    hooksecurefunc(ProfessionsFrame.CraftingPage, "SelectRecipe", OnRecipeSelected)
    hookInstalled = true

    -- Bell only: hide when leaving a recipe detail
    ProfessionsFrame.CraftingPage.SchematicForm:HookScript("OnHide", function()
        if trackButton then trackButton:Hide() end
        currentRecipeID = nil
    end)

    -- Track All follows the crafting page (list), not a selected recipe
    ProfessionsFrame.CraftingPage:HookScript("OnShow", function()
        C_Timer.After(0, ShowBulkButton)
    end)
    ProfessionsFrame.CraftingPage:HookScript("OnHide", function()
        if bulkButton then bulkButton:Hide() end
    end)
end

local waitFrame = CreateFrame("Frame")
waitFrame:RegisterEvent("TRADE_SKILL_SHOW")
waitFrame:SetScript("OnEvent", function(self, event)
    if event == "TRADE_SKILL_SHOW" then
        InstallHooks()
        C_Timer.After(0.15, function()
            if ProfessionsFrame and ProfessionsFrame.CraftingPage
                and ProfessionsFrame.CraftingPage:IsShown() then
                ShowBulkButton()
            end
        end)
    end
end)

-- Slash helper for testing without UI
ns.RegisterCallback("DB_READY", function()
    -- /cb bulk is registered from Init; expose the function only
end)