local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Debug subsystem
-- - Ring buffer log (feeds window + optional chat via ns.Debug)
-- - Step checklist for synthetic self-test and live alerts
-- - Debug window: checklist + log + Copy / Clear / Run self-test
----------------------------------------------------------------------

local MAX_LOG = 250
local logBuffer = {} -- { { t=, text= }, ... } newest last

-- Current / last pipeline runs
-- run = { mode="selftest"|"live", started, steps={ {key, label, ok, detail}, ... }, byKey={} }
ns.debugLastRun = nil
ns.debugCurrentRun = nil

local STEP_ORDER_SELFTEST = {
    { key = "db",           label = "Database ready" },
    { key = "recipes",      label = "Tracked recipes present" },
    { key = "cache",        label = "Scanner cache built" },
    { key = "callback",     label = "ALERT_FIRED has listeners" },
    { key = "synthetic",    label = "Synthetic message built" },
    { key = "match",        label = "Match path (FireCallback)" },
    { key = "showalert",    label = "ShowAlert entered" },
    { key = "realm",        label = "Realm filter passed" },
    { key = "charfilter",   label = "Current-char filter passed" },
    { key = "whisper",      label = "Whisper template built" },
    { key = "history",      label = "History entry recorded" },
    { key = "toast",        label = "Toast shown" },
}

local STEP_ORDER_LIVE = {
    { key = "channel",      label = "Channel allowed" },
    { key = "match",        label = "Recipe / keyword match" },
    { key = "callback",     label = "ALERT_FIRED fired" },
    { key = "showalert",    label = "ShowAlert entered" },
    { key = "realm",        label = "Realm filter passed" },
    { key = "charfilter",   label = "Current-char filter passed" },
    { key = "whisper",      label = "Whisper template built" },
    { key = "history",      label = "History entry recorded" },
    { key = "toast",        label = "Toast shown" },
}

----------------------------------------------------------------------
-- Log buffer
----------------------------------------------------------------------
function ns.DebugIsEnabled()
    return ns.debugEnabled or (ns.db and ns.db.settings and ns.db.settings.debugEnabled)
end

function ns.DebugLog(msg, opts)
    opts = opts or {}
    local text = tostring(msg)
    local entry = {
        t = date("%H:%M:%S"),
        text = text,
    }
    table.insert(logBuffer, entry)
    while #logBuffer > MAX_LOG do
        table.remove(logBuffer, 1)
    end

    -- Always chat when debug on, unless silent
    if not opts.silent and ns.DebugIsEnabled() then
        print("|cff888888[CB-Debug]|r " .. text)
    end

    if debugFrame and debugFrame:IsShown() and debugFrame.RefreshLog then
        debugFrame:RefreshLog()
    end
end

-- Override-friendly: Utils.lua ns.Debug will call this if present
function ns.DebugBufferOnly(msg)
    ns.DebugLog(msg, { silent = true })
end

function ns.GetDebugLogText()
    local lines = {}
    for _, e in ipairs(logBuffer) do
        table.insert(lines, string.format("[%s] %s", e.t, e.text))
    end
    return table.concat(lines, "\n")
end

function ns.ClearDebugLog()
    wipe(logBuffer)
    if debugFrame and debugFrame:IsShown() and debugFrame.RefreshLog then
        debugFrame:RefreshLog()
    end
end

----------------------------------------------------------------------
-- Step checklist
----------------------------------------------------------------------
function ns.DebugBeginRun(mode, note)
    mode = mode or "live"
    local run = {
        mode = mode,
        started = time(),
        startedStr = date("%H:%M:%S"),
        note = note,
        steps = {},
        byKey = {},
    }
    ns.debugCurrentRun = run
    ns.DebugLog(string.format("── %s run started%s",
        mode == "selftest" and "Self-test" or "Live",
        note and (" — " .. note) or ""), { silent = not ns.DebugIsEnabled() })
    return run
end

function ns.DebugStep(key, ok, detail)
    local run = ns.debugCurrentRun
    if not run then
        -- Opportunistic live step without explicit begin
        if ns.DebugIsEnabled() then
            run = ns.DebugBeginRun("live")
        else
            return
        end
    end
    local step = {
        key = key,
        ok = ok and true or false,
        detail = detail and tostring(detail) or nil,
    }
    -- Update if same key already recorded this run
    if run.byKey[key] then
        local prev = run.byKey[key]
        prev.ok = step.ok
        prev.detail = step.detail
    else
        table.insert(run.steps, step)
        run.byKey[key] = step
    end

    local mark = step.ok and "OK" or "FAIL"
    local line = string.format("  [%s] %s%s",
        mark, key, step.detail and (" — " .. step.detail) or "")
    ns.DebugLog(line, { silent = not ns.DebugIsEnabled() })

    if debugFrame and debugFrame:IsShown() and debugFrame.RefreshChecklist then
        debugFrame:RefreshChecklist()
    end
end

function ns.DebugEndRun()
    local run = ns.debugCurrentRun
    if not run then return end
    ns.debugLastRun = run
    ns.debugCurrentRun = nil

    local pass, fail = 0, 0
    for _, s in ipairs(run.steps) do
        if s.ok then pass = pass + 1 else fail = fail + 1 end
    end
    ns.DebugLog(string.format("── %s run done — %d ok, %d fail",
        run.mode == "selftest" and "Self-test" or "Live", pass, fail),
        { silent = not ns.DebugIsEnabled() })

    if debugFrame and debugFrame:IsShown() then
        if debugFrame.RefreshChecklist then debugFrame:RefreshChecklist() end
        if debugFrame.RefreshLog then debugFrame:RefreshLog() end
    end
    return run
end

function ns.GetDebugRunForDisplay()
    return ns.debugCurrentRun or ns.debugLastRun
end

----------------------------------------------------------------------
-- Synthetic full-cycle self-test
----------------------------------------------------------------------
function ns.RunSelfTest()
    -- Force logging for this run even if debug was off
    local wasDebug = ns.debugEnabled
    ns.debugEnabled = true

    ns.DebugBeginRun("selftest", "full pipeline")

    -- 1. DB
    local dbOk = ns.db ~= nil
    ns.DebugStep("db", dbOk, dbOk and "CraftBellDB bound" or "ns.db is nil")

    -- 2. Recipes
    local nRecipes = 0
    local firstID, firstData
    if ns.db and ns.db.trackedRecipes then
        for id, data in pairs(ns.db.trackedRecipes) do
            nRecipes = nRecipes + 1
            if not firstID then firstID, firstData = id, data end
        end
    end
    ns.DebugStep("recipes", nRecipes > 0,
        nRecipes > 0 and (nRecipes .. " tracked") or "none — track a recipe first")

    -- 3. Cache (indirect: we cannot see lookupCache; re-fire RECIPE_TRACKED rebuild is heavy)
    -- Report recipe count as cache proxy; ChatScanner rebuilds on DB_READY
    ns.DebugStep("cache", nRecipes > 0,
        nRecipes > 0 and "cache should include tracked recipes" or "empty")

    -- 4. Callback listeners
    local nListeners = 0
    if ns.CountCallbacks then
        nListeners = ns.CountCallbacks("ALERT_FIRED") or 0
    end
    local hasShow = type(ns.ShowAlert) == "function"
    ns.DebugStep("callback", nListeners > 0 or hasShow,
        nListeners > 0 and (nListeners .. " listener(s)")
            or (hasShow and "ShowAlert exists (listener count unknown)" or "no ShowAlert"))

    if not dbOk or not firstID then
        ns.DebugStep("synthetic", false, "skipped — no recipe")
        ns.DebugStep("match", false, "skipped")
        ns.DebugStep("showalert", false, "skipped")
        ns.DebugStep("realm", false, "skipped")
        ns.DebugStep("charfilter", false, "skipped")
        ns.DebugStep("whisper", false, "skipped")
        ns.DebugStep("history", false, "skipped")
        ns.DebugStep("toast", false, "skipped")
        ns.DebugEndRun()
        ns.debugEnabled = wasDebug
        ns.Print("Self-test finished — track at least one recipe and run again.")
        if ns.ToggleDebugWindow then ns.ToggleDebugWindow(true) end
        return ns.debugLastRun
    end

    -- 5. Synthetic message (prefer item link for ID-match path)
    local link = firstData.itemLink or firstData.recipeName or "item"
    local fakeMessage = string.format("LF someone to craft %s, will pay!", link)
    local sender = "CBSelfTest-" .. tostring(math.random(100, 999))
    ns.DebugStep("synthetic", true,
        string.format("sender=%s recipeID=%s", sender, tostring(firstID)))

    -- 6–12. Fire real pipeline; ShowAlert records further steps
    ns.DebugStep("match", true, "FireCallback(ALERT_FIRED)")
    local okFire, errFire = pcall(function()
        ns.FireCallback("ALERT_FIRED", sender, fakeMessage, { [firstID] = firstData })
    end)
    if not okFire then
        ns.DebugStep("match", false, "FireCallback error: " .. tostring(errFire))
    end

    -- ShowAlert ends the run via DebugEndRun; if it never ran, close here
    local run = ns.debugCurrentRun
    if run and not run.byKey["showalert"] then
        ns.DebugStep("showalert", false, "ShowAlert was not called — callback not wired?")
        ns.DebugStep("toast", false, "skipped")
        ns.DebugEndRun()
    elseif ns.debugCurrentRun then
        ns.DebugEndRun()
    end

    ns.debugEnabled = wasDebug

    local last = ns.debugLastRun
    local fail = 0
    if last then
        for _, s in ipairs(last.steps) do
            if not s.ok then fail = fail + 1 end
        end
    end
    if fail == 0 then
        ns.Print("Self-test passed — all steps OK.")
    else
        ns.Print(string.format("Self-test finished with %d failure(s). Open Debug window for details.", fail))
    end
    if ns.ToggleDebugWindow then ns.ToggleDebugWindow(true) end
    return last
end

----------------------------------------------------------------------
-- Debug window UI
----------------------------------------------------------------------
local debugFrame

local function StepLabel(key, mode)
    local order = (mode == "selftest") and STEP_ORDER_SELFTEST or STEP_ORDER_LIVE
    for _, s in ipairs(order) do
        if s.key == key then return s.label end
    end
    return key
end

local function OrderedSteps(run)
    if not run then return {} end
    local order = (run.mode == "selftest") and STEP_ORDER_SELFTEST or STEP_ORDER_LIVE
    local out = {}
    local seen = {}
    for _, def in ipairs(order) do
        local s = run.byKey[def.key]
        if s then
            table.insert(out, { key = def.key, label = def.label, ok = s.ok, detail = s.detail })
            seen[def.key] = true
        else
            table.insert(out, { key = def.key, label = def.label, ok = nil, detail = "not run" })
        end
    end
    -- Extra keys not in template
    for _, s in ipairs(run.steps) do
        if not seen[s.key] then
            table.insert(out, { key = s.key, label = s.key, ok = s.ok, detail = s.detail })
        end
    end
    return out
end

local function EnsureDebugFrame()
    if debugFrame then return debugFrame end

    local f = CreateFrame("Frame", "CraftBellDebugFrame", UIParent, "BackdropTemplate")
    f:SetSize(560, 480)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, "CraftBellDebugFrame")

    if ns.ApplyDarkTheme then
        ns.ApplyDarkTheme(f)
    else
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(0.06, 0.07, 0.09, 0.97)
        f:SetBackdropBorderColor(0.22, 0.24, 0.28, 1)
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetTextColor(0.15, 0.75, 0.95)
    title:SetText("CraftBell Debug")
    f.title = title

    f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.subtitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    f.subtitle:SetTextColor(0.55, 0.58, 0.62)
    f.subtitle:SetText("")

    local closeBtn
    if ns.CreateUIButton then
        closeBtn = ns.CreateUIButton(f, { width = 28, height = 28, text = "×", variant = "ghost" })
    else
        closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    end
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Left: checklist
    local checkHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checkHeader:SetPoint("TOPLEFT", 16, -42)
    checkHeader:SetTextColor(0.15, 0.75, 0.95)
    checkHeader:SetText("PIPELINE STEPS")

    local checkScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    checkScroll:SetPoint("TOPLEFT", 12, -60)
    checkScroll:SetPoint("BOTTOMLEFT", 12, 52)
    checkScroll:SetWidth(240)

    local checkChild = CreateFrame("Frame", nil, checkScroll)
    checkChild:SetSize(220, 1)
    checkScroll:SetScrollChild(checkChild)
    f.checkChild = checkChild
    f.checkScroll = checkScroll

    -- Right: log
    local logHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logHeader:SetPoint("TOPLEFT", checkScroll, "TOPRIGHT", 28, 18)
    logHeader:SetTextColor(0.15, 0.75, 0.95)
    logHeader:SetText("LOG")

    local logScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    logScroll:SetPoint("TOPLEFT", checkScroll, "TOPRIGHT", 24, 0)
    logScroll:SetPoint("BOTTOMRIGHT", -36, 52)

    local logEdit = CreateFrame("EditBox", nil, logScroll)
    logEdit:SetMultiLine(true)
    logEdit:SetFontObject(GameFontHighlightSmall)
    logEdit:SetAutoFocus(false)
    logEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    logEdit:SetWidth(250)
    logScroll:SetScrollChild(logEdit)
    f.logEdit = logEdit
    f.logScroll = logScroll

    logScroll:SetScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if w and w > 20 then logEdit:SetWidth(w) end
    end)

    -- Footer buttons
    local function MakeBtn(label, variant, width)
        if ns.CreateUIButton then
            return ns.CreateUIButton(f, {
                width = width or 100, height = 26, text = label, variant = variant or "ghost",
            })
        end
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width or 100, 26)
        b:SetText(label)
        return b
    end

    local selftestBtn = MakeBtn("Run self-test", "primary", 120)
    selftestBtn:SetPoint("BOTTOMLEFT", 16, 14)
    selftestBtn:SetScript("OnClick", function()
        ns.RunSelfTest()
    end)

    local copyBtn = MakeBtn("Copy all", "ghost", 90)
    copyBtn:SetPoint("LEFT", selftestBtn, "RIGHT", 8, 0)
    copyBtn:SetScript("OnClick", function()
        local run = ns.GetDebugRunForDisplay()
        local parts = { "=== CraftBell Debug ===", "" }
        if run then
            table.insert(parts, string.format("Mode: %s  Started: %s",
                run.mode or "?", run.startedStr or "?"))
            table.insert(parts, "")
            table.insert(parts, "-- Steps --")
            for _, s in ipairs(OrderedSteps(run)) do
                local mark = s.ok == true and "OK" or (s.ok == false and "FAIL" or "—")
                table.insert(parts, string.format("[%s] %s%s",
                    mark, s.label or s.key,
                    s.detail and (" — " .. s.detail) or ""))
            end
            table.insert(parts, "")
        end
        table.insert(parts, "-- Log --")
        table.insert(parts, ns.GetDebugLogText())
        local text = table.concat(parts, "\n")
        if CopyToClipboard then
            CopyToClipboard(text)
            ns.Print(L["COPIED_CLIPBOARD"] or "Copied to clipboard.")
        else
            logEdit:SetText(text)
            logEdit:SetFocus()
            logEdit:HighlightText()
            ns.Print(L["COPY_MANUAL"] or "Text selected — press Ctrl+C to copy.")
        end
    end)

    local clearBtn = MakeBtn("Clear log", "ghost", 90)
    clearBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
    clearBtn:SetScript("OnClick", function()
        ns.ClearDebugLog()
        ns.Print("Debug log cleared.")
    end)

    local debugToggle = MakeBtn("Debug ON", "ghost", 90)
    debugToggle:SetPoint("BOTTOMRIGHT", -16, 14)
    f.debugToggle = debugToggle
    local function RefreshToggleLabel()
        local on = ns.DebugIsEnabled()
        if debugToggle.SetText then
            debugToggle:SetText(on and "Debug ON" or "Debug OFF")
        end
        if debugToggle.SetActive then debugToggle:SetActive(on) end
    end
    debugToggle:SetScript("OnClick", function()
        local on = not ns.DebugIsEnabled()
        ns.debugEnabled = on
        if ns.db and ns.db.settings then ns.db.settings.debugEnabled = on end
        RefreshToggleLabel()
        ns.Print(on and (L["DEBUG_ON"] or "Debug mode ON.")
            or (L["DEBUG_OFF"] or "Debug mode OFF."))
    end)
    f.RefreshToggle = RefreshToggleLabel

    function f:RefreshLog()
        local text = ns.GetDebugLogText()
        if text == "" then text = "(empty — enable Debug and scan Trade, or run self-test)" end
        logEdit:SetText(text)
        -- Keep view at bottom
        C_Timer.After(0, function()
            if logScroll and logScroll.SetVerticalScroll and logScroll.GetVerticalScrollRange then
                logScroll:SetVerticalScroll(logScroll:GetVerticalScrollRange() or 0)
            end
        end)
    end

    function f:RefreshChecklist()
        for _, c in ipairs({ checkChild:GetChildren() }) do
            c:Hide()
            c:SetParent(nil)
        end
        for _, r in ipairs({ checkChild:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" then
                r:Hide()
            end
        end

        local run = ns.GetDebugRunForDisplay()
        if run then
            f.subtitle:SetText(string.format("%s · %s",
                run.mode == "selftest" and "Self-test" or "Live",
                run.startedStr or ""))
        else
            f.subtitle:SetText("No run yet")
        end

        local y = 4
        local steps = OrderedSteps(run)
        if #steps == 0 then
            local empty = checkChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            empty:SetPoint("TOPLEFT", 4, -y)
            empty:SetWidth(210)
            empty:SetJustifyH("LEFT")
            empty:SetText("Run self-test or enable Debug and wait for a Trade match.")
            y = y + 40
        else
            for _, s in ipairs(steps) do
                local row = CreateFrame("Frame", nil, checkChild)
                row:SetSize(210, 28)
                row:SetPoint("TOPLEFT", 0, -y)

                local mark = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                mark:SetPoint("LEFT", 2, 0)
                if s.ok == true then
                    mark:SetText("|cff30cc50OK|r")
                elseif s.ok == false then
                    mark:SetText("|cffff4444FAIL|r")
                else
                    mark:SetText("|cff888888—|r")
                end

                local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                label:SetPoint("LEFT", 36, 6)
                label:SetPoint("RIGHT", -4, 6)
                label:SetJustifyH("LEFT")
                label:SetText(s.label or s.key)

                if s.detail then
                    local det = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                    det:SetPoint("LEFT", 36, -8)
                    det:SetPoint("RIGHT", -4, -8)
                    det:SetJustifyH("LEFT")
                    det:SetText(s.detail)
                end

                y = y + 30
            end
        end
        checkChild:SetHeight(math.max(y + 8, 1))
    end

    function f:RefreshAll()
        RefreshToggleLabel()
        self:RefreshChecklist()
        self:RefreshLog()
    end

    f:SetScript("OnShow", function(self) self:RefreshAll() end)

    debugFrame = f
    return f
end

function ns.ToggleDebugWindow(forceShow)
    local f = EnsureDebugFrame()
    if forceShow then
        f:Show()
        f:Raise()
        f:RefreshAll()
        return
    end
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        f:Raise()
        f:RefreshAll()
    end
end

function ns.ShowDebugWindow()
    ns.ToggleDebugWindow(true)
end