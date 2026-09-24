local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Internal event bus
----------------------------------------------------------------------
local callbacks = {}

function ns.RegisterCallback(event, fn)
    if not callbacks[event] then
        callbacks[event] = {}
    end
    table.insert(callbacks[event], fn)
end

function ns.FireCallback(event, ...)
    if callbacks[event] then
        for _, fn in ipairs(callbacks[event]) do
            fn(...)
        end
    end
end

----------------------------------------------------------------------
-- SavedVariables schema (v2 — multi-owner + assignment)
--
-- trackedRecipes[recipeID] = {
--     recipeName, itemLink, tradeSkillLink,
--     professionID, professionName,
--     needsConcentration = false,
--     owners = {
--         ["CharName-Realm"] = { name, realm, fullName },
--     },
--     assignedCharacter = "CharName-Realm" | nil,
--         -- preferred character for trade-order whispers when multiple
--         -- alts know the same recipe (e.g. Mail LW vs Leather LW)
-- }
--
-- settings.professionFees[professionID] = amount
-- settings.bulkTrackLearnedOnly = true
-- settings.bulkTrackSkipConcentration = false
----------------------------------------------------------------------
local defaults = {
    trackedRecipes = {},
    messageTemplate = nil,
    crossCharTemplate = nil,
    keywords = {
        triggers = { "LF", "WTB", "Need", "LFC", "Seek" },
        pairs = {},
        freewords = {},
    },
    settings = {
        soundEnabled = true,
        soundID = 11466,
        language = "en",
        minimapAngle = 225,
        keywordScanEnabled = true,
        dndEnabled = false,
        debugEnabled = false,
        -- Only show toasts for recipes assigned to (or owned by) the logged-in character
        alertsCurrentCharOnly = false,
        -- Skip toast if no crafter realm is compatible with this client
        blockIncompatibleRealmAlerts = false,
        -- Prefer a realm-compatible owner when assigned crafter is not whisperable
        smartRealmCrafter = true,
        -- Quiet mode (former Focus Mode): mute game audio on alerts
        quietModeEnabled = false,
        relayEnabled = false,
        -- Which chat sources to scan
        chatChannels = {
            trade = true,
            services = true,
            general = false,
            lookingforgroup = false,
            say = true,
            yell = true,
            guild = false,
            party = false,
            raid = false,
            instance = false,
        },
        relayTargets = {},
        concentrationMuted = {},
        concentrationMutedAll = false,
        toastPoint = "TOPRIGHT",
        toastRelPoint = "TOPRIGHT",
        toastOffsetX = -350,
        toastOffsetY = -120,
        toastSize = "medium",
        professionFees = {},
        realmMismatchMode = "warn",
        -- Matching
        recipeWholeWord = true,
        -- Bulk track defaults
        bulkTrackLearnedOnly = true,
        bulkTrackSkipConcentration = false,
        bulkTrackAutoAssign = true, -- if recipe has no assignedCharacter, set current char
        -- Prefer recipes that appear on the Crafting Orders table (Blizzard filter)
        bulkTrackOrdersOnly = true,
        -- Per-expansion checklist: { [skillLineID] = true, ... }
        -- Empty table = "currently selected expansion only" (safe default).
        -- Non-empty = only the checked skill lines that this character has trained.
        bulkTrackExpansions = {},
        -- Appearance
        windowSize = "normal",   -- compact | normal | large | xl
        colorScheme = "cyan",    -- cyan | violet | emerald | amber | rose
        bgScheme = "slate",      -- slate | charcoal | midnight | graphite | warm
        uiFont = "default",      -- default | friz | arialn | morpheus | skurri
    },
}

local function DeepCopy(v)
    if type(v) == "table" then
        return CopyTable(v)
    end
    return v
end

local function ApplyDefaults(tbl, defaultTbl)
    for k, v in pairs(defaultTbl) do
        if tbl[k] == nil then
            tbl[k] = DeepCopy(v)
        elseif type(v) == "table" and type(tbl[k]) == "table" then
            ApplyDefaults(tbl[k], v)
        end
    end
end

----------------------------------------------------------------------
-- Migrate a single recipe entry to multi-owner schema
----------------------------------------------------------------------
local function MigrateRecipeEntry(data)
    if not data then return data end

    -- Old flat characterName → character table
    if not data.character and data.characterName then
        local name, realm = ns.ParseNameRealm(data.characterName)
        data.character = { name = name, realm = realm, fullName = data.characterName }
        data.characterName = nil
    end

    -- Old single character → owners map
    if not data.owners then
        data.owners = {}
        if data.character and data.character.fullName then
            data.owners[data.character.fullName] = {
                name = data.character.name,
                realm = data.character.realm,
                fullName = data.character.fullName,
            }
            -- Keep character as a convenience pointer to the assigned (or first) owner
        end
    end

    if data.professionID == nil then
        data.professionID = false
    end

    -- assignedCharacter defaults to the only owner if exactly one exists
    if data.assignedCharacter == nil then
        local only = nil
        local count = 0
        for fullName in pairs(data.owners) do
            count = count + 1
            only = fullName
        end
        if count == 1 then
            data.assignedCharacter = only
        end
    end

    return data
end

----------------------------------------------------------------------
-- Resolve which character "owns" this recipe for whisper / display
----------------------------------------------------------------------
function ns.GetAssignedOwner(recipeData)
    if not recipeData then return nil end
    local owners = recipeData.owners or {}

    if recipeData.assignedCharacter and owners[recipeData.assignedCharacter] then
        return owners[recipeData.assignedCharacter]
    end

    -- Prefer the logged-in character if they know it
    local me = ns.GetPlayerFullName()
    if owners[me] then
        return owners[me]
    end

    -- Fall back to any owner
    for _, owner in pairs(owners) do
        return owner
    end
    return nil
end

-- Build a synthetic "character" view used by whisper / realm checks
function ns.GetRecipeCharacterView(recipeData)
    local owner = ns.GetAssignedOwner(recipeData)
    if owner then
        return owner
    end
    -- Legacy fallback
    return recipeData.character
end

----------------------------------------------------------------------
-- One-time import from CraftRadar
----------------------------------------------------------------------
local function ImportFromCraftRadar()
    if not CraftRadarDB or not CraftRadarDB.trackedRecipes then return end
    if next(CraftBellDB.trackedRecipes) then return end

    local imported = 0
    for recipeID, data in pairs(CraftRadarDB.trackedRecipes) do
        local copy = CopyTable(data)
        MigrateRecipeEntry(copy)
        CraftBellDB.trackedRecipes[recipeID] = copy
        imported = imported + 1
    end
    if imported > 0 then
        ns.Print(string.format(L["IMPORTED_FROM_CRAFTRADAR"] or "Imported %d tracked recipe(s) from CraftRadar.", imported))
    end
end

local function InitializeDB()
    if not CraftBellDB then
        CraftBellDB = {}
    end
    ApplyDefaults(CraftBellDB, defaults)
    ns.db = CraftBellDB

    for recipeID, data in pairs(ns.db.trackedRecipes) do
        MigrateRecipeEntry(data)
    end

    ImportFromCraftRadar()

    if not ns.db.messageTemplate then
        ns.db.messageTemplate = L["DEFAULT_TEMPLATE"] or
            "Hi! I saw you're looking for {item}. I can craft it ({profession}). Fee: {fee}. Let me know!"
    end
    if not ns.db.crossCharTemplate then
        ns.db.crossCharTemplate = L["DEFAULT_CROSS_TEMPLATE"] or
            "Hi! My crafting alt {characterName} can make {item} ({profession}). Fee: {fee}. Let me know!"
    end
end

ns.InitializeDB = InitializeDB

----------------------------------------------------------------------
-- Recipe tracking API — multi-owner aware
----------------------------------------------------------------------

--- Add (or reinforce) the current character as an owner of this recipe.
--- Does not remove other owners. Optionally becomes assignedCharacter.
function ns.TrackRecipe(recipeID, recipeName, professionID, professionName, itemLink, tradeSkillLink, opts)
    opts = opts or {}
    local fullName = ns.GetPlayerFullName()
    local name, realm = ns.ParseNameRealm(fullName)

    local entry = ns.db.trackedRecipes[recipeID]
    if not entry then
        entry = {
            recipeName = recipeName,
            itemLink = itemLink,
            tradeSkillLink = tradeSkillLink,
            professionID = professionID or false,
            professionName = professionName,
            needsConcentration = opts.needsConcentration or false,
            owners = {},
            assignedCharacter = nil,
        }
        ns.db.trackedRecipes[recipeID] = entry
    else
        -- Refresh display fields from the latest scan
        entry.recipeName = recipeName or entry.recipeName
        entry.itemLink = itemLink or entry.itemLink
        entry.tradeSkillLink = tradeSkillLink or entry.tradeSkillLink
        if professionID then entry.professionID = professionID end
        if professionName then entry.professionName = professionName end
        if opts.needsConcentration ~= nil then
            entry.needsConcentration = opts.needsConcentration
        end
        entry.owners = entry.owners or {}
    end

    -- Profession-book category (leaf). Only store when the API returns a real id (> 0).
    -- On alts without the profession open, GetRecipeInfo often yields categoryID 0 —
    -- never overwrite a good saved name with that.
    if opts.categoryID and opts.categoryID ~= 0 then
        entry.categoryID = opts.categoryID
        if opts.categoryName and opts.categoryName ~= "" then
            entry.categoryName = opts.categoryName
        end
    elseif C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if ok and info and type(info.categoryID) == "number" and info.categoryID > 0 then
            local catName
            if C_TradeSkillUI.GetCategoryInfo then
                local ok2, cat = pcall(C_TradeSkillUI.GetCategoryInfo, info.categoryID)
                if ok2 and cat and cat.name and cat.name ~= "" then
                    catName = cat.name
                end
            end
            if catName then
                entry.categoryID = info.categoryID
                entry.categoryName = catName
            end
        end
    end

    local alreadyOwned = entry.owners[fullName] ~= nil
    entry.owners[fullName] = {
        name = name,
        realm = realm,
        fullName = fullName,
    }

    -- Every tracked recipe must have a crafter. If none is set yet, this
    -- character becomes the assigned crafter (never leave assignedCharacter empty).
    if opts.forceAssign or not entry.assignedCharacter then
        entry.assignedCharacter = fullName
    end

    -- Keep legacy `character` pointer in sync with assigned owner for older UI paths
    entry.character = ns.GetAssignedOwner(entry)

    -- opts.silent = true suppresses the per-recipe chat line (used by bulk track)
    if not alreadyOwned and not opts.silent then
        ns.Print((L["RECIPE_TRACKED"] or "Tracking: ") .. (itemLink or recipeName)
            .. " |cff888888(" .. fullName .. ")|r")
    end
    ns.FireCallback("RECIPE_TRACKED", recipeID)
    return entry, not alreadyOwned
end

--- Remove ONE character as an owner. If no owners remain, drop the recipe.
--- Does NOT delete the recipe while other alts still own it.
--- opts.silent = true suppresses per-recipe chat lines (used by bulk clear).
function ns.UntrackRecipe(recipeID, characterFullName, opts)
    opts = opts or {}
    local data = ns.db.trackedRecipes[recipeID]
    if not data then return end

    local target = characterFullName or ns.GetPlayerFullName()
    if data.owners then
        data.owners[target] = nil
    end

    if data.assignedCharacter == target then
        data.assignedCharacter = nil
        for fullName in pairs(data.owners or {}) do
            data.assignedCharacter = fullName
            break
        end
    end

    local remaining = ns.TableCount(data.owners or {})
    if remaining == 0 then
        if not opts.silent then
            ns.Print((L["RECIPE_REMOVED"] or "Untracked: ") .. (data.itemLink or data.recipeName))
        end
        ns.db.trackedRecipes[recipeID] = nil
    else
        if not opts.silent then
            ns.Print((L["OWNER_REMOVED"] or "Removed owner: ") .. target
                .. " — " .. (data.itemLink or data.recipeName)
                .. " (" .. remaining .. " owner(s) left)")
        end
        data.character = ns.GetAssignedOwner(data)
    end
    ns.FireCallback("RECIPE_UNTRACKED", recipeID)
end

--- Fully delete a recipe from the tracked list (all owners, all alts).
--- Use for the list "Remove" button when the user wants the item gone.
function ns.DeleteTrackedRecipe(recipeID, opts)
    opts = opts or {}
    if not ns.db or not ns.db.trackedRecipes then return false end
    local data = ns.db.trackedRecipes[recipeID]
    if not data then return false end

    local label = data.itemLink or data.recipeName or ("#" .. tostring(recipeID))
    ns.db.trackedRecipes[recipeID] = nil
    if not opts.silent then
        ns.Print((L["RECIPE_DELETED"] or "Untracked (all owners): ") .. label)
    end
    ns.FireCallback("RECIPE_UNTRACKED", recipeID)
    return true
end

----------------------------------------------------------------------
-- Bulk clear / reset
----------------------------------------------------------------------

--- Remove ALL tracked recipes (every character, every profession).
--- Use when you want a completely clean slate.
function ns.ClearAllRecipes()
    if not ns.db then return 0 end
    local count = ns.TableCount(ns.db.trackedRecipes)
    wipe(ns.db.trackedRecipes)
    ns.Print(string.format(L["CLEAR_ALL"] or "Cleared all tracked recipes (%d removed).", count))
    ns.FireCallback("RECIPES_CLEARED", "all")
    return count
end

--- Remove the current character as owner from every recipe.
--- Recipes that still have other alt owners stay tracked under them.
function ns.ClearCurrentCharacter()
    if not ns.db then return 0 end
    local me = ns.GetPlayerFullName()
    local removed = 0
    local ids = {}
    for recipeID, data in pairs(ns.db.trackedRecipes) do
        if data.owners and data.owners[me] then
            table.insert(ids, recipeID)
        elseif data.character and data.character.fullName == me and not data.owners then
            -- legacy single-character entry
            table.insert(ids, recipeID)
        end
    end
    for _, recipeID in ipairs(ids) do
        ns.UntrackRecipe(recipeID, me, { silent = true })
        removed = removed + 1
    end
    ns.Print(string.format(
        L["CLEAR_CHARACTER"] or "Cleared %d recipe(s) for %s.",
        removed, me
    ))
    ns.FireCallback("RECIPES_CLEARED", "character", me)
    return removed
end

--- Remove recipes for the currently open profession (current character as owner).
--- If professionID is nil, tries to read it from the open profession window.
function ns.ClearCurrentProfession(professionID)
    if not ns.db then return 0 end

    if not professionID and C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfo then
        local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
        if profInfo then
            professionID = profInfo.parentProfessionID
        end
    end
    if not professionID then
        ns.Print(L["CLEAR_NO_PROF"] or "Open a profession window first, or pass a profession ID.")
        return 0
    end

    local me = ns.GetPlayerFullName()
    local removed = 0
    local ids = {}
    for recipeID, data in pairs(ns.db.trackedRecipes) do
        if data.professionID == professionID then
            if (data.owners and data.owners[me])
                or (data.character and data.character.fullName == me and not data.owners)
                or not data.owners then
                table.insert(ids, recipeID)
            end
        end
    end
    for _, recipeID in ipairs(ids) do
        -- Prefer removing only this character; drop recipe if last owner
        if ns.db.trackedRecipes[recipeID] then
            local data = ns.db.trackedRecipes[recipeID]
            if data.owners and next(data.owners) then
                ns.UntrackRecipe(recipeID, me, { silent = true })
            else
                ns.db.trackedRecipes[recipeID] = nil
                ns.FireCallback("RECIPE_UNTRACKED", recipeID)
            end
            removed = removed + 1
        end
    end
    ns.Print(string.format(
        L["CLEAR_PROFESSION"] or "Cleared %d recipe(s) for this profession on %s.",
        removed, me
    ))
    ns.FireCallback("RECIPES_CLEARED", "profession", professionID)
    return removed
end

function ns.IsRecipeTracked(recipeID)
    return ns.db.trackedRecipes[recipeID] ~= nil
end

function ns.DoesCharacterOwnRecipe(recipeID, characterFullName)
    local data = ns.db.trackedRecipes[recipeID]
    if not data or not data.owners then return false end
    return data.owners[characterFullName or ns.GetPlayerFullName()] ~= nil
end

--- Set (or clear) the preferred character for trade-order replies on this recipe.
function ns.AssignRecipeCharacter(recipeID, characterFullName)
    local data = ns.db.trackedRecipes[recipeID]
    if not data then return false end
    if characterFullName and data.owners and not data.owners[characterFullName] then
        ns.Print(L["ASSIGN_NOT_OWNER"] or "That character does not own this recipe.")
        return false
    end
    data.assignedCharacter = characterFullName
    data.character = ns.GetAssignedOwner(data)
    ns.FireCallback("RECIPE_ASSIGNED", recipeID, characterFullName)
    ns.Print(string.format(L["RECIPE_ASSIGNED"] or "Assigned %s → %s",
        data.itemLink or data.recipeName or tostring(recipeID),
        characterFullName or (L["ASSIGN_NONE"] or "none")))
    return true
end

--- Cycle assigned character among owners (for quick UI toggles).
function ns.CycleAssignedCharacter(recipeID)
    local data = ns.db.trackedRecipes[recipeID]
    if not data or not data.owners then return nil end

    local list = {}
    for fullName in pairs(data.owners) do
        table.insert(list, fullName)
    end
    table.sort(list)
    if #list == 0 then return nil end

    local current = data.assignedCharacter
    local nextIdx = 1
    for i, name in ipairs(list) do
        if name == current then
            nextIdx = (i % #list) + 1
            break
        end
    end
    ns.AssignRecipeCharacter(recipeID, list[nextIdx])
    return list[nextIdx]
end

----------------------------------------------------------------------
-- Fee lookup
----------------------------------------------------------------------
function ns.GetRecipeFee(recipeData)
    if not recipeData then return 0 end
    if recipeData.feeOverride ~= nil then
        return recipeData.feeOverride
    end
    if recipeData.professionID and ns.db.settings.professionFees then
        return ns.db.settings.professionFees[recipeData.professionID] or 0
    end
    return 0
end

--- True when this recipe uses a per-recipe override instead of the profession default.
function ns.HasRecipeFeeOverride(recipeData)
    return recipeData and recipeData.feeOverride ~= nil
end

--- Set or clear per-recipe fee. Pass nil to clear override (fall back to profession fee).
function ns.SetRecipeFee(recipeID, amountOrNil)
    local data = ns.db.trackedRecipes[recipeID]
    if not data then return false end
    if amountOrNil == nil or amountOrNil == "" then
        data.feeOverride = nil
    else
        local n = tonumber(amountOrNil)
        if not n or n < 0 then return false end
        data.feeOverride = n
    end
    ns.FireCallback("RECIPE_FEE_CHANGED", recipeID, data.feeOverride)
    return true
end

--- Set default fee for a profession ID (all recipes without override).
function ns.SetProfessionFee(professionID, amount)
    professionID = tonumber(professionID)
    if not professionID then return false end
    ns.db.settings.professionFees = ns.db.settings.professionFees or {}
    if amount == nil or amount == "" then
        ns.db.settings.professionFees[professionID] = nil
    else
        local n = tonumber(amount)
        if not n or n < 0 then return false end
        ns.db.settings.professionFees[professionID] = n
    end
    ns.FireCallback("PROFESSION_FEE_CHANGED", professionID)
    return true
end

--- Unique professions among tracked recipes: { { id=, name= }, ... } sorted by name.
function ns.GetTrackedProfessionList()
    local byID = {}
    if not ns.db or not ns.db.trackedRecipes then return {} end
    for _, data in pairs(ns.db.trackedRecipes) do
        local id = data.professionID
        if id and id ~= false then
            if not byID[id] then
                byID[id] = data.professionName or ("Profession " .. tostring(id))
            end
        end
    end
    local list = {}
    for id, name in pairs(byID) do
        table.insert(list, { id = id, name = name })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

--- Owner full names for a recipe, sorted.
function ns.GetRecipeOwnerList(recipeID)
    local data = ns.db.trackedRecipes[recipeID]
    if not data or not data.owners then return {} end
    local list = {}
    for fullName in pairs(data.owners) do
        table.insert(list, fullName)
    end
    table.sort(list)
    return list
end

----------------------------------------------------------------------
-- Bulk track helpers (used by RecipeTracker)
----------------------------------------------------------------------

--- Returns true if this recipeInfo looks concentration-gated.
local function RecipeNeedsConcentration(recipeID)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetCraftingOperationInfo then
        return false
    end
    local ok, info = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeID, {})
    if ok and info and info.concentrationCost and info.concentrationCost > 0 then
        return true
    end
    return false
end

-- Profession-stat / non-craftable names that GetAllRecipeIDs sometimes returns.
-- These are not useful for Trade chat matching.
local JUNK_RECIPE_NAMES = {
    ["concentration"] = true, ["knowledge"] = true, ["quality"] = true,
    ["sparks"] = true, ["ingenuity"] = true, ["multicraft"] = true,
    ["resourcefulness"] = true, ["skill"] = true, ["crafting speed"] = true,
    ["finesse"] = true, ["perception"] = true, ["deeftness"] = true,
    ["deftness"] = true,
}

local function IsJunkRecipeName(name)
    if not name then return true end
    local key = name:lower():match("^%s*(.-)%s*$")
    return JUNK_RECIPE_NAMES[key] == true
end

--- Salvage / dummy / gathering / non-craftable / stat rows — not useful for trade chat or orders.
local function IsNonProductRecipe(recipeID, info)
    if not info then return true end
    if IsJunkRecipeName(info.name) then return true end
    if info.isDummyRecipe or info.isSalvageRecipe or info.isGatheringRecipe then
        return true
    end
    if info.craftable == false then return true end

    if C_TradeSkillUI.GetRecipeSchematic and Enum and Enum.TradeskillRecipeType then
        local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
        if ok and schematic and schematic.recipeType then
            local t = schematic.recipeType
            if t == Enum.TradeskillRecipeType.Salvage
                or t == Enum.TradeskillRecipeType.Gathering then
                return true
            end
        end
    end
    return false
end

--- Recipe IDs eligible for the Crafting Orders table (Blizzard filter).
--- Restores the orders-only UI filter to false after scanning.
local function GetOrderEligibleRecipeIDs()
    if not C_TradeSkillUI.SetOnlyShowAvailableForOrders
        or not C_TradeSkillUI.GetFilteredRecipeIDs then
        return nil
    end

    local ok = pcall(C_TradeSkillUI.SetOnlyShowAvailableForOrders, true)
    if not ok then return nil end

    local filtered = C_TradeSkillUI.GetFilteredRecipeIDs()

    pcall(C_TradeSkillUI.SetOnlyShowAvailableForOrders, false)

    if type(filtered) ~= "table" or #filtered == 0 then
        return nil
    end
    return filtered
end

----------------------------------------------------------------------
-- Progress overlay (visual feedback instead of chat spam)
----------------------------------------------------------------------
local progressFrame

local function EnsureProgressFrame()
    if progressFrame then return progressFrame end

    local f = CreateFrame("Frame", "CraftBellBulkProgress", UIParent, "BackdropTemplate")
    f:SetSize(360, 78)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetClampedToScreen(true)
    if ns.ApplyDarkTheme then
        ns.ApplyDarkTheme(f)
    else
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -12)
    f.title:SetTextColor(0, 0.8, 1)
    f.title:SetText(L["BULK_PROGRESS_TITLE"] or "CraftBell — Scanning recipes")

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.status:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
    f.status:SetText("")

    f.barBG = f:CreateTexture(nil, "BACKGROUND")
    f.barBG:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    f.barBG:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    f.barBG:SetHeight(14)
    f.barBG:SetColorTexture(0.15, 0.15, 0.18, 1)

    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetPoint("TOPLEFT", f.barBG, "TOPLEFT", 0, 0)
    f.bar:SetPoint("BOTTOMLEFT", f.barBG, "BOTTOMLEFT", 0, 0)
    f.bar:SetWidth(1)
    f.bar:SetColorTexture(0, 0.75, 1, 1)

    f:Hide()
    progressFrame = f
    return f
end

local function ShowProgress(current, total, label)
    local f = EnsureProgressFrame()
    f:Show()
    f:Raise()
    local pct = (total > 0) and (current / total) or 0
    local barWidth = math.max(1, (f.barBG:GetWidth() or 328) * pct)
    f.bar:SetWidth(barWidth)
    f.status:SetText(string.format("%s  %d / %d", label or "", current, total))
end

local function HideProgress(delay)
    local f = progressFrame
    if not f then return end
    if delay and delay > 0 then
        C_Timer.After(delay, function()
            if f then f:Hide() end
        end)
    else
        f:Hide()
    end
end

----------------------------------------------------------------------
-- Expansion skill-line helpers
----------------------------------------------------------------------

--- Resolve the currently selected expansion skill-line ID + display name.
local function GetSelectedSkillLine()
    local skillLineID, skillLineName, parentID, parentName

    -- CraftSim / Blizzard UI use this for the expansion currently shown
    if C_TradeSkillUI.GetProfessionChildSkillLineID then
        local ok, id = pcall(C_TradeSkillUI.GetProfessionChildSkillLineID)
        if ok and id and id > 0 then
            skillLineID = id
        end
    end

    -- Fallback: older GetTradeSkillLine API
    if (not skillLineID or skillLineID == 0) and C_TradeSkillUI.GetTradeSkillLine then
        local ok, id, displayName, _, _, _, parentSkillLineID, parentSkillLineName =
            pcall(C_TradeSkillUI.GetTradeSkillLine)
        if ok and id and id > 0 then
            skillLineID = id
            skillLineName = displayName
            parentID = parentSkillLineID
            parentName = parentSkillLineName
        end
    end

    local childInfo = C_TradeSkillUI.GetChildProfessionInfo and C_TradeSkillUI.GetChildProfessionInfo()
    if childInfo then
        if (not skillLineID or skillLineID == 0) and childInfo.professionID and childInfo.professionID > 0 then
            skillLineID = childInfo.professionID
        end
        skillLineName = skillLineName or childInfo.professionName or childInfo.expansionName
        parentID = parentID or childInfo.parentProfessionID
        parentName = parentName or childInfo.parentProfessionName
    end

    if skillLineID and skillLineID > 0 and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
        if ok and info then
            -- Display name: prefer skill-line specific name
            if C_TradeSkillUI.GetTradeSkillDisplayName then
                local ok2, dn = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, skillLineID)
                if ok2 and dn and dn ~= "" then
                    skillLineName = dn
                end
            end
            skillLineName = skillLineName or info.professionName or info.expansionName
            parentID = parentID or info.parentProfessionID
            parentName = parentName or info.parentProfessionName
        end
    end

    return skillLineID, skillLineName, parentID, parentName
end

--- Does this recipe belong to any of the allowed skill line IDs?
local function RecipeInAnySkillLine(recipeID, allowedSet)
    if not allowedSet or not next(allowedSet) then return true end
    if C_TradeSkillUI.GetTradeSkillLineForRecipe then
        local ok, tradeSkillID = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)
        if ok and tradeSkillID then
            return allowedSet[tradeSkillID] == true
        end
    end
    if C_TradeSkillUI.IsRecipeInSkillLine then
        for skillLineID in pairs(allowedSet) do
            local ok, result = pcall(C_TradeSkillUI.IsRecipeInSkillLine, recipeID, skillLineID)
            if ok and result then return true end
        end
        return false
    end
    return true
end

--- List every expansion skill line relevant to the *open* profession.
--- Strategy (most reliable first):
---   1) Discover unique skill lines from recipes via GetTradeSkillLineForRecipe
---   2) Fall back to GetAllProfessionTradeSkillLines filtered by parent profession
--- Each entry: { skillLineID, name, skillLevel, maxSkillLevel, trained }
function ns.GetAvailableProfessionExpansions()
    local list = {}
    if not C_TradeSkillUI then return list end

    local byID = {}

    local function addLine(skillLineID, preferredName)
        if not skillLineID or skillLineID == 0 or byID[skillLineID] then return end

        local name = preferredName
        local level, maxLevel, parentID, parentName = 0, 0, nil, nil

        if C_TradeSkillUI.GetProfessionInfoBySkillLineID then
            local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
            if ok and info then
                level = info.skillLevel or 0
                maxLevel = info.maxSkillLevel or 0
                parentID = info.parentProfessionID
                parentName = info.parentProfessionName
                -- professionName is often the *parent* name; keep preferredName if we have it
                if not name or name == "" then
                    name = info.professionName or info.expansionName
                end
            end
        end

        if (not name or name == "") and C_TradeSkillUI.GetTradeSkillDisplayName then
            local ok, dn = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, skillLineID)
            if ok and dn and dn ~= "" then name = dn end
        end

        if (not name or name == "") and C_TradeSkillUI.GetTradeSkillLineInfoByID then
            local ok, dn, rank, maxRank = pcall(C_TradeSkillUI.GetTradeSkillLineInfoByID, skillLineID)
            if ok then
                name = name or dn
                if rank then level = rank end
                if maxRank then maxLevel = maxRank end
            end
        end

        name = name or ("SkillLine " .. tostring(skillLineID))

        byID[skillLineID] = {
            skillLineID = skillLineID,
            name = name,
            skillLevel = level,
            maxSkillLevel = maxLevel,
            trained = level > 0,
            parentProfessionID = parentID,
            parentProfessionName = parentName,
        }
    end

    -- 1) From recipes currently in the open profession book (best signal)
    if C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetTradeSkillLineForRecipe then
        local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs() or {}
        for _, recipeID in ipairs(recipeIDs) do
            local ok, tradeSkillID, skillLineName = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)
            if ok and tradeSkillID and tradeSkillID > 0 then
                addLine(tradeSkillID, skillLineName)
            end
        end
    end

    -- 2) Fallback: all character skill lines filtered to this profession's parent
    if not next(byID) and C_TradeSkillUI.GetAllProfessionTradeSkillLines then
        local parentID = select(3, GetSelectedSkillLine())
        if not parentID then
            local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
            parentID = base and base.professionID
        end

        local ok, allLines = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
        if ok and allLines then
            for _, skillLineID in ipairs(allLines) do
                local infoOk, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLineID)
                if infoOk and info then
                    local matchesParent = (not parentID)
                        or (info.parentProfessionID == parentID)
                        or (info.professionID == parentID)
                        or (skillLineID == parentID)
                    if matchesParent then
                        addLine(skillLineID, info.professionName)
                    end
                end
            end
        end
    end

    -- 3) Always ensure the currently selected line is present
    local currentID, currentName = GetSelectedSkillLine()
    if currentID and currentID > 0 then
        addLine(currentID, currentName)
    end

    for _, entry in pairs(byID) do
        table.insert(list, entry)
    end
    table.sort(list, function(a, b)
        return (a.skillLineID or 0) > (b.skillLineID or 0)
    end)
    return list
end

--- Count how many skill lines are checked in settings.
local function CountCheckedExpansions()
    local t = ns.db and ns.db.settings and ns.db.settings.bulkTrackExpansions
    if not t then return 0 end
    local n = 0
    for _, v in pairs(t) do
        if v then n = n + 1 end
    end
    return n
end

--- Build the set of skill line IDs that bulk track should include right now.
--- Returns: allowedSet { [id]=true }, label string, skippedUntrained { {id,name}, ... }
local function ResolveBulkSkillLines(opts)
    opts = opts or {}
    local expansions = ns.GetAvailableProfessionExpansions()
    local availableByID = {}
    for _, e in ipairs(expansions) do
        availableByID[e.skillLineID] = e
    end

    local currentID, currentName = GetSelectedSkillLine()
    local checked = ns.db.settings.bulkTrackExpansions or {}
    local hasChecklist = CountCheckedExpansions() > 0

    -- opts override: forceCurrent / forceAll
    if opts.forceCurrent or (not hasChecklist and not opts.forceAll) then
        local set = {}
        if currentID then set[currentID] = true end
        return set, currentName or "current", {}
    end

    if opts.forceAll then
        local set, skipped = {}, {}
        for _, e in ipairs(expansions) do
            if e.trained then
                set[e.skillLineID] = true
            else
                table.insert(skipped, e)
            end
        end
        local names = {}
        for id in pairs(set) do
            local e = availableByID[id]
            table.insert(names, e and e.name or tostring(id))
        end
        table.sort(names)
        return set, (#names > 0 and table.concat(names, ", ") or "none"), skipped
    end

    -- Checklist mode
    local set, skipped, names = {}, {}, {}
    for skillLineID, enabled in pairs(checked) do
        if enabled then
            local e = availableByID[skillLineID]
            if not e then
                -- Selected in settings but not present on this character / profession
                table.insert(skipped, {
                    skillLineID = skillLineID,
                    name = "Unknown #" .. tostring(skillLineID),
                    reason = "not_on_profession",
                })
            elseif not e.trained then
                table.insert(skipped, {
                    skillLineID = skillLineID,
                    name = e.name,
                    reason = "not_trained",
                    skillLevel = e.skillLevel,
                    maxSkillLevel = e.maxSkillLevel,
                })
            else
                set[skillLineID] = true
                table.insert(names, e.name)
            end
        end
    end
    table.sort(names)

    -- If everything checked was untrained/missing, fall back to current so bulk isn't a no-op
    if not next(set) and currentID then
        set[currentID] = true
        return set, (currentName or "current") .. " (fallback)", skipped
    end

    return set, (#names > 0 and table.concat(names, ", ") or "none"), skipped
end

--- Print the expansion checklist + trained status (open a profession first).
function ns.PrintBulkExpansionStatus()
    local expansions = ns.GetAvailableProfessionExpansions()
    if #expansions == 0 then
        ns.Print(L["EXP_NEED_PROF"] or "Open a profession window first to list expansions.")
        return
    end

    local checked = ns.db.settings.bulkTrackExpansions or {}
    local hasChecklist = CountCheckedExpansions() > 0
    local currentID = select(1, GetSelectedSkillLine())

    if not hasChecklist then
        ns.Print(L["EXP_MODE_CURRENT"] or "Bulk mode: selected expansion only (no checklist).")
        ns.Print("  Use /cb exp add <name|id>  or  /cb exp alltrained  to build a checklist.")
    else
        ns.Print(L["EXP_MODE_LIST"] or "Bulk mode: checklist —")
    end

    for _, e in ipairs(expansions) do
        local mark
        if hasChecklist then
            mark = checked[e.skillLineID] and "|cff00ff00[x]|r" or "|cff888888[ ]|r"
        else
            mark = (e.skillLineID == currentID) and "|cff00ccff[>]|r" or "|cff888888[ ]|r"
        end
        local trained = e.trained
            and string.format("|cff88ff88%d/%d|r", e.skillLevel, e.maxSkillLevel)
            or "|cffff6666not trained|r"
        ns.Print(string.format("  %s %s  %s  |cff888888(id %s)|r",
            mark, e.name, trained, tostring(e.skillLineID)))
    end
end

--- Enable/disable a skill line in the checklist by ID or partial name.
function ns.SetBulkExpansion(skillLineIDOrName, enabled)
    if not ns.db or not ns.db.settings then return false end
    ns.db.settings.bulkTrackExpansions = ns.db.settings.bulkTrackExpansions or {}

    local raw = tostring(skillLineIDOrName or ""):match("^%s*(.-)%s*$") or ""
    -- Strip surrounding quotes: "Khaz Algar" or 'Midnight'
    raw = raw:gsub("^[\"'](.*)[\"']$", "%1")
    raw = raw:match("^%s*(.-)%s*$") or raw

    local id = tonumber(raw)
    local nameMatch = not id and raw:lower() or nil

    if not id and nameMatch and nameMatch ~= "" then
        local expansions = ns.GetAvailableProfessionExpansions()
        for _, e in ipairs(expansions) do
            if e.name:lower():find(nameMatch, 1, true) then
                id = e.skillLineID
                break
            end
        end
        if not id then
            ns.Print(string.format(
                L["EXP_NOT_FOUND"] or "No expansion matching '%s'. Open the profession and /cb exp list",
                tostring(skillLineIDOrName)
            ))
            return false
        end
    end

    if not id then
        ns.Print(L["EXP_NEED_ID"] or "Usage: /cb exp add <name|id>  or  /cb exp remove <name|id>")
        return false
    end

    if enabled then
        ns.db.settings.bulkTrackExpansions[id] = true
        local expansions = ns.GetAvailableProfessionExpansions()
        local name, trained = tostring(id), true
        for _, e in ipairs(expansions) do
            if e.skillLineID == id then
                name = e.name
                trained = e.trained
                break
            end
        end
        ns.Print(string.format(L["EXP_ADDED"] or "Added to bulk checklist: %s", name))
        if not trained then
            ns.Print(L["EXP_NOT_TRAINED_WARN"] or
                "|cffffaa00Warning:|r this character has not trained that expansion line — it will be skipped during bulk track.")
        end
    else
        ns.db.settings.bulkTrackExpansions[id] = nil
        ns.Print(string.format(L["EXP_REMOVED"] or "Removed from bulk checklist: %s", tostring(id)))
    end
    return true
end

--- Clear checklist → fall back to "current expansion only".
function ns.ClearBulkExpansions()
    if not ns.db or not ns.db.settings then return end
    wipe(ns.db.settings.bulkTrackExpansions)
    ns.Print(L["EXP_CLEARED"] or "Bulk checklist cleared — Track All uses the selected expansion only.")
end

--- Check every *trained* expansion for the open profession.
function ns.SelectAllTrainedExpansions()
    if not ns.db or not ns.db.settings then return 0 end
    ns.db.settings.bulkTrackExpansions = ns.db.settings.bulkTrackExpansions or {}
    local expansions = ns.GetAvailableProfessionExpansions()
    if #expansions == 0 then
        ns.Print(L["EXP_NEED_PROF"] or "Open a profession window first.")
        return 0
    end
    local n = 0
    wipe(ns.db.settings.bulkTrackExpansions)
    for _, e in ipairs(expansions) do
        if e.trained then
            ns.db.settings.bulkTrackExpansions[e.skillLineID] = true
            n = n + 1
        end
    end
    ns.Print(string.format(
        L["EXP_ALL_TRAINED"] or "Checklist set to all trained expansions (%d).",
        n
    ))
    return n
end

--- Scan the open profession using the expansion checklist (or current selection).
--- By default only tracks recipes that can appear on the Crafting Orders table.
function ns.BulkTrackCurrentProfession(opts)
    opts = opts or {}
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs then
        ns.Print(L["BULK_NO_API"] or "Profession API unavailable — open a profession window first.")
        return 0, 0, 0
    end

    local learnedOnly = opts.learnedOnly
    if learnedOnly == nil then learnedOnly = ns.db.settings.bulkTrackLearnedOnly end
    -- Skip-concentration removed: cost depends on specs/tools/reagents — not reliable for bulk.
    local skipConc = false
    -- Crafter is always assigned on track (see ns.TrackRecipe)
    local autoAssign = true
    local ordersOnly = opts.ordersOnly
    if ordersOnly == nil then ordersOnly = ns.db.settings.bulkTrackOrdersOnly end
    if ordersOnly == nil then ordersOnly = true end

    -- Legacy opts.scope support
    if opts.scope == "all" then opts.forceAll = true end
    if opts.scope == "current" then opts.forceCurrent = true end

    local allowedSet, label, skippedUntrained = ResolveBulkSkillLines(opts)
    local _, _, parentID, parentName = GetSelectedSkillLine()
    local professionID = parentID
    local professionName = parentName or "Unknown"

    if not next(allowedSet) then
        ns.Print(L["BULK_NO_SKILLLINES"] or "No valid expansions to scan. Check /cb exp list")
        return 0, 0, 0
    end

    -- Report expansions that were requested but aren't trained on this character
    for _, e in ipairs(skippedUntrained) do
        local reason = e.reason == "not_trained"
            and (L["EXP_SKIP_NOT_TRAINED"] or "not trained on this character")
            or (L["EXP_SKIP_MISSING"] or "not available for this profession")
        ns.Print(string.format(
            "|cffffaa00%s|r %s — %s",
            L["EXP_SKIPPED"] or "Skipped expansion:",
            e.name,
            reason
        ))
    end

    -- Prefer Blizzard's "available for orders" recipe set when ordersOnly is on
    local recipeIDs
    local usedOrdersFilter = false
    if ordersOnly then
        recipeIDs = GetOrderEligibleRecipeIDs()
        if recipeIDs then
            usedOrdersFilter = true
        end
    end
    if not recipeIDs then
        recipeIDs = C_TradeSkillUI.GetAllRecipeIDs() or {}
    end

    if not recipeIDs or #recipeIDs == 0 then
        ns.Print(L["BULK_NO_RECIPES"] or "No recipes found. Open a profession window and try again.")
        return 0, 0, 0
    end

    local tradeSkillLink
    if professionID and C_SpellBook and C_Spell then
        local ok, result = pcall(function()
            local spellSkillIndex = C_SpellBook.GetSkillLineIndexByID(professionID)
            if not spellSkillIndex then return nil end
            local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(spellSkillIndex)
            if not skillLineInfo then return nil end
            local _, skillSpellID = C_SpellBook.GetSpellBookItemType(
                skillLineInfo.itemIndexOffset + 1, Enum.SpellBookSpellBank.Player)
            if skillSpellID then
                return C_Spell.GetSpellTradeSkillLink(skillSpellID)
            end
        end)
        if ok then tradeSkillLink = result end
    end

    local total = #recipeIDs
    -- newRecipe  = first time this recipeID enters the DB
    -- newOwner   = recipe already tracked by another alt; this char added as owner
    -- alreadyOwn = this character already owned it (re-scan)
    local newRecipe, newOwner, alreadyOwn, skipped = 0, 0, 0, 0
    local me = ns.GetPlayerFullName()

    local modeLabel = usedOrdersFilter
        and (L["BULK_MODE_ORDERS"] or "order-eligible")
        or (ordersOnly and (L["BULK_MODE_HEURISTIC"] or "order-style filter")
            or (L["BULK_MODE_ALL"] or "all recipes"))

    ns.Print(string.format(
        L["BULK_START"] or "Scanning %s — %d recipes (%s)…",
        label, total, modeLabel
    ))
    ShowProgress(0, total, label)

    local index = 1
    local CHUNK = 25

    local function ProcessChunk()
        local limit = math.min(index + CHUNK - 1, total)
        for i = index, limit do
            local recipeID = recipeIDs[i]
            local info = C_TradeSkillUI.GetRecipeInfo(recipeID)

            if not info or IsNonProductRecipe(recipeID, info) then
                skipped = skipped + 1
            elseif not RecipeInAnySkillLine(recipeID, allowedSet) then
                skipped = skipped + 1
            elseif learnedOnly and info.learned == false then
                skipped = skipped + 1
            elseif opts.categoryIDs and next(opts.categoryIDs)
                and not opts.categoryIDs[info.categoryID]
                and not (info.categoryID and opts.categoryIDs["id:" .. tostring(info.categoryID)]) then
                -- Optional category filter from Track All dialog
                skipped = skipped + 1
            else
                local needsConc = RecipeNeedsConcentration(recipeID)
                if skipConc and needsConc then
                    skipped = skipped + 1
                else
                    local itemLink = C_TradeSkillUI.GetRecipeItemLink and C_TradeSkillUI.GetRecipeItemLink(recipeID)
                    local existedBefore = ns.db.trackedRecipes[recipeID] ~= nil
                    local ownedBefore = ns.DoesCharacterOwnRecipe(recipeID, me)
                    ns.TrackRecipe(
                        recipeID,
                        info.name,
                        professionID,
                        professionName,
                        itemLink,
                        tradeSkillLink,
                        {
                            needsConcentration = needsConc,
                            autoAssign = autoAssign,
                            silent = true,
                        }
                    )
                    if ownedBefore then
                        alreadyOwn = alreadyOwn + 1
                    elseif existedBefore then
                        newOwner = newOwner + 1
                    else
                        newRecipe = newRecipe + 1
                    end
                end
            end
        end

        index = limit + 1
        ShowProgress(math.min(index - 1, total), total, label)

        if index <= total then
            C_Timer.After(0, ProcessChunk)
        else
            ShowProgress(total, total, label)
            ns.Print(string.format(
                L["BULK_TRACK_SUMMARY"]
                    or "Bulk track: +%d new recipes, +%d as owner, %d already yours, %d skipped (%s)",
                newRecipe, newOwner, alreadyOwn, skipped, label
            ))
            ns.FireCallback("BULK_TRACK_DONE", newRecipe, newOwner, alreadyOwn, skipped)
            HideProgress(1.5)
        end
    end

    ProcessChunk()
    return newRecipe, newOwner, alreadyOwn, skipped
end