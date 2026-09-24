local addonName, ns = ...

----------------------------------------------------------------------
-- CraftBell premium UI kit
-- Flat dark surfaces, thin borders, cyan accent — no stock Blizzard
-- button art.
----------------------------------------------------------------------

ns.UI = ns.UI or {}

-- Palette (accent overridden by color scheme)
ns.UI.colors = {
    bg          = { 0.06, 0.07, 0.09, 0.97 },   -- main window
    bgRaised    = { 0.10, 0.11, 0.14, 1 },      -- cards / rows
    bgHover     = { 0.14, 0.16, 0.20, 1 },
    bgInput     = { 0.04, 0.05, 0.07, 1 },
    border      = { 0.22, 0.24, 0.28, 1 },
    borderSoft  = { 0.18, 0.20, 0.24, 0.9 },
    accent      = { 0.15, 0.75, 0.95, 1 },       -- cyan default
    accentDim   = { 0.10, 0.45, 0.60, 1 },
    accentGlow  = { 0.15, 0.75, 0.95, 0.25 },
    text        = { 0.92, 0.93, 0.95, 1 },
    textMuted   = { 0.55, 0.58, 0.62, 1 },
    textDim     = { 0.40, 0.42, 0.46, 1 },
    danger      = { 0.85, 0.30, 0.32, 1 },
    success     = { 0.30, 0.80, 0.50, 1 },
    warning     = { 0.95, 0.70, 0.25, 1 },
}

-- Convenience alias used by tabs (same table reference)
ns.UI.C = ns.UI.colors

-- Legacy aliases (older code)
ns.UI.bgColor = ns.UI.colors.bg
ns.UI.borderColor = ns.UI.colors.border
ns.UI.accentColor = ns.UI.colors.accent
ns.UI.headerBgColor = ns.UI.colors.bgRaised
ns.UI.rowAltColor = { 1, 1, 1, 0.03 }

----------------------------------------------------------------------
-- Appearance: window size, accent theme, background theme, font
----------------------------------------------------------------------
ns.UI.WINDOW_SIZES = {
    compact = { w = 480, h = 440 },
    normal  = { w = 580, h = 520 },
    large   = { w = 720, h = 620 },
    xl      = { w = 860, h = 700 },
}

-- Accent-only themes (buttons, toggles, segmented pills, tabs)
ns.UI.COLOR_SCHEMES = {
    cyan = {
        accent     = { 0.15, 0.75, 0.95, 1 },
        accentDim  = { 0.10, 0.45, 0.60, 1 },
        accentGlow = { 0.15, 0.75, 0.95, 0.25 },
    },
    violet = {
        accent     = { 0.62, 0.42, 0.95, 1 },
        accentDim  = { 0.40, 0.28, 0.65, 1 },
        accentGlow = { 0.62, 0.42, 0.95, 0.25 },
    },
    emerald = {
        accent     = { 0.20, 0.82, 0.55, 1 },
        accentDim  = { 0.12, 0.50, 0.35, 1 },
        accentGlow = { 0.20, 0.82, 0.55, 0.25 },
    },
    amber = {
        accent     = { 0.95, 0.72, 0.25, 1 },
        accentDim  = { 0.65, 0.48, 0.15, 1 },
        accentGlow = { 0.95, 0.72, 0.25, 0.25 },
    },
    rose = {
        accent     = { 0.95, 0.40, 0.55, 1 },
        accentDim  = { 0.60, 0.25, 0.35, 1 },
        accentGlow = { 0.95, 0.40, 0.55, 0.25 },
    },
}

-- Background surfaces (main window, cards, inputs, borders)
ns.UI.BG_SCHEMES = {
    slate = { -- default cool dark
        bg         = { 0.06, 0.07, 0.09, 0.97 },
        bgRaised   = { 0.10, 0.11, 0.14, 1 },
        bgHover    = { 0.14, 0.16, 0.20, 1 },
        bgInput    = { 0.04, 0.05, 0.07, 1 },
        border     = { 0.22, 0.24, 0.28, 1 },
        borderSoft = { 0.18, 0.20, 0.24, 0.9 },
    },
    charcoal = { -- deeper black
        bg         = { 0.04, 0.04, 0.05, 0.98 },
        bgRaised   = { 0.08, 0.08, 0.10, 1 },
        bgHover    = { 0.12, 0.12, 0.14, 1 },
        bgInput    = { 0.03, 0.03, 0.04, 1 },
        border     = { 0.18, 0.18, 0.20, 1 },
        borderSoft = { 0.14, 0.14, 0.16, 0.9 },
    },
    midnight = { -- blue-black
        bg         = { 0.05, 0.07, 0.12, 0.97 },
        bgRaised   = { 0.08, 0.11, 0.18, 1 },
        bgHover    = { 0.12, 0.16, 0.24, 1 },
        bgInput    = { 0.03, 0.05, 0.09, 1 },
        border     = { 0.18, 0.24, 0.34, 1 },
        borderSoft = { 0.14, 0.18, 0.28, 0.9 },
    },
    graphite = { -- neutral gray
        bg         = { 0.09, 0.09, 0.10, 0.97 },
        bgRaised   = { 0.13, 0.13, 0.14, 1 },
        bgHover    = { 0.18, 0.18, 0.19, 1 },
        bgInput    = { 0.06, 0.06, 0.07, 1 },
        border     = { 0.28, 0.28, 0.30, 1 },
        borderSoft = { 0.22, 0.22, 0.24, 0.9 },
    },
    warm = { -- slight brown / sepia dark
        bg         = { 0.08, 0.07, 0.06, 0.97 },
        bgRaised   = { 0.12, 0.10, 0.09, 1 },
        bgHover    = { 0.17, 0.14, 0.12, 1 },
        bgInput    = { 0.05, 0.04, 0.04, 1 },
        border     = { 0.28, 0.24, 0.20, 1 },
        borderSoft = { 0.22, 0.18, 0.16, 0.9 },
    },
}

ns.UI.FONTS = {
    default  = nil, -- system default
    friz     = "Fonts\\FRIZQT__.TTF",
    arialn   = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF",
    skurri   = "Fonts\\skurri.TTF",
}

-- Widgets that recolor themselves when the theme changes
ns.UI._themedWidgets = ns.UI._themedWidgets or {}

function ns.UI.RegisterThemed(widget, refreshFn)
    if not widget then return end
    widget._craftBellRefreshTheme = refreshFn
    -- Avoid double-register
    for _, w in ipairs(ns.UI._themedWidgets) do
        if w == widget then return end
    end
    table.insert(ns.UI._themedWidgets, widget)
end

function ns.UI.RefreshAllThemed()
    local list = ns.UI._themedWidgets
    for i = #list, 1, -1 do
        local w = list[i]
        if not w or (w.IsForbidden and w:IsForbidden()) then
            table.remove(list, i)
        elseif w._craftBellRefreshTheme then
            pcall(w._craftBellRefreshTheme, w)
        else
            table.remove(list, i)
        end
    end
end

local function CopyColorInto(dst, src)
    if not dst or not src then return end
    dst[1], dst[2], dst[3], dst[4] = src[1], src[2], src[3], src[4] or 1
end

function ns.UI.GetFontPath()
    local key = ns.db and ns.db.settings and ns.db.settings.uiFont or "default"
    return ns.UI.FONTS[key]
end

function ns.UI.ApplyColorScheme(schemeKey)
    schemeKey = schemeKey or (ns.db and ns.db.settings and ns.db.settings.colorScheme) or "cyan"
    local scheme = ns.UI.COLOR_SCHEMES[schemeKey] or ns.UI.COLOR_SCHEMES.cyan
    local c = ns.UI.colors
    CopyColorInto(c.accent, scheme.accent)
    CopyColorInto(c.accentDim, scheme.accentDim)
    CopyColorInto(c.accentGlow, scheme.accentGlow)
    ns.UI.accentColor = c.accent
    if ns.db and ns.db.settings then
        ns.db.settings.colorScheme = schemeKey
    end
end

function ns.UI.ApplyBgScheme(bgKey)
    bgKey = bgKey or (ns.db and ns.db.settings and ns.db.settings.bgScheme) or "slate"
    local scheme = ns.UI.BG_SCHEMES[bgKey] or ns.UI.BG_SCHEMES.slate
    local c = ns.UI.colors
    CopyColorInto(c.bg, scheme.bg)
    CopyColorInto(c.bgRaised, scheme.bgRaised)
    CopyColorInto(c.bgHover, scheme.bgHover)
    CopyColorInto(c.bgInput, scheme.bgInput)
    CopyColorInto(c.border, scheme.border)
    CopyColorInto(c.borderSoft, scheme.borderSoft)
    ns.UI.bgColor = c.bg
    ns.UI.borderColor = c.border
    ns.UI.headerBgColor = c.bgRaised
    if ns.db and ns.db.settings then
        ns.db.settings.bgScheme = bgKey
    end
end

function ns.UI.GetWindowSize()
    local key = ns.db and ns.db.settings and ns.db.settings.windowSize or "normal"
    return ns.UI.WINDOW_SIZES[key] or ns.UI.WINDOW_SIZES.normal, key
end

function ns.UI.ApplyAppearance()
    local scheme = ns.db and ns.db.settings and ns.db.settings.colorScheme or "cyan"
    local bg = ns.db and ns.db.settings and ns.db.settings.bgScheme or "slate"
    ns.UI.ApplyColorScheme(scheme)
    ns.UI.ApplyBgScheme(bg)
    ns.UI.RefreshAllThemed()
    if ns.UI.ApplyMainWindowAppearance then
        ns.UI.ApplyMainWindowAppearance()
    end
end

ns.UI.backdrop = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

ns.UI.backdropSoft = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function SetColor(texOrFrame, c, method)
    if not c then return end
    if method == "backdrop" then
        texOrFrame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
    elseif method == "border" then
        texOrFrame:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
    elseif method == "vertex" then
        texOrFrame:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    elseif method == "text" then
        texOrFrame:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
end

function ns.ApplyDarkTheme(frame)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop(ns.UI.backdrop)
    SetColor(frame, ns.UI.colors.bg, "backdrop")
    SetColor(frame, ns.UI.colors.border, "border")
    ns.UI.RegisterThemed(frame, function()
        if frame.SetBackdropColor then
            SetColor(frame, ns.UI.colors.bg, "backdrop")
            SetColor(frame, ns.UI.colors.border, "border")
        end
    end)
end

function ns.ApplyCardTheme(frame)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop(ns.UI.backdropSoft)
    SetColor(frame, ns.UI.colors.bgRaised, "backdrop")
    SetColor(frame, ns.UI.colors.borderSoft, "border")
    ns.UI.RegisterThemed(frame, function()
        if frame.SetBackdropColor then
            SetColor(frame, ns.UI.colors.bgRaised, "backdrop")
            SetColor(frame, ns.UI.colors.borderSoft, "border")
        end
    end)
end

--- Flat custom button (no UIPanelButtonTemplate chrome)
--- variant: "primary" | "ghost" | "danger" | "tab"
function ns.CreateUIButton(parent, opts)
    opts = opts or {}
    local w = opts.width or 80
    local h = opts.height or 26
    local variant = opts.variant or "ghost"
    local label = opts.text or ""

    local btn = CreateFrame("Button", opts.name, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    btn:SetBackdrop(ns.UI.backdropSoft)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(label)
    btn.label = text

    local function Style(state)
        -- state: normal | hover | pushed | disabled
        local bg, border, tc
        local a = ns.UI.colors.accent
        if variant == "primary" then
            if state == "disabled" then
                bg, border, tc = ns.UI.colors.bgRaised, ns.UI.colors.border, ns.UI.colors.textDim
            elseif state == "hover" or state == "pushed" then
                -- Lighter accent for hover
                bg = {
                    math.min(1, a[1] + 0.12),
                    math.min(1, a[2] + 0.12),
                    math.min(1, a[3] + 0.12),
                    1,
                }
                border = bg
                tc = { 0.05, 0.08, 0.10, 1 }
            else
                bg, border, tc = a, a, { 0.05, 0.08, 0.10, 1 }
            end
        elseif variant == "danger" then
            if state == "disabled" then
                bg, border, tc = ns.UI.colors.bgRaised, ns.UI.colors.border, ns.UI.colors.textDim
            elseif state == "hover" then
                bg = { 0.95, 0.35, 0.38, 1 }
                border = bg
                tc = { 1, 1, 1, 1 }
            else
                bg = { 0.55, 0.18, 0.20, 1 }
                border = ns.UI.colors.danger
                tc = { 1, 0.85, 0.85, 1 }
            end
        elseif variant == "tab" then
            if state == "active" then
                bg = ns.UI.colors.bgHover
                border = a
                tc = a
            elseif state == "hover" then
                bg = ns.UI.colors.bgHover
                border = ns.UI.colors.border
                tc = ns.UI.colors.text
            else
                bg = ns.UI.colors.bgRaised
                border = ns.UI.colors.borderSoft
                tc = ns.UI.colors.textMuted
            end
        else -- ghost
            if state == "disabled" then
                bg, border, tc = ns.UI.colors.bgRaised, ns.UI.colors.borderSoft, ns.UI.colors.textDim
            elseif state == "active" then
                bg = {
                    a[1] * 0.25 + ns.UI.colors.bgRaised[1] * 0.75,
                    a[2] * 0.25 + ns.UI.colors.bgRaised[2] * 0.75,
                    a[3] * 0.25 + ns.UI.colors.bgRaised[3] * 0.75,
                    1,
                }
                border = a
                tc = a
            elseif state == "hover" then
                bg, border, tc = ns.UI.colors.bgHover, ns.UI.colors.accentDim, ns.UI.colors.text
            else
                bg, border, tc = ns.UI.colors.bgRaised, ns.UI.colors.border, ns.UI.colors.textMuted
            end
        end
        SetColor(btn, bg, "backdrop")
        SetColor(btn, border, "border")
        SetColor(text, tc, "text")
    end

    btn._style = Style
    btn._variant = variant
    btn._active = false
    Style("normal")
    ns.UI.RegisterThemed(btn, function()
        Style(btn._active and "active" or (btn:IsEnabled() and "normal" or "disabled"))
    end)

    btn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            Style(self._active and "active" or "hover")
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then
            Style(self._active and "active" or "normal")
        else
            Style("disabled")
        end
    end)
    btn:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() and variant == "primary" then Style("pushed") end
    end)
    btn:SetScript("OnMouseUp", function(self)
        if self:IsEnabled() then Style(self._active and "active" or "hover") end
    end)

    local oldEnable = btn.Enable
    local oldDisable = btn.Disable
    function btn:Enable()
        oldEnable(self)
        Style(self._active and "active" or "normal")
    end
    function btn:Disable()
        oldDisable(self)
        Style("disabled")
    end
    function btn:SetActive(active)
        self._active = active and true or false
        Style(self._active and "active" or "normal")
    end
    function btn:SetText(t)
        text:SetText(t)
    end

    return btn
end

--- Soft card row for lists
function ns.CreateUIRow(parent, height)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(height or 44)
    ns.ApplyCardTheme(row)

    -- Left accent bar (shown when multi-owner / highlight)
    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetColorTexture(0.15, 0.75, 0.95, 0)
    row.accentBar = bar

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(ns.UI.colors.bgHover))
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(ns.UI.colors.bgRaised))
    end)

    function row:SetAccent(on)
        if on then
            self.accentBar:SetColorTexture(0.15, 0.75, 0.95, 1)
        else
            self.accentBar:SetColorTexture(0.15, 0.75, 0.95, 0)
        end
    end

    return row
end

--- Styled edit box on dark surface
function ns.CreateUIEditBox(parent, opts)
    opts = opts or {}
    local box = CreateFrame("EditBox", opts.name, parent, "BackdropTemplate")
    box:SetHeight(opts.height or 26)
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlight)
    box:SetTextColor(unpack(ns.UI.colors.text))
    box:SetBackdrop(ns.UI.backdropSoft)
    box:SetBackdropColor(unpack(ns.UI.colors.bgInput))
    box:SetBackdropBorderColor(unpack(ns.UI.colors.border))
    box:SetTextInsets(8, 8, 0, 0)
    if opts.numeric then box:SetNumeric(true) end
    if opts.maxLetters then box:SetMaxLetters(opts.maxLetters) end

    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(unpack(ns.UI.colors.accent))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(ns.UI.colors.border))
    end)
    return box
end

--- Section header with thin accent underline
function ns.CreateUISectionHeader(parent, text, yPos)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 4, yPos)
    header:SetText(string.upper(text or ""))
    header:SetTextColor(unpack(ns.UI.colors.accent))
    header:SetFont(header:GetFont(), 11)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", header, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -4, 0)
    line:SetColorTexture(0.15, 0.75, 0.95, 0.25)

    return header
end


--- Custom dropdown (flat menu, no Blizzard UIDropDownMenu)
--- opts: width, height, placeholder, onSelect(value, label)
--- Methods: SetOptions({ {value=, label=}, ... }), SetValue(value), GetValue(), Close()
function ns.CreateUIDropdown(parent, opts)
    opts = opts or {}
    local width = opts.width or 140
    local height = opts.height or 26
    local onSelect = opts.onSelect

    local btn = ns.CreateUIButton(parent, {
        width = width,
        height = height,
        text = opts.placeholder or "…",
        variant = "ghost",
    })
    btn._value = nil
    btn._options = {}
    btn._menu = nil

    -- Use Blizzard sort-arrow texture (Unicode ▼ often renders as □ / lock)
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    arrow:SetTexCoord(0, 0.9, 0, 0.6)
    arrow:SetVertexColor(0.70, 0.74, 0.80, 1)
    btn._arrow = arrow

    if btn.label then
        btn.label:ClearAllPoints()
        btn.label:SetPoint("LEFT", 10, 0)
        btn.label:SetPoint("RIGHT", btn, "RIGHT", -22, 0)
        btn.label:SetJustifyH("LEFT")
    end

    local function SetArrowOpen(open)
        if not btn._arrow then return end
        -- Flip vertically when open
        if open then
            btn._arrow:SetTexCoord(0, 0.9, 0.6, 0)
        else
            btn._arrow:SetTexCoord(0, 0.9, 0, 0.6)
        end
    end

    local function CloseMenu()
        if btn._menu then btn._menu:Hide() end
        SetArrowOpen(false)
    end

    local function OpenMenu()
        if not btn._menu then
            local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            menu:SetFrameStrata("TOOLTIP")
            menu:SetClampedToScreen(true)
            if ns.ApplyDarkTheme then ns.ApplyDarkTheme(menu) end
            menu:EnableMouse(true)
            menu:SetScript("OnLeave", function(self)
                if not self:IsMouseOver() and not btn:IsMouseOver() then
                    self:Hide()
                end
            end)
            btn._menu = menu
        end

        local menu = btn._menu
        for _, c in ipairs({ menu:GetChildren() }) do
            c:Hide()
            c:SetParent(nil)
        end
        for _, r in ipairs({ menu:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" then
                r:Hide()
            end
        end

        local y = 6
        local maxW = width
        for _, opt in ipairs(btn._options) do
            local isActive = opt.value == btn._value
            local row = ns.CreateUIButton(menu, {
                width = width - 12,
                height = 24,
                text = (isActive and "> " or "  ") .. (opt.label or tostring(opt.value)),
                variant = isActive and "primary" or "ghost",
            })
            row:SetPoint("TOPLEFT", 6, -y)
            row:SetScript("OnClick", function()
                btn._value = opt.value
                if btn.SetText then
                    btn:SetText(opt.label or tostring(opt.value))
                end
                CloseMenu()
                if onSelect then onSelect(opt.value, opt.label) end
            end)
            y = y + 26
            maxW = math.max(maxW, width)
        end

        if y <= 6 then
            local empty = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            empty:SetPoint("TOPLEFT", 10, -10)
            empty:SetText("No options")
            y = 30
        end

        menu:SetSize(maxW, y + 6)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        menu:Show()
        SetArrowOpen(true)
    end

    btn:SetScript("OnClick", function()
        if btn._menu and btn._menu:IsShown() then
            CloseMenu()
        else
            OpenMenu()
        end
    end)

    function btn:SetOptions(options)
        self._options = options or {}
    end

    function btn:SetValue(value, silent)
        self._value = value
        local label = opts.placeholder or "…"
        for _, opt in ipairs(self._options) do
            if opt.value == value then
                label = opt.label
                break
            end
        end
        if self.SetText then self:SetText(label) end
        if not silent and onSelect then
            onSelect(value, label)
        end
    end

    function btn:GetValue()
        return self._value
    end

    function btn:Close()
        CloseMenu()
    end

    ns.UI.RegisterThemed(btn, function()
        if btn._style then
            btn._style(btn._active and "active" or "normal")
        elseif btn.SetActive then
            btn:SetActive(btn._active)
        end
    end)

    return btn
end

----------------------------------------------------------------------
-- Cascading dropdown: primary list with hover flyout children on the right
-- opts: width, height, placeholder, submenuWidth,
--       onSelect(parentValue, childValue, parentLabel, childLabel)
-- options entry: { value=, label=, children = { { value=, label= }, ... } }
-- Clicking the parent row selects parent + nil child ("all" under that parent).
-- Clicking a child selects parent + child.
----------------------------------------------------------------------
function ns.CreateCascadingDropdown(parent, opts)
    opts = opts or {}
    local width = opts.width or 160
    local height = opts.height or 26
    local subWidth = opts.submenuWidth or 180
    local onSelect = opts.onSelect

    local btn = ns.CreateUIButton(parent, {
        width = width,
        height = height,
        text = opts.placeholder or "…",
        variant = "ghost",
    })
    btn._parentValue = nil
    btn._childValue = nil
    btn._options = {}
    btn._menu = nil
    btn._submenu = nil

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    arrow:SetTexCoord(0, 0.9, 0, 0.6)
    arrow:SetVertexColor(0.70, 0.74, 0.80, 1)
    btn._arrow = arrow

    if btn.label then
        btn.label:ClearAllPoints()
        btn.label:SetPoint("LEFT", 10, 0)
        btn.label:SetPoint("RIGHT", btn, "RIGHT", -22, 0)
        btn.label:SetJustifyH("LEFT")
    end

    local function TruncateLabel(text, maxWidth)
        if not text or not maxWidth then return text end
        if not ns._cascadeMeasureFS then
            ns._cascadeMeasureFS = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            ns._cascadeMeasureFS:Hide()
        end
        local fs = ns._cascadeMeasureFS
        fs:SetText(text)
        if (fs:GetStringWidth() or 0) <= maxWidth then
            return text
        end
        -- Prefer keeping the category part visible: "Leatherworking › Competitor's…"
        local ellipsis = "…"
        local s = text
        while #s > 4 do
            s = s:sub(1, #s - 1)
            fs:SetText(s .. ellipsis)
            if (fs:GetStringWidth() or 0) <= maxWidth then
                return s .. ellipsis
            end
        end
        return ellipsis
    end

    local function UpdateLabel()
        local label = opts.placeholder or "…"
        for _, opt in ipairs(btn._options) do
            if opt.value == btn._parentValue then
                if btn._childValue ~= nil and opt.children then
                    for _, ch in ipairs(opt.children) do
                        if ch.value == btn._childValue then
                            label = (opt.label or "?") .. " › " .. (ch.label or "?")
                            break
                        end
                    end
                    if label == (opts.placeholder or "…") then
                        label = opt.label or "?"
                    end
                else
                    label = opt.label or "?"
                end
                break
            end
        end
        -- Fit inside the button (leave room for the arrow)
        local maxW = (btn:GetWidth() or width) - 28
        label = TruncateLabel(label, maxW)
        if btn.SetText then btn:SetText(label) end
    end

    local function HideSubmenu()
        if btn._submenu then btn._submenu:Hide() end
    end

    local function CloseAll()
        HideSubmenu()
        if btn._menu then btn._menu:Hide() end
        if btn._arrow then
            btn._arrow:SetTexCoord(0, 0.9, 0, 0.6)
        end
    end

    local function EnsureMenu()
        if not btn._menu then
            local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            menu:SetFrameStrata("TOOLTIP")
            menu:SetClampedToScreen(true)
            if ns.ApplyDarkTheme then ns.ApplyDarkTheme(menu) end
            menu:EnableMouse(true)
            menu:SetScript("OnLeave", function(self)
                C_Timer.After(0.12, function()
                    if not self:IsShown() then return end
                    local overMenu = self:IsMouseOver()
                    local overSub = btn._submenu and btn._submenu:IsShown() and btn._submenu:IsMouseOver()
                    local overBtn = btn:IsMouseOver()
                    if not overMenu and not overSub and not overBtn then
                        CloseAll()
                    end
                end)
            end)
            btn._menu = menu
        end
        if not btn._submenu then
            local sub = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            sub:SetFrameStrata("TOOLTIP")
            sub:SetFrameLevel((btn._menu:GetFrameLevel() or 100) + 5)
            sub:SetClampedToScreen(true)
            if ns.ApplyDarkTheme then ns.ApplyDarkTheme(sub) end
            sub:EnableMouse(true)
            sub:Hide()
            sub:SetScript("OnLeave", function(self)
                C_Timer.After(0.12, function()
                    if not self:IsShown() then return end
                    local overSub = self:IsMouseOver()
                    local overMenu = btn._menu and btn._menu:IsMouseOver()
                    if not overSub and not overMenu then
                        HideSubmenu()
                    end
                end)
            end)
            btn._submenu = sub
        end
    end

    local function ClearFrameChildren(frame)
        for _, c in ipairs({ frame:GetChildren() }) do
            c:Hide()
            c:SetParent(nil)
        end
        for _, r in ipairs({ frame:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" then
                r:Hide()
            end
        end
    end

    local function ShowSubmenu(anchorRow, parentOpt)
        EnsureMenu()
        local sub = btn._submenu
        ClearFrameChildren(sub)

        local children = parentOpt.children or {}
        local minSubW = math.max(subWidth or 160, 160)
        local maxSubW = 360
        local needed = minSubW
        local allLabel = opts.allChildrenLabel or "All categories"
        if not ns._cascadeMeasureFS then
            ns._cascadeMeasureFS = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            ns._cascadeMeasureFS:Hide()
        end
        local fs = ns._cascadeMeasureFS
        fs:SetText("> " .. allLabel)
        needed = math.max(needed, (fs:GetStringWidth() or 0) + 36)
        for _, ch in ipairs(children) do
            fs:SetText("> " .. (ch.label or tostring(ch.value)))
            needed = math.max(needed, (fs:GetStringWidth() or 0) + 36)
        end
        local thisSubW = math.min(maxSubW, needed)

        local y = 6
        local allRow = ns.CreateUIButton(sub, {
            width = thisSubW - 12,
            height = 24,
            text = (btn._parentValue == parentOpt.value and btn._childValue == nil)
                and ("> " .. allLabel)
                or ("  " .. allLabel),
            variant = (btn._parentValue == parentOpt.value and btn._childValue == nil) and "primary" or "ghost",
        })
        allRow:SetPoint("TOPLEFT", 6, -y)
        allRow:SetScript("OnClick", function()
            btn._parentValue = parentOpt.value
            btn._childValue = nil
            UpdateLabel()
            CloseAll()
            if onSelect then
                onSelect(parentOpt.value, nil, parentOpt.label, nil)
            end
        end)
        y = y + 26

        for _, ch in ipairs(children) do
            local isActive = btn._parentValue == parentOpt.value and btn._childValue == ch.value
            local row = ns.CreateUIButton(sub, {
                width = thisSubW - 12,
                height = 24,
                text = (isActive and "> " or "  ") .. (ch.label or tostring(ch.value)),
                variant = isActive and "primary" or "ghost",
            })
            row:SetPoint("TOPLEFT", 6, -y)
            row:SetScript("OnClick", function()
                btn._parentValue = parentOpt.value
                btn._childValue = ch.value
                UpdateLabel()
                CloseAll()
                if onSelect then
                    onSelect(parentOpt.value, ch.value, parentOpt.label, ch.label)
                end
            end)
            y = y + 26
        end

        if y <= 6 then
            y = 30
        end
        sub:SetSize(thisSubW, y + 6)
        sub:ClearAllPoints()
        sub:SetPoint("TOPLEFT", anchorRow, "TOPRIGHT", 4, 4)
        sub:Show()
    end

    local function OpenMenu()
        EnsureMenu()
        local menu = btn._menu
        ClearFrameChildren(menu)
        HideSubmenu()

        local y = 6
        for _, opt in ipairs(btn._options) do
            local isActive = opt.value == btn._parentValue
            local hasChildren = opt.children and #opt.children > 0
            local label = (isActive and "> " or "  ") .. (opt.label or tostring(opt.value))
            if hasChildren then
                label = label .. "  ›"
            end
            local row = ns.CreateUIButton(menu, {
                width = width - 12,
                height = 24,
                text = label,
                variant = isActive and "primary" or "ghost",
            })
            row:SetPoint("TOPLEFT", 6, -y)
            row:SetScript("OnEnter", function(self)
                if hasChildren then
                    ShowSubmenu(self, opt)
                else
                    HideSubmenu()
                end
            end)
            row:SetScript("OnClick", function()
                -- Parent click = that profession, all categories
                btn._parentValue = opt.value
                btn._childValue = nil
                UpdateLabel()
                CloseAll()
                if onSelect then
                    onSelect(opt.value, nil, opt.label, nil)
                end
            end)
            y = y + 26
        end

        if y <= 6 then
            local empty = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            empty:SetPoint("TOPLEFT", 10, -10)
            empty:SetText("No options")
            y = 30
        end

        menu:SetSize(width, y + 6)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        menu:Show()
        if btn._arrow then
            btn._arrow:SetTexCoord(0, 0.9, 0.6, 0)
        end
    end

    btn:SetScript("OnClick", function()
        if btn._menu and btn._menu:IsShown() then
            CloseAll()
        else
            OpenMenu()
        end
    end)

    function btn:SetOptions(options)
        self._options = options or {}
    end

    function btn:SetValue(parentValue, childValue, silent)
        self._parentValue = parentValue
        self._childValue = childValue
        UpdateLabel()
        if not silent and onSelect then
            local pl, cl
            for _, opt in ipairs(self._options) do
                if opt.value == parentValue then
                    pl = opt.label
                    if childValue ~= nil and opt.children then
                        for _, ch in ipairs(opt.children) do
                            if ch.value == childValue then
                                cl = ch.label
                                break
                            end
                        end
                    end
                    break
                end
            end
            onSelect(parentValue, childValue, pl, cl)
        end
    end

    function btn:GetValue()
        return self._parentValue, self._childValue
    end

    function btn:Close()
        CloseAll()
    end

    return btn
end

----------------------------------------------------------------------
-- Toggle switch (on / off)
-- Looks like a modern iOS/Android switch: track + sliding knob.
--
-- opts: width, height, checked, label, labelOnRight, onChange(checked)
-- Methods: SetChecked(bool, silent), GetChecked(), SetEnabled(bool)
--
-- Example:
--   local t = ns.CreateUIToggle(parent, {
--       checked = true,
--       label = "Orders only",
--       onChange = function(on) ns.db.settings.bulkTrackOrdersOnly = on end,
--   })
----------------------------------------------------------------------
function ns.CreateUIToggle(parent, opts)
    opts = opts or {}
    local trackW = opts.width or 40
    local trackH = opts.height or 20
    local knobPad = 2
    local knobSize = trackH - knobPad * 2
    local checked = opts.checked and true or false
    local onChange = opts.onChange

    local root = CreateFrame("Button", opts.name, parent)
    root:SetHeight(math.max(trackH, 20))
    root:EnableMouse(true)

    local track = CreateFrame("Frame", nil, root, "BackdropTemplate")
    track:SetSize(trackW, trackH)
    track:SetBackdrop(ns.UI.backdropSoft)
    root.track = track

    local knob = track:CreateTexture(nil, "OVERLAY")
    knob:SetSize(knobSize, knobSize)
    knob:SetColorTexture(1, 1, 1, 1)
    root.knob = knob

    local labelFS
    if opts.label then
        labelFS = root:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        labelFS:SetText(opts.label)
        labelFS:SetTextColor(unpack(ns.UI.colors.text))
        root.label = labelFS
        if opts.labelOnRight then
            track:SetPoint("LEFT", root, "LEFT", 0, 0)
            labelFS:SetPoint("LEFT", track, "RIGHT", 8, 0)
            root:SetWidth(trackW + 8 + (labelFS:GetStringWidth() or 80) + 4)
        else
            labelFS:SetPoint("LEFT", root, "LEFT", 0, 0)
            track:SetPoint("LEFT", labelFS, "RIGHT", 8, 0)
            root:SetWidth((labelFS:GetStringWidth() or 80) + 8 + trackW + 4)
        end
    else
        track:SetPoint("LEFT", root, "LEFT", 0, 0)
        root:SetWidth(trackW)
    end

    local function ApplyVisual()
        local a = ns.UI.colors.accent
        local bg = ns.UI.colors.bgRaised
        local border = ns.UI.colors.border
        if checked then
            track:SetBackdropColor(a[1], a[2], a[3], 0.85)
            track:SetBackdropBorderColor(a[1], a[2], a[3], 1)
            knob:SetVertexColor(0.95, 0.97, 1, 1)
            knob:ClearAllPoints()
            knob:SetPoint("RIGHT", track, "RIGHT", -knobPad, 0)
        else
            track:SetBackdropColor(bg[1], bg[2], bg[3], 1)
            track:SetBackdropBorderColor(border[1], border[2], border[3], 1)
            knob:SetVertexColor(0.55, 0.58, 0.62, 1)
            knob:ClearAllPoints()
            knob:SetPoint("LEFT", track, "LEFT", knobPad, 0)
        end
    end

    local function SetChecked(value, silent)
        checked = value and true or false
        ApplyVisual()
        if not silent and onChange then
            onChange(checked)
        end
    end

    root:SetScript("OnClick", function()
        if root._disabled then return end
        SetChecked(not checked, false)
    end)
    root:SetScript("OnEnter", function()
        if root._disabled then return end
        local a = ns.UI.colors.accent
        local hover = ns.UI.colors.bgHover
        if checked then
            track:SetBackdropColor(
                math.min(1, a[1] + 0.08),
                math.min(1, a[2] + 0.08),
                math.min(1, a[3] + 0.08),
                0.95
            )
        else
            track:SetBackdropColor(hover[1], hover[2], hover[3], 1)
        end
    end)
    root:SetScript("OnLeave", function()
        ApplyVisual()
    end)

    function root:SetChecked(v, silent) SetChecked(v, silent) end
    function root:GetChecked() return checked end
    function root:SetEnabled(enabled)
        root._disabled = not enabled
        root:SetAlpha(enabled and 1 or 0.45)
        if labelFS then
            labelFS:SetTextColor(unpack(enabled and ns.UI.colors.text or ns.UI.colors.textDim))
        end
    end
    function root:SetLabel(text)
        if labelFS then
            labelFS:SetText(text or "")
            if opts.labelOnRight then
                root:SetWidth(trackW + 8 + (labelFS:GetStringWidth() or 80) + 4)
            else
                root:SetWidth((labelFS:GetStringWidth() or 80) + 8 + trackW + 4)
            end
        end
    end

    ApplyVisual()
    ns.UI.RegisterThemed(root, ApplyVisual)
    return root
end

----------------------------------------------------------------------
-- Segmented control (option1 | option2 | option3 …)
-- Pill track with a sliding accent highlight behind the active option.
--
-- opts: width (total, optional — auto from labels), height, options,
--       value, onChange(value, label, index)
-- options: { { value=, label= }, ... }  or  { "A", "B", "C" }
-- Methods: SetOptions(list), SetValue(value, silent), GetValue()
--
-- Example:
--   local seg = ns.CreateUISegmented(parent, {
--       options = {
--           { value = "name", label = "Name" },
--           { value = "fee",  label = "Fee" },
--           { value = "owners", label = "Owners" },
--       },
--       value = "name",
--       onChange = function(v) sortMode = v; Refresh() end,
--   })
----------------------------------------------------------------------
function ns.CreateUISegmented(parent, opts)
    opts = opts or {}
    local height = opts.height or 26
    local onChange = opts.onChange
    local options = {}
    local value = opts.value

    local root = CreateFrame("Frame", opts.name, parent, "BackdropTemplate")
    root:SetHeight(height)
    root:SetBackdrop(ns.UI.backdropSoft)
    root:SetBackdropColor(0.06, 0.07, 0.09, 1)
    root:SetBackdropBorderColor(0.22, 0.24, 0.28, 1)
    root:EnableMouse(true)

    -- Sliding accent pill (behind labels)
    local slider = root:CreateTexture(nil, "ARTWORK")
    slider:SetColorTexture(0.15, 0.75, 0.95, 0.90)
    slider:Hide()
    root.slider = slider

    local segments = {} -- { btn, value, label }

    local function NormalizeOptions(list)
        local out = {}
        for i, o in ipairs(list or {}) do
            if type(o) == "string" then
                table.insert(out, { value = o, label = o })
            else
                table.insert(out, {
                    value = o.value ~= nil and o.value or i,
                    label = o.label or tostring(o.value or i),
                })
            end
        end
        return out
    end

    local function Layout()
        for _, seg in ipairs(segments) do
            seg.btn:Hide()
            seg.btn:SetParent(nil)
        end
        wipe(segments)

        options = NormalizeOptions(options)
        local n = #options
        if n == 0 then
            root:SetWidth(opts.width or 80)
            slider:Hide()
            return
        end

        local totalW = opts.width
        if not totalW then
            -- Auto width from labels
            local pad = 28
            totalW = 0
            for _, o in ipairs(options) do
                local fs = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetText(o.label)
                totalW = totalW + (fs:GetStringWidth() or 40) + pad
                fs:Hide()
            end
            totalW = math.max(totalW, n * 56)
        end
        root:SetWidth(totalW)

        local segW = totalW / n
        for i, o in ipairs(options) do
            local btn = CreateFrame("Button", nil, root)
            btn:SetSize(segW, height - 2)
            btn:SetPoint("LEFT", root, "LEFT", (i - 1) * segW, 0)

            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("CENTER")
            fs:SetText(o.label)
            fs:SetTextColor(unpack(ns.UI.colors.textMuted))
            btn.label = fs

            btn:SetScript("OnClick", function()
                root:SetValue(o.value, false)
            end)
            btn:SetScript("OnEnter", function()
                if o.value ~= value then
                    fs:SetTextColor(unpack(ns.UI.colors.text))
                end
            end)
            btn:SetScript("OnLeave", function()
                if o.value == value then
                    fs:SetTextColor(0.05, 0.08, 0.10, 1)
                else
                    fs:SetTextColor(unpack(ns.UI.colors.textMuted))
                end
            end)

            table.insert(segments, { btn = btn, value = o.value, label = o.label, index = i })
        end

        root:SetValue(value, true)
    end

    function root:SetOptions(list, silent)
        options = list or {}
        Layout()
        if not silent and onChange and value ~= nil then
            -- keep current if still valid
        end
    end

    function root:SetValue(v, silent)
        value = v
        local active
        for _, seg in ipairs(segments) do
            if seg.value == v then
                active = seg
                seg.btn.label:SetTextColor(0.05, 0.08, 0.10, 1)
            else
                seg.btn.label:SetTextColor(unpack(ns.UI.colors.textMuted))
            end
        end
        if active then
            local segW = root:GetWidth() / math.max(#segments, 1)
            local a = ns.UI.colors.accent
            slider:SetColorTexture(a[1], a[2], a[3], 0.90)
            slider:ClearAllPoints()
            slider:SetSize(segW - 4, height - 6)
            slider:SetPoint("LEFT", root, "LEFT", (active.index - 1) * segW + 2, 0)
            slider:Show()
        else
            slider:Hide()
        end
        if not silent and onChange then
            local label = active and active.label or nil
            local index = active and active.index or nil
            onChange(value, label, index)
        end
    end

    function root:GetValue()
        return value
    end

    options = opts.options or {}
    Layout()
    if value ~= nil then
        root:SetValue(value, true)
    end
    ns.UI.RegisterThemed(root, function()
        -- Restyle track + slider pill
        root:SetBackdropColor(ns.UI.colors.bg[1], ns.UI.colors.bg[2], ns.UI.colors.bg[3], 1)
        root:SetBackdropBorderColor(ns.UI.colors.border[1], ns.UI.colors.border[2], ns.UI.colors.border[3], 1)
        root:SetValue(value, true)
    end)
    return root
end