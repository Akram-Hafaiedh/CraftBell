local addonName, ns = ...
local L = ns.L

-- Session only, not persisted.
ns.focusModeActive = false
ns.focusModeSavedCVars = nil
ns.focusSoundCounter = 0

local FOCUS_CVARS = {
    "Sound_EnableSFX",
    "Sound_EnableMusic",
    "Sound_EnableAmbience",
    "Sound_EnableDialog",
    "Sound_EnableErrorSpeech",
    "Sound_MasterVolume",
}

function ns.SetFocusMode(enabled)
    if enabled and not ns.focusModeActive then
        ns.focusModeSavedCVars = {}
        for _, cvar in ipairs(FOCUS_CVARS) do
            ns.focusModeSavedCVars[cvar] = GetCVar(cvar)
        end
        SetCVar("Sound_EnableSFX", 0)
        SetCVar("Sound_EnableMusic", 0)
        SetCVar("Sound_EnableAmbience", 0)
        SetCVar("Sound_EnableDialog", 0)
        SetCVar("Sound_EnableErrorSpeech", 0)
        ns.focusModeActive = true
        if not ns.db or not ns.db.settings.soundEnabled then
            ns.Print(L["FOCUS_WARN_NO_SOUND"] or "Focus Mode is on, but alert sounds are disabled in settings.")
        end
        ns.Print(L["FOCUS_ON"] or "Focus Mode: ON — game sound muted except alerts.")
        ns.FireCallback("FOCUS_MODE_CHANGED", true)
    elseif not enabled and ns.focusModeActive then
        if ns.focusModeSavedCVars then
            for cvar, value in pairs(ns.focusModeSavedCVars) do
                SetCVar(cvar, value)
            end
        end
        ns.focusModeSavedCVars = nil
        ns.focusModeActive = false
        ns.Print(L["FOCUS_OFF"] or "Focus Mode: OFF.")
        ns.FireCallback("FOCUS_MODE_CHANGED", false)
    end
end

function ns.ToggleFocusMode()
    ns.SetFocusMode(not ns.focusModeActive)
end
