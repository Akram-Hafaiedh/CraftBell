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
-- Whisper sending (255 byte limit per message)
-- Full item/profession hyperlinks easily exceed 255 bytes. Splitting mid-link
-- makes the client drop the whisper with no error — that looked like
-- "Message sent" with nothing in chat.
----------------------------------------------------------------------
local WHISPER_MAX = 255

local function ChatSend(msg, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, "WHISPER", nil, target)
    else
        SendChatMessage(msg, "WHISPER", nil, target)
    end
end

--- Prefer a split at whitespace that does not land inside |H...|h...|h
local function SafeSplitPos(msg, limit)
    limit = math.min(limit or WHISPER_MAX, #msg)
    local window = msg:sub(1, limit)
    -- Walk back to a space that is outside an open hyperlink
    local pos = window:match(".*()%s")
    if not pos then return limit end
    local before = msg:sub(1, pos)
    local opens = 0
    for _ in before:gmatch("|H") do opens = opens + 1 end
    for _ in before:gmatch("|h") do opens = opens - 1 end
    -- Uneven |H vs |h means we are still inside a link — search earlier spaces
    if opens ~= 0 then
        local search = before
        while true do
            local p = search:match(".*()%s")
            if not p or p < 20 then
                -- Fall back: strip links and send plain text instead
                return nil
            end
            local b = msg:sub(1, p)
            local o = 0
            for _ in b:gmatch("|H") do o = o + 1 end
            for _ in b:gmatch("|h") do o = o - 1 end
            if o == 0 then return p end
            search = msg:sub(1, p - 1)
        end
    end
    return pos
end

local function PlainForWhisper(msg)
    -- Collapse hyperlinks to their bracket text so long templates still fit
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    msg = msg:gsub("|H.-|[Hh](.-)|[Hh]", "%1")
    msg = msg:gsub("|T.-|t", "")
    return msg
end

local function SendWhisper(msg, target)
    if not msg or msg == "" or not target or target == "" then
        ns.Debug("SendWhisper: missing msg or target")
        return false
    end

    -- Normalize target (trim); keep Name-Realm as provided by chat events
    target = target:match("^%s*(.-)%s*$") or target

    local function trySend(payload)
        ns.Debug(string.format("SendWhisper: target=%s len=%d", tostring(target), #payload))
        local ok, err = pcall(ChatSend, payload, target)
        if not ok then
            ns.Error("Whisper failed: " .. tostring(err))
            return false
        end
        return true
    end

    if #msg <= WHISPER_MAX then
        return trySend(msg)
    end

    -- Too long with full links: try plain-text version first (still readable)
    local plain = PlainForWhisper(msg)
    if #plain <= WHISPER_MAX then
        ns.Debug("SendWhisper: using plain-text form (links stripped) len=" .. #plain)
        return trySend(plain)
    end

    -- Still long: split safely, or split plain text
    local splitPos = SafeSplitPos(msg, WHISPER_MAX)
    if not splitPos then
        splitPos = SafeSplitPos(plain, WHISPER_MAX) or WHISPER_MAX
        msg = plain
    end
    local first = msg:sub(1, splitPos):match("^(.-)%s*$") or msg:sub(1, splitPos)
    local rest = msg:sub(splitPos + 1):match("^%s*(.-)%s*$") or ""
    local ok = trySend(first)
    if ok and #rest > 0 then
        if #rest > WHISPER_MAX then
            rest = PlainForWhisper(rest)
            if #rest > WHISPER_MAX then
                rest = rest:sub(1, WHISPER_MAX - 3) .. "..."
            end
        end
        C_Timer.After(0.15, function()
            trySend(rest)
        end)
    end
    return ok
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

--- Prefer an owner whose realm is whisper-compatible with the current client.
local function PickCompatibleOwner(recipeData)
    if not recipeData then return nil end
    local owners = recipeData.owners or {}
    local assigned = ns.GetRecipeCharacterView and ns.GetRecipeCharacterView(recipeData)
        or recipeData.character
    local smart = not ns.db or ns.db.settings.smartRealmCrafter ~= false

    if assigned and assigned.realm and ns.IsRealmCompatible(assigned.realm) then
        return assigned
    end
    if not smart then
        return assigned
    end
    for _, o in pairs(owners) do
        if o and o.realm and ns.IsRealmCompatible(o.realm) then
            return o
        end
    end
    return assigned
end

local function BuildRecipeWhisper(recipeData)
    if not recipeData then return nil, false, false end

    local currentPlayer = ns.GetPlayerFullName()
    local owner = PickCompatibleOwner(recipeData)
    local recipeOwner = (owner and owner.fullName) or currentPlayer
    local isCrossChar = recipeOwner ~= currentPlayer

    local isMismatched = false
    local isBlocked = false
    if owner and owner.realm then
        if not ns.IsRealmCompatible(owner.realm) then
            isMismatched = true
            isBlocked = (ns.db.settings.blockIncompatibleRealmAlerts == true)
                or (ns.db.settings.realmMismatchMode == "block")
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

    -- Prefer links in the template; SendWhisper falls back to plain text if over 255 bytes.
    -- Fee as plain compact units (2k / 2m) — no "g", no color codes.
    local whisperMsg = ns.FormatTemplate(template, {
        profession = recipeData.tradeSkillLink or recipeData.professionName or "Artisan",
        item = recipeData.itemLink or recipeData.recipeName,
        playerName = UnitName("player"),
        characterName = recipeOwner,
        fee = ns.FormatFee(ns.GetRecipeFee(recipeData), { plain = true }),
    })

    return whisperMsg, isMismatched, isBlocked
end

----------------------------------------------------------------------
-- Toast + expanded panel
----------------------------------------------------------------------
local toastFrame, toastSenderText, toastRecipeText, toastIcon
local expandedFrame, expandedSender, expandedMessage, expandedRecipe
local expandedWhisperPreview, expandedWhisperBtn, expandedRealmNote
local currentSender, currentWhisperMessage, currentHistoryEntry, currentFirstRecipeID
local autoHideTimer
local toastEditMode = false
local editOverlayFrame = nil

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
    if toastEditMode then return end
    CancelAutoHide()
    autoHideTimer = C_Timer.NewTimer(AUTO_HIDE_DELAY, function()
        if toastFrame and toastFrame:IsShown() then toastFrame:Hide() end
        if expandedFrame and expandedFrame:IsShown() then expandedFrame:Hide() end
    end)
end

local function SaveToastPosition()
    if not toastFrame or not ns.db then return end
    local pt, _, relPt, ox, oy = toastFrame:GetPoint()
    ns.db.settings.toastPoint = pt
    ns.db.settings.toastRelPoint = relPt
    ns.db.settings.toastOffsetX = ox
    ns.db.settings.toastOffsetY = oy
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

    if ns.CreateUIButton then
        expandedWhisperBtn = ns.CreateUIButton(expandedFrame, {
            width = 140, height = 28,
            text = L["WHISPER"] or "Whisper",
            variant = "primary",
        })
    else
        expandedWhisperBtn = CreateFrame("Button", nil, expandedFrame, "UIPanelButtonTemplate")
        expandedWhisperBtn:SetSize(140, 28)
        expandedWhisperBtn:SetText(L["WHISPER"] or "Whisper")
    end
    expandedWhisperBtn:SetPoint("BOTTOM", expandedFrame, "BOTTOM", 0, 14)

    expandedWhisperBtn:SetScript("OnClick", function()
        if currentSender and currentWhisperMessage and currentWhisperMessage ~= "" then
            local ok = SendWhisper(currentWhisperMessage, currentSender)
            if ok then
                ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. currentSender)
                if currentHistoryEntry and ns.HistoryMarkContacted then
                    ns.HistoryMarkContacted(currentHistoryEntry)
                elseif currentHistoryEntry then
                    currentHistoryEntry.replied = true
                    ns.FireCallback("HISTORY_UPDATED")
                end
                expandedFrame:Hide()
                if toastFrame then toastFrame:Hide() end
                CancelAutoHide()
            else
                ns.Print(L["WHISPER_FAILED"] or "Whisper failed — check target name/realm or message length.")
            end
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

    toastFrame:SetMovable(true)
    toastFrame:EnableMouse(true)
    toastFrame:RegisterForDrag("RightButton")
    toastFrame:SetScript("OnDragStart", toastFrame.StartMoving)
    toastFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if toastEditMode then SaveToastPosition() end
    end)

    toastFrame:SetFrameStrata("DIALOG")
    toastFrame:SetFrameLevel(101)
    toastFrame:SetClampedToScreen(true)
    ns.ApplyDarkTheme(toastFrame)

    toastIcon = toastFrame:CreateTexture(nil, "ARTWORK")
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
        if toastEditMode then return end
        CancelAutoHide()
        CreateExpandedFrame()
        expandedFrame:ClearAllPoints()
        expandedFrame:SetPoint("TOPRIGHT", toastFrame, "BOTTOMRIGHT", 0, -4)
        expandedFrame:Show()
    end)
    toastFrame:SetScript("OnLeave", function()
        if toastEditMode then return end
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

    toastFrame:SetScript("OnMouseUp", function(self, button)
        if toastEditMode then return end
        if button == "LeftButton" then
            local clickWhisper = not ns.db or ns.db.settings.toastClickWhispers ~= false
            if clickWhisper and currentSender and currentWhisperMessage and currentWhisperMessage ~= "" then
                local ok = SendWhisper(currentWhisperMessage, currentSender)
                if ok then
                    ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. currentSender)
                    if currentHistoryEntry then
                        currentHistoryEntry.replied = true
                        ns.FireCallback("HISTORY_UPDATED")
                    end
                else
                    ns.Print(L["WHISPER_FAILED"] or "Whisper failed — check target name/realm or message length.")
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
-- Toast size + edit mode
----------------------------------------------------------------------
function ns.ApplyToastSize(presetKey)
    local p = TOAST_PRESETS[presetKey]
    if not p then return end
    if ns.db then ns.db.settings.toastSize = presetKey end
    CreateToastFrame()
    toastFrame:SetSize(p.width, p.height)
    if toastIcon then toastIcon:SetSize(p.iconSize, p.iconSize) end
    if toastSenderText then toastSenderText:SetFontObject(p.font1) end
    if toastRecipeText then toastRecipeText:SetFontObject(p.font2) end
end

function ns.ToggleToastEditMode()
    CreateToastFrame()

    if toastEditMode then
        toastEditMode = false
        if editOverlayFrame then editOverlayFrame:Hide() end
        toastFrame:RegisterForDrag("RightButton")
        toastFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)
        toastFrame:Hide()
        return
    end

    toastEditMode = true
    CancelAutoHide()
    if expandedFrame then expandedFrame:Hide() end

    toastFrame:RegisterForDrag("LeftButton")
    toastFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveToastPosition()
    end)

    toastSenderText:SetText((L["TOAST_FROM"] or "From: ") .. "PlayerName-Realm")
    toastRecipeText:SetText("[" .. (L["TOAST_EDIT_MODE"] or "Configure popup") .. "]")
    toastFrame:Show()
    toastFrame:SetAlpha(1)
    toastFrame:Raise()

    if not editOverlayFrame then
        editOverlayFrame = CreateFrame("Frame", nil, toastFrame, "BackdropTemplate")
        editOverlayFrame:SetSize(300, 56)
        editOverlayFrame:SetPoint("TOP", toastFrame, "BOTTOM", 0, -8)
        editOverlayFrame:SetFrameStrata("DIALOG")
        editOverlayFrame:SetFrameLevel(102)
        ns.ApplyDarkTheme(editOverlayFrame)

        editOverlayFrame.hint = editOverlayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        editOverlayFrame.hint:SetPoint("TOP", editOverlayFrame, "TOP", 0, -8)

        editOverlayFrame.saveBtn = ns.CreateUIButton and ns.CreateUIButton(editOverlayFrame, {
            width = 120, height = 24, text = L["TOAST_EDIT_SAVE"] or "Save", variant = "primary",
        }) or CreateFrame("Button", nil, editOverlayFrame, "UIPanelButtonTemplate")
        editOverlayFrame.saveBtn:SetPoint("BOTTOM", editOverlayFrame, "BOTTOM", 0, 8)
        if not ns.CreateUIButton then
            editOverlayFrame.saveBtn:SetSize(120, 24)
            editOverlayFrame.saveBtn:SetText(L["TOAST_EDIT_SAVE"] or "Save")
        end
        editOverlayFrame.saveBtn:SetScript("OnClick", function()
            SaveToastPosition()
            ns.Print(L["TOAST_POSITION_SAVED"] or "Popup position saved.")
            toastEditMode = false
            editOverlayFrame:Hide()
            toastFrame:RegisterForDrag("RightButton")
            toastFrame:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
            end)
            toastFrame:Hide()
        end)
    end

    editOverlayFrame.hint:SetText("|cff00ccff" .. (L["TOAST_EDIT_HINT"] or "Drag the popup, then click Save") .. "|r")
    if editOverlayFrame.saveBtn.SetText then
        editOverlayFrame.saveBtn:SetText(L["TOAST_EDIT_SAVE"] or "Save")
    end
    editOverlayFrame:Show()
end

----------------------------------------------------------------------
-- Show an alert for a recipe match
----------------------------------------------------------------------
function ns.ShowAlert(sender, message, matches)
    if ns.DebugStep then
        ns.DebugStep("showalert", true, "from " .. tostring(sender))
    end

    if ns.db and ns.db.settings.relayEnabled and not ns.isRelayedAlert then
        local names = {}
        for _, data in pairs(matches) do table.insert(names, data.itemLink or data.recipeName) end
        ns.AddToHistory(sender, message, matches, table.concat(names, ", "))
        if ns.DebugStep then
            ns.DebugStep("history", true, "relay mode — history only")
            ns.DebugStep("toast", false, "skipped (relayEnabled)")
        end
        if ns.DebugEndRun then ns.DebugEndRun() end
        return
    end

    -- Optional: skip if no crafter is realm-compatible with this client
    if ns.db and ns.db.settings.blockIncompatibleRealmAlerts and matches then
        local anyOk = false
        for _, data in pairs(matches) do
            local owners = data.owners or {}
            local hasOwner = false
            for _, o in pairs(owners) do
                hasOwner = true
                if o.realm and ns.IsRealmCompatible(o.realm) then
                    anyOk = true
                    break
                end
            end
            if not hasOwner then
                -- no owner map: treat as ok for this character
                anyOk = true
            end
            if anyOk then break end
        end
        if not anyOk then
            ns.Debug("ShowAlert: blocked — no realm-compatible crafter")
            if ns.DebugStep then
                ns.DebugStep("realm", false, "no realm-compatible crafter")
                ns.DebugStep("toast", false, "blocked by realm filter")
            end
            if ns.DebugEndRun then ns.DebugEndRun() end
            return
        end
    end
    if ns.DebugStep then ns.DebugStep("realm", true, "ok") end

    -- Optional: only alert when the logged-in character is the crafter
    if ns.db and ns.db.settings.alertsCurrentCharOnly and matches then
        local me = ns.GetPlayerFullName and ns.GetPlayerFullName()
        local filtered = {}
        for recipeID, data in pairs(matches) do
            local assigned = data.assignedCharacter
            local isMe = assigned and me and assigned == me
            if not isMe and ns.DoesCharacterOwnRecipe then
                isMe = ns.DoesCharacterOwnRecipe(recipeID, me)
            end
            if isMe then
                filtered[recipeID] = data
            end
        end
        if not next(filtered) then
            if ns.DebugStep then
                ns.DebugStep("charfilter", false, "no match for current character")
                ns.DebugStep("toast", false, "filtered")
            end
            if ns.DebugEndRun then ns.DebugEndRun() end
            return
        end
        matches = filtered
    end
    if ns.DebugStep then ns.DebugStep("charfilter", true, "ok") end

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
    if ns.DebugStep then
        ns.DebugStep("whisper", whisperMsg and whisperMsg ~= "",
            isBlocked and "blocked (realm)" or (whisperMsg and (#whisperMsg .. " chars") or "empty"))
    end

    if isMismatched then
        local ownerView = ns.GetRecipeCharacterView and ns.GetRecipeCharacterView(firstRecipeData)
            or firstRecipeData.character
        local realmName = (ownerView and ownerView.realm) or "?"
        local realmText = string.format(
            L["REALM_MISMATCH_NOTE"] or "Crafter is on %s — may not be whisperable from here.",
            realmName)
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
    if ns.DebugStep then
        ns.DebugStep("history", histEntry ~= nil,
            histEntry and string.format("count=%s status=%s",
                tostring(histEntry.count or 1), tostring(histEntry.status or "new")) or "nil")
    end
    if histEntry.count > 1 then
        if ns.DebugStep then
            ns.DebugStep("toast", false, "skipped — duplicate open history (count=" .. tostring(histEntry.count) .. ")")
        end
        if ns.DebugEndRun then ns.DebugEndRun() end
        return -- duplicate, toast already shown once
    end

    PlayAlertSound()
    if expandedFrame then expandedFrame:Hide() end
    toastFrame:Show()
    toastFrame:SetAlpha(1)
    toastFrame:Raise()
    StartAutoHide()
    if ns.DebugStep then ns.DebugStep("toast", true, "shown") end
    if ns.DebugEndRun then ns.DebugEndRun() end
end

----------------------------------------------------------------------
-- Show an alert for a keyword match (no specific recipe/crafter, so no
-- fee or realm data to resolve — dynamic whisper built from the keywords)
----------------------------------------------------------------------
function ns.ShowKeywordAlert(sender, message, kwMatches)
    if ns.DebugStep then
        ns.DebugStep("showalert", true, "keyword from " .. tostring(sender))
        ns.DebugStep("realm", true, "n/a (keyword)")
        ns.DebugStep("charfilter", true, "n/a (keyword)")
    end

    if ns.db and ns.db.settings.relayEnabled and not ns.isRelayedAlert then
        local parts = {}
        for _, list in ipairs({ kwMatches.professions, kwMatches.items, kwMatches.freewords }) do
            for _, v in ipairs(list or {}) do table.insert(parts, v) end
        end
        ns.AddToHistory(sender, message, nil, table.concat(parts, ", "), "keyword", kwMatches)
        if ns.DebugStep then
            ns.DebugStep("history", true, "relay mode")
            ns.DebugStep("toast", false, "skipped (relayEnabled)")
        end
        if ns.DebugEndRun then ns.DebugEndRun() end
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
    if ns.DebugStep then
        ns.DebugStep("whisper", kwWhisper ~= "", kwWhisper ~= "" and (#kwWhisper .. " chars") or "empty")
    end

    expandedWhisperBtn:SetText(L["WHISPER"] or "Whisper")
    expandedWhisperBtn:SetScript("OnClick", function()
        if currentSender and kwWhisper ~= "" then
            local ok = SendWhisper(kwWhisper, currentSender)
            if ok then
                ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. currentSender)
                if currentHistoryEntry and ns.HistoryMarkContacted then
                    ns.HistoryMarkContacted(currentHistoryEntry)
                elseif currentHistoryEntry then
                    currentHistoryEntry.replied = true
                    ns.FireCallback("HISTORY_UPDATED")
                end
                if expandedFrame then expandedFrame:Hide() end
                if toastFrame then toastFrame:Hide() end
                CancelAutoHide()
            else
                ns.Print(L["WHISPER_FAILED"] or "Whisper failed — check target name/realm or message length.")
            end
        end
    end)

    local histEntry = ns.AddToHistory(sender, message, nil, kwDisplay, "keyword", kwMatches)
    currentHistoryEntry = histEntry
    if ns.DebugStep then
        ns.DebugStep("history", histEntry ~= nil,
            histEntry and string.format("count=%s", tostring(histEntry.count or 1)) or "nil")
    end
    if histEntry.count > 1 then
        if ns.DebugStep then
            ns.DebugStep("toast", false, "skipped — duplicate open history")
        end
        if ns.DebugEndRun then ns.DebugEndRun() end
        return
    end

    PlayAlertSound()
    if expandedFrame then expandedFrame:Hide() end
    toastFrame:Show()
    toastFrame:SetAlpha(1)
    toastFrame:Raise()
    StartAutoHide()
    if ns.DebugStep then ns.DebugStep("toast", true, "shown") end
    if ns.DebugEndRun then ns.DebugEndRun() end
end

----------------------------------------------------------------------
-- History actions: offer whisper, ready/mail notify
----------------------------------------------------------------------
function ns.WhisperFromHistory(entry)
    if not entry then return end

    if entry.alertType == "keyword" then
        local kwWhisper = BuildKeywordWhisper(entry.keywordMatches)
        if kwWhisper ~= "" then
            local ok = SendWhisper(kwWhisper, entry.sender)
            if ok then
                ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. entry.sender)
                if ns.HistoryMarkContacted then ns.HistoryMarkContacted(entry) end
            else
                ns.Print(L["WHISPER_FAILED"] or "Whisper failed — check target name/realm or message length.")
            end
        end
        return
    end

    local whisperMsg, isMismatched, isBlocked = BuildRecipeWhisper(entry.matchData)
    if isBlocked or not whisperMsg then
        ns.Print(L["REALM_MISMATCH_BLOCKED"] or "Whisper blocked: crafter is on an incompatible realm.")
        return
    end

    local ok = SendWhisper(whisperMsg, entry.sender)
    if ok then
        ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. entry.sender)
        if ns.HistoryMarkContacted then ns.HistoryMarkContacted(entry) end
    else
        ns.Print(L["WHISPER_FAILED"] or "Whisper failed — check target name/realm or message length.")
    end
end

--- "Ready / mailed" notify from the current character (usually the crafter).
function ns.NotifyFromHistory(entry)
    if not entry then return end

    local template = (ns.db and ns.db.notifyTemplate and ns.db.notifyTemplate ~= "" and ns.db.notifyTemplate)
        or (L["DEFAULT_NOTIFY_TEMPLATE"] or "Hi! {item} is ready — check your mailbox.")

    local item = entry.recipeNames
    local profession = entry.professionName or "Artisan"
    if entry.matchData then
        item = entry.matchData.itemLink or entry.matchData.recipeName or item
        profession = entry.matchData.tradeSkillLink or entry.matchData.professionName or profession
    end

    local msg = ns.FormatTemplate(template, {
        profession = profession,
        item = item or "your order",
        playerName = UnitName("player"),
        characterName = ns.GetPlayerFullName and ns.GetPlayerFullName() or UnitName("player"),
        fee = entry.feeOffered and ns.FormatFee(entry.feeOffered, { plain = true }) or "",
    })

    if not msg or msg == "" then
        ns.Print(L["WHISPER_FAILED"] or "Whisper failed — empty notify template.")
        return
    end

    local ok = SendWhisper(msg, entry.sender)
    if ok then
        ns.Print((L["MESSAGE_SENT_TO"] or "Message sent to ") .. entry.sender)
        if ns.HistoryMarkDone then ns.HistoryMarkDone(entry) end
    else
        ns.Print(L["WHISPER_FAILED"] or "Whisper failed — check target name/realm or message length.")
    end
end

----------------------------------------------------------------------
-- Wire scanner / test events to the toast UI
----------------------------------------------------------------------
ns.RegisterCallback("ALERT_FIRED", ns.ShowAlert)
ns.RegisterCallback("KEYWORD_ALERT_FIRED", ns.ShowKeywordAlert)