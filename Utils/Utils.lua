local addonName, ns = ...

-- Debug mode: toggle with /cb debug
ns.debugEnabled = false

-- Colored addon print
function ns.Print(msg)
    print("|cff00ccff[CraftBell]|r " .. tostring(msg))
end

-- Debug print — always buffers when Debug.lua is loaded; chat only when debug is on
function ns.Debug(msg)
    if ns.DebugLog then
        ns.DebugLog(msg)
        return
    end
    local on = ns.debugEnabled or (ns.db and ns.db.settings and ns.db.settings.debugEnabled)
    if on then
        print("|cff888888[CB-Debug]|r " .. tostring(msg))
    end
end

-- Error print
function ns.Error(msg)
    print("|cffff4444[CB-Error]|r " .. tostring(msg))
end

----------------------------------------------------------------------
-- String utilities
----------------------------------------------------------------------

-- Replace {placeholder} tokens in a template string
function ns.FormatTemplate(template, vars)
    return string.gsub(template, "{(%w+)}", function(key)
        return vars[key] or ("{" .. key .. "}")
    end)
end

-- Count entries in a hash table
function ns.TableCount(t)
    local count = 0
    if t then for _ in pairs(t) do count = count + 1 end end
    return count
end

-- Format a fee amount for display / whispers.
-- Returns "" for 0/nil so {fee} disappears from templates that don't need it.
--
-- Compact units (no "g" — gold is the default currency in whispers):
--   500      → "500"
--   2000     → "2k"
--   2500     → "2.5k"
--   2000000  → "2m"
--
-- opts.plain = true  → no color codes (chat / templates)
-- default            → gold-tinted for UI fontstrings
function ns.FormatFee(amount, opts)
    if not amount or amount <= 0 then return "" end
    amount = math.floor(amount + 0.5)

    local function compact(n)
        local abs = math.abs(n)
        if abs >= 1000000 then
            local v = n / 1000000
            if math.abs(v - math.floor(v + 0.5)) < 0.05 then
                return string.format("%dm", math.floor(v + 0.5))
            end
            local s = string.format("%.1f", v):gsub("0+$", ""):gsub("%.$", "")
            return s .. "m"
        end
        if abs >= 1000 then
            local v = n / 1000
            if math.abs(v - math.floor(v + 0.5)) < 0.05 then
                return string.format("%dk", math.floor(v + 0.5))
            end
            local s = string.format("%.1f", v):gsub("0+$", ""):gsub("%.$", "")
            return s .. "k"
        end
        return tostring(n)
    end

    local num = compact(amount)
    local plain = (type(opts) == "boolean" and opts)
        or (type(opts) == "table" and opts.plain)
    if plain then
        return num
    end
    return "|cffe6c35c" .. num .. "|r"
end

-- Parse user gold input: "10000", "10k", "10K", "1.5k", "2m", optional trailing g
function ns.ParseGoldAmount(text)
    if text == nil then return nil end
    if type(text) == "number" then
        return text >= 0 and math.floor(text) or nil
    end
    text = tostring(text):lower():gsub(",", ""):gsub("%s+", "")
    text = text:gsub("g$", "")
    if text == "" then return nil end
    local mult = 1
    if text:match("k$") then
        mult = 1000
        text = text:sub(1, -2)
    elseif text:match("m$") then
        mult = 1000000
        text = text:sub(1, -2)
    end
    local n = tonumber(text)
    if not n or n < 0 then return nil end
    return math.floor(n * mult + 0.5)
end

-- True if we should offer "open in profession UI" for this recipe.
-- Allows unlearned recipes when the client still has recipe info (same
-- profession book). Owning the recipe as a CraftBell tracker is enough
-- to try; OpenRecipe itself reports failure if the API cannot open it.
function ns.CanOpenRecipe(recipeID, recipeData)
    if not recipeID then return false end
    recipeData = recipeData or (ns.db and ns.db.trackedRecipes and ns.db.trackedRecipes[recipeID])

    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        -- Any info (learned or not) means the client can usually navigate to it
        if info then return true end
    end

    -- Tracked by this character — still offer the click; OpenRecipe will try
    if recipeData and ns.DoesCharacterOwnRecipe and ns.DoesCharacterOwnRecipe(recipeID) then
        return true
    end

    -- Known profession on this character matching the tracked entry
    if recipeData and recipeData.professionID and C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local base = C_TradeSkillUI.GetBaseProfessionInfo()
        if base and base.professionID == recipeData.professionID then
            return true
        end
    end

    return false
end

-- Strip WoW color codes / hyperlink markup from a string
function ns.StripColorCodes(str)
    str = string.gsub(str, "|c%x%x%x%x%x%x%x%x", "")
    str = string.gsub(str, "|r", "")
    str = string.gsub(str, "|H.-|h", "")
    str = string.gsub(str, "|h", "")
    return str
end

-- Strip accents from common Latin accented characters (UTF-8 two-byte
-- sequences), so chat scanning is accent-insensitive across languages.
function ns.StripAccents(str)
    local map = {
        ["\195\160"] = "a", ["\195\161"] = "a", ["\195\162"] = "a", ["\195\163"] = "a", ["\195\164"] = "a",
        ["\195\168"] = "e", ["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e",
        ["\195\172"] = "i", ["\195\173"] = "i", ["\195\174"] = "i", ["\195\175"] = "i",
        ["\195\178"] = "o", ["\195\179"] = "o", ["\195\180"] = "o", ["\195\182"] = "o",
        ["\195\185"] = "u", ["\195\186"] = "u", ["\195\187"] = "u", ["\195\188"] = "u",
        ["\195\189"] = "y", ["\195\191"] = "y",
        ["\195\167"] = "c", ["\195\177"] = "n",
        ["\197\147"] = "oe", ["\195\134"] = "ae", ["\195\166"] = "ae",
    }
    for accented, plain in pairs(map) do
        str = string.gsub(str, accented, plain)
    end
    return str
end

-- Normalize a string for case-insensitive, accent-insensitive matching
function ns.NormalizeString(str)
    return ns.StripAccents(string.lower(ns.StripColorCodes(str)))
end

-- Extract numeric IDs from WoW hyperlinks in a raw chat message.
-- Returns { [numericID] = linkType, ... }, e.g. { [12345] = "item" }
function ns.ExtractLinkIDs(str)
    local ids = {}
    for linkType, id in string.gmatch(str, "|H(%a+):(%d+)") do
        ids[tonumber(id)] = linkType
    end
    return ids
end

----------------------------------------------------------------------
-- UI theme constants
----------------------------------------------------------------------
ns.UI = {
    backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
    bgColor = { 0.08, 0.08, 0.1, 0.95 },
    borderColor = { 0.3, 0.3, 0.35, 1 },
    accentColor = { 0, 0.8, 1 },
    headerBgColor = { 0.12, 0.12, 0.15, 1 },
    rowAltColor = { 1, 1, 1, 0.04 },
}

function ns.ApplyDarkTheme(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop(ns.UI.backdrop)
        frame:SetBackdropColor(unpack(ns.UI.bgColor))
        frame:SetBackdropBorderColor(unpack(ns.UI.borderColor))
    end
end

-- Open a recipe in the profession window.
-- Tries C_TradeSkillUI.OpenRecipe even when unlearned; the profession UI
-- will show the recipe entry if it exists in this character's skill book.
function ns.OpenRecipe(recipeID)
    if not recipeID then return end
    local L = ns.L
    if not C_TradeSkillUI or not C_TradeSkillUI.OpenRecipe then
        ns.Print((L and L["OPEN_RECIPE_NEED_PROF"]) or "Profession UI is not available.")
        return
    end

    local ok, err = pcall(C_TradeSkillUI.OpenRecipe, recipeID)
    if ok then
        return
    end

    -- Fallback: open the skill book first if we know the profession, then retry
    local data = ns.db and ns.db.trackedRecipes and ns.db.trackedRecipes[recipeID]
    local profID = data and data.professionID
    if profID and C_TradeSkillUI.OpenTradeSkill then
        pcall(C_TradeSkillUI.OpenTradeSkill, profID)
        C_Timer.After(0.15, function()
            local ok2 = pcall(C_TradeSkillUI.OpenRecipe, recipeID)
            if not ok2 then
                ns.Print((L and L["OPEN_RECIPE_NEED_PROF"])
                    or "Could not open that recipe — open the profession window and try again.")
            end
        end)
        return
    end

    ns.Print((L and L["OPEN_RECIPE_NEED_PROF"])
        or "Could not open that recipe on this character.")
    if ns.Debug and err then
        ns.Debug("OpenRecipe failed: " .. tostring(err))
    end
end

----------------------------------------------------------------------
-- Config import / export (keywords + settings subset, not full recipe list)
----------------------------------------------------------------------
function ns.ExportConfig()
    if not ns.db then return "" end
    local payload = {
        v = 1,
        settings = {
            soundEnabled = ns.db.settings.soundEnabled,
            soundID = ns.db.settings.soundID,
            keywordScanEnabled = ns.db.settings.keywordScanEnabled,
            recipeWholeWord = ns.db.settings.recipeWholeWord,
            bulkTrackOrdersOnly = ns.db.settings.bulkTrackOrdersOnly,
            bulkTrackLearnedOnly = ns.db.settings.bulkTrackLearnedOnly,
            realmMismatchMode = ns.db.settings.realmMismatchMode,
            language = ns.db.settings.language,
            professionFees = ns.db.settings.professionFees,
            toastSize = ns.db.settings.toastSize,
        },
        keywords = ns.db.keywords,
        messageTemplate = ns.db.messageTemplate,
        crossCharTemplate = ns.db.crossCharTemplate,
    }
    if ns.Serialize and ns.Base64Encode then
        return ns.Base64Encode(ns.Serialize(payload))
    end
    -- Fallback: plain serialized table string via default tostring is useless;
    -- require Utils serialize from original CraftRadar port.
    return ""
end

function ns.ImportConfig(encoded)
    if not encoded or encoded == "" or not ns.db then return false end
    local raw = encoded
    if ns.Base64Decode then
        local ok, decoded = pcall(ns.Base64Decode, encoded)
        if ok and decoded and decoded ~= "" then raw = decoded end
    end
    local data
    if ns.Deserialize then
        local ok, result = pcall(ns.Deserialize, raw)
        if ok then data = result end
    end
    if type(data) ~= "table" then
        ns.Print(L and L["IMPORT_FAILED"] or "Import failed — invalid data.")
        return false
    end
    if type(data.settings) == "table" then
        for k, v in pairs(data.settings) do
            ns.db.settings[k] = v
        end
    end
    if type(data.keywords) == "table" then
        ns.db.keywords = data.keywords
        ns.FireCallback("KEYWORDS_CHANGED")
    end
    if data.messageTemplate then ns.db.messageTemplate = data.messageTemplate end
    if data.crossCharTemplate then ns.db.crossCharTemplate = data.crossCharTemplate end
    ns.Print(L and L["IMPORT_OK"] or "Config imported.")
    ns.FireCallback("SETTINGS_CHANGED")
    return true
end

----------------------------------------------------------------------
-- Player / realm identity
----------------------------------------------------------------------

-- Get "Name-Realm" for the current character
function ns.GetPlayerFullName()
    local name = UnitName("player")
    local realm = GetRealmName()
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

-- Split a "Name-Realm" string into its two parts.
-- Realm names can themselves contain a hyphen (e.g. "Azjol-Nerub"), so we
-- split on the LAST hyphen rather than the first.
-- Returns name, realm (realm is nil if the string had no realm suffix).
function ns.ParseNameRealm(fullName)
    if not fullName then return nil, nil end
    local lastHyphen = nil
    for i = #fullName, 1, -1 do
        if fullName:sub(i, i) == "-" then
            lastHyphen = i
            break
        end
    end
    if not lastHyphen then
        return fullName, nil
    end
    return fullName:sub(1, lastHyphen - 1), fullName:sub(lastHyphen + 1)
end

-- Is the given realm one we can currently whisper without a realm suffix?
-- (i.e. the player's own realm, or a realm connected to it in the same shard)
-- Returns true/false. Falls back to true (assume compatible) if the client
-- API doesn't give us a connected-realm list, so this never blocks a whisper
-- it merely can't confirm.
function ns.IsRealmCompatible(realm)
    if not realm or realm == "" then return true end -- no realm suffix = same realm
    local myRealm = GetRealmName()
    if realm == myRealm then return true end
    if GetAutoCompleteRealms then
        local realms = GetAutoCompleteRealms()
        if realms then
            for _, r in ipairs(realms) do
                if r == realm then return true end
            end
            return false
        end
    end
    return true
end

----------------------------------------------------------------------
-- Minimal table serialize / base64 for config import-export
----------------------------------------------------------------------
local function ser(v, depth)
    depth = depth or 0
    if depth > 8 then return "nil" end
    local t = type(v)
    if t == "nil" then return "nil" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then return tostring(v) end
    if t == "string" then return string.format("%q", v) end
    if t ~= "table" then return "nil" end
    local parts = {}
    local n = #v
    local isArray = n > 0
    if isArray then
        for i = 1, n do
            if v[i] == nil then isArray = false; break end
        end
    end
    if isArray then
        for i = 1, n do
            parts[#parts + 1] = ser(v[i], depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    for k, val in pairs(v) do
        local key
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            key = k
        else
            key = "[" .. ser(k, depth + 1) .. "]"
        end
        parts[#parts + 1] = key .. "=" .. ser(val, depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function ns.Serialize(tbl)
    return ser(tbl, 0)
end

function ns.Deserialize(str)
    if type(str) ~= "string" or str == "" then return nil end
    local fn, err = loadstring("return " .. str)
    if not fn then return nil end
    local ok, result = pcall(fn)
    if ok then return result end
    return nil
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function ns.Base64Encode(data)
    if not data then return "" end
    local r = {}
    local n = #data
    for i = 1, n, 3 do
        local a, b, c = data:byte(i, i + 2)
        b, c = b or 0, c or 0
        local n1 = math.floor(a / 4)
        local n2 = (a % 4) * 16 + math.floor(b / 16)
        local n3 = (b % 16) * 4 + math.floor(c / 64)
        local n4 = c % 64
        r[#r + 1] = B64:sub(n1 + 1, n1 + 1)
        r[#r + 1] = B64:sub(n2 + 1, n2 + 1)
        r[#r + 1] = (i + 1 <= n) and B64:sub(n3 + 1, n3 + 1) or "="
        r[#r + 1] = (i + 2 <= n) and B64:sub(n4 + 1, n4 + 1) or "="
    end
    return table.concat(r)
end

function ns.Base64Decode(data)
    if not data then return "" end
    data = data:gsub("%s+", ""):gsub("[^" .. B64 .. "=]", "")
    local out = {}
    local function val(c)
        if c == "=" then return 0 end
        return (B64:find(c, 1, true) or 1) - 1
    end
    for i = 1, #data, 4 do
        local a, b, c, d = data:sub(i, i), data:sub(i + 1, i + 1), data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
        local n = val(a) * 262144 + val(b) * 4096 + val(c) * 64 + val(d)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c ~= "=" then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if d ~= "=" then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end