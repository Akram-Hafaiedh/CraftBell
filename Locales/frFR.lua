local addonName, ns = ...

-- enUS.lua loads first as the fallback base; overlay French strings on top
-- if the client is running in French.
ns.L = ns.L or {}
local L = ns.L

if GetLocale() == "frFR" then
    L["RECIPE_TRACKED"] = "Suivi : "
    L["RECIPE_REMOVED"] = "Retire : "
    L["TOOLTIP_TRACK"] = "Suivre cette recette"
    L["TOOLTIP_UNTRACK"] = "Ne plus suivre cette recette"
    L["UNKNOWN_PROFESSION"] = "Inconnu"

    L["IMPORTED_FROM_CRAFTRADAR"] = "%d recette(s) suivie(s) importee(s) depuis CraftRadar."

    L["TOAST_FROM"] = "De : "
    L["ALERT_FROM"] = "De : "
    L["ALERT_RECIPES"] = "Recettes : "
    L["ALERT_KEYWORDS"] = "Mots-cles : "
    L["WHISPER"] = "Chuchoter"
    L["MESSAGE_SENT_TO"] = "Message envoye a "
    L["REALM_MISMATCH_NOTE"] = "L'artisan est sur %s — chuchotement peut-etre impossible depuis ici."
    L["REALM_MISMATCH_BLOCKED"] = "Chuchotement bloque : royaume incompatible."

    L["KEYWORDS_WHISPER_BOTH"] = "Salut ! Je fais %s, j'ai vu que tu cherchais %s — interesse(e) ?"
    L["KEYWORDS_WHISPER_PROF"] = "Salut ! Je fais %s — dis-moi si tu as besoin de quelque chose !"
    L["KEYWORDS_WHISPER_ITEM"] = "Salut ! J'ai vu ton message sur %s — je peux peut-etre t'aider !"
    L["KEYWORDS_WHISPER_FREE"] = "Salut ! J'ai vu ton message sur %s — je peux peut-etre t'aider !"

    L["DEFAULT_TEMPLATE"] = "Salut ! Je vois que tu cherches {item}. Je peux le fabriquer ({profession}). Tarif : {fee}. Dis-moi !"
    L["DEFAULT_CROSS_TEMPLATE"] = "Salut ! Mon perso {characterName} peut fabriquer {item} ({profession}). Tarif : {fee}. Dis-moi !"

    L["FOCUS_ON"] = "Mode Concentration : ACTIVE — son coupe sauf les alertes."
    L["FOCUS_OFF"] = "Mode Concentration : DESACTIVE."
    L["FOCUS_WARN_NO_SOUND"] = "Le Mode Concentration est actif, mais le son des alertes est desactive."
    L["FOCUS_MODE"] = "Mode Concentration"
    L["CLICK_TO_TOGGLE"] = "Clic gauche : ouvrir les parametres"
    L["FOCUS_RIGHT_CLICK"] = "Clic droit : activer/desactiver le Mode Concentration"

    L["MAIN_WINDOW_TODO"] = "La fenetre de parametres n'est pas encore prete. Essaie /cb test ou /cb dump."
    L["NO_RECIPE_TRACKED"] = "Aucune recette suivie — suis-en une depuis la fenetre de metier d'abord."
    L["TEST_FAKE_MESSAGE"] = "Cherche quelqu'un pour fabriquer %s, je paie !"
    L["ALERT_SIMULATION"] = "Simulation d'une alerte..."
end
