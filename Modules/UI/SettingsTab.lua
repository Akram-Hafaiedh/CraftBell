local addonName, ns = ...
local L = ns.L
local C = ns.UI.C

ns.UI.SettingsTab = ns.UI.SettingsTab or {}

local scroll, child
local settingsRefreshers = {}
local feeListFrame, feeProfInput, feeAmountInput
local templateBox, crossTemplateBox

local DEFAULT_SAME = L["DEFAULT_TEMPLATE"]
    or "Hi! I saw you're looking for {item}. I can craft it ({profession}). Fee: {fee}. Let me know!"
local DEFAULT_CROSS = L["DEFAULT_CROSS_TEMPLATE"]
    or "Hi! My crafting alt {characterName} can make {item} ({profession}). Fee: {fee}. Let me know!"

--- On/off row using CraftBell toggle switch (falls back to stock checkbox).
local function CreateCheckbox(parent, text, yPos, getValue, setValue)
    if ns.CreateUIToggle then
        local t = ns.CreateUIToggle(parent, {
            checked = false,
            label = text,
            labelOnRight = true,
            onChange = function(on) setValue(on and true or false) end,
        })
        t:SetPoint("TOPLEFT", 4, yPos)
        table.insert(settingsRefreshers, function()
            if ns.db then t:SetChecked(getValue() and true or false, true) end
        end)
        return t
    end

    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 4, yPos)
    cb:SetSize(24, 24)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetText(text)
    label:SetTextColor(unpack(C.text))
    cb:SetScript("OnClick", function(self) setValue(self:GetChecked() and true or false) end)
    table.insert(settingsRefreshers, function()
        if ns.db then cb:SetChecked(getValue()) end
    end)
    return cb
end

local function Header(text, y)
    if ns.CreateUISectionHeader then
        return ns.CreateUISectionHeader(child, text, y)
    end
    local h = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 4, y)
    h:SetText(text)
    h:SetTextColor(unpack(C.accent))
    return h
end

local function RefreshFeeList()
    if not ns.db or not feeListFrame then return end
    ns.UI.ClearChildren(feeListFrame)
    local y = 0
    local fees = ns.db.settings.professionFees or {}

    -- Prefer known professions from tracked recipes (named rows)
    local known = ns.GetTrackedProfessionList and ns.GetTrackedProfessionList() or {}
    local shown = {}

    for _, prof in ipairs(known) do
        shown[prof.id] = true
        local row = ns.CreateUIRow and ns.CreateUIRow(feeListFrame, 32)
            or CreateFrame("Frame", nil, feeListFrame)
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        if row.SetHeight then row:SetHeight(32) end

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", 10, 0)
        label:SetTextColor(unpack(C.text))
        label:SetText(string.format("%s  |cff888888#%d|r", prof.name, prof.id))

        local box = ns.CreateUIEditBox and ns.CreateUIEditBox(row, {
            height = 22, numeric = false,
        }) or CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        box:SetSize(72, 22)
        box:SetPoint("RIGHT", -70, 0)
        box:SetAutoFocus(false)
        if box.SetNumeric then box:SetNumeric(false) end
        local current = fees[prof.id]
        box:SetText(current and tostring(current) or "")
        box:SetScript("OnEnterPressed", function(self)
            local t = self:GetText()
            local n = (t == "" or not t) and nil
                or ((ns.ParseGoldAmount and ns.ParseGoldAmount(t)) or tonumber(t))
            if ns.SetProfessionFee then
                ns.SetProfessionFee(prof.id, n)
            else
                ns.db.settings.professionFees[prof.id] = n
            end
            self:ClearFocus()
            ns.Print(string.format(L["FEE_SET"] or "Fee for %s → %s",
                prof.name, n and (ns.FormatFee and ns.FormatFee(n, true) or (n .. "g")) or "cleared"))
            RefreshFeeList()
        end)
        box:SetScript("OnEditFocusLost", function(self)
            local t = self:GetText()
            if t == "" then
                if ns.SetProfessionFee then ns.SetProfessionFee(prof.id, nil)
                else ns.db.settings.professionFees[prof.id] = nil end
            else
                local n = (ns.ParseGoldAmount and ns.ParseGoldAmount(t)) or tonumber(t)
                if n and ns.SetProfessionFee then ns.SetProfessionFee(prof.id, n)
                elseif n then ns.db.settings.professionFees[prof.id] = n end
            end
        end)

        local unit = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        unit:SetPoint("LEFT", box, "RIGHT", 4, 0)
        unit:SetTextColor(unpack(C.textMuted))
        unit:SetText("|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t")

        y = y + 36
    end

    -- Orphan fees (set for IDs we no longer track)
    for profID, amount in pairs(fees) do
        if not shown[profID] then
            local row = ns.CreateUIRow and ns.CreateUIRow(feeListFrame, 28)
                or CreateFrame("Frame", nil, feeListFrame)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", 0, -y)
            if row.SetHeight then row:SetHeight(28) end

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("LEFT", 10, 0)
            label:SetTextColor(unpack(C.textMuted))
            label:SetText("ID " .. tostring(profID) .. "   " .. ns.FormatFee(amount))

            local del = ns.CreateUIButton and ns.CreateUIButton(row, {
                width = 56, height = 20, text = L["REMOVE"] or "Remove", variant = "danger",
            }) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            del:SetPoint("RIGHT", -6, 0)
            if not ns.CreateUIButton then del:SetSize(56, 20); del:SetText("Remove") end
            del:SetScript("OnClick", function()
                if ns.SetProfessionFee then ns.SetProfessionFee(profID, nil)
                else ns.db.settings.professionFees[profID] = nil end
                RefreshFeeList()
            end)
            y = y + 32
        end
    end

    if #known == 0 then
        local empty = feeListFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 4, -y)
        empty:SetText(L["FEE_NO_PROFS"] or "Track some recipes first — professions appear here automatically.")
        y = y + 24
    end

    -- Manual add fallback
    if not feeProfInput then
        feeProfInput = ns.CreateUIEditBox and ns.CreateUIEditBox(feeListFrame, {
            name = "CraftBellFeeProfInput", height = 26, numeric = true,
        }) or CreateFrame("EditBox", "CraftBellFeeProfInput", feeListFrame, "InputBoxTemplate")
        feeProfInput:SetSize(80, 26)
        feeProfInput:SetAutoFocus(false)

        feeAmountInput = ns.CreateUIEditBox and ns.CreateUIEditBox(feeListFrame, {
            name = "CraftBellFeeAmtInput", height = 26, numeric = false,
        }) or CreateFrame("EditBox", "CraftBellFeeAmtInput", feeListFrame, "InputBoxTemplate")
        feeAmountInput:SetSize(70, 26)
        feeAmountInput:SetAutoFocus(false)

        feeListFrame.addBtn = ns.CreateUIButton and ns.CreateUIButton(feeListFrame, {
            width = 56, height = 26, text = L["ADD"] or "Add", variant = "primary",
        }) or CreateFrame("Button", nil, feeListFrame, "UIPanelButtonTemplate")
        if not ns.CreateUIButton then
            feeListFrame.addBtn:SetSize(56, 26)
            feeListFrame.addBtn:SetText("Add")
        end
        feeListFrame.addBtn:SetScript("OnClick", function()
            local profID = tonumber(feeProfInput:GetText())
            local amount = (ns.ParseGoldAmount and ns.ParseGoldAmount(feeAmountInput:GetText()))
                or tonumber(feeAmountInput:GetText())
            if profID and amount and ns.SetProfessionFee then
                ns.SetProfessionFee(profID, amount)
                feeProfInput:SetText("")
                feeAmountInput:SetText("")
                RefreshFeeList()
            elseif profID and amount then
                ns.db.settings.professionFees = ns.db.settings.professionFees or {}
                ns.db.settings.professionFees[profID] = amount
                feeProfInput:SetText("")
                feeAmountInput:SetText("")
                RefreshFeeList()
            else
                ns.Print(L["FEE_NEED_BOTH"] or "Enter profession ID and gold amount.")
            end
        end)
    end

    local manual = feeListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manual:SetPoint("TOPLEFT", 2, -y)
    manual:SetTextColor(unpack(C.textMuted))
    manual:SetText(L["FEE_MANUAL"] or "Manual (ID + gold) — only if a profession is missing above")
    y = y + 18

    feeProfInput:SetParent(feeListFrame)
    feeProfInput:ClearAllPoints()
    feeProfInput:SetPoint("TOPLEFT", 0, -y)
    feeProfInput:Show()

    feeAmountInput:SetParent(feeListFrame)
    feeAmountInput:ClearAllPoints()
    feeAmountInput:SetPoint("LEFT", feeProfInput, "RIGHT", 10, 0)
    feeAmountInput:Show()

    feeListFrame.addBtn:SetParent(feeListFrame)
    feeListFrame.addBtn:ClearAllPoints()
    feeListFrame.addBtn:SetPoint("LEFT", feeAmountInput, "RIGHT", 8, 0)
    feeListFrame.addBtn:Show()

    feeListFrame:SetHeight(y + 36)
end

local function EnsureDefaultTemplates()
    if not ns.db then return end
    if not ns.db.messageTemplate or ns.db.messageTemplate == "" then
        ns.db.messageTemplate = DEFAULT_SAME
    end
    if not ns.db.crossCharTemplate or ns.db.crossCharTemplate == "" then
        ns.db.crossCharTemplate = DEFAULT_CROSS
    end
end

local function RefreshTemplateBoxes()
    if not ns.db or not templateBox then return end
    EnsureDefaultTemplates()
    local w = scroll and scroll:GetWidth()
    if w and w > 20 then
        templateBox:SetWidth(w - 16)
        crossTemplateBox:SetWidth(w - 16)
    end
    templateBox:SetText(ns.db.messageTemplate or DEFAULT_SAME)
    crossTemplateBox:SetText(ns.db.crossCharTemplate or DEFAULT_CROSS)
        -- notify box refreshed via settingsRefreshers
end

function ns.UI.SettingsTab.Init(parent)
    scroll, child = ns.UI.CreateScrollArea(parent)
    child:SetSize(1, 1)

    ----------------------------------------------------------------------
    -- Language (top)
    ----------------------------------------------------------------------
    Header(L["SECTION_LANGUAGE"] or "Language", -4)
    local LANGS = {
        { value = "en", label = "English" },
        { value = "fr", label = "Français" },
        { value = "es", label = "Español" },
    }
    local langDD = ns.CreateUIDropdown and ns.CreateUIDropdown(child, {
        width = 160, height = 26, placeholder = "English",
        onSelect = function(value)
            if not ns.db then return end
            ns.db.settings.language = value
            if ns.SetLanguage then ns.SetLanguage(value) end
            ns.Print(L["LANGUAGE_SET"] or "Language saved. /reload to refresh all strings.")
        end,
    })
    if langDD then
        langDD:SetPoint("TOPLEFT", 4, -30)
        langDD:SetOptions(LANGS)
        table.insert(settingsRefreshers, function()
            if ns.db and langDD.SetValue then
                langDD:SetValue(ns.db.settings.language or "en", true)
            end
        end)
    end

    Header(L["SECTION_GENERAL"] or "General", -70)
    CreateCheckbox(child, L["SETTING_SOUND"] or "Play sound on alert", -96,
        function() return ns.db.settings.soundEnabled end,
        function(v) ns.db.settings.soundEnabled = v end)
    CreateCheckbox(child, L["SETTING_KEYWORD_SCAN"] or "Scan for keyword matches", -122,
        function() return ns.db.settings.keywordScanEnabled end,
        function(v) ns.db.settings.keywordScanEnabled = v end)
    CreateCheckbox(child, L["SETTING_DND"] or "Do Not Disturb (pause scanning)", -148,
        function() return ns.db.settings.dndEnabled end,
        function(v) ns.db.settings.dndEnabled = v end)
    CreateCheckbox(child, L["SETTING_CURRENT_CHAR_ONLY"] or "Alerts only for this character (assigned crafter)", -174,
        function() return ns.db.settings.alertsCurrentCharOnly end,
        function(v) ns.db.settings.alertsCurrentCharOnly = v end)
    CreateCheckbox(child, L["SETTING_QUIET_MODE"] or "Quiet mode (mute game sound during alerts)", -200,
        function() return ns.db.settings.quietModeEnabled end,
        function(v)
            ns.db.settings.quietModeEnabled = v
            if ns.SetFocusMode then ns.SetFocusMode(v) end
        end)

    ----------------------------------------------------------------------
    -- Bulk track (Track All button / /cb bulk)
    ----------------------------------------------------------------------
    Header(L["SECTION_BULK"] or "Bulk track", -236)
    CreateCheckbox(child, L["BULK_OPT_ORDERS"] or "Orders only (Crafting Orders table)", -262,
        function() return ns.db.settings.bulkTrackOrdersOnly ~= false end,
        function(v) ns.db.settings.bulkTrackOrdersOnly = v end)
    CreateCheckbox(child, L["BULK_OPT_LEARNED"] or "Learned only", -288,
        function() return ns.db.settings.bulkTrackLearnedOnly end,
        function(v) ns.db.settings.bulkTrackLearnedOnly = v end)
    local bulkScopeHint = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bulkScopeHint:SetPoint("TOPLEFT", 4, -314)
    bulkScopeHint:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    bulkScopeHint:SetJustifyH("LEFT")
    bulkScopeHint:SetWordWrap(true)
    bulkScopeHint:SetTextColor(unpack(C.textMuted))
    bulkScopeHint:SetText(L["BULK_SCOPE_HINT"] or "Expansion scope: /cb exp list · /cb exp add <name> · /cb exp alltrained · /cb exp clear  (UI checklist later)")

    ----------------------------------------------------------------------
    -- Toast size + position + sound
    ----------------------------------------------------------------------
    Header(L["SECTION_TOAST"] or "Alert popup", -350)

    local toastSizeLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toastSizeLabel:SetPoint("TOPLEFT", 4, -370)
    toastSizeLabel:SetTextColor(unpack(C.textMuted))
    toastSizeLabel:SetText(L["TOAST_SIZE_LABEL"] or "Popup size:")

    local TOAST_SIZES = {
        { value = "small",  label = L["TOAST_SIZE_SMALL"] or "Small" },
        { value = "medium", label = L["TOAST_SIZE_MEDIUM"] or "Medium" },
        { value = "large",  label = L["TOAST_SIZE_LARGE"] or "Large" },
    }

    local toastSizeControl
    if ns.CreateUISegmented then
        toastSizeControl = ns.CreateUISegmented(child, {
            width = 240,
            height = 26,
            options = TOAST_SIZES,
            value = "medium",
            onChange = function(value)
                if ns.db then ns.db.settings.toastSize = value end
                if ns.ApplyToastSize then ns.ApplyToastSize(value) end
            end,
        })
        toastSizeControl:SetPoint("TOPLEFT", 4, -390)
        table.insert(settingsRefreshers, function()
            if ns.db and toastSizeControl.SetValue then
                toastSizeControl:SetValue(ns.db.settings.toastSize or "medium", true)
            end
        end)
    else
        -- Fallback: three ghost buttons
        local prevBtn
        for i, opt in ipairs(TOAST_SIZES) do
            local btn = ns.CreateUIButton and ns.CreateUIButton(child, {
                width = 72, height = 24, text = opt.label, variant = "ghost",
            }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
            if prevBtn then
                btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
            else
                btn:SetPoint("TOPLEFT", 4, -390)
            end
            if not ns.CreateUIButton then
                btn:SetSize(72, 24)
                btn:SetText(opt.label)
            end
            btn:SetScript("OnClick", function()
                if ns.ApplyToastSize then ns.ApplyToastSize(opt.value) end
                if ns.db then ns.db.settings.toastSize = opt.value end
            end)
            prevBtn = btn
        end
    end

    local toastEditBtn = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 160, height = 26, text = L["TOAST_EDIT_MODE"] or "Configure popup", variant = "primary",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    toastEditBtn:SetPoint("TOPLEFT", 4, -422)
    if not ns.CreateUIButton then
        toastEditBtn:SetSize(160, 26)
        toastEditBtn:SetText(L["TOAST_EDIT_MODE"] or "Configure popup")
    end
    toastEditBtn:SetScript("OnClick", function()
        if ns.ToggleToastEditMode then
            ns.ToggleToastEditMode()
        else
            ns.Print("Toast edit mode not available.")
        end
    end)

    -- Click-to-whisper on the compact toast bar (anchored under Configure popup)
    local toastClickToggle
    if ns.CreateUIToggle then
        toastClickToggle = ns.CreateUIToggle(child, {
            label = L["SETTING_TOAST_CLICK_WHISPER"] or "Left-click toast to whisper (and dismiss)",
            labelOnRight = true,
            checked = true,
            onChange = function(on)
                if ns.db then ns.db.settings.toastClickWhispers = on and true or false end
            end,
        })
        toastClickToggle:SetPoint("TOPLEFT", toastEditBtn, "BOTTOMLEFT", 0, -10)
        table.insert(settingsRefreshers, function()
            if ns.db and toastClickToggle.SetChecked then
                toastClickToggle:SetChecked(ns.db.settings.toastClickWhispers ~= false, true)
            end
        end)
    else
        CreateCheckbox(child, L["SETTING_TOAST_CLICK_WHISPER"] or "Left-click toast to whisper (and dismiss)", -450,
            function() return ns.db.settings.toastClickWhispers ~= false end,
            function(v) ns.db.settings.toastClickWhispers = v end)
    end

    -- Alert sound (lives with the popup section)
    local soundLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soundLabel:SetPoint("TOPLEFT", 4, -500)
    soundLabel:SetTextColor(unpack(C.textMuted))
    soundLabel:SetText(L["SECTION_SOUND"] or "Alert sound")

    local SOUNDS = {
        { value = 11466, label = "Bell (default)" },
        { value = 5274,  label = "Auction" },
        { value = 3081,  label = "Map ping" },
        { value = 8459,  label = "Raid warning" },
        { value = 888,   label = "Level up" },
        { value = 0,     label = "Silent" },
    }
    local soundDD = ns.CreateUIDropdown and ns.CreateUIDropdown(child, {
        width = 180, height = 26, placeholder = "Bell (default)",
        onSelect = function(value)
            if not ns.db then return end
            ns.db.settings.soundID = value
            if value and value > 0 and PlaySound then
                pcall(PlaySound, value)
            end
        end,
    })
    if soundDD then
        soundDD:SetPoint("TOPLEFT", 4, -522)
        soundDD:SetOptions(SOUNDS)
        table.insert(settingsRefreshers, function()
            if ns.db and soundDD.SetValue then
                soundDD:SetValue(ns.db.settings.soundID or 11466, true)
            end
        end)
    end

    Header(L["SECTION_REALM"] or "Realm compatibility", -560)
    CreateCheckbox(child, L["SETTING_BLOCK_BAD_REALM"] or "Do not alert if no crafter can whisper this client realm", -586,
        function() return ns.db.settings.blockIncompatibleRealmAlerts end,
        function(v) ns.db.settings.blockIncompatibleRealmAlerts = v end)
    CreateCheckbox(child, L["SETTING_SMART_REALM"] or "Smart crafter: use a realm-compatible owner when assigned cannot", -612,
        function() return ns.db.settings.smartRealmCrafter ~= false end,
        function(v) ns.db.settings.smartRealmCrafter = v end)
    local realmHint = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    realmHint:SetPoint("TOPLEFT", 4, -638)
    realmHint:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    realmHint:SetJustifyH("LEFT")
    realmHint:SetWordWrap(true)
    realmHint:SetTextColor(unpack(C.textMuted))
    realmHint:SetText(L["REALM_HINT"] or "Smart crafter picks another owner on a connected realm. Turn it off if another addon handles realm routing.")

    ----------------------------------------------------------------------
    -- Chat channels
    ----------------------------------------------------------------------
    Header(L["SECTION_CHANNELS"] or "Chat channels", -680)
    local CHANNEL_OPTS = {
        { key = "trade", label = L["CH_TRADE"] or "Trade" },
        { key = "services", label = L["CH_SERVICES"] or "Services" },
        { key = "general", label = L["CH_GENERAL"] or "General" },
        { key = "lookingforgroup", label = L["CH_LFG"] or "Looking for Group" },
        { key = "say", label = L["CH_SAY"] or "Say" },
        { key = "yell", label = L["CH_YELL"] or "Yell" },
        { key = "guild", label = L["CH_GUILD"] or "Guild" },
        { key = "party", label = L["CH_PARTY"] or "Party" },
        { key = "raid", label = L["CH_RAID"] or "Raid" },
        { key = "instance", label = L["CH_INSTANCE"] or "Instance" },
    }
    local chY = -706
    for _, opt in ipairs(CHANNEL_OPTS) do
        local key = opt.key
        CreateCheckbox(child, opt.label, chY,
            function()
                local ch = ns.db.settings.chatChannels or {}
                if key == "trade" or key == "services" or key == "say" or key == "yell" then
                    return ch[key] ~= false
                end
                return ch[key] and true or false
            end,
            function(v)
                ns.db.settings.chatChannels = ns.db.settings.chatChannels or {}
                ns.db.settings.chatChannels[key] = v
                if ns.RestartScanner then ns.RestartScanner() end
            end)
        chY = chY - 26
    end

    ----------------------------------------------------------------------
    -- Keyword ↔ profession pairing (placeholder)
    ----------------------------------------------------------------------
    Header(L["SECTION_KW_PAIR"] or "Keyword / profession pairing", chY - 20)
    local pairHint = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pairHint:SetPoint("TOPLEFT", 4, chY - 44)
    pairHint:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    pairHint:SetJustifyH("LEFT")
    pairHint:SetWordWrap(true)
    pairHint:SetTextColor(unpack(C.textMuted))
    pairHint:SetText(L["KW_PAIR_PLACEHOLDER"] or "Coming soon — link free-word keywords to a profession so matches only fire when that craft is relevant.")

    local feesY = chY - 90
    Header(L["SECTION_FEES"] or "Per-profession fees", feesY)
    local feeHint = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    feeHint:SetPoint("TOPLEFT", 4, feesY - 20) -- set below after feesY known
    feeHint:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    feeHint:SetJustifyH("LEFT")
    feeHint:SetWordWrap(true)
    feeHint:SetTextColor(unpack(C.textMuted))
    feeHint:SetText(L["FEE_HINT"] or
        "Default gold fee per profession for {fee}. Per-recipe overrides are set on the Recipes tab. Accepts 8k, 1.5k, …")

    -- Fee list grows with content; everything below anchors to its bottom
    feeListFrame = CreateFrame("Frame", nil, child)
    feeListFrame:SetPoint("TOPLEFT", feeHint, "BOTTOMLEFT", 0, -10)
    feeListFrame:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    feeListFrame:SetHeight(1)

    -- Templates: always sit under the fee list (no fixed Y → no overlap)
    local templatesHeader = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    templatesHeader:SetPoint("TOPLEFT", feeListFrame, "BOTTOMLEFT", 0, -36)
    templatesHeader:SetTextColor(unpack(C.accent))
    templatesHeader:SetText(string.upper(L["SECTION_TEMPLATES"] or "Whisper templates"))

    local templateHint = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    templateHint:SetPoint("TOPLEFT", templatesHeader, "BOTTOMLEFT", 0, -8)
    templateHint:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    templateHint:SetJustifyH("LEFT")
    templateHint:SetJustifyV("TOP")
    templateHint:SetWordWrap(true)
    templateHint:SetSpacing(2)
    templateHint:SetTextColor(unpack(C.textMuted))
    templateHint:SetText(L["TEMPLATE_PLACEHOLDERS"] or table.concat({
        "Wildcards replaced when you send a whisper:",
        "  {item}            recipe / item link",
        "  {profession}      profession name or skill link",
        "  {fee}             fee in gold (empty if unset)",
        "  {characterName}   assigned crafter (Name-Realm)",
        "  {playerName}      your current character name",
        "Edit the line, then press Enter or click away to save.",
    }, "\n"))
    templateHint:SetHeight(96)

    local sameCharLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sameCharLabel:SetPoint("TOPLEFT", templateHint, "BOTTOMLEFT", 0, -10)
    sameCharLabel:SetTextColor(unpack(C.text))
    sameCharLabel:SetText(L["TEMPLATE_SAME"] or "Same character (you are the crafter)")

    templateBox = ns.CreateUIEditBox and ns.CreateUIEditBox(child, {
        name = "CraftBellMsgTemplate", height = 28, maxLetters = 255,
    }) or CreateFrame("EditBox", "CraftBellMsgTemplate", child, "InputBoxTemplate")
    templateBox:SetHeight(28)
    templateBox:SetAutoFocus(false)
    templateBox:SetPoint("TOPLEFT", sameCharLabel, "BOTTOMLEFT", 0, -6)
    templateBox:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    templateBox:SetWidth(480)
    templateBox:SetScript("OnEnterPressed", function(self)
        local t = self:GetText()
        if t == "" then t = DEFAULT_SAME end
        ns.db.messageTemplate = t
        self:SetText(t)
        self:ClearFocus()
        ns.Print(L["TEMPLATE_SAVED"] or "Whisper template saved.")
    end)
    templateBox:SetScript("OnEditFocusLost", function(self)
        if not ns.db then return end
        local t = self:GetText()
        if t == "" then t = DEFAULT_SAME; self:SetText(t) end
        ns.db.messageTemplate = t
    end)

    local crossCharLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    crossCharLabel:SetPoint("TOPLEFT", templateBox, "BOTTOMLEFT", 0, -14)
    crossCharLabel:SetTextColor(unpack(C.text))
    crossCharLabel:SetText(L["TEMPLATE_CROSS"] or "Cross-character (an alt is the crafter)")

    crossTemplateBox = ns.CreateUIEditBox and ns.CreateUIEditBox(child, {
        name = "CraftBellCrossTemplate", height = 28, maxLetters = 255,
    }) or CreateFrame("EditBox", "CraftBellCrossTemplate", child, "InputBoxTemplate")
    crossTemplateBox:SetHeight(28)
    crossTemplateBox:SetAutoFocus(false)
    crossTemplateBox:SetPoint("TOPLEFT", crossCharLabel, "BOTTOMLEFT", 0, -6)
    crossTemplateBox:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    crossTemplateBox:SetWidth(480)
    crossTemplateBox:SetScript("OnEnterPressed", function(self)
        local t = self:GetText()
        if t == "" then t = DEFAULT_CROSS end
        ns.db.crossCharTemplate = t
        self:SetText(t)
        self:ClearFocus()
        ns.Print(L["TEMPLATE_SAVED"] or "Whisper template saved.")
    end)
    crossTemplateBox:SetScript("OnEditFocusLost", function(self)
        if not ns.db then return end
        local t = self:GetText()
        if t == "" then t = DEFAULT_CROSS; self:SetText(t) end
        ns.db.crossCharTemplate = t
    end)

    local DEFAULT_NOTIFY = L["DEFAULT_NOTIFY_TEMPLATE"]
        or "Hi! {item} is ready — check your mailbox."
    if not ns.db.notifyTemplate or ns.db.notifyTemplate == "" then
        ns.db.notifyTemplate = DEFAULT_NOTIFY
    end

    local notifyLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    notifyLabel:SetPoint("TOPLEFT", crossTemplateBox, "BOTTOMLEFT", 0, -14)
    notifyLabel:SetTextColor(unpack(C.text))
    notifyLabel:SetText(L["SETTING_NOTIFY_TEMPLATE"] or "Ready / mailed (History → Ready)")

    local notifyBox = ns.CreateUIEditBox and ns.CreateUIEditBox(child, {
        name = "CraftBellNotifyTemplate", height = 28, maxLetters = 255,
    }) or CreateFrame("EditBox", "CraftBellNotifyTemplate", child, "InputBoxTemplate")
    notifyBox:SetHeight(28)
    notifyBox:SetAutoFocus(false)
    notifyBox:SetPoint("TOPLEFT", notifyLabel, "BOTTOMLEFT", 0, -6)
    notifyBox:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    notifyBox:SetWidth(480)
    notifyBox:SetText(ns.db.notifyTemplate or DEFAULT_NOTIFY)
    notifyBox:SetScript("OnEnterPressed", function(self)
        local t = self:GetText()
        if t == "" then t = DEFAULT_NOTIFY end
        ns.db.notifyTemplate = t
        self:SetText(t)
        self:ClearFocus()
        ns.Print(L["TEMPLATE_SAVED"] or "Whisper template saved.")
    end)
    notifyBox:SetScript("OnEditFocusLost", function(self)
        if not ns.db then return end
        local t = self:GetText()
        if t == "" then t = DEFAULT_NOTIFY; self:SetText(t) end
        ns.db.notifyTemplate = t
    end)
    table.insert(settingsRefreshers, function()
        if ns.db then
            notifyBox:SetText(ns.db.notifyTemplate or DEFAULT_NOTIFY)
        end
    end)

    ----------------------------------------------------------------------
    -- Appearance (window size, color scheme, font)
    ----------------------------------------------------------------------
    local appearHeader = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    appearHeader:SetPoint("TOPLEFT", notifyBox, "BOTTOMLEFT", 0, -28)
    appearHeader:SetTextColor(unpack(C.accent))
    appearHeader:SetText(string.upper(L["SECTION_APPEARANCE"] or "Appearance"))

    local sizeLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("TOPLEFT", appearHeader, "BOTTOMLEFT", 0, -12)
    sizeLabel:SetTextColor(unpack(C.textMuted))
    sizeLabel:SetText(L["APPEARANCE_SIZE"] or "Window size")

    local SIZE_OPTS = {
        { value = "compact", label = L["APPEARANCE_SIZE_COMPACT"] or "Compact" },
        { value = "normal",  label = L["APPEARANCE_SIZE_NORMAL"] or "Normal" },
        { value = "large",   label = L["APPEARANCE_SIZE_LARGE"] or "Large" },
        { value = "xl",      label = L["APPEARANCE_SIZE_XL"] or "Extra large" },
    }
    local sizeControl
    if ns.CreateUISegmented then
        sizeControl = ns.CreateUISegmented(child, {
            width = 360, height = 26,
            options = SIZE_OPTS,
            value = "normal",
            onChange = function(value)
                if ns.db then ns.db.settings.windowSize = value end
                if ns.UI.ApplyAppearance then ns.UI.ApplyAppearance() end
            end,
        })
        sizeControl:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -6)
        table.insert(settingsRefreshers, function()
            if ns.db and sizeControl.SetValue then
                sizeControl:SetValue(ns.db.settings.windowSize or "normal", true)
            end
        end)
    end

    local themeLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    themeLabel:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -44)
    themeLabel:SetTextColor(unpack(C.textMuted))
    themeLabel:SetText(L["APPEARANCE_THEME"] or "Accent color")

    local THEME_OPTS = {
        { value = "cyan",    label = L["APPEARANCE_THEME_CYAN"] or "Cyan" },
        { value = "violet",  label = L["APPEARANCE_THEME_VIOLET"] or "Violet" },
        { value = "emerald", label = L["APPEARANCE_THEME_EMERALD"] or "Emerald" },
        { value = "amber",   label = L["APPEARANCE_THEME_AMBER"] or "Amber" },
        { value = "rose",    label = L["APPEARANCE_THEME_ROSE"] or "Rose" },
    }
    local themeControl
    if ns.CreateUISegmented then
        themeControl = ns.CreateUISegmented(child, {
            width = 400, height = 26,
            options = THEME_OPTS,
            value = "cyan",
            onChange = function(value)
                if ns.db then ns.db.settings.colorScheme = value end
                if ns.UI.ApplyAppearance then ns.UI.ApplyAppearance() end
            end,
        })
        themeControl:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", 0, -6)
        table.insert(settingsRefreshers, function()
            if ns.db and themeControl.SetValue then
                themeControl:SetValue(ns.db.settings.colorScheme or "cyan", true)
            end
        end)
    end

    local bgLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bgLabel:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", 0, -44)
    bgLabel:SetTextColor(unpack(C.textMuted))
    bgLabel:SetText(L["APPEARANCE_BG"] or "Background")

    local BG_OPTS = {
        { value = "slate",    label = L["APPEARANCE_BG_SLATE"] or "Slate" },
        { value = "charcoal", label = L["APPEARANCE_BG_CHARCOAL"] or "Charcoal" },
        { value = "midnight", label = L["APPEARANCE_BG_MIDNIGHT"] or "Midnight" },
        { value = "graphite", label = L["APPEARANCE_BG_GRAPHITE"] or "Graphite" },
        { value = "warm",     label = L["APPEARANCE_BG_WARM"] or "Warm" },
    }
    local bgControl
    if ns.CreateUISegmented then
        bgControl = ns.CreateUISegmented(child, {
            width = 400, height = 26,
            options = BG_OPTS,
            value = "slate",
            onChange = function(value)
                if ns.db then ns.db.settings.bgScheme = value end
                if ns.UI.ApplyAppearance then ns.UI.ApplyAppearance() end
            end,
        })
        bgControl:SetPoint("TOPLEFT", bgLabel, "BOTTOMLEFT", 0, -6)
        table.insert(settingsRefreshers, function()
            if ns.db and bgControl.SetValue then
                bgControl:SetValue(ns.db.settings.bgScheme or "slate", true)
            end
        end)
    end

    local fontLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontLabel:SetPoint("TOPLEFT", bgLabel, "BOTTOMLEFT", 0, -44)
    fontLabel:SetTextColor(unpack(C.textMuted))
    fontLabel:SetText(L["APPEARANCE_FONT"] or "UI font")

    local FONT_OPTS = {
        { value = "default",  label = L["APPEARANCE_FONT_DEFAULT"] or "Default" },
        { value = "friz",     label = L["APPEARANCE_FONT_FRIZ"] or "Friz Quadrata" },
        { value = "arialn",   label = L["APPEARANCE_FONT_ARIALN"] or "Arial Narrow" },
        { value = "morpheus", label = L["APPEARANCE_FONT_MORPHEUS"] or "Morpheus" },
        { value = "skurri",   label = L["APPEARANCE_FONT_SKURRI"] or "Skurri" },
    }
    local fontDD = ns.CreateUIDropdown and ns.CreateUIDropdown(child, {
        width = 180, height = 26, placeholder = L["APPEARANCE_FONT_DEFAULT"] or "Default",
        onSelect = function(value)
            if ns.db then ns.db.settings.uiFont = value end
            if ns.UI.ApplyAppearance then ns.UI.ApplyAppearance() end
            ns.Print(L["APPEARANCE_APPLY"] or "Applied. Some labels need /reload.")
        end,
    })
    if fontDD then
        fontDD:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -6)
        fontDD:SetOptions(FONT_OPTS)
        table.insert(settingsRefreshers, function()
            if ns.db and fontDD.SetValue then
                fontDD:SetValue(ns.db.settings.uiFont or "default", true)
            end
        end)
    end

    local appearHint = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    appearHint:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -40)
    appearHint:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    appearHint:SetJustifyH("LEFT")
    appearHint:SetWordWrap(true)
    appearHint:SetTextColor(unpack(C.textMuted))
    appearHint:SetText(L["APPEARANCE_HINT"] or "Size applies immediately. Theme and font update open windows; /reload for full refresh.")

    ----------------------------------------------------------------------
    -- Import / Export
    ----------------------------------------------------------------------
    local configHeader = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    configHeader:SetPoint("TOPLEFT", appearHint, "BOTTOMLEFT", 0, -24)
    configHeader:SetTextColor(unpack(C.accent))
    configHeader:SetText(string.upper(L["SECTION_CONFIG"] or "Config"))

    local exportBtn = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 120, height = 26, text = L["EXPORT_CONFIG"] or "Export", variant = "ghost",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    exportBtn:SetPoint("TOPLEFT", configHeader, "BOTTOMLEFT", 0, -8)
    if not ns.CreateUIButton then exportBtn:SetSize(120, 26); exportBtn:SetText("Export") end
    exportBtn:SetScript("OnClick", function()
        if not ns.ExportConfig then
            ns.Print("Export not available.")
            return
        end
        local s = ns.ExportConfig()
        if not s or s == "" then
            ns.Print(L["EXPORT_FAILED"] or "Export failed.")
            return
        end
        if not CraftBellExportFrame then
            local f = CreateFrame("Frame", "CraftBellExportFrame", UIParent, "BackdropTemplate")
            f:SetSize(420, 220)
            f:SetPoint("CENTER")
            f:SetFrameStrata("DIALOG")
            if ns.ApplyDarkTheme then ns.ApplyDarkTheme(f) end
            local eb = CreateFrame("EditBox", nil, f)
            eb:SetMultiLine(true)
            eb:SetFontObject(GameFontHighlightSmall)
            eb:SetPoint("TOPLEFT", 12, -12)
            eb:SetPoint("BOTTOMRIGHT", -12, 48)
            eb:SetAutoFocus(true)
            f.eb = eb

            local copyBtn = ns.CreateUIButton and ns.CreateUIButton(f, {
                width = 140, height = 26,
                text = L["COPY_CLIPBOARD"] or "Copy to clipboard",
                variant = "primary",
            }) or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            copyBtn:SetPoint("BOTTOMLEFT", 16, 12)
            if not ns.CreateUIButton then
                copyBtn:SetSize(140, 26)
                copyBtn:SetText("Copy to clipboard")
            end
            copyBtn:SetScript("OnClick", function()
                local text = f.eb:GetText() or ""
                if text == "" then return end
                -- Modern clients expose CopyToClipboard; fall back to highlight for Ctrl+C
                if CopyToClipboard then
                    CopyToClipboard(text)
                    ns.Print(L["COPIED_CLIPBOARD"] or "Copied to clipboard.")
                else
                    f.eb:SetFocus()
                    f.eb:HighlightText()
                    ns.Print(L["COPY_MANUAL"] or "Text selected — press Ctrl+C to copy.")
                end
            end)

            local close = ns.CreateUIButton and ns.CreateUIButton(f, {
                width = 80, height = 26, text = "Close", variant = "ghost",
            }) or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            close:SetPoint("BOTTOMRIGHT", -16, 12)
            if not ns.CreateUIButton then close:SetSize(80, 26); close:SetText("Close") end
            close:SetScript("OnClick", function() f:Hide() end)
            f:EnableMouse(true)
            f:SetMovable(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)
        end
        CraftBellExportFrame.eb:SetText(s)
        CraftBellExportFrame.eb:HighlightText()
        CraftBellExportFrame:Show()
        ns.Print(L["EXPORT_OK"] or "Config exported — use Copy to clipboard, or Ctrl+C.")
    end)

    local importBtn = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 120, height = 26, text = L["IMPORT_CONFIG"] or "Import", variant = "ghost",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
    if not ns.CreateUIButton then importBtn:SetSize(120, 26); importBtn:SetText("Import") end
    importBtn:SetScript("OnClick", function()
        if not CraftBellImportFrame then
            local f = CreateFrame("Frame", "CraftBellImportFrame", UIParent, "BackdropTemplate")
            f:SetSize(420, 200)
            f:SetPoint("CENTER")
            f:SetFrameStrata("DIALOG")
            if ns.ApplyDarkTheme then ns.ApplyDarkTheme(f) end
            local eb = CreateFrame("EditBox", nil, f)
            eb:SetMultiLine(true)
            eb:SetFontObject(GameFontHighlightSmall)
            eb:SetPoint("TOPLEFT", 12, -12)
            eb:SetPoint("BOTTOMRIGHT", -12, 40)
            eb:SetAutoFocus(true)
            f.eb = eb
            local go = ns.CreateUIButton and ns.CreateUIButton(f, {
                width = 100, height = 24, text = L["IMPORT_CONFIG"] or "Import", variant = "primary",
            }) or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            go:SetPoint("BOTTOMLEFT", 40, 10)
            if not ns.CreateUIButton then go:SetSize(100, 24); go:SetText("Import") end
            go:SetScript("OnClick", function()
                local text = f.eb:GetText()
                if ns.ImportConfig and ns.ImportConfig(text) then
                    f:Hide()
                    ns.UI.SettingsTab.Refresh()
                end
            end)
            local close = ns.CreateUIButton and ns.CreateUIButton(f, {
                width = 80, height = 24, text = "Close", variant = "ghost",
            }) or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            close:SetPoint("BOTTOMRIGHT", -40, 10)
            if not ns.CreateUIButton then close:SetSize(80, 24); close:SetText("Close") end
            close:SetScript("OnClick", function() f:Hide() end)
        end
        CraftBellImportFrame.eb:SetText("")
        CraftBellImportFrame:Show()
    end)

    -- Tall enough for templates + language/sound/config under them
    child:SetHeight(1200)
end

function ns.UI.SettingsTab.Refresh()
    if not ns.db or not child then return end
    ns.UI.SyncScrollChildWidth(scroll, child, 1200)
    for _, refresh in ipairs(settingsRefreshers) do refresh() end
    RefreshFeeList()
    RefreshTemplateBoxes()
end

ns.RegisterCallback("DB_READY", function()
    ns.UI.SettingsTab.Refresh()
end)