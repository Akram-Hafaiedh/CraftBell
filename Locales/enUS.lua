local addonName, ns = ...
if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then return end

ns.L = ns.L or {}
local L = ns.L

-- Recipe tracking
L["RECIPE_TRACKED"] = "Tracking: "
L["RECIPE_REMOVED"] = "Removed: "
L["TOOLTIP_TRACK"] = "Track this recipe"
L["TOOLTIP_UNTRACK"] = "Stop tracking this recipe"
L["UNKNOWN_PROFESSION"] = "Unknown"

-- Import
L["IMPORTED_FROM_CRAFTRADAR"] = "Imported %d tracked recipe(s) from CraftRadar."

-- Alerts / whisper
L["TOAST_FROM"] = "From: "
L["ALERT_FROM"] = "From: "
L["ALERT_RECIPES"] = "Recipes: "
L["ALERT_KEYWORDS"] = "Keywords: "
L["WHISPER"] = "Whisper"
L["MESSAGE_SENT_TO"] = "Message sent to "
L["REALM_MISMATCH_NOTE"] = "Crafter is on %s — may not be whisperable from here."
L["REALM_MISMATCH_BLOCKED"] = "Whisper blocked: crafter is on an incompatible realm."

L["KEYWORDS_WHISPER_BOTH"] = "Hi! I do %s, saw you mention %s — interested?"
L["KEYWORDS_WHISPER_PROF"] = "Hi! I do %s — let me know if you need anything!"
L["KEYWORDS_WHISPER_ITEM"] = "Hi! Saw you mention %s — I might be able to help!"
L["KEYWORDS_WHISPER_FREE"] = "Hi! Saw your message about %s — I might be able to help!"

-- Default templates ({fee} resolves to e.g. "50g", or "" if no fee is set)
L["DEFAULT_TEMPLATE"] = "Hi! I saw you're looking for {item}. I can craft it ({profession}). Fee: {fee}. Let me know!"
L["DEFAULT_CROSS_TEMPLATE"] = "Hi! My crafting alt {characterName} can make {item} ({profession}). Fee: {fee}. Let me know!"

-- Focus Mode
L["FOCUS_ON"] = "Focus Mode: ON — game sound muted except alerts."
L["FOCUS_OFF"] = "Focus Mode: OFF."
L["FOCUS_WARN_NO_SOUND"] = "Focus Mode is on, but alert sounds are disabled in settings."
L["FOCUS_MODE"] = "Focus Mode"
L["CLICK_TO_TOGGLE"] = "Left-click: open settings"
L["FOCUS_RIGHT_CLICK"] = "Right-click: toggle Focus Mode"

-- Main window / misc
L["MAIN_WINDOW_TODO"] = "Settings window isn't built yet — coming in MainWindow.lua. Try /cb test or /cb dump for now."
L["NO_RECIPE_TRACKED"] = "No recipes tracked yet — track one from the profession window first."
L["TEST_FAKE_MESSAGE"] = "LF someone to craft %s, will pay!"
L["ALERT_SIMULATION"] = "Simulating an alert..."
