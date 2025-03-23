std = "lua51"
max_line_length = false
codes = true
exclude_files = {
	"**/Libs",
}
ignore = {
	"111/GetBossID",
	"111/GetInstanceID",
	"111/GetMapArtID",
	"111/GetSectionID",
	"111/SLASH_GETSPELLS1",
	"111/SLASH_TRANSCRIPTOR[123]",
	"11[123]/TranscriptDB",
	"11[123]/TranscriptIgnore",
	"112/SlashCmdList",
	"212/self",
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
	"C_EventUtils",
	"C_GossipInfo",
	"C_Map",
	"C_Scenario",
	"C_ScenarioInfo",
	"C_Spell",
	"C_UIWidgetManager",
	"C_UnitAuras",
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
	"InCombatLockdown",
	"IsEncounterInProgress",
	"IsEncounterLimitingResurrections",
	"IsEncounterSuppressingRelease",
	"IsFalling",
	"IsInRaid",
	"ShowBossFrameWhenUninteractable",
	"UnitAffectingCombat",
	"UnitAura",
	"UnitCanAttack",
	"UnitCastingInfo",
	"UnitChannelInfo",
	"UnitClass",
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
	"UnitNameUnmodified",
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
	"MenuUtil",
	"Enum",
	"GameTooltip",
	"GameTooltip_Hide",
	"UIParent",
}
