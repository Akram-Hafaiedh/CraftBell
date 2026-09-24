local addonName, ns = ...
local L = ns.L
local C = ns.UI and ns.UI.C or {
    accent = { 0.15, 0.75, 0.95, 1 },
    textMuted = { 0.55, 0.58, 0.62, 1 },
}

----------------------------------------------------------------------
-- Main frame shell — tabs live in Modules/UI/*
----------------------------------------------------------------------
local mainFrame = CreateFrame("Frame", "CraftBellMainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(580, 520)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetFrameStrata("HIGH")
mainFrame:SetClampedToScreen(true)
mainFrame:Hide()
tinsert(UISpecialFrames, "CraftBellMainFrame")

if ns.ApplyDarkTheme then
    ns.ApplyDarkTheme(mainFrame)
else
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    mainFrame:SetBackdropColor(0.06, 0.07, 0.09, 0.97)
    mainFrame:SetBackdropBorderColor(0.22, 0.24, 0.28, 1)
end

local topStrip = mainFrame:CreateTexture(nil, "ARTWORK")
topStrip:SetHeight(2)
topStrip:SetPoint("TOPLEFT", 1, -1)
topStrip:SetPoint("TOPRIGHT", -1, -1)
topStrip:SetColorTexture(0.15, 0.75, 0.95, 0.9)

local titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 20, -16)
titleText:SetText("CraftBell")
titleText:SetTextColor(unpack(C.accent))

local subtitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
subtitle:SetTextColor(unpack(C.textMuted))
subtitle:SetText("trade · craft · alert")

--- Apply saved window size, accent color, and optional font.
function ns.UI.ApplyMainWindowAppearance()
    if not mainFrame then return end
    local size = { w = 580, h = 520 }
    if ns.UI.GetWindowSize then
        size = select(1, ns.UI.GetWindowSize()) or size
    end
    mainFrame:SetSize(size.w, size.h)

    local accent = (ns.UI.colors and ns.UI.colors.accent) or C.accent
    if topStrip and topStrip.SetColorTexture then
        topStrip:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
    end
    if titleText then
        titleText:SetTextColor(accent[1], accent[2], accent[3], accent[4] or 1)
        local path = ns.UI.GetFontPath and ns.UI.GetFontPath()
        if path then
            local _, h, flags = titleText:GetFont()
            pcall(titleText.SetFont, titleText, path, h or 16, flags)
        end
    end
    if subtitle then
        local path = ns.UI.GetFontPath and ns.UI.GetFontPath()
        if path then
            local _, h, flags = subtitle:GetFont()
            pcall(subtitle.SetFont, subtitle, path, h or 12, flags)
        end
    end
    if ns.ApplyDarkTheme then
        ns.ApplyDarkTheme(mainFrame)
    end
end

local closeBtn = ns.CreateUIButton and ns.CreateUIButton(mainFrame, {
    width = 28, height = 28, text = "×", variant = "ghost",
}) or CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
if closeBtn.label then
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)
else
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -2)
end

-- Test alert + Debug (near close)
local debugBtn = ns.CreateUIButton and ns.CreateUIButton(mainFrame, {
    width = 72, height = 24, text = L["BTN_DEBUG"] or "Debug", variant = "ghost",
}) or CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
debugBtn:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
if not ns.CreateUIButton then debugBtn:SetSize(72, 24); debugBtn:SetText("Debug") end
local function UpdateDebugBtn()
    local on = ns.debugEnabled or (ns.db and ns.db.settings and ns.db.settings.debugEnabled)
    if debugBtn.SetText then
        debugBtn:SetText(on and (L["BTN_DEBUG_ON"] or "Debug*") or (L["BTN_DEBUG"] or "Debug"))
    end
    if debugBtn.SetActive then debugBtn:SetActive(on and true or false) end
end
debugBtn:SetScript("OnClick", function()
    local on = not (ns.debugEnabled or (ns.db and ns.db.settings and ns.db.settings.debugEnabled))
    ns.debugEnabled = on
    if ns.db and ns.db.settings then ns.db.settings.debugEnabled = on end
    UpdateDebugBtn()
    ns.Print(on and (L["DEBUG_ON"] or "Debug mode ON — extra chat spam.")
        or (L["DEBUG_OFF"] or "Debug mode OFF."))
end)
debugBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["BTN_DEBUG_TIP"] or "Toggle debug logging (alerts, scanner, realm checks)", 1, 1, 1, true)
    GameTooltip:Show()
end)
debugBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local testBtn = ns.CreateUIButton and ns.CreateUIButton(mainFrame, {
    width = 64, height = 24, text = L["BTN_TEST"] or "Test", variant = "ghost",
}) or CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
testBtn:SetPoint("RIGHT", debugBtn, "LEFT", -6, 0)
if not ns.CreateUIButton then testBtn:SetSize(64, 24); testBtn:SetText("Test") end
local testClickCount = 0
testBtn:SetScript("OnClick", function()
    if not ns.db or not next(ns.db.trackedRecipes) then
        ns.Print(L["NO_RECIPE_TRACKED"] or "No recipes tracked yet.")
        return
    end
    testClickCount = testClickCount + 1
    local firstID, firstData = next(ns.db.trackedRecipes)
    local link = firstData.itemLink or firstData.recipeName or "item"
    local fakeMessage = string.format(L["TEST_FAKE_MESSAGE"] or "LF someone to craft %s, will pay!", link)
    local sender = "TestBuyer-" .. testClickCount
    ns.Print(L["ALERT_SIMULATION"] or "Simulating an alert...")
    ns.FireCallback("ALERT_FIRED", sender, fakeMessage, { [firstID] = firstData })
end)
testBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["BTN_TEST_TIP"] or "Fire a test toast for the first tracked recipe", 1, 1, 1, true)
    GameTooltip:Show()
end)
testBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

ns.RegisterCallback("DB_READY", UpdateDebugBtn)

----------------------------------------------------------------------
-- Tabs
----------------------------------------------------------------------
local activeTab = 1
local contentFrames = {}
local tabs = {}

local function CreateTab(text, index)
    local tab
    if ns.CreateUIButton then
        tab = ns.CreateUIButton(mainFrame, {
            width = 100, height = 28, text = text, variant = "tab",
        })
    else
        tab = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
        tab:SetSize(100, 28)
        tab:SetText(text)
    end
    tabs[index] = tab
    return tab
end

local tabRecipes = CreateTab(L["TAB_RECIPES"] or "Recipes", 1)
local tabSettings = CreateTab(L["TAB_SETTINGS"] or "Settings", 2)
local tabHistory = CreateTab(L["TAB_HISTORY"] or "History", 3)
local tabKeywords = CreateTab(L["TAB_KEYWORDS"] or "Keywords", 4)

tabRecipes:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -48)
tabSettings:SetPoint("LEFT", tabRecipes, "RIGHT", 6, 0)
tabHistory:SetPoint("LEFT", tabSettings, "RIGHT", 6, 0)
tabKeywords:SetPoint("LEFT", tabHistory, "RIGHT", 6, 0)

local tabLine = mainFrame:CreateTexture(nil, "ARTWORK")
tabLine:SetHeight(1)
tabLine:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -84)
tabLine:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -14, -84)
tabLine:SetColorTexture(0.22, 0.24, 0.28, 0.8)

local CONTENT_TOP, CONTENT_INSET = -92, 16
local function CreateContentFrame()
    local f = CreateFrame("Frame", nil, mainFrame)
    f:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CONTENT_INSET, CONTENT_TOP)
    f:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -CONTENT_INSET, 16)
    f:Hide()
    return f
end

contentFrames[1] = CreateContentFrame()
contentFrames[2] = CreateContentFrame()
contentFrames[3] = CreateContentFrame()
contentFrames[4] = CreateContentFrame()

-- Init tab modules (loaded before this file via TOC)
if ns.UI.RecipesTab then ns.UI.RecipesTab.Init(contentFrames[1]) end
if ns.UI.SettingsTab then ns.UI.SettingsTab.Init(contentFrames[2]) end
if ns.UI.HistoryTab then ns.UI.HistoryTab.Init(contentFrames[3]) end
if ns.UI.KeywordsTab then ns.UI.KeywordsTab.Init(contentFrames[4]) end

local function SetActiveTab(index)
    activeTab = index
    for i, frame in pairs(contentFrames) do
        frame:SetShown(i == index)
    end
    for i, tab in pairs(tabs) do
        if tab.SetActive then
            tab:SetActive(i == index)
        else
            tab:SetEnabled(i ~= index)
        end
    end
    -- Refresh the visible tab so layout has correct widths
    if index == 1 and ns.UI.RecipesTab then ns.UI.RecipesTab.Refresh() end
    if index == 2 and ns.UI.SettingsTab then ns.UI.SettingsTab.Refresh() end
    if index == 3 and ns.UI.HistoryTab then ns.UI.HistoryTab.Refresh() end
    if index == 4 and ns.UI.KeywordsTab then ns.UI.KeywordsTab.Refresh() end
end

tabRecipes:SetScript("OnClick", function() SetActiveTab(1) end)
tabSettings:SetScript("OnClick", function() SetActiveTab(2) end)
tabHistory:SetScript("OnClick", function() SetActiveTab(3) end)
tabKeywords:SetScript("OnClick", function() SetActiveTab(4) end)

----------------------------------------------------------------------
-- Show / hide
----------------------------------------------------------------------
function ns.ToggleMainWindow()
    if mainFrame:IsShown() then
        mainFrame:Hide()
        return
    end
    if ns.UI.ApplyMainWindowAppearance then
        ns.UI.ApplyMainWindowAppearance()
    end
    mainFrame:Show()
    SetActiveTab(activeTab or 1)
    -- One-frame defer so ScrollFrames have real width (edit boxes, rows)
    if ns.db then
        C_Timer.After(0, function()
            if not mainFrame:IsShown() then return end
            if ns.UI.RecipesTab then ns.UI.RecipesTab.Refresh() end
            if ns.UI.SettingsTab then ns.UI.SettingsTab.Refresh() end
            if ns.UI.HistoryTab then ns.UI.HistoryTab.Refresh() end
            if ns.UI.KeywordsTab then ns.UI.KeywordsTab.Refresh() end
        end)
    end
end