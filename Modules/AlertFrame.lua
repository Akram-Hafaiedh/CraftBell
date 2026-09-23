local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Sound
----------------------------------------------------------------------
local function PlayAlertSound()
    if not ns.db or not ns.db.settings.soundEnabled then return end
    local soundID = ns.db.settings.soundID or 11466
    if soundID <= 0 then return end

    if ns.focusModeActive then
        ns.focusSoundCounter = ns.focusSoundCounter + 1
        local myCounter = ns.focusSoundCounter
        if ns.focusModeSavedCVars then
            SetCVar("Sound_EnableSFX", 1)
            local savedMaster = ns.focusModeSavedCVars["Sound_MasterVolume"]
            if savedMaster then SetCVar("Sound_MasterVolume", savedMaster) end
        end
        PlaySound(soundID)
        C_Timer.After(2.0, function()
            if ns.focusModeActive and ns.focusSoundCounter == myCounter then
                SetCVar("Sound_EnableSFX", 0)
            end
        end)
    else
        PlaySound(soundID)
    end
end

----------------------------------------------------------------------
-- Whisper sending (255 char limit)
----------------------------------------------------------------------
local function SendWhisper(msg, target)
    if #msg <= 255 then
        SendChatMessage(msg, "WHISPER", nil, target)
        return
    end
    local splitPos = msg:sub(1, 255):match(".*()%s") or 255
    SendChatMessage(msg:sub(1, splitPos), "WHISPER", nil, target)
    local remainder = msg:sub(splitPos + 1)
    if #remainder > 0 then
        SendChatMessage(remainder, "WHISPER", nil, target)
    end
end

local function BuildKeywordWhisper(kwMatches)
    if not kwMatches then return "" end
    local prof = kwMatches.professions and kwMatches.professions[1]
    local item = kwMatches.items and kwMatches.items[1]
    local free = kwMatches.freewords and kwMatches.freewords[1]
    if prof and item then
        return string.format(L["KEYWORDS_WHISPER_BOTH"] or "Hi! I do %s, saw you mention %s — interested?", prof, item)
    elseif prof then
        return string.format(L["KEYWORDS_WHISPER_PROF"] or "Hi! I do %s — let me know if you need anything!", prof)
    elseif item then
        return string.format(L["KEYWORDS_WHISPER_ITEM"] or "Hi! Saw you mention %s — I might be able to help!", item)
    elseif free then
        return string.format(L["KEYWORDS_WHISPER_FREE"] or "Hi! Saw your message about %s — I might be able to help!", free)
    end
    return ""
end

----------------------------------------------------------------------
-- Build the whisper message for a recipe match: resolves cross-character
-- template selection, the {fee} placeholder, and realm-mismatch state.
-- Returns whisperMessage (or nil if blocked), isMismatched, isBlocked
----------------------------------------------------------------------
-- DROP-IN replacement for BuildRecipeWhisper in Modules/AlertFrame.lua
-- Uses assigned owner (multi-character) instead of the old single `character` field.

local function BuildRecipeWhisper(recipeData)
    if not recipeData then return nil, false, false end

    local currentPlayer = ns.GetPlayerFullName()
    local owner = ns.GetRecipeCharacterView and ns.GetRecipeCharacterView(recipeData)
        or (recipeData.character)
    local recipeOwner = (owner and owner.fullName) or currentPlayer
    local isCrossChar = recipeOwner ~= currentPlayer

    local isMismatched = false
    local isBlocked = false
    if owner and owner.realm then
        if not ns.IsRealmCompatible(owner.realm) then
            isMismatched = true
            isBlocked = (ns.db.settings.realmMismatchMode == "block")
        end
    end

    if isBlocked then
        return nil, isMismatched, isBlocked
    end

    local template
    if isCrossChar and ns.db.crossCharTemplate and ns.db.crossCharTemplate ~= "" then
        template = ns.db.crossCharTemplate
    else
        template = ns.db.messageTemplate
    end

    local whisperMsg = ns.FormatTemplate(template, {
        profession = recipeData.tradeSkillLink or recipeData.professionName or "Artisan",
        item = recipeData.itemLink or recipeData.recipeName,
        playerName = UnitName("player"),
        characterName = recipeOwner,
        fee = ns.FormatFee(ns.GetRecipeFee(recipeData)),
    })

    return whisperMsg, isMismatched, isBlocked
end

----------------------------------------------------------------------
-- Toast + expanded panel
----------------------------------------------------------------------
local toastFrame, toastSenderText, toastRecipeText
local expandedFrame, expandedSender, expandedMessage, expandedRecipe
local expandedWhisperPreview, expandedWhisperBtn, expandedRealmNote
local currentSender, currentWhisperMessage, currentHistoryEntry, currentFirstRecipeID
local autoHideTimer

local TOAST_PRESETS = {
    small  = { width = 300, height = 40, iconSize = 20, font1 = "GameFontHighlightSmall", font2 = "GameFontNormalSmall" },
    medium = { width = 380, height = 48, iconSize = 26, font1 = "GameFontHighlight",      font2 = "GameFontNormal" },
    large  = { width = 440, height = 56, iconSize = 30, font1 = "GameFontHighlight",      font2 = "GameFontNormal" },
}
local EXPANDED_WIDTH, EXPANDED_HEIGHT = 380, 220
local AUTO_HIDE_DELAY = 15

local function CancelAutoHide()
    if autoHideTimer then
        autoHideTimer:Cancel()
        autoHideTimer = nil
    end
end

local function StartAutoHide()
    CancelAutoHide()
    autoHideTimer = C_Timer.NewTimer(AUTO_HIDE_DELAY, function()
        if toastFrame and toastFrame:IsShown() then toastFrame:Hide() end
        if expandedFrame and expandedFrame:IsShown() then expandedFrame:Hide() end
    end)
end

local function CreateExpandedFrame()
    if expandedFrame then return end

    expandedFrame = CreateFrame("Frame", "CraftBellAlertExpanded", UIParent, "BackdropTemplate")
    expandedFrame:SetSize(EXPANDED_WIDTH, EXPANDED_HEIGHT)
    expandedFrame:SetFrameStrata("DIALOG")
    expandedFrame:SetFrameLevel(102)
    expandedFrame:SetClampedToScreen(true)
    expandedFrame:EnableMouse(true)
    ns.ApplyDarkTheme(expandedFrame)

    local title = expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", expandedFrame, "TOP", 0, -12)
    title:SetText("CraftBell")
    title:SetTextColor(unpack(ns.UI.accentColor))

    local closeBtn = CreateFrame("Button", nil, expandedFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", expandedFrame, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        expandedFrame:Hide()
        if toastFrame then toastFrame:Hide() end
        CancelAutoHide()
    end)

    expandedSender = expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    expandedSender:SetPoint("TOPLEFT", expandedFrame, "TOPLEFT", 16, -36)
    expandedSender:SetPoint("TOPRIGHT", expandedFrame, "TOPRIGHT", -16, -36)
    expandedSender:SetJustifyH("LEFT")

    expandedMessage = expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    expandedMessage:SetPoint("TOPLEFT", expandedSender, "BOTTOMLEFT", 0, -6)
    expandedMessage:SetPoint("TOPRIGHT", expandedSender, "BOTTOMRIGHT", 0, -6)
    expandedMessage:SetJustifyH("LEFT")
    expandedMessage:SetWordWrap(true)
    expandedMessage:SetMaxLines(2)

    local recipeBtn = CreateFrame("Button", nil, expandedFrame)
    recipeBtn:SetHeight(18)
    recipeBtn:SetPoint("TOPLEFT", expandedMessage, "BOTTOMLEFT", 0, -6)
    recipeBtn:SetPoint("TOPRIGHT", expandedMessage, "BOTTOMRIGHT", 0, -6)
    expandedRecipe = recipeBtn:CreateFontString(nil, "OVERLAY", "GameFontGreen")
    expandedRecipe:SetAllPoints()
    expandedRecipe:SetJustifyH("LEFT")
    recipeBtn:SetScript("OnEnter", function()
        if currentFirstRecipeID then
            expandedRecipe:SetTextColor(0, 0.8, 1)
            CancelAutoHide()
        end
    end)
    recipeBtn:SetScript("OnLeave", function()
        expandedRecipe:SetTextColor(0.1, 1, 0.1)
        if not (toastFrame and toastFrame:IsMouseOver()) and not expandedFrame:IsMouseOver() then
            StartAutoHide()
        end
    end)
    recipeBtn:SetScript("OnClick", function()
        if currentFirstRecipeID then ns.OpenRecipe(currentFirstRecipeID) end
    end)

    -- New: realm-mismatch note, between the recipe line and the whisper preview
    expandedRealmNote = expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expandedRealmNote:SetPoint("TOPLEFT", recipeBtn, "BOTTOMLEFT", 0, -4)
    expandedRealmNote:SetPoint("TOPRIGHT", recipeBtn, "BOTTOMRIGHT", 0, -4)
    expandedRealmNote:SetJustifyH("LEFT")
    expandedRealmNote:SetTextColor(1, 0.6, 0.1) -- orange
    expandedRealmNote:Hide()

    expandedWhisperPreview = expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expandedWhisperPreview:SetPoint("TOPLEFT", expandedRealmNote, "BOTTOMLEFT", 0, -6)
    expandedWhisperPreview:SetPoint("TOPRIGHT", expandedRealmNote, "BOTTOMRIGHT", 0, -6)
    expandedWhisperPreview:SetJustifyH("LEFT")
    expandedWhisperPreview:SetWordWrap(true)
    expandedWhisperPreview:SetMaxLines(3)
    expandedWhisperPreview:SetTextColor(1, 0.5, 0.7)

    expandedWhisperBtn = CreateFrame("Button", nil, expandedFrame, "UIPanelButtonTemplate")
    expandedWhisperBtn:SetSize(140, 24)
    expandedWhisperBtn:SetPoint("BOTTOM", expandedFrame, "BOTTOM", 0, 14)
    expandedWhisperBtn:SetText(L["WHISPER"] or "Whisper")

    expandedWhisperBtn:SetScript("OnClick", function()
        if currentSender and currentWhisperMessage then
            SendWhisper(currentWhisperMessage, currentSender)
            ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. currentSender)
            if currentHistoryEntry then
                currentHistoryEntry.replied = true
                ns.FireCallback("HISTORY_UPDATED")
            end
            expandedFrame:Hide()
            if toastFrame then toastFrame:Hide() end
            CancelAutoHide()
        end
    end)

    expandedFrame:SetScript("OnEnter", CancelAutoHide)
    expandedFrame:SetScript("OnLeave", function()
        if not (toastFrame and toastFrame:IsMouseOver()) and not expandedFrame:IsMouseOver() then
            expandedFrame:Hide()
            StartAutoHide()
        end
    end)

    expandedFrame:Hide()
end

local function CreateToastFrame()
    if toastFrame then return end
    local preset = TOAST_PRESETS[(ns.db and ns.db.settings.toastSize) or "medium"] or TOAST_PRESETS.medium

    toastFrame = CreateFrame("Frame", "CraftBellAlertFrame", UIParent, "BackdropTemplate")
    toastFrame:SetSize(preset.width, preset.height)

    local point = (ns.db and ns.db.settings.toastPoint) or "TOPRIGHT"
    local relPoint = (ns.db and ns.db.settings.toastRelPoint) or "TOPRIGHT"
    local offX = (ns.db and ns.db.settings.toastOffsetX) or -350
    local offY = (ns.db and ns.db.settings.toastOffsetY) or -120
    toastFrame:SetPoint(point, UIParent, relPoint, offX, offY)

    toastFrame:SetFrameStrata("DIALOG")
    toastFrame:SetFrameLevel(101)
    toastFrame:SetClampedToScreen(true)
    ns.ApplyDarkTheme(toastFrame)

    local toastIcon = toastFrame:CreateTexture(nil, "ARTWORK")
    toastIcon:SetSize(preset.iconSize, preset.iconSize)
    toastIcon:SetPoint("LEFT", toastFrame, "LEFT", 14, 0)
    toastIcon:SetTexture("Interface\\Icons\\INV_Inscription_Tradeskill01")
    toastIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    toastSenderText = toastFrame:CreateFontString(nil, "OVERLAY", preset.font1)
    toastSenderText:SetPoint("TOPLEFT", toastIcon, "TOPRIGHT", 10, 0)
    toastSenderText:SetPoint("RIGHT", toastFrame, "RIGHT", -12, 0)
    toastSenderText:SetJustifyH("LEFT")

    toastRecipeText = toastFrame:CreateFontString(nil, "OVERLAY", preset.font2)
    toastRecipeText:SetPoint("BOTTOMLEFT", toastIcon, "BOTTOMRIGHT", 10, 0)
    toastRecipeText:SetPoint("RIGHT", toastFrame, "RIGHT", -12, 0)
    toastRecipeText:SetJustifyH("LEFT")
    toastRecipeText:SetTextColor(0.5, 1, 0.5)

    local hoverTex = toastFrame:CreateTexture(nil, "HIGHLIGHT")
    hoverTex:SetPoint("TOPLEFT", 4, -4)
    hoverTex:SetPoint("BOTTOMRIGHT", -4, 4)
    hoverTex:SetColorTexture(0, 0.8, 1, 0.06)

    toastFrame:SetScript("OnEnter", function()
        CancelAutoHide()
        CreateExpandedFrame()
        expandedFrame:ClearAllPoints()
        expandedFrame:SetPoint("TOPRIGHT", toastFrame, "BOTTOMRIGHT", 0, -4)
        expandedFrame:Show()
    end)
    toastFrame:SetScript("OnLeave", function()
        C_Timer.After(0.15, function()
            if expandedFrame and expandedFrame:IsShown() then
                if not toastFrame:IsMouseOver() and not expandedFrame:IsMouseOver() then
                    expandedFrame:Hide()
                    StartAutoHide()
                end
            else
                StartAutoHide()
            end
        end)
    end)

    toastFrame:EnableMouse(true)
    toastFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            if currentSender and currentWhisperMessage and currentWhisperMessage ~= "" then
                SendWhisper(currentWhisperMessage, currentSender)
                ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. currentSender)
                if currentHistoryEntry then
                    currentHistoryEntry.replied = true
                    ns.FireCallback("HISTORY_UPDATED")
                end
            end
            self:Hide()
            if expandedFrame then expandedFrame:Hide() end
            CancelAutoHide()
        elseif button == "RightButton" then
            self:Hide()
            if expandedFrame then expandedFrame:Hide() end
            CancelAutoHide()
        end
    end)

    toastFrame:Hide()
end

----------------------------------------------------------------------
-- Show an alert for a recipe match
----------------------------------------------------------------------
function ns.ShowAlert(sender, message, matches)
    if ns.db and ns.db.settings.relayEnabled and not ns.isRelayedAlert then
        local names = {}
        for _, data in pairs(matches) do table.insert(names, data.itemLink or data.recipeName) end
        ns.AddToHistory(sender, message, matches, table.concat(names, ", "))
        return
    end

    CreateToastFrame()
    CreateExpandedFrame()
    currentSender = sender

    local recipeNames = {}
    local firstRecipeData, firstRecipeID = nil, nil
    for recipeID, data in pairs(matches) do
        if not firstRecipeData then
            firstRecipeData, firstRecipeID = data, recipeID
        end
        table.insert(recipeNames, data.itemLink or data.recipeName)
    end
    currentFirstRecipeID = firstRecipeID
    local recipeDisplay = table.concat(recipeNames, ", ")

    toastSenderText:SetText((L["TOAST_FROM"] or "From: ") .. sender)
    toastRecipeText:SetText(recipeDisplay)

    expandedSender:SetText((L["ALERT_FROM"] or "From: ") .. sender)
    local displayMsg = #message > 150 and (message:sub(1, 147) .. "...") or message
    expandedMessage:SetText("|cffaaaaaa" .. displayMsg .. "|r")
    expandedRecipe:SetText((L["ALERT_RECIPES"] or "Recipes: ") .. recipeDisplay)

    expandedWhisperBtn:SetText(L["WHISPER"] or "Whisper")
    expandedWhisperBtn:Show()
    expandedRealmNote:Hide()

    local whisperMsg, isMismatched, isBlocked = BuildRecipeWhisper(firstRecipeData)
    currentWhisperMessage = whisperMsg

    if isMismatched then
        local realmText = string.format(
            L["REALM_MISMATCH_NOTE"] or "Crafter is on %s — may not be whisperable from here.",
            firstRecipeData.character.realm)
        expandedRealmNote:SetText(realmText)
        expandedRealmNote:Show()
        if isBlocked then
            expandedWhisperBtn:Hide()
        end
    end

    if expandedWhisperPreview then
        expandedWhisperPreview:SetText(whisperMsg and ("|cffff80b3" .. whisperMsg .. "|r") or "")
    end

    local histEntry = ns.AddToHistory(sender, message, matches, recipeDisplay)
    currentHistoryEntry = histEntry
    if histEntry.count > 1 then return end -- duplicate, toast already shown once

    PlayAlertSound()
    if expandedFrame then expandedFrame:Hide() end
    toastFrame:Show()
    toastFrame:SetAlpha(1)
    toastFrame:Raise()
    StartAutoHide()
end

----------------------------------------------------------------------
-- Show an alert for a keyword match (no specific recipe/crafter, so no
-- fee or realm data to resolve — dynamic whisper built from the keywords)
----------------------------------------------------------------------
function ns.ShowKeywordAlert(sender, message, kwMatches)
    if ns.db and ns.db.settings.relayEnabled and not ns.isRelayedAlert then
        local parts = {}
        for _, list in ipairs({ kwMatches.professions, kwMatches.items, kwMatches.freewords }) do
            for _, v in ipairs(list or {}) do table.insert(parts, v) end
        end
        ns.AddToHistory(sender, message, nil, table.concat(parts, ", "), "keyword", kwMatches)
        return
    end

    CreateToastFrame()
    CreateExpandedFrame()
    currentSender = sender
    currentFirstRecipeID = nil

    local parts = {}
    for _, list in ipairs({ kwMatches.professions, kwMatches.items, kwMatches.freewords }) do
        for _, v in ipairs(list or {}) do table.insert(parts, v) end
    end
    local kwDisplay = table.concat(parts, ", ")

    toastSenderText:SetText((L["TOAST_FROM"] or "From: ") .. sender)
    toastRecipeText:SetText((L["ALERT_KEYWORDS"] or "Keywords: ") .. kwDisplay)

    expandedSender:SetText((L["ALERT_FROM"] or "From: ") .. sender)
    local displayMsg = #message > 150 and (message:sub(1, 147) .. "...") or message
    expandedMessage:SetText("|cffaaaaaa" .. displayMsg .. "|r")
    expandedRecipe:SetText((L["ALERT_KEYWORDS"] or "Keywords: ") .. kwDisplay)
    expandedRealmNote:Hide()
    expandedWhisperBtn:Show()

    local kwWhisper = BuildKeywordWhisper(kwMatches)
    currentWhisperMessage = kwWhisper
    if expandedWhisperPreview then
        expandedWhisperPreview:SetText("|cffff80b3" .. kwWhisper .. "|r")
    end

    expandedWhisperBtn:SetText(L["WHISPER"] or "Whisper")
    expandedWhisperBtn:SetScript("OnClick", function()
        if currentSender and kwWhisper ~= "" then
            SendChatMessage(kwWhisper, "WHISPER", nil, currentSender)
            ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. currentSender)
            if currentHistoryEntry then
                currentHistoryEntry.replied = true
                ns.FireCallback("HISTORY_UPDATED")
            end
            if expandedFrame then expandedFrame:Hide() end
            if toastFrame then toastFrame:Hide() end
            CancelAutoHide()
        end
    end)

    local histEntry = ns.AddToHistory(sender, message, nil, kwDisplay, "keyword", kwMatches)
    currentHistoryEntry = histEntry
    if histEntry.count > 1 then return end

    PlayAlertSound()
    if expandedFrame then expandedFrame:Hide() end
    toastFrame:Show()
    toastFrame:SetAlpha(1)
    toastFrame:Raise()
    StartAutoHide()
end

----------------------------------------------------------------------
-- Re-send from history (e.g. a "Whisper" button in the future history list)
----------------------------------------------------------------------
function ns.WhisperFromHistory(entry)
    if not entry then return end

    if entry.alertType == "keyword" then
        local kwWhisper = BuildKeywordWhisper(entry.keywordMatches)
        if kwWhisper ~= "" then
            SendChatMessage(kwWhisper, "WHISPER", nil, entry.sender)
            ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. entry.sender)
        end
        entry.replied = true
        ns.FireCallback("HISTORY_UPDATED")
        return
    end

    local whisperMsg, isMismatched, isBlocked = BuildRecipeWhisper(entry.matchData)
    if isBlocked or not whisperMsg then
        ns.Print(L["REALM_MISMATCH_BLOCKED"] or "Whisper blocked: crafter is on an incompatible realm.")
        return
    end

    SendWhisper(whisperMsg, entry.sender)
    entry.replied = true
    ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. entry.sender)
    ns.FireCallback("HISTORY_UPDATED")
end

----------------------------------------------------------------------
-- Wire up to the event bus
----------------------------------------------------------------------
ns.RegisterCallback("ALERT_FIRED", ns.ShowAlert)
ns.RegisterCallback("KEYWORD_ALERT_FIRED", ns.ShowKeywordAlert)
