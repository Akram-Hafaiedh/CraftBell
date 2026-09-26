-- luacheck config for the CraftBell WoW addon.
-- Run: luacheck . --config .luacheckrc

std = "lua51"

globals = {
    "CraftBellDB",
    "CraftRadarDB",
    "SLASH_CRAFTBELL1",
    "SLASH_CRAFTBELL2",
    "SlashCmdList",
    "StaticPopupDialogs",
    "CraftBellMainFrame",
    "CraftBellExportFrame",
    "CraftBellImportFrame",
    "CraftBellDebugFrame",
    "CraftBellFeeEdit",
    "CraftBellFeeEditBox",
    "CraftBellAssignMenu",
    "CraftBellMsgTemplate",
    "CraftBellCrossTemplate",
    "CraftBellFeeProfInput",
    "CraftBellFeeAmtInput",
    "debugFrame",
    "feeEditFrame",
}

read_globals = {
    "C_AddOns", "C_TradeSkillUI", "C_SpellBook", "C_Spell", "C_ChatInfo",
    "C_Timer", "C_Item", "C_VoiceChat", "C_EncodingUtil", "Enum",
    "CreateFrame", "UIParent", "Minimap", "ProfessionsFrame", "GameTooltip",
    "UISpecialFrames", "UICheckButtonTemplate", "UIPanelButtonTemplate",
    "UIPanelCloseButton", "InputBoxTemplate", "BackdropTemplate",
    "GameFontNormal", "GameFontNormalLarge", "GameFontNormalSmall",
    "GameFontHighlight", "GameFontHighlightSmall", "GameFontDisable",
    "GameFontDisableSmall",
    "UnitName", "GetRealmName", "GetAutoCompleteRealms", "GetLocale",
    "GetTime", "GetCVar", "SetCVar", "GetProfessions", "GetProfessionInfo",
    "SendChatMessage", "ChatFrame_AddMessageEventFilter", "PlaySound",
    "PlaySoundFile", "CopyToClipboard",
    "GetItemIcon", "GetItemInfo", "GetItemInfoInstant", "GetCoinTextureString",
    "GetCursorPosition",
    "StaticPopup_Show", "StaticPopup_Hide", "YES", "NO", "CANCEL", "OKAY",
    "ACCEPT", "DECLINE",
    "CopyTable", "wipe", "tinsert", "tremove", "date", "time",
    "hooksecurefunc", "loadstring", "setfenv", "strsplit", "strjoin", "strtrim",
    "L",
}

ignore = {
    "211/addonName",
    "212",
    "512",
}

unused_args = false
max_line_length = 160
max_cyclomatic_complexity = false

exclude_files = {
    "Locales",
    ".git",
    ".github",
}