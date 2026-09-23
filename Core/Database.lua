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
        relayEnabled = false,
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
        -- Bulk track defaults
        bulkTrackLearnedOnly = true,
        bulkTrackSkipConcentration = false,
        bulkTrackAutoAssign = true, -- if recipe has no assignedCharacter, set current char
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

    local alreadyOwned = entry.owners[fullName] ~= nil
    entry.owners[fullName] = {
        name = name,
        realm = realm,
        fullName = fullName,
    }

    -- Auto-assign rules
    local shouldAssign = opts.forceAssign
        or (opts.autoAssign ~= false and ns.db.settings.bulkTrackAutoAssign and not entry.assignedCharacter)
        or (not entry.assignedCharacter and ns.TableCount(entry.owners) == 1)

    if shouldAssign then
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

--- Remove the current character as an owner. If no owners remain, drop the recipe.
function ns.UntrackRecipe(recipeID, characterFullName)
    local data = ns.db.trackedRecipes[recipeID]
    if not data then return end

    local target = characterFullName or ns.GetPlayerFullName()
    if data.owners then
        data.owners[target] = nil
    end

    if data.assignedCharacter == target then
        data.assignedCharacter = nil
        -- Re-assign to any remaining owner
        for fullName in pairs(data.owners or {}) do
            data.assignedCharacter = fullName
            break
        end
    end

    local remaining = ns.TableCount(data.owners or {})
    if remaining == 0 then
        ns.Print((L["RECIPE_REMOVED"] or "Removed: ") .. (data.itemLink or data.recipeName))
        ns.db.trackedRecipes[recipeID] = nil
    else
        ns.Print((L["OWNER_REMOVED"] or "Removed owner: ") .. target
            .. " — " .. (data.itemLink or data.recipeName))
        data.character = ns.GetAssignedOwner(data)
    end
    ns.FireCallback("RECIPE_UNTRACKED", recipeID)
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

--- Scan the currently open profession and track recipes for this character.
--- Chat is not flooded: only a single summary line is printed.
--- A center progress bar shows live status.
--- Returns added, skipped, alreadyOwned counts.
function ns.BulkTrackCurrentProfession(opts)
    opts = opts or {}
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs then
        ns.Print(L["BULK_NO_API"] or "Profession API unavailable — open a profession window first.")
        return 0, 0, 0
    end

    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if not recipeIDs or #recipeIDs == 0 then
        ns.Print(L["BULK_NO_RECIPES"] or "No recipes found. Open a profession window and try again.")
        return 0, 0, 0
    end

    local learnedOnly = opts.learnedOnly
    if learnedOnly == nil then learnedOnly = ns.db.settings.bulkTrackLearnedOnly end
    local skipConc = opts.skipConcentration
    if skipConc == nil then skipConc = ns.db.settings.bulkTrackSkipConcentration end
    local autoAssign = opts.autoAssign
    if autoAssign == nil then autoAssign = ns.db.settings.bulkTrackAutoAssign end

    local professionID, professionName, tradeSkillLink
    do
        local profInfo = C_TradeSkillUI.GetChildProfessionInfo and C_TradeSkillUI.GetChildProfessionInfo()
        if profInfo then
            professionID = profInfo.parentProfessionID or false
            professionName = profInfo.parentProfessionName or profInfo.professionName or "Unknown"
        end
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
    end

    local total = #recipeIDs
    local added, skipped, already = 0, 0, 0
    local me = ns.GetPlayerFullName()
    local label = professionName or "Profession"

    ns.Print(string.format(L["BULK_START"] or "Scanning %s — %d recipes…", label, total))
    ShowProgress(0, total, label)

    -- Process in chunks so the progress bar can paint and the client stays responsive.
    local index = 1
    local CHUNK = 25

    local function ProcessChunk()
        local limit = math.min(index + CHUNK - 1, total)
        for i = index, limit do
            local recipeID = recipeIDs[i]
            local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
            if not info or IsJunkRecipeName(info.name) then
                skipped = skipped + 1
            elseif learnedOnly and info.learned == false then
                skipped = skipped + 1
            else
                local needsConc = RecipeNeedsConcentration(recipeID)
                if skipConc and needsConc then
                    skipped = skipped + 1
                else
                    local itemLink = C_TradeSkillUI.GetRecipeItemLink and C_TradeSkillUI.GetRecipeItemLink(recipeID)
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
                            silent = true, -- no per-recipe chat spam
                        }
                    )
                    if ownedBefore then
                        already = already + 1
                    else
                        added = added + 1
                    end
                end
            end
        end

        index = limit + 1
        ShowProgress(math.min(index - 1, total), total, label)

        if index <= total then
            C_Timer.After(0, ProcessChunk) -- yield a frame, continue
        else
            -- Done
            ShowProgress(total, total, label)
            ns.Print(string.format(
                L["BULK_TRACK_SUMMARY"] or "Bulk track: +%d new, %d already owned, %d skipped (%s)",
                added, already, skipped, label
            ))
            ns.FireCallback("BULK_TRACK_DONE", added, already, skipped)
            HideProgress(1.5)
        end
    end

    ProcessChunk()
    return added, already, skipped -- initial return; final counts fire via callback
end