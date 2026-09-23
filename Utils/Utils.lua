local addonName, ns = ...

-- Debug mode: toggle with /cb debug
ns.debugEnabled = false

-- Colored addon print
function ns.Print(msg)
    print("|cff00ccff[CraftBell]|r " .. tostring(msg))
end

-- Debug print (shown only when debug mode is on)
function ns.Debug(msg)
    if ns.debugEnabled then
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

-- Format a fee amount for display in a whisper template. Returns "" for
-- 0/nil so {fee} cleanly disappears from templates that don't need it.
function ns.FormatFee(amount)
    if not amount or amount <= 0 then return "" end
    return tostring(amount) .. "g"
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

-- Open a recipe in the profession window
function ns.OpenRecipe(recipeID)
    if not recipeID then return end
    if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        C_TradeSkillUI.OpenRecipe(recipeID)
    end
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
