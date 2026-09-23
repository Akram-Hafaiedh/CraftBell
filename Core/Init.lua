local addonName, ns = ...
local L = ns.L

----------------------------------------------------------------------
-- Main window stub — replaced once MainWindow.lua exists
----------------------------------------------------------------------
function ns.ToggleMainWindow()
    ns.Print(L["MAIN_WINDOW_TODO"] or "Settings window isn't built yet — coming in MainWindow.lua. Try /cb test or /cb dump for now.")
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "CraftBellEventFrame", UIParent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGOUT" then
        -- CVars persist across sessions — don't log out with sound muted
        if ns.focusModeActive then
            ns.SetFocusMode(false)
        end
    elseif event == "ADDON_LOADED" and arg1 == addonName then
        ns.InitializeDB()
        local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
        ns.Print("v" .. version .. " loaded.")
        ns.FireCallback("DB_READY")
    elseif event == "PLAYER_LOGIN" then
        ns.FireCallback("PLAYER_READY")
    end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
SLASH_CRAFTBELL1 = "/craftbell"
SLASH_CRAFTBELL2 = "/cb"
SlashCmdList["CRAFTBELL"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "test" then
        -- Fire a fake alert through the real pipeline (ChatScanner -> AlertFrame)
        -- using your first tracked recipe, so you can see the toast/whisper
        -- flow without waiting for a real trade chat message.
        if not ns.db or not next(ns.db.trackedRecipes) then
            ns.Print(L["NO_RECIPE_TRACKED"] or "No recipes tracked yet — track one from the profession window first.")
            return
        end
        local firstID, firstData
        for id, data in pairs(ns.db.trackedRecipes) do
            firstID, firstData = id, data
            break
        end
        local fakeMessage = string.format(L["TEST_FAKE_MESSAGE"] or "LF someone to craft %s, will pay!",
            firstData.recipeName or "an item")
        ns.Print(L["ALERT_SIMULATION"] or "Simulating an alert...")
        ns.FireCallback("ALERT_FIRED", "Testbuyer", fakeMessage, { [firstID] = firstData })

    elseif msg == "testcross" then
        -- Same, but the recipe's crafter is on a different realm — lets you
        -- see the realm-mismatch note/block without needing a real alt
        -- on another realm.
        if not ns.db or not next(ns.db.trackedRecipes) then
            ns.Print(L["NO_RECIPE_TRACKED"] or "No recipes tracked yet — track one from the profession window first.")
            return
        end
        local firstID, firstData
        for id, data in pairs(ns.db.trackedRecipes) do
            firstID, firstData = id, data
            break
        end
        local fakeData = CopyTable(firstData)
        fakeData.character = { name = "TestAlt", realm = "SomeOtherRealm", fullName = "TestAlt-SomeOtherRealm" }
        local fakeMessage = string.format(L["TEST_FAKE_MESSAGE"] or "LF someone to craft %s, will pay!",
            firstData.recipeName or "an item")
        ns.Print(L["ALERT_SIMULATION"] or "Simulating an alert (mismatched realm)...")
        ns.FireCallback("ALERT_FIRED", "Testbuyer", fakeMessage, { [firstID] = fakeData })

    elseif msg == "focus" then
        ns.ToggleFocusMode()

    elseif msg == "debug" then
        ns.debugEnabled = not ns.debugEnabled
        ns.Print("Debug mode: " .. (ns.debugEnabled and "ON" or "OFF"))

    elseif msg == "dump" then
        if not ns.db or not next(ns.db.trackedRecipes) then
            ns.Print("No recipes tracked.")
            return
        end
        for id, data in pairs(ns.db.trackedRecipes) do
            ns.Print("ID=" .. id .. "  " .. tostring(data.recipeName)
                .. "  prof=" .. tostring(data.professionName) .. " (id=" .. tostring(data.professionID) .. ")"
                .. "  char=" .. tostring(data.character and data.character.fullName)
                .. "  fee=" .. tostring(ns.GetRecipeFee(data)))
        end

    else
        ns.Print("CraftBell commands:")
        ns.Print("  /cb test — simulate an alert from your first tracked recipe")
        ns.Print("  /cb testcross — simulate the same, but from a different realm")
        ns.Print("  /cb focus — toggle Focus Mode (mutes game sound except alerts)")
        ns.Print("  /cb debug — toggle debug logging")
        ns.Print("  /cb dump — list tracked recipes")
    end
end
