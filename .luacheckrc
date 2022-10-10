std = "lua51"
max_line_length = false
codes = true
exclude_files = {
	"**/libs",
}
ignore = {
	--"111/SLASH_BASICMINIMAP[12]", -- slash handlers
	"111/GetMapArtID",
	"111/GetInstanceID",
	"111/GetBossID",
	"111/GetSectionID",
	"111/SLASH_GETSPELLS1",
	"111/TranscriptDB",
	"111/TranscriptIgnore",
	"111/SLASH_TRANSCRIPTOR[123]",
	"112/SlashCmdList",
	"112/TranscriptIgnore",
	"112/TranscriptDB",
	"113/TranscriptDB",
	"113/TranscriptIgnore",
	"212/self",
}
files["**/Transcriptor_TBC.lua"].ignore = {
	"[1-9]",
}
files["**/Transcriptor_Vanilla.lua"].ignore = {
	"[1-9]",
}
read_globals = {
	-- Lua
	"date",
	"bit",
	"string.join",
	"string.split",
	"tostringall",
	"table.wipe",

	-- Addon
	"BigWigsLoader",
	"DBM",
	"LibStub",

	-- WoW (general API)
	"C_ChatInfo",
	"C_DeathInfo",
	"C_EncounterJournal",
	"C_Map",
	"C_Scenario",
	"C_UIWidgetManager",
	"CombatLogGetCurrentEventInfo",
	"EJ_GetEncounterInfo",
	"GetBuildInfo",
	"GetInstanceInfo",
	"GetLocale",
	"GetNumGroupMembers",
	"GetRealZoneText",
	"GetSpellInfo",
	"GetSubZoneText",
	"GetTime",
	"GetZoneText",
	"IsAltKeyDown",
	"InCombatLockdown",
	"IsEncounterInProgress",
	"IsEncounterLimitingResurrections",
	"IsEncounterSuppressingRelease",
	"IsFalling",
	"IsInRaid",
	"UnitAffectingCombat",
	"UnitAura",
	"UnitCanAttack",
	"UnitCastingInfo",
	"UnitChannelInfo",
	"UnitClassification",
	"UnitCreatureType",
	"UnitExists",
	"UnitGUID",
	"UnitHealth",
	"UnitHealthMax",
	"UnitInParty",
	"UnitInRaid",
	"UnitIsFriend",
	"UnitIsUnit",
	"UnitIsVisible",
	"UnitLevel",
	"UnitName",
	"UnitPercentHealthFromGUID",
	"UnitPosition",
	"UnitPower",
	"UnitPowerMax",
	"UnitPowerType",
	"UnitTokenFromGUID",

	-- WoW (misc)
	"ChatFontNormal",
	"CLOSE",
	"CloseDropDownMenus",
	"CreateFrame",
	"debugprofilestop",
	"EasyMenu",
	"Enum",
	"GameTooltip",
	"GameTooltip_Hide",
	"UIParent",
}
