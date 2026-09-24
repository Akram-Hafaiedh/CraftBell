local addonName, ns = ...
local L = ns.L
local C = ns.UI.C

ns.UI.RecipesTab = ns.UI.RecipesTab or {}

local parentFrame, toolbar, footer, scroll, child
local searchBox, sortBtn, filterBtn, countLabel
local searchText = ""
local sortMode = "name"       -- name | profession | fee | owners
local filterProfessionID = nil -- nil = all
local filterCategoryID = nil   -- nil = all categories (within profession filter)
local assignMenuFrame
local actionMenuFrame

local SORT_LABELS = {
    name = "Sort: Name",
    profession = "Sort: Profession",
    fee = "Sort: Fee",
    owners = "Sort: Owners",
}
local SORT_CYCLE = { "name", "profession", "fee", "owners" }

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function OwnerCount(data)
    if not data or not data.owners then return 0 end
    local n = 0
    for _ in pairs(data.owners) do n = n + 1 end
    return n
end

local function AssignedLabel(data)
    local owner = ns.GetAssignedOwner and ns.GetAssignedOwner(data)
    if owner and owner.fullName then return owner.fullName end
    if data.character and data.character.fullName then return data.character.fullName end
    return "?"
end

local function ShortName(fullName)
    if not fullName then return "?" end
    local name = fullName:match("^([^-]+)")
    return name or fullName
end

local RECIPE_ICON_SIZE = 28

--- Resolve an item texture path/fileID from a tracked recipe entry.
local function ResolveRecipeIcon(data)
    if not data then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    if data.iconID then
        return data.iconID
    end
    local link = data.itemLink
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
        -- Enchant / spell-style links sometimes appear for profession products
        local spellID = tonumber(link:match("spell:(%d+)") or link:match("enchant:(%d+)"))
        if spellID and C_Spell and C_Spell.GetSpellTexture then
            local icon = C_Spell.GetSpellTexture(spellID)
            if icon then return icon end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function HideAssignMenu()
    if assignMenuFrame then assignMenuFrame:Hide() end
end

local function HideActionMenu()
    if actionMenuFrame then actionMenuFrame:Hide() end
end

local function HideAllRowMenus()
    HideAssignMenu()
    HideActionMenu()
    if feeEditFrame then feeEditFrame:Hide() end
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

local function MeasureTextWidth(text, fontObject)
    if not ns._measureFS then
        ns._measureFS = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ns._measureFS:Hide()
    end
    local fs = ns._measureFS
    if fontObject then fs:SetFontObject(fontObject) end
    fs:SetText(text or "")
    return fs:GetStringWidth() or 0
end

--- sideAnchor: if true, dock to the RIGHT of `anchor` (used next to Actions menu).
local function ShowAssignMenu(anchor, recipeID, data, sideAnchor)
    HideAssignMenu()
    local owners = ns.GetRecipeOwnerList and ns.GetRecipeOwnerList(recipeID) or {}
    if #owners == 0 then return end

    if not assignMenuFrame then
        assignMenuFrame = CreateFrame("Frame", "CraftBellAssignMenu", UIParent, "BackdropTemplate")
        assignMenuFrame:SetFrameStrata("TOOLTIP")
        assignMenuFrame:SetClampedToScreen(true)
        if ns.ApplyDarkTheme then ns.ApplyDarkTheme(assignMenuFrame) end
        assignMenuFrame:EnableMouse(true)
        assignMenuFrame:SetScript("OnLeave", function(self)
            C_Timer.After(0.12, function()
                if not self:IsShown() then return end
                local overAssign = self:IsMouseOver()
                local overActions = actionMenuFrame and actionMenuFrame:IsShown() and actionMenuFrame:IsMouseOver()
                if not overAssign and not overActions then
                    self:Hide()
                end
            end)
        end)
    end

    ClearMenuChildren(assignMenuFrame)

    local title = assignMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetTextColor(unpack(C.accent))
    title:SetText(L["ASSIGN_TO"] or "Assign to")

    local y = 24
    local minW, maxW = 160, 320
    local width = minW
    for _, fullName in ipairs(owners) do
        width = math.max(width, MeasureTextWidth("> " .. fullName) + 36)
    end
    width = math.min(maxW, math.max(minW, width))

    for _, fullName in ipairs(owners) do
        local isActive = data.assignedCharacter == fullName
        -- Avoid Unicode bullets (often render as lock/box); use ">" + primary style
        local btn = ns.CreateUIButton and ns.CreateUIButton(assignMenuFrame, {
            width = width - 16, height = 24,
            text = (isActive and "> " or "  ") .. fullName,
            variant = isActive and "primary" or "ghost",
        }) or CreateFrame("Button", nil, assignMenuFrame, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", 8, -y)
        if not ns.CreateUIButton then
            btn:SetSize(width - 16, 24)
            btn:SetText((isActive and "> " or "  ") .. fullName)
        end
        btn:SetScript("OnClick", function()
            if ns.AssignRecipeCharacter then
                ns.AssignRecipeCharacter(recipeID, fullName)
            end
            HideAllRowMenus()
            ns.UI.RecipesTab.Refresh()
        end)
        y = y + 28
    end

    assignMenuFrame:SetSize(width, y + 8)
    assignMenuFrame:ClearAllPoints()
    if sideAnchor and anchor then
        assignMenuFrame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    else
        assignMenuFrame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    end
    assignMenuFrame:Show()
end

-- Forward declare: ShowRowActionsMenu calls ShowFeeEditor (defined below).
local ShowFeeEditor
local feeEditFrame, feeEditBox, feeEditRecipeID

--- Single "Actions" menu per row (replaces Assign / Fee / Remove buttons).
local function ShowRowActionsMenu(anchor, recipeID, data)
    HideAllRowMenus()

    if not actionMenuFrame then
        actionMenuFrame = CreateFrame("Frame", "CraftBellRowActions", UIParent, "BackdropTemplate")
        actionMenuFrame:SetFrameStrata("TOOLTIP")
        actionMenuFrame:SetClampedToScreen(true)
        if ns.ApplyDarkTheme then ns.ApplyDarkTheme(actionMenuFrame) end
        actionMenuFrame:EnableMouse(true)
        actionMenuFrame:SetScript("OnLeave", function(self)
            C_Timer.After(0.12, function()
                if not self:IsShown() then return end
                local overActions = self:IsMouseOver()
                local overAssign = assignMenuFrame and assignMenuFrame:IsShown() and assignMenuFrame:IsMouseOver()
                local overFee = feeEditFrame and feeEditFrame:IsShown() and feeEditFrame:IsMouseOver()
                if not overActions and not overAssign and not overFee then
                    HideAllRowMenus()
                end
            end)
        end)
    end

    ClearMenuChildren(actionMenuFrame)

    local nOwners = 0
    if data.owners then for _ in pairs(data.owners) do nOwners = nOwners + 1 end end
    local me = ns.GetPlayerFullName and ns.GetPlayerFullName()
    local iOwn = me and data.owners and data.owners[me]
    local hasOverride = ns.HasRecipeFeeOverride and ns.HasRecipeFeeOverride(data)
    local canOpen = not ns.CanOpenRecipe or ns.CanOpenRecipe(recipeID, data)

    local width = 200
    local y = 8

    -- keepOpen = true → leave Actions visible; panel docks to its right
    local function AddAction(label, variant, onClick, keepOpen)
        local btn = ns.CreateUIButton and ns.CreateUIButton(actionMenuFrame, {
            width = width - 16, height = 24,
            text = label,
            variant = variant or "ghost",
        }) or CreateFrame("Button", nil, actionMenuFrame, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", 8, -y)
        if not ns.CreateUIButton then
            btn:SetSize(width - 16, 24)
            btn:SetText(label)
        end
        btn:SetScript("OnClick", function()
            if not keepOpen then
                HideAllRowMenus()
            else
                HideAssignMenu()
                if feeEditFrame then feeEditFrame:Hide() end
            end
            onClick()
        end)
        y = y + 28
        return btn
    end

    local title = actionMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetTextColor(unpack(C.accent))
    title:SetText(L["ACTIONS"] or "Actions")
    y = 26

    if canOpen then
        AddAction(L["ACTION_OPEN"] or "Open in profession", "ghost", function()
            if ns.OpenRecipe then ns.OpenRecipe(recipeID) end
        end)
    end

    if nOwners > 1 then
        AddAction(L["ACTION_ASSIGN"] or "Assign crafter…", "ghost", function()
            ShowAssignMenu(actionMenuFrame, recipeID, data, true)
        end, true)
    end

    AddAction(L["ACTION_FEE"] or "Set fee…", "ghost", function()
        ShowFeeEditor(actionMenuFrame, recipeID, data, true)
    end, true)

    if hasOverride then
        AddAction(L["ACTION_CLEAR_FEE"] or "Clear fee override", "ghost", function()
            if ns.SetRecipeFeeOverride then
                ns.SetRecipeFeeOverride(recipeID, nil)
            end
            ns.UI.RecipesTab.Refresh()
        end)
    end

    if iOwn then
        AddAction(L["ACTION_DROP_ME"] or "Remove me as owner", "ghost", function()
            if ns.UntrackRecipe then ns.UntrackRecipe(recipeID) end
            ns.UI.RecipesTab.Refresh()
        end)
    end

    -- Fully delete for all owners. Never call UntrackRecipe here (that only drops
    -- the current character and prints "Removed owner: …").
    local function FullyUntrack()
        if ns.DeleteTrackedRecipe then
            ns.DeleteTrackedRecipe(recipeID)
        elseif ns.db and ns.db.trackedRecipes and ns.db.trackedRecipes[recipeID] then
            local d = ns.db.trackedRecipes[recipeID]
            local label = d.itemLink or d.recipeName or ("#" .. tostring(recipeID))
            ns.db.trackedRecipes[recipeID] = nil
            ns.Print((L["RECIPE_DELETED"] or "Untracked (all owners): ") .. label)
            if ns.FireCallback then ns.FireCallback("RECIPE_UNTRACKED", recipeID) end
        else
            ns.Print("Could not untrack — recipe not found.")
        end
        ns.UI.RecipesTab.Refresh()
    end

    AddAction(L["ACTION_UNTRACK"] or "Untrack for everyone", "danger", function()
        if nOwners > 1 and StaticPopupDialogs and StaticPopup_Show then
            local key = "CRAFTBELL_DELETE_RECIPE"
            local rName = data.recipeName or ("#" .. tostring(recipeID))
            local rOwners = nOwners
            StaticPopupDialogs[key] = {
                text = string.format(
                    L["DELETE_RECIPE_CONFIRM"]
                        or "Untrack this recipe for ALL owners?\n%s\n(%d characters own it)",
                    rName,
                    rOwners
                ),
                button1 = YES or "Yes",
                button2 = NO or "No",
                OnAccept = FullyUntrack,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show(key)
        else
            FullyUntrack()
        end
    end)

    actionMenuFrame:SetSize(width, y + 8)
    actionMenuFrame:ClearAllPoints()
    actionMenuFrame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    actionMenuFrame:Show()
end

----------------------------------------------------------------------
-- Fee edit popup (simple)
----------------------------------------------------------------------
function ShowFeeEditor(anchor, recipeID, data, sideAnchor)
    if not feeEditFrame then
        feeEditFrame = CreateFrame("Frame", "CraftBellFeeEdit", UIParent, "BackdropTemplate")
        feeEditFrame:SetSize(220, 90)
        feeEditFrame:SetFrameStrata("TOOLTIP")
        feeEditFrame:SetClampedToScreen(true)
        if ns.ApplyDarkTheme then ns.ApplyDarkTheme(feeEditFrame) end
        feeEditFrame:EnableMouse(true)
        feeEditFrame:SetScript("OnLeave", function(self)
            C_Timer.After(0.12, function()
                if not self:IsShown() then return end
                local overFee = self:IsMouseOver()
                local overActions = actionMenuFrame and actionMenuFrame:IsShown() and actionMenuFrame:IsMouseOver()
                if not overFee and not overActions then
                    -- keep open while typing; only auto-hide if focus left entirely
                    if feeEditBox and feeEditBox:HasFocus() then return end
                    self:Hide()
                end
            end)
        end)

        local lbl = feeEditFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 10, -10)
        lbl:SetTextColor(unpack(C.accent))
        lbl:SetText(L["FEE_EDIT_TITLE"] or "Recipe fee (gold)")

        local hint = feeEditFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 10, -26)
        hint:SetTextColor(unpack(C.textMuted))
        hint:SetText(L["FEE_EDIT_HINT"] or "Empty = profession default. Try 10k or 1.5k")

        feeEditBox = ns.CreateUIEditBox and ns.CreateUIEditBox(feeEditFrame, {
            name = "CraftBellFeeEditBox", height = 24, numeric = false,
        }) or CreateFrame("EditBox", "CraftBellFeeEditBox", feeEditFrame, "InputBoxTemplate")
        -- allow 10k / 1.5k style input (not numeric-only)
        feeEditBox:SetSize(80, 24)
        feeEditBox:SetPoint("TOPLEFT", 10, -48)
        feeEditBox:SetAutoFocus(true)

        local saveBtn = ns.CreateUIButton and ns.CreateUIButton(feeEditFrame, {
            width = 50, height = 24, text = "OK", variant = "primary",
        }) or CreateFrame("Button", nil, feeEditFrame, "UIPanelButtonTemplate")
        saveBtn:SetPoint("LEFT", feeEditBox, "RIGHT", 8, 0)
        if not ns.CreateUIButton then saveBtn:SetSize(50, 24); saveBtn:SetText("OK") end

        local clearBtn = ns.CreateUIButton and ns.CreateUIButton(feeEditFrame, {
            width = 50, height = 24, text = "Clear", variant = "ghost",
        }) or CreateFrame("Button", nil, feeEditFrame, "UIPanelButtonTemplate")
        clearBtn:SetPoint("LEFT", saveBtn, "RIGHT", 4, 0)
        if not ns.CreateUIButton then clearBtn:SetSize(50, 24); clearBtn:SetText("Clear") end

        local function Commit(clear)
            local rid = feeEditRecipeID
            -- Hide + detach first so Refresh / fee callbacks cannot re-anchor
            -- the popup to a destroyed Actions button (snap to bottom of screen).
            feeEditRecipeID = nil
            if feeEditFrame then
                feeEditFrame:Hide()
                feeEditFrame:ClearAllPoints()
            end
            HideActionMenu()
            HideAssignMenu()
            if not rid then return end
            if clear then
                ns.SetRecipeFee(rid, nil)
            else
                local t = feeEditBox:GetText()
                if t == "" then
                    ns.SetRecipeFee(rid, nil)
                else
                    local gold = (ns.ParseGoldAmount and ns.ParseGoldAmount(t)) or tonumber(t)
                    ns.SetRecipeFee(rid, gold)
                end
            end
            -- Refresh already fired via RECIPE_FEE_CHANGED; preserve scroll there
            if ns.UI.RecipesTab.Refresh then
                ns.UI.RecipesTab.Refresh()
            end
        end
        saveBtn:SetScript("OnClick", function() Commit(false) end)
        clearBtn:SetScript("OnClick", function() Commit(true) end)
        feeEditBox:SetScript("OnEnterPressed", function() Commit(false) end)
        feeEditBox:SetScript("OnEscapePressed", function() HideAllRowMenus() end)
    end

    feeEditRecipeID = recipeID
    local shown = data.feeOverride
    feeEditBox:SetText(shown ~= nil and tostring(shown) or "")
    feeEditFrame:ClearAllPoints()
    if sideAnchor and anchor then
        feeEditFrame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    else
        feeEditFrame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    end
    feeEditFrame:Show()
    feeEditBox:SetFocus()
end

----------------------------------------------------------------------
-- Filter / collect
----------------------------------------------------------------------

--- High-level profession buckets like "Midnight Patterns" are too coarse for
--- filtering (everything lands in one folder). Prefer the leaf category name
--- from the profession book; if that is still generic, fall back to item type
--- (Leather / Mail / Cloth / …) so Mail LW vs Leather LW is usable.
local function IsGenericCategoryName(name)
    if not name or name == "" then return true end
    local n = name:lower()
    return n:find("pattern", 1, true)
        or n:find("recipes", 1, true)
        or n:find("uncategorized", 1, true)
        or n == "midnight"
        or n:find("war within", 1, true)
        or n:find("dragonflight", 1, true)
        or n:find("shadowlands", 1, true)
end

local function ItemTypeGroupLabel(data)
    local link = data and data.itemLink
    if not link then return nil end
    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return nil end

    local classID, subclassID
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, c, s = C_Item.GetItemInfoInstant(itemID)
        classID, subclassID = c, s
    elseif GetItemInfoInstant then
        local _, _, _, _, _, c, s = GetItemInfoInstant(itemID)
        classID, subclassID = c, s
    end
    if not classID then return nil end

    -- Enum.ItemClass: 2 Weapon, 3 Gem, 4 Armor, 7 Tradeskill, …
    if classID == 4 then -- Armor
        local armor = {
            [0] = "Miscellaneous",
            [1] = "Cloth",
            [2] = "Leather",
            [3] = "Mail",
            [4] = "Plate",
            [5] = "Cosmetic",
            [6] = "Shields",
        }
        return armor[subclassID] or "Armor"
    elseif classID == 2 then
        return "Weapons"
    elseif classID == 3 then
        return "Gems"
    elseif classID == 7 then
        return "Profession tools"
    elseif classID == 9 then
        return "Recipes"
    elseif classID == 15 or classID == 5 then
        return "Consumables"
    end
    return nil
end

local function IsValidCategoryID(id)
    if id == nil then return false end
    if type(id) == "string" then return id ~= "" end
    if type(id) == "number" then return id > 0 end
    return false
end

--- Resolve a filter category for a recipe.
--- On the tracking character (profession open) we get real book folders.
--- On other alts GetRecipeInfo often returns categoryID 0 — never overwrite
--- a good saved name with that. Saved fields come from Track All / TrackRecipe.
--- Returns id (number or "type:Leather"), display name.
local function GetRecipeCategory(recipeID, data)
    if not data then return nil, nil end

    local catID, catName

    -- 1) Prefer saved category when it is valid and not a generic expansion bucket
    if IsValidCategoryID(data.categoryID) and data.categoryName
        and not IsGenericCategoryName(data.categoryName)
        and not tostring(data.categoryName):match("^Category%s*%d+$") then
        return data.categoryID, data.categoryName
    end

    -- 2) Live profession API (only when it returns a real category id > 0)
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if ok and info and IsValidCategoryID(info.categoryID) then
            catID = info.categoryID
            if C_TradeSkillUI.GetCategoryInfo then
                local ok2, cat = pcall(C_TradeSkillUI.GetCategoryInfo, info.categoryID)
                if ok2 and cat and cat.name and cat.name ~= "" then
                    catName = cat.name
                end
            end
            if catName and not IsGenericCategoryName(catName) then
                data.categoryID = catID
                data.categoryName = catName
                return catID, catName
            end
            -- keep catID/catName for possible generic → type fallback below
            catName = catName or nil
        end
    end

    -- 3) Saved value even if generic (better than "Category 0")
    if IsValidCategoryID(data.categoryID) and data.categoryName
        and not tostring(data.categoryName):match("^Category%s*%d+$") then
        catID = data.categoryID
        catName = data.categoryName
    end

    -- 4) Item armor/type group (works offline via itemLink — Leather / Mail / …)
    if not catName or IsGenericCategoryName(catName) or tostring(catName):match("^Category%s*%d+$") then
        local typeLabel = ItemTypeGroupLabel(data)
        if typeLabel then
            catID = "type:" .. typeLabel
            catName = typeLabel
        end
    end

    -- 5) Last resort: never persist "Category 0"
    if catID == 0 or catName and tostring(catName):match("^Category%s*%d+$") then
        return nil, nil
    end

    if IsValidCategoryID(catID) and catName then
        data.categoryID = catID
        data.categoryName = catName
    end
    return catID, catName
end

local function CollectIDs()
    local ids = {}
    if not ns.db or not ns.db.trackedRecipes then return ids end
    local q = (searchText or ""):lower()
    for id, data in pairs(ns.db.trackedRecipes) do
        if filterProfessionID and data.professionID ~= filterProfessionID then
            -- skip
        else
            local catOK = true
            if filterCategoryID then
                local catID = GetRecipeCategory(id, data)
                catOK = (catID == filterCategoryID)
            end
            if catOK then
                if q == "" then
                    table.insert(ids, id)
                else
                    local name = (data.recipeName or ""):lower()
                    local prof = (data.professionName or ""):lower()
                    local assigned = AssignedLabel(data):lower()
                    local catName = (data.categoryName or ""):lower()
                    if name:find(q, 1, true) or prof:find(q, 1, true)
                        or assigned:find(q, 1, true) or catName:find(q, 1, true) then
                        table.insert(ids, id)
                    end
                end
            end
        end
    end

    table.sort(ids, function(a, b)
        local da, db = ns.db.trackedRecipes[a], ns.db.trackedRecipes[b]
        if sortMode == "profession" then
            local pa, pb = da.professionName or "", db.professionName or ""
            if pa ~= pb then return pa < pb end
            return (da.recipeName or "") < (db.recipeName or "")
        elseif sortMode == "fee" then
            local fa, fb = ns.GetRecipeFee(da), ns.GetRecipeFee(db)
            if fa ~= fb then return fa > fb end
            return (da.recipeName or "") < (db.recipeName or "")
        elseif sortMode == "owners" then
            local oa, ob = OwnerCount(da), OwnerCount(db)
            if oa ~= ob then return oa > ob end
            return (da.recipeName or "") < (db.recipeName or "")
        else
            return (da.recipeName or "") < (db.recipeName or "")
        end
    end)
    return ids
end

--- Cascading options: each profession carries its category children for the flyout.
local function BuildCascadingFilterOptions()
    local opts = {
        { value = nil, label = L["FILTER_ALL"] or "All professions", children = nil },
    }
    if not ns.db or not ns.db.trackedRecipes then return opts end

    local list = ns.GetTrackedProfessionList and ns.GetTrackedProfessionList() or {}
    for _, p in ipairs(list) do
        local byCat = {}
        for recipeID, data in pairs(ns.db.trackedRecipes) do
            if data.professionID == p.id then
                local catID, catName = GetRecipeCategory(recipeID, data)
                if catID and not byCat[catID] then
                    byCat[catID] = catName or ("#" .. tostring(catID))
                end
            end
        end
        local children = {}
        for id, name in pairs(byCat) do
            table.insert(children, { value = id, label = name })
        end
        table.sort(children, function(a, b) return (a.label or "") < (b.label or "") end)
        table.insert(opts, {
            value = p.id,
            label = p.name,
            children = (#children > 0) and children or nil,
        })
    end
    return opts
end

local function RefreshFilterDropdown()
    if not filterBtn or not filterBtn.SetOptions then return end
    local opts = BuildCascadingFilterOptions()
    filterBtn:SetOptions(opts)

    local stillValid = filterProfessionID == nil
    if filterProfessionID then
        for _, o in ipairs(opts) do
            if o.value == filterProfessionID then
                stillValid = true
                if filterCategoryID and o.children then
                    local catOK = false
                    for _, ch in ipairs(o.children) do
                        if ch.value == filterCategoryID then catOK = true; break end
                    end
                    if not catOK then filterCategoryID = nil end
                end
                break
            end
        end
    end
    if not stillValid then
        filterProfessionID = nil
        filterCategoryID = nil
    end
    -- silent so we don't re-trigger refresh loops
    if filterBtn.SetValue then
        filterBtn:SetValue(filterProfessionID, filterCategoryID, true)
    end
end

----------------------------------------------------------------------
-- Init / Refresh
----------------------------------------------------------------------
function ns.UI.RecipesTab.Init(parent)
    parentFrame = parent

    -- Top toolbar: search + profession + sort, then category row
    toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", 0, 0)
    toolbar:SetHeight(36)

    -- Sort (right) → filter (left of sort) → search fills remaining space
    if ns.CreateUIDropdown then
        sortBtn = ns.CreateUIDropdown(toolbar, {
            width = 120, height = 26,
            placeholder = SORT_LABELS.name,
            onSelect = function(value)
                sortMode = value or "name"
                ns.UI.RecipesTab.Refresh()
            end,
        })
        sortBtn:SetOptions({
            { value = "name", label = SORT_LABELS.name },
            { value = "profession", label = SORT_LABELS.profession },
            { value = "fee", label = SORT_LABELS.fee },
            { value = "owners", label = SORT_LABELS.owners },
        })
        sortBtn:SetValue(sortMode, true)
    else
        sortBtn = ns.CreateUIButton and ns.CreateUIButton(toolbar, {
            width = 120, height = 26, text = SORT_LABELS[sortMode], variant = "ghost",
        }) or CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
        sortBtn:SetScript("OnClick", function()
            local idx = 1
            for i, m in ipairs(SORT_CYCLE) do
                if m == sortMode then idx = i; break end
            end
            sortMode = SORT_CYCLE[(idx % #SORT_CYCLE) + 1]
            if sortBtn.SetText then sortBtn:SetText(SORT_LABELS[sortMode]) end
            ns.UI.RecipesTab.Refresh()
        end)
    end
    sortBtn:SetPoint("TOPRIGHT", 0, -2)

    -- Profession filter with category flyout (hover profession → categories on the right)
    if ns.CreateCascadingDropdown then
        filterBtn = ns.CreateCascadingDropdown(toolbar, {
            width = 200, height = 26,
            submenuWidth = 160, -- minimum; expands for long category names
            placeholder = L["FILTER_ALL"] or "All professions",
            allChildrenLabel = L["FILTER_ALL_CATS"] or "All categories",
            onSelect = function(profID, catID)
                filterProfessionID = profID
                filterCategoryID = catID
                ns.UI.RecipesTab.Refresh()
            end,
        })
    elseif ns.CreateUIDropdown then
        filterBtn = ns.CreateUIDropdown(toolbar, {
            width = 200, height = 26,
            placeholder = L["FILTER_ALL"] or "All professions",
            onSelect = function(value)
                filterProfessionID = value
                filterCategoryID = nil
                ns.UI.RecipesTab.Refresh()
            end,
        })
    else
        filterBtn = ns.CreateUIButton and ns.CreateUIButton(toolbar, {
            width = 200, height = 26, text = L["FILTER_ALL"] or "Filter: All", variant = "ghost",
        }) or CreateFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
    end
    filterBtn:SetPoint("RIGHT", sortBtn, "LEFT", -6, 0)

    searchBox = ns.CreateUIEditBox and ns.CreateUIEditBox(toolbar, {
        name = "CraftBellRecipeSearch", height = 26,
    }) or CreateFrame("EditBox", "CraftBellRecipeSearch", toolbar, "InputBoxTemplate")
    searchBox:SetHeight(26)
    searchBox:SetPoint("TOPLEFT", 0, -2)
    -- Stretch up to the filter button (no fixed width — avoids overlap)
    searchBox:SetPoint("RIGHT", filterBtn, "LEFT", -8, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(60)
    if searchBox.SetTextColor then searchBox:SetTextColor(unpack(C.text)) end
    local searchHint = toolbar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchBox, "LEFT", 10, 0)
    searchHint:SetText(L["SEARCH_HINT"] or "Search recipes, profession, character…")
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        searchHint:SetShown(searchText == "")
        ns.UI.RecipesTab.Refresh()
    end)
    searchBox:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then searchHint:Show() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        searchText = ""
        self:ClearFocus()
        ns.UI.RecipesTab.Refresh()
    end)

    countLabel = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("TOPLEFT", 2, -34)
    countLabel:SetTextColor(unpack(C.textMuted))
    countLabel:SetText("")

    -- Keep count visible under the search row
    toolbar:SetHeight(52)
    countLabel:ClearAllPoints()
    countLabel:SetPoint("TOPLEFT", 2, -32)

    RefreshFilterDropdown()

    ----------------------------------------------------------------------
    -- Footer: clear actions (bottom-right)
    ----------------------------------------------------------------------
    footer = CreateFrame("Frame", nil, parent)
    footer:SetPoint("BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", 0, 0)
    footer:SetHeight(28)

    local function ConfirmThen(title, message, action)
        if StaticPopupDialogs and StaticPopup_Show then
            local key = "CRAFTBELL_CONFIRM_CLEAR"
            StaticPopupDialogs[key] = {
                text = message,
                button1 = YES or "Yes",
                button2 = NO or "No",
                OnAccept = action,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show(key)
        else
            action()
        end
    end

    local clearAllBtn = ns.CreateUIButton and ns.CreateUIButton(footer, {
        width = 90, height = 22,
        text = L["CLEAR_ALL_BTN"] or "Clear all",
        variant = "danger",
    }) or CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    clearAllBtn:SetPoint("BOTTOMRIGHT", 0, 2)
    if not ns.CreateUIButton then clearAllBtn:SetSize(90, 22); clearAllBtn:SetText("Clear all") end
    clearAllBtn:SetScript("OnClick", function()
        ConfirmThen(
            "Clear all",
            L["CLEAR_ALL_CONFIRM"]
                or "Delete ALL tracked recipes for every character?\nThis cannot be undone.",
            function()
                if ns.ClearAllRecipes then ns.ClearAllRecipes() end
                ns.UI.RecipesTab.Refresh()
            end
        )
    end)
    clearAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["CLEAR_ALL_TIP"] or "Same as /cb clear all", 0.85, 0.30, 0.32)
        GameTooltip:AddLine("Wipes the entire tracked list (all alts).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local clearProfBtn = ns.CreateUIButton and ns.CreateUIButton(footer, {
        width = 110, height = 22,
        text = L["CLEAR_PROF_BTN"] or "Clear profession",
        variant = "ghost",
    }) or CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    clearProfBtn:SetPoint("RIGHT", clearAllBtn, "LEFT", -6, 0)
    if not ns.CreateUIButton then clearProfBtn:SetSize(110, 22); clearProfBtn:SetText("Clear profession") end
    clearProfBtn:SetScript("OnClick", function()
        ConfirmThen(
            "Clear profession",
            L["CLEAR_PROF_CONFIRM"]
                or "Remove this character's ownership of recipes for the currently open profession?\nOpen a profession window first.",
            function()
                if ns.ClearCurrentProfession then ns.ClearCurrentProfession() end
                ns.UI.RecipesTab.Refresh()
            end
        )
    end)
    clearProfBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["CLEAR_PROF_TIP"] or "Same as /cb clear prof", 0.15, 0.75, 0.95)
        GameTooltip:AddLine("Needs an open profession window. Only affects the current character.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearProfBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local clearCharBtn = ns.CreateUIButton and ns.CreateUIButton(footer, {
        width = 110, height = 22,
        text = L["CLEAR_CHAR_BTN"] or "Clear character",
        variant = "ghost",
    }) or CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    clearCharBtn:SetPoint("RIGHT", clearProfBtn, "LEFT", -6, 0)
    if not ns.CreateUIButton then clearCharBtn:SetSize(110, 22); clearCharBtn:SetText("Clear character") end
    clearCharBtn:SetScript("OnClick", function()
        local me = ns.GetPlayerFullName and ns.GetPlayerFullName() or UnitName("player")
        ConfirmThen(
            "Clear character",
            string.format(
                L["CLEAR_CHAR_CONFIRM"]
                    or "Remove %s as owner from all tracked recipes?\n(Shared recipes stay if other alts still own them.)",
                me or "?"
            ),
            function()
                if ns.ClearCurrentCharacter then ns.ClearCurrentCharacter() end
                ns.UI.RecipesTab.Refresh()
            end
        )
    end)
    clearCharBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["CLEAR_CHAR_TIP"] or "Same as /cb clear", 0.15, 0.75, 0.95)
        GameTooltip:AddLine("Drops this character as owner; multi-owner recipes keep other alts.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    clearCharBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Scroll between toolbar and footer
    local scrollHost = CreateFrame("Frame", nil, parent)
    scrollHost:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
    scrollHost:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 4)
    scroll, child = ns.UI.CreateScrollArea(scrollHost)
end

function ns.UI.RecipesTab.Refresh()
    if not child or not ns.db then return end

    -- Keep list scroll position (fee save used to jump the list)
    local savedScroll = 0
    if scroll and scroll.GetVerticalScroll then
        savedScroll = scroll:GetVerticalScroll() or 0
    end

    RefreshFilterDropdown()
    -- Don't call HideAllRowMenus here when fee just closed — already hidden.
    -- Still close menus on normal refresh so stale popups don't linger.
    if feeEditFrame and feeEditFrame:IsShown() then
        feeEditFrame:Hide()
        feeEditFrame:ClearAllPoints()
        feeEditRecipeID = nil
    end
    HideAssignMenu()
    HideActionMenu()

    ns.UI.ClearChildren(child)
    local y = 0
    local rowHeight = 52
    local gap = 4

    local ids = CollectIDs()
    local total = 0
    for _ in pairs(ns.db.trackedRecipes) do total = total + 1 end
    if countLabel then
        countLabel:SetText(string.format(L["RECIPE_COUNT"] or "%d shown · %d tracked", #ids, total))
    end

    if #ids == 0 then
        local empty = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetPoint("RIGHT", child, "RIGHT", -16, 0)
        empty:SetJustifyH("LEFT")
        empty:SetJustifyV("TOP")
        empty:SetWordWrap(true)
        empty:SetSpacing(2)
        empty:SetTextColor(unpack(C.textMuted))
        if total == 0 then
            empty:SetText(L["NO_RECIPES_TRACKED"] or table.concat({
                "No recipes tracked yet.",
                "",
                "How to scan:",
                "  1. Open your profession window (e.g. Enchanting).",
                "  2. Pick the expansion tab you care about (Midnight, Khaz Algar, …).",
                "  3. Click  Track All  next to the recipe list.",
                "",
                "Optional — multi-expansion checklist:",
                "  /cb exp list          see trained expansions",
                "  /cb exp add Midnight  include that line in Track All",
                "  /cb exp alltrained    check every trained expansion",
                "",
                "Repeat on each crafting alt so shared recipes get multiple owners.",
            }, "\n"))
        else
            empty:SetText(L["NO_RECIPES_MATCH"] or "No recipes match this search / filter.")
        end
        y = 220
    end

    for _, id in ipairs(ids) do
        local data = ns.db.trackedRecipes[id]
        local nOwners = OwnerCount(data)
        local row = ns.CreateUIRow and ns.CreateUIRow(child, rowHeight - gap)
            or CreateFrame("Frame", nil, child, "BackdropTemplate")
        if not ns.CreateUIRow then
            row:SetHeight(rowHeight - gap)
            if ns.ApplyCardTheme then ns.ApplyCardTheme(row) end
        end
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", -4, -y)
        if row.SetAccent then row:SetAccent(nOwners > 1) end

        -- Item icon (28px) + name: full item tooltip on hover; click opens profession UI
        local canOpen = not ns.CanOpenRecipe or ns.CanOpenRecipe(id, data)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(RECIPE_ICON_SIZE, RECIPE_ICON_SIZE)
        icon:SetPoint("LEFT", 8, 0)
        icon:SetTexture(ResolveRecipeIcon(data))
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        -- Subtle border behind the icon
        local iconBg = row:CreateTexture(nil, "BACKGROUND")
        iconBg:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
        iconBg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
        iconBg:SetColorTexture(0.15, 0.16, 0.18, 0.9)

        local nameBtn = CreateFrame("Button", nil, row)
        nameBtn:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 4)
        nameBtn:SetPoint("RIGHT", row, "RIGHT", -88, 0)
        nameBtn:SetHeight(18)
        nameBtn:EnableMouse(true)

        local nameFS = nameBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameFS:SetAllPoints()
        nameFS:SetJustifyH("LEFT")
        nameFS:SetTextColor(unpack(C.text))
        nameFS:SetText(data.itemLink or data.recipeName or ("#" .. id))

        local function ShowRecipeTooltip(anchor)
            nameFS:SetTextColor(unpack(C.accent))
            GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
            local shown = false
            if data.itemLink then
                local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, data.itemLink)
                shown = ok
            end
            if not shown then
                GameTooltip:SetText(data.recipeName or ("#" .. tostring(id)), 1, 1, 1)
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("CraftBell", 0.15, 0.75, 0.95)
            if data.owners and next(data.owners) then
                GameTooltip:AddLine(L["OWNERS_LABEL"] or "Owners:", 0.7, 0.7, 0.7)
                for fullName in pairs(data.owners) do
                    local isAssigned = (fullName == data.assignedCharacter)
                    if isAssigned then
                        GameTooltip:AddLine("  > " .. fullName, 0.15, 0.75, 0.95)
                    else
                        GameTooltip:AddLine("    " .. fullName, 0.85, 0.85, 0.85)
                    end
                end
            elseif data.assignedCharacter then
                GameTooltip:AddLine((L["ASSIGNED_LABEL"] or "Assigned: ") .. data.assignedCharacter, 0.85, 0.85, 0.85)
            end
            if canOpen then
                GameTooltip:AddLine(L["OPEN_RECIPE_TIP"] or "Click to open in the profession window", 0.5, 0.5, 0.5)
            else
                GameTooltip:AddLine(L["OPEN_RECIPE_NEED_PROF"] or "This character cannot open that recipe.", 0.85, 0.35, 0.35)
            end
            GameTooltip:Show()
        end

        local function HideRecipeTooltip()
            nameFS:SetTextColor(unpack(C.text))
            GameTooltip:Hide()
        end

        local function ClickOpenRecipe()
            if ns.OpenRecipe then
                ns.OpenRecipe(id)
            elseif C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
                pcall(C_TradeSkillUI.OpenRecipe, id)
            end
        end

        nameBtn:SetScript("OnEnter", function(self) ShowRecipeTooltip(self) end)
        nameBtn:SetScript("OnLeave", HideRecipeTooltip)
        nameBtn:SetScript("OnClick", ClickOpenRecipe)

        -- Icon is also hoverable / clickable (same tooltip + open)
        local iconBtn = CreateFrame("Button", nil, row)
        iconBtn:SetAllPoints(icon)
        iconBtn:SetScript("OnEnter", function(self) ShowRecipeTooltip(self) end)
        iconBtn:SetScript("OnLeave", HideRecipeTooltip)
        iconBtn:SetScript("OnClick", ClickOpenRecipe)

        -- Subline (aligned with name, under the icon row)
        local sub = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 0)
        sub:SetPoint("RIGHT", row, "RIGHT", -88, 0)
        sub:SetJustifyH("LEFT")
        sub:SetTextColor(unpack(C.textMuted))

        local fee = ns.GetRecipeFee(data)
        local hasOverride = ns.HasRecipeFeeOverride and ns.HasRecipeFeeOverride(data)
        local feeText
        if fee > 0 then
            feeText = (hasOverride and "|cff26c0f2" or "|cffe6c35c") .. ns.FormatFee(fee) .. "|r"
            if hasOverride then feeText = feeText .. " |cff888888(custom)|r" end
        else
            feeText = L["NO_FEE_SET"] or "no fee"
        end

        local assigned = AssignedLabel(data)
        local ownerNote = nOwners > 1
            and string.format("|cff26c0f2%d|r · %s", nOwners, ShortName(assigned))
            or ShortName(assigned)

        sub:SetText(string.format("%s    %s    %s",
            data.professionName or "?",
            ownerNote,
            feeText))

        -- Single Actions menu (replaces Assign / Fee / Remove)
        local actionsBtn = ns.CreateUIButton and ns.CreateUIButton(row, {
            width = 72, height = 22,
            text = L["ACTIONS"] or "Actions",
            variant = "ghost",
        }) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        actionsBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        if not ns.CreateUIButton then
            actionsBtn:SetSize(72, 22)
            actionsBtn:SetText(L["ACTIONS"] or "Actions")
        end
        actionsBtn:SetScript("OnClick", function(self)
            if actionMenuFrame and actionMenuFrame:IsShown() then
                HideActionMenu()
            else
                ShowRowActionsMenu(self, id, data)
            end
        end)

        y = y + rowHeight
    end

    child:SetSize(math.max(scroll:GetWidth() or 1, 1), math.max(y, 1))

    -- Restore scroll after rebuild (fee edits / assign used to jump the list)
    if scroll and scroll.SetVerticalScroll then
        C_Timer.After(0, function()
            if not scroll then return end
            local maxScroll = 0
            if scroll.GetVerticalScrollRange then
                maxScroll = scroll:GetVerticalScrollRange() or 0
            end
            scroll:SetVerticalScroll(math.min(savedScroll or 0, maxScroll))
        end)
    end
end

local function RefreshIfVisible()
    if ns.UI.IsMainWindowShown() then ns.UI.RecipesTab.Refresh() end
end

ns.RegisterCallback("RECIPE_TRACKED", RefreshIfVisible)
ns.RegisterCallback("RECIPE_UNTRACKED", RefreshIfVisible)
ns.RegisterCallback("RECIPE_ASSIGNED", RefreshIfVisible)
ns.RegisterCallback("RECIPE_FEE_CHANGED", RefreshIfVisible)
ns.RegisterCallback("BULK_TRACK_DONE", RefreshIfVisible)
ns.RegisterCallback("PROFESSION_FEE_CHANGED", RefreshIfVisible)
ns.RegisterCallback("RECIPES_CLEARED", RefreshIfVisible)