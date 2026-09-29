local addonName, ns = ...
local L = ns.L
local C = ns.UI and ns.UI.C or {
    accent = { 0.15, 0.75, 0.95, 1 },
    text = { 0.92, 0.93, 0.95, 1 },
    textMuted = { 0.55, 0.58, 0.62, 1 },
}

ns.UI.KeywordsTab = ns.UI.KeywordsTab or {}

local scroll, child

local function EnsureKeywords()
    if not ns.db then return end
    ns.db.keywords = ns.db.keywords or {}
    ns.db.keywords.triggers = ns.db.keywords.triggers or {}
    ns.db.keywords.pairs = ns.db.keywords.pairs or {}
    ns.db.keywords.freewords = ns.db.keywords.freewords or {}
end

local function FireKeywordsChanged()
    ns.FireCallback("KEYWORDS_CHANGED")
end

function ns.UI.KeywordsTab.Init(parent)
    scroll, child = ns.UI.CreateScrollArea(parent)
    child:SetSize(1, 1)
end

function ns.UI.KeywordsTab.Refresh()
    if not child or not ns.db then return end
    EnsureKeywords()
    ns.UI.ClearChildren(child)

    local pack = (ns.GetChatLangPack and ns.GetChatLangPack()) or {
        triggerExamples = "LF, WTB, Need...",
        pairExample = 'LF JC neck  ->  left "JC, jewel"  /  right "neck, ring"',
        phProf = "JC, jewelcrafting, jewel",
        phItem = "neck, ring, back, cloak",
        triggers = { "LF", "WTB", "Need", "LFC", "Seek" },
    }
    local y = 0
    local function Header(text)
        if ns.CreateUISectionHeader then
            ns.CreateUISectionHeader(child, text, -y)
            y = y + 28
        else
            local h = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h:SetPoint("TOPLEFT", 4, -y)
            h:SetText(string.upper(text or ""))
            h:SetTextColor(unpack(C.accent))
            y = y + 22
        end
    end

    local function Hint(text)
        local fs = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 4, -y)
        fs:SetPoint("RIGHT", child, "RIGHT", -8, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetTextColor(unpack(C.textMuted))
        fs:SetText(text or "")
        -- Use real wrapped height so long hints don't undersize the scroll child
        -- (fixed +28 left the bottom of Keywords unreachable when text wrapped).
        local h = 28
        if fs.GetStringHeight then
            local sh = fs:GetStringHeight()
            if sh and sh > 0 then h = math.max(28, math.ceil(sh) + 6) end
        end
        y = y + h
    end

    Header(L["SECTION_MATCHING"] or "Matching")

    if ns.CreateUIToggle then
        local enableToggle = ns.CreateUIToggle(child, {
            label = L["KEYWORDS_ENABLE"] or "Enable keyword scanning",
            labelOnRight = true,
            checked = ns.db.settings.keywordScanEnabled and true or false,
            onChange = function(on)
                ns.db.settings.keywordScanEnabled = on and true or false
            end,
        })
        enableToggle:SetPoint("TOPLEFT", 4, -y)
        y = y + 28

        local wwToggle = ns.CreateUIToggle(child, {
            label = L["RECIPE_WHOLE_WORD"] or "Whole-word match for recipe names",
            labelOnRight = true,
            checked = ns.db.settings.recipeWholeWord ~= false,
            onChange = function(on)
                ns.db.settings.recipeWholeWord = on and true or false
            end,
        })
        wwToggle:SetPoint("TOPLEFT", 4, -y)
        y = y + 28
    else
        local enableCheck = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate")
        enableCheck:SetPoint("TOPLEFT", 4, -y)
        enableCheck:SetSize(24, 24)
        enableCheck:SetChecked(ns.db.settings.keywordScanEnabled)
        local enableLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 6, 0)
        enableLabel:SetText(L["KEYWORDS_ENABLE"] or "Enable keyword scanning")
        enableLabel:SetTextColor(unpack(C.text))
        enableCheck:SetScript("OnClick", function(self)
            ns.db.settings.keywordScanEnabled = self:GetChecked() and true or false
        end)
        y = y + 28

        local wholeWordCheck = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate")
        wholeWordCheck:SetPoint("TOPLEFT", 4, -y)
        wholeWordCheck:SetSize(24, 24)
        wholeWordCheck:SetChecked(ns.db.settings.recipeWholeWord ~= false)
        local wwLabel = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        wwLabel:SetPoint("LEFT", wholeWordCheck, "RIGHT", 6, 0)
        wwLabel:SetText(L["RECIPE_WHOLE_WORD"] or "Whole-word match for recipe names")
        wwLabel:SetTextColor(unpack(C.text))
        wholeWordCheck:SetScript("OnClick", function(self)
            ns.db.settings.recipeWholeWord = self:GetChecked() and true or false
        end)
        y = y + 22
    end

    Hint(L["RECIPE_WHOLE_WORD_HINT"] or
        "When on, plain-text recipe names must appear as whole words (fewer false positives). Item-link matches are unchanged.")

    y = y + 8

    Header(L["KEYWORDS_SECTION_TRIGGERS"] or "Triggers")
    Hint((L["KEYWORDS_TRIGGER_HELP"] or "At least one trigger is required.")
        .. "  " .. (L["KEYWORDS_EXAMPLE_PREFIX"] or "Example:") .. " " .. (pack.triggerExamples or ""))

    local trigInput = ns.CreateUIEditBox and ns.CreateUIEditBox(child, {
        height = 26, maxLetters = 40,
    }) or CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    trigInput:SetHeight(26)
    trigInput:SetAutoFocus(false)
    trigInput:SetPoint("TOPLEFT", 4, -y)
    trigInput:SetWidth(280)

    local trigAdd = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 80, height = 26, text = L["KEYWORDS_ADD"] or "Add", variant = "primary",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    trigAdd:SetPoint("LEFT", trigInput, "RIGHT", 8, 0)
    if not ns.CreateUIButton then
        trigAdd:SetSize(80, 26)
        trigAdd:SetText(L["KEYWORDS_ADD"] or "Add")
    end

    local function AddTrigger()
        local text = (trigInput:GetText() or ""):match("^%s*(.-)%s*$") or ""
        if text == "" then return end
        local lower = text:lower()
        for _, existing in ipairs(ns.db.keywords.triggers) do
            if existing:lower() == lower then
                ns.Print(L["KEYWORDS_DUPLICATE"] or "This keyword already exists.")
                return
            end
        end
        table.insert(ns.db.keywords.triggers, text)
        trigInput:SetText("")
        FireKeywordsChanged()
        ns.UI.KeywordsTab.Refresh()
    end
    trigAdd:SetScript("OnClick", AddTrigger)
    trigInput:SetScript("OnEnterPressed", AddTrigger)
    trigInput:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    y = y + 32

    for i, keyword in ipairs(ns.db.keywords.triggers) do
        local row = ns.CreateUIRow and ns.CreateUIRow(child, 26)
            or CreateFrame("Frame", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", -4, -y)
        if row.SetHeight then row:SetHeight(26) end

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", 12, 0)
        text:SetText(keyword)
        text:SetTextColor(unpack(C.text))

        local rm = ns.CreateUIButton and ns.CreateUIButton(row, {
            width = 28, height = 20, text = "x", variant = "danger",
        }) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        rm:SetPoint("RIGHT", -6, 0)
        if not ns.CreateUIButton then rm:SetSize(28, 20); rm:SetText("x") end
        local idx = i
        rm:SetScript("OnClick", function()
            table.remove(ns.db.keywords.triggers, idx)
            FireKeywordsChanged()
            ns.UI.KeywordsTab.Refresh()
        end)
        y = y + 30
    end

    y = y + 10

    Header(L["KEYWORDS_PAIRS_HEADER"] or "Profession + item pairs")
    Hint(L["KEYWORDS_PAIRS_HELP"] or
        "Alert when a message has a trigger and both sides of a row. Left = craft words, Right = item words (comma-separated).")
    Hint((L["KEYWORDS_EXAMPLE_PREFIX"] or "Example:") .. " " .. (pack.pairExample or ""))
    Hint(L["KEYWORDS_LANG_HINT"] or
        "Type words as players write them in trade chat on this realm (see Settings > Trade chat language).")

    local pairsAdd = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 140, height = 26, text = L["KEYWORDS_PAIRS_ADD"] or "Add a pair", variant = "ghost",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    pairsAdd:SetPoint("TOPLEFT", 4, -y)
    if not ns.CreateUIButton then
        pairsAdd:SetSize(140, 26)
        pairsAdd:SetText(L["KEYWORDS_PAIRS_ADD"] or "Add a pair")
    end
    pairsAdd:SetScript("OnClick", function()
        table.insert(ns.db.keywords.pairs, { professions = "", items = "", mode = "and" })
        FireKeywordsChanged()
        ns.UI.KeywordsTab.Refresh()
    end)
    y = y + 32

    -- Column labels aligned with the two 180px inputs (no long text in the label)
    local BOX_W, BOX_GAP, BOX_LEFT = 180, 8, 8
    local colProf = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colProf:SetPoint("TOPLEFT", BOX_LEFT, -y)
    colProf:SetWidth(BOX_W)
    colProf:SetJustifyH("LEFT")
    colProf:SetWordWrap(false)
    colProf:SetTextColor(unpack(C.textMuted))
    colProf:SetText(L["KEYWORDS_PAIR_COL_PROF"] or "Profession words")
    local colItem = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colItem:SetPoint("TOPLEFT", BOX_LEFT + BOX_W + BOX_GAP, -y)
    colItem:SetWidth(BOX_W)
    colItem:SetJustifyH("LEFT")
    colItem:SetWordWrap(false)
    colItem:SetTextColor(unpack(C.textMuted))
    colItem:SetText(L["KEYWORDS_PAIR_COL_ITEM"] or "Item words")
    local colMode = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colMode:SetPoint("TOPLEFT", BOX_LEFT + BOX_W + BOX_GAP + BOX_W + BOX_GAP, -y)
    colMode:SetTextColor(unpack(C.textMuted))
    colMode:SetText((L["KEYWORDS_PAIR_MODE_AND"] or "AND") .. " / " .. (L["KEYWORDS_PAIR_MODE_OR"] or "OR"))
    y = y + 16

    for i, pair in ipairs(ns.db.keywords.pairs) do
        if not pair.mode or (pair.mode ~= "and" and pair.mode ~= "or") then
            pair.mode = "and"
        end
        local row = ns.CreateUIRow and ns.CreateUIRow(child, 32)
            or CreateFrame("Frame", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", -4, -y)
        if row.SetHeight then row:SetHeight(32) end

        local MODE_W = 96
        local profBox = ns.CreateUIEditBox and ns.CreateUIEditBox(row, {
            height = 24, maxLetters = 200,
            placeholder = pack.phProf or "JC, jewelcrafting, jewel",
        }) or CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        profBox:SetSize(BOX_W, 24)
        profBox:SetPoint("LEFT", BOX_LEFT, 0)
        profBox:SetAutoFocus(false)
        profBox:SetText(pair.professions or "")
        if profBox.UpdatePlaceholder then profBox:UpdatePlaceholder() end

        local itemBox = ns.CreateUIEditBox and ns.CreateUIEditBox(row, {
            height = 24, maxLetters = 200,
            placeholder = pack.phItem or "neck, ring, back, cloak",
        }) or CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        itemBox:SetSize(BOX_W, 24)
        itemBox:SetPoint("LEFT", profBox, "RIGHT", BOX_GAP, 0)
        itemBox:SetAutoFocus(false)
        itemBox:SetText(pair.items or "")
        if itemBox.UpdatePlaceholder then itemBox:UpdatePlaceholder() end

        local idx = i
        local function SavePair()
            if ns.db.keywords.pairs[idx] then
                ns.db.keywords.pairs[idx].professions = (profBox:GetText() or ""):match("^%s*(.-)%s*$") or ""
                ns.db.keywords.pairs[idx].items = (itemBox:GetText() or ""):match("^%s*(.-)%s*$") or ""
                FireKeywordsChanged()
            end
        end
        profBox:HookScript("OnEnterPressed", function(self) SavePair(); self:ClearFocus() end)
        profBox:HookScript("OnEditFocusLost", function() SavePair() end)
        itemBox:HookScript("OnEnterPressed", function(self) SavePair(); self:ClearFocus() end)
        itemBox:HookScript("OnEditFocusLost", function() SavePair() end)

        local modeVal = pair.mode or "and"
        local modeCtrl
        if ns.CreateUISegmented then
            modeCtrl = ns.CreateUISegmented(row, {
                width = MODE_W,
                height = 22,
                options = {
                    { value = "and", label = L["KEYWORDS_PAIR_MODE_AND"] or "AND" },
                    { value = "or",  label = L["KEYWORDS_PAIR_MODE_OR"] or "OR" },
                },
                value = modeVal,
                onChange = function(v)
                    if ns.db.keywords.pairs[idx] then
                        ns.db.keywords.pairs[idx].mode = (v == "or") and "or" or "and"
                        FireKeywordsChanged()
                    end
                end,
            })
            modeCtrl:SetPoint("LEFT", itemBox, "RIGHT", BOX_GAP, 0)
        else
            modeCtrl = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            modeCtrl:SetSize(MODE_W, 22)
            modeCtrl:SetPoint("LEFT", itemBox, "RIGHT", BOX_GAP, 0)
            modeCtrl:SetText(string.upper(modeVal))
            modeCtrl:SetScript("OnClick", function(self)
                local pr = ns.db.keywords.pairs[idx]
                if not pr then return end
                pr.mode = (pr.mode == "or") and "and" or "or"
                self:SetText(string.upper(pr.mode))
                FireKeywordsChanged()
            end)
        end
        modeCtrl:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L["KEYWORDS_PAIR_MODE_TIP"] or
                "AND = both sides required. OR = either side is enough.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        modeCtrl:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local rm = ns.CreateUIButton and ns.CreateUIButton(row, {
            width = 28, height = 20, text = "x", variant = "danger",
        }) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        rm:SetPoint("RIGHT", -6, 0)
        if not ns.CreateUIButton then rm:SetSize(28, 20); rm:SetText("x") end
        rm:SetScript("OnClick", function()
            table.remove(ns.db.keywords.pairs, idx)
            FireKeywordsChanged()
            ns.UI.KeywordsTab.Refresh()
        end)
        y = y + 36
    end

    y = y + 10

    Header(L["KEYWORDS_FREEWORDS_HEADER"] or "Free keywords")
    Hint(L["KEYWORDS_FREEWORDS_HELP"] or
        "Simple words that fire an alert with only a trigger (no profession+item pair required).")

    local freeInput = ns.CreateUIEditBox and ns.CreateUIEditBox(child, {
        height = 26, maxLetters = 40,
    }) or CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    freeInput:SetHeight(26)
    freeInput:SetAutoFocus(false)
    freeInput:SetPoint("TOPLEFT", 4, -y)
    freeInput:SetWidth(280)

    local freeAdd = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 80, height = 26, text = L["KEYWORDS_ADD"] or "Add", variant = "primary",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    freeAdd:SetPoint("LEFT", freeInput, "RIGHT", 8, 0)
    if not ns.CreateUIButton then
        freeAdd:SetSize(80, 26)
        freeAdd:SetText(L["KEYWORDS_ADD"] or "Add")
    end

    local function AddFreeword()
        local text = (freeInput:GetText() or ""):match("^%s*(.-)%s*$") or ""
        if text == "" then return end
        local lower = text:lower()
        for _, existing in ipairs(ns.db.keywords.freewords) do
            if existing:lower() == lower then
                ns.Print(L["KEYWORDS_DUPLICATE"] or "This keyword already exists.")
                return
            end
        end
        table.insert(ns.db.keywords.freewords, text)
        freeInput:SetText("")
        FireKeywordsChanged()
        ns.UI.KeywordsTab.Refresh()
    end
    freeAdd:SetScript("OnClick", AddFreeword)
    freeInput:SetScript("OnEnterPressed", AddFreeword)
    freeInput:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    y = y + 32

    for i, word in ipairs(ns.db.keywords.freewords) do
        local row = ns.CreateUIRow and ns.CreateUIRow(child, 26)
            or CreateFrame("Frame", nil, child, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", -4, -y)
        if row.SetHeight then row:SetHeight(26) end

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", 12, 0)
        text:SetText(word)
        text:SetTextColor(unpack(C.text))

        local rm = ns.CreateUIButton and ns.CreateUIButton(row, {
            width = 28, height = 20, text = "x", variant = "danger",
        }) or CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        rm:SetPoint("RIGHT", -6, 0)
        if not ns.CreateUIButton then rm:SetSize(28, 20); rm:SetText("x") end
        local idx = i
        rm:SetScript("OnClick", function()
            table.remove(ns.db.keywords.freewords, idx)
            FireKeywordsChanged()
            ns.UI.KeywordsTab.Refresh()
        end)
        y = y + 30
    end

    y = y + 16

    local resetBtn = ns.CreateUIButton and ns.CreateUIButton(child, {
        width = 180, height = 26, text = L["KEYWORDS_RESET"] or "Reset keywords", variant = "danger",
    }) or CreateFrame("Button", nil, child, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 4, -y)
    if not ns.CreateUIButton then
        resetBtn:SetSize(180, 26)
        resetBtn:SetText(L["KEYWORDS_RESET"] or "Reset keywords")
    end
    resetBtn:SetScript("OnClick", function()
        wipe(ns.db.keywords.pairs)
        wipe(ns.db.keywords.freewords)
        local def = (ns.GetChatLangPack and ns.GetChatLangPack().triggers)
            or { "LF", "WTB", "Need", "LFC", "Seek" }
        ns.db.keywords.triggers = {}
        for _, w in ipairs(def) do table.insert(ns.db.keywords.triggers, w) end
        FireKeywordsChanged()
        ns.UI.KeywordsTab.Refresh()
        ns.Print(L["KEYWORDS_RESET"] or "Keywords reset.")
    end)
    y = y + 48 -- bottom padding so last control isn't flush against the edge

    child:SetHeight(math.max(y, 1))
    if scroll and scroll.UpdateThumb then scroll:UpdateThumb() end
    if scroll and scroll.SyncWidth then scroll:SyncWidth() end
    if scroll and ns.UI.SyncScrollChildWidth then
        ns.UI.SyncScrollChildWidth(scroll, child, y)
    end
end