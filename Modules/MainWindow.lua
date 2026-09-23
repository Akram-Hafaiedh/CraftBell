local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Main frame
----------------------------------------------------------------------
local mainFrame = CreateFrame("Frame", "CraftBellMainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(520, 480)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetFrameStrata("HIGH")
mainFrame:SetClampedToScreen(true)
ns.ApplyDarkTheme(mainFrame)
mainFrame:Hide()
tinsert(UISpecialFrames, "CraftBellMainFrame") -- lets Escape close it

local titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOP", mainFrame, "TOP", 0, -14)
titleText:SetText("CraftBell")
titleText:SetTextColor(unpack(ns.UI.accentColor))

local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -2)

----------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------
local activeTab = 1
local recipesContent, settingsContent, historyContent
local tabs = {}

local function CreateTab(text, index, anchorTo)
    local tab = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    tab:SetSize(110, 24)
    if anchorTo then
        tab:SetPoint("LEFT", anchorTo, "RIGHT", 6, 0)
    else
        tab:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 16, -38)
    end
    tab:SetText(text)
    tabs[index] = tab
    return tab
end

local tabRecipes = CreateTab(L["TAB_RECIPES"] or "Recipes", 1)
local tabSettings = CreateTab(L["TAB_SETTINGS"] or "Settings", 2, tabRecipes)
local tabHistory = CreateTab(L["TAB_HISTORY"] or "History", 3, tabSettings)

local separator = mainFrame:CreateTexture(nil, "ARTWORK")
separator:SetHeight(1)
separator:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -66)
separator:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -12, -66)
separator:SetColorTexture(0.3, 0.3, 0.35, 0.8)

local function SetActiveTab(index)
    activeTab = index
    if recipesContent then recipesContent:SetShown(index == 1) end
    if settingsContent then settingsContent:SetShown(index == 2) end
    if historyContent then historyContent:SetShown(index == 3) end
    for i, tab in pairs(tabs) do
        tab:SetEnabled(i ~= index)
    end
end

tabRecipes:SetScript("OnClick", function() SetActiveTab(1) end)
tabSettings:SetScript("OnClick", function() SetActiveTab(2) end)
tabHistory:SetScript("OnClick", function() SetActiveTab(3) end)

local CONTENT_TOP, CONTENT_INSET = -72, 16
local function CreateContentFrame()
    local f = CreateFrame("Frame", nil, mainFrame)
    f:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CONTENT_INSET, CONTENT_TOP)
    f:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -CONTENT_INSET, 16)
    return f
end

----------------------------------------------------------------------
-- Small shared helpers
----------------------------------------------------------------------
local function CreateScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1) -- resized as rows are added
    scroll:SetScrollChild(child)
    return scroll, child
end

-- Rows are rebuilt from scratch on each refresh rather than pooled — simple,
-- and fine at the scale a personal addon's recipe/history lists actually hit.
local function ClearChildren(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
end

----------------------------------------------------------------------
-- Recipes tab
----------------------------------------------------------------------
recipesContent = CreateContentFrame()
local recipeScroll, recipeChild = CreateScrollArea(recipesContent)

local function RefreshRecipeList()
    ClearChildren(recipeChild)
    local y = 0
    local rowHeight = 40

    local ids = {}
    for id in pairs(ns.db.trackedRecipes) do table.insert(ids, id) end
    table.sort(ids)

    if #ids == 0 then
        local empty = recipeChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 4, -4)
        empty:SetText(L["NO_RECIPES_TRACKED"] or "No recipes tracked yet. Track one from any profession window.")
        y = 24
    end

    for _, id in ipairs(ids) do
        local data = ns.db.trackedRecipes[id]
        local row = CreateFrame("Frame", nil, recipeChild, "BackdropTemplate")
        row:SetSize(1, rowHeight - 4)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        ns.ApplyDarkTheme(row)

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("TOPLEFT", 8, -4)
        name:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        name:SetJustifyH("LEFT")
        name:SetText(data.itemLink or data.recipeName)

        local sub = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetPoint("BOTTOMLEFT", 8, 4)
        sub:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        sub:SetJustifyH("LEFT")
        sub:SetTextColor(0.6, 0.6, 0.65)
        local fee = ns.GetRecipeFee(data)
        local charLabel = (data.character and data.character.fullName) or "?"
        sub:SetText(string.format("%s  |  %s  |  %s",
            data.professionName or "?", charLabel, fee > 0 and ns.FormatFee(fee) or (L["NO_FEE_SET"] or "no fee set")))

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 20)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        removeBtn:SetText(L["REMOVE"] or "Remove")
        removeBtn:SetScript("OnClick", function()
            ns.UntrackRecipe(id)
        end)

        y = y + rowHeight
    end

    recipeChild:SetSize(recipeScroll:GetWidth(), math.max(y, 1))
end

ns.RegisterCallback("RECIPE_TRACKED", function() if mainFrame:IsShown() then RefreshRecipeList() end end)
ns.RegisterCallback("RECIPE_UNTRACKED", function() if mainFrame:IsShown() then RefreshRecipeList() end end)

----------------------------------------------------------------------
-- Settings tab
----------------------------------------------------------------------
settingsContent = CreateContentFrame()
local settingsScroll, settingsChild = CreateScrollArea(settingsContent)
settingsChild:SetSize(1, 1)

local function CreateSectionHeader(parent, text, yPos)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 4, yPos)
    header:SetText(text)
    header:SetTextColor(unpack(ns.UI.accentColor))
    return header
end

-- Widgets that need an initial value from ns.db can't set it at creation
-- time -- this file's top-level code runs when the file loads, which is
-- BEFORE ADDON_LOADED/DB_READY fires and ns.db gets set. Each such widget
-- registers itself here and gets its real value applied by RefreshSettingsTab
-- once the DB actually exists.
local settingsRefreshers = {}

local function CreateCheckbox(parent, text, yPos, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 4, yPos)
    cb:SetSize(22, 22)

    -- The template's built-in label only exists if the checkbox has a real
    -- global frame name (GetName() otherwise returns nil, which is exactly
    -- what caused the earlier "attempt to concatenate a nil value" error).
    -- We pass no name, so create our own label instead of relying on that.
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(text)

    cb:SetScript("OnClick", function(self) setValue(self:GetChecked() and true or false) end)
    table.insert(settingsRefreshers, function() cb:SetChecked(getValue()) end)
    return cb
end

-- General
CreateSectionHeader(settingsChild, L["SECTION_GENERAL"] or "General", -4)
CreateCheckbox(settingsChild, L["SETTING_SOUND"] or "Play sound on alert", -28,
    function() return ns.db.settings.soundEnabled end,
    function(v) ns.db.settings.soundEnabled = v end)
CreateCheckbox(settingsChild, L["SETTING_KEYWORD_SCAN"] or "Scan for keyword matches (not just tracked recipes)", -54,
    function() return ns.db.settings.keywordScanEnabled end,
    function(v) ns.db.settings.keywordScanEnabled = v end)
CreateCheckbox(settingsChild, L["SETTING_DND"] or "Do Not Disturb (pause all scanning)", -80,
    function() return ns.db.settings.dndEnabled end,
    function(v) ns.db.settings.dndEnabled = v end)

-- Realm compatibility (new)
CreateSectionHeader(settingsChild, L["SECTION_REALM"] or "Realm compatibility", -114)
local realmDesc = settingsChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
realmDesc:SetPoint("TOPLEFT", 4, -134)
realmDesc:SetPoint("RIGHT", settingsChild, "RIGHT", -4, 0)
realmDesc:SetJustifyH("LEFT")
realmDesc:SetWordWrap(true)
realmDesc:SetTextColor(0.6, 0.6, 0.65)
realmDesc:SetText(L["REALM_MODE_DESC"] or
    "When a matched recipe's crafter is on a realm you likely can't whisper: Warn shows the whisper option with a flag; Block hides it entirely.")

local realmModeBtn = CreateFrame("Button", nil, settingsChild, "UIPanelButtonTemplate")
realmModeBtn:SetSize(160, 24)
realmModeBtn:SetPoint("TOPLEFT", 4, -172)
local function UpdateRealmModeBtn()
    if not ns.db then return end -- not ready yet; RefreshSettingsTab calls this again once it is
    local mode = ns.db.settings.realmMismatchMode or "warn"
    local label = (mode == "block") and (L["REALM_MODE_BLOCK"] or "Mode: Block") or (L["REALM_MODE_WARN"] or "Mode: Warn")
    realmModeBtn:SetText(label)
end
realmModeBtn:SetScript("OnClick", function()
    ns.db.settings.realmMismatchMode = (ns.db.settings.realmMismatchMode == "block") and "warn" or "block"
    UpdateRealmModeBtn()
end)
table.insert(settingsRefreshers, UpdateRealmModeBtn)

-- Per-profession fees (new)
CreateSectionHeader(settingsChild, L["SECTION_FEES"] or "Per-profession fees", -212)
local feeHint = settingsChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
feeHint:SetPoint("TOPLEFT", 4, -232)
feeHint:SetPoint("RIGHT", settingsChild, "RIGHT", -4, 0)
feeHint:SetJustifyH("LEFT")
feeHint:SetWordWrap(true)
feeHint:SetTextColor(0.6, 0.6, 0.65)
feeHint:SetText(L["FEE_HINT"] or
    "Fee (in gold) charged per profession, used in the {fee} whisper placeholder. Find a recipe's profession ID via /cb dump.")

local feeListFrame = CreateFrame("Frame", nil, settingsChild)
feeListFrame:SetPoint("TOPLEFT", 4, -268)
feeListFrame:SetPoint("RIGHT", settingsChild, "RIGHT", -4, 0)
feeListFrame:SetHeight(1)

local feeProfInput, feeAmountInput

local function RefreshFeeList()
    ClearChildren(feeListFrame)
    local y = 0
    local fees = ns.db.settings.professionFees or {}
    local ids = {}
    for profID in pairs(fees) do table.insert(ids, profID) end
    table.sort(ids)

    for _, profID in ipairs(ids) do
        local row = CreateFrame("Frame", nil, feeListFrame)
        row:SetSize(1, 22)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", 0, 0)
        label:SetText("Profession ID " .. tostring(profID) .. ":  " .. ns.FormatFee(fees[profID]))

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(24, 20)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        removeBtn:SetText("X")
        removeBtn:SetScript("OnClick", function()
            ns.db.settings.professionFees[profID] = nil
            RefreshFeeList()
        end)

        y = y + 24
    end

    -- "Add new" row
    if not feeProfInput then
        feeProfInput = CreateFrame("EditBox", nil, feeListFrame, "InputBoxTemplate")
        feeProfInput:SetSize(70, 20)
        feeProfInput:SetAutoFocus(false)
        feeProfInput:SetNumeric(true)

        feeAmountInput = CreateFrame("EditBox", nil, feeListFrame, "InputBoxTemplate")
        feeAmountInput:SetSize(60, 20)
        feeAmountInput:SetAutoFocus(false)
        feeAmountInput:SetNumeric(true)

        feeListFrame.addBtn = CreateFrame("Button", nil, feeListFrame, "UIPanelButtonTemplate")
        feeListFrame.addBtn:SetSize(50, 20)
        feeListFrame.addBtn:SetText(L["ADD"] or "Add")
        feeListFrame.addBtn:SetScript("OnClick", function()
            local profID = tonumber(feeProfInput:GetText())
            local amount = tonumber(feeAmountInput:GetText())
            if profID and amount then
                ns.db.settings.professionFees[profID] = amount
                feeProfInput:SetText("")
                feeAmountInput:SetText("")
                RefreshFeeList()
            end
        end)
    end
    feeProfInput:SetParent(feeListFrame)
    feeProfInput:ClearAllPoints()
    feeProfInput:SetPoint("TOPLEFT", 0, -y)
    feeProfInput:Show()

    feeAmountInput:SetParent(feeListFrame)
    feeAmountInput:ClearAllPoints()
    feeAmountInput:SetPoint("LEFT", feeProfInput, "RIGHT", 8, 0)
    feeAmountInput:Show()

    feeListFrame.addBtn:SetParent(feeListFrame)
    feeListFrame.addBtn:ClearAllPoints()
    feeListFrame.addBtn:SetPoint("LEFT", feeAmountInput, "RIGHT", 8, 0)
    feeListFrame.addBtn:Show()

    feeListFrame:SetHeight(y + 24)
end

-- Message templates
CreateSectionHeader(settingsChild, L["SECTION_TEMPLATES"] or "Whisper templates", -372)
local templateHint = settingsChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
templateHint:SetPoint("TOPLEFT", 4, -392)
templateHint:SetPoint("RIGHT", settingsChild, "RIGHT", -4, 0)
templateHint:SetJustifyH("LEFT")
templateHint:SetWordWrap(true)
templateHint:SetTextColor(0.6, 0.6, 0.65)
templateHint:SetText(L["TEMPLATE_PLACEHOLDERS"] or "Placeholders: {item} {profession} {fee} {characterName} {playerName}")

local templateBox = CreateFrame("EditBox", nil, settingsChild, "InputBoxTemplate")
templateBox:SetPoint("TOPLEFT", 4, -428)
templateBox:SetPoint("RIGHT", settingsChild, "RIGHT", -4, 0)
templateBox:SetHeight(20)
templateBox:SetAutoFocus(false)
templateBox:SetScript("OnEnterPressed", function(self)
    ns.db.messageTemplate = self:GetText()
    self:ClearFocus()
end)

local crossTemplateBox = CreateFrame("EditBox", nil, settingsChild, "InputBoxTemplate")
crossTemplateBox:SetPoint("TOPLEFT", templateBox, "BOTTOMLEFT", 0, -12)
crossTemplateBox:SetPoint("RIGHT", settingsChild, "RIGHT", -4, 0)
crossTemplateBox:SetHeight(20)
crossTemplateBox:SetAutoFocus(false)
crossTemplateBox:SetScript("OnEnterPressed", function(self)
    ns.db.crossCharTemplate = self:GetText()
    self:ClearFocus()
end)

local function RefreshTemplateBoxes()
    templateBox:SetText(ns.db.messageTemplate or "")
    crossTemplateBox:SetText(ns.db.crossCharTemplate or "")
end

settingsChild:SetSize(1, 500)

local function RefreshSettingsTab()
    if not ns.db then return end -- called too early (e.g. before login) — no-op
    for _, refresh in ipairs(settingsRefreshers) do
        refresh()
    end
end

-- Covers two different timings: DB_READY fires once at login regardless of
-- whether the window is open yet; ToggleMainWindow (below) covers the case
-- where the window opens well after that, so values are always current.
ns.RegisterCallback("DB_READY", RefreshSettingsTab)

----------------------------------------------------------------------
-- History tab
----------------------------------------------------------------------
historyContent = CreateContentFrame()
local historyScroll, historyChild = CreateScrollArea(historyContent)

local function RefreshHistory()
    ClearChildren(historyChild)
    local y = 0
    local rowHeight = 44

    if #ns.alertHistory == 0 then
        local empty = historyChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 4, -4)
        empty:SetText(L["NO_HISTORY"] or "No alerts yet.")
        y = 24
    end

    for _, entry in ipairs(ns.alertHistory) do
        local row = CreateFrame("Frame", nil, historyChild, "BackdropTemplate")
        row:SetSize(1, rowHeight - 4)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        ns.ApplyDarkTheme(row)

        local top = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        top:SetPoint("TOPLEFT", 8, -4)
        top:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        top:SetJustifyH("LEFT")
        local countSuffix = entry.count and entry.count > 1 and ("  x" .. entry.count) or ""
        top:SetText(entry.time .. "  " .. entry.sender .. countSuffix)

        local bottom = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bottom:SetPoint("BOTTOMLEFT", 8, 4)
        bottom:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        bottom:SetJustifyH("LEFT")
        bottom:SetTextColor(0.6, 0.6, 0.65)
        bottom:SetText(entry.recipeNames or "")

        local whisperBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        whisperBtn:SetSize(60, 20)
        whisperBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        whisperBtn:SetText(entry.replied and (L["REPLIED"] or "Replied") or (L["WHISPER"] or "Whisper"))
        whisperBtn:SetEnabled(not entry.replied)
        whisperBtn:SetScript("OnClick", function()
            ns.WhisperFromHistory(entry)
        end)

        y = y + rowHeight
    end

    historyChild:SetSize(historyScroll:GetWidth(), math.max(y, 1))
end

ns.RegisterCallback("HISTORY_UPDATED", function() if mainFrame:IsShown() then RefreshHistory() end end)

----------------------------------------------------------------------
-- Show/hide
----------------------------------------------------------------------
function ns.ToggleMainWindow()
    if mainFrame:IsShown() then
        mainFrame:Hide()
        return
    end
    mainFrame:Show()
    RefreshRecipeList()
    RefreshSettingsTab()
    RefreshFeeList()
    RefreshTemplateBoxes()
    RefreshHistory()
    SetActiveTab(1)
end