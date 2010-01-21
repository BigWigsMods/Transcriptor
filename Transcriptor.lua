local revision = tonumber(("$Revision$"):sub(12, -3))

local logName = nil
local currentLog = nil
local logStartTime = nil
local logging = nil
local insert = table.insert
local fmt = string.format

--------------------------------------------------------------------------------
-- Localization
--
local AL = LibStub("AceLocale-3.0")

local L = AL:NewLocale("Transcriptor", "enUS", true)
if L then
	L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = true
	L["You are already logging an encounter."] = true
	L["Beginning Transcript: "] = true
	L["You are not logging an encounter."] = true
	L["Ending Transcript: "] = true
	L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = true
	L["All transcripts cleared."] = true
	L["You can't clear your transcripts while logging an encounter."] = true
	L["|cff696969Idle|r"] = true
	L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = true
	L["|cffFF0000Recording|r"] = true
end
L = AL:NewLocale("Transcriptor", "deDE")
if L then
	L["You are already logging an encounter."] = "Du zeichnest bereits einen Begegnung auf."
	L["Beginning Transcript: "] = "Beginne Aufzeichnung: "
	L["You are not logging an encounter."] = "Du zeichnest keine Begegnung auf."
	L["Ending Transcript: "] = "Beende Aufzeichnung: "
	L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Aufzeichnungen werden gespeichert nach WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua sobald du reloggst oder das Interface neu l\195\164dst."
	L["Added Note: "] = "Notiz hinzugef\195\188gt: "
	L["All transcripts cleared."] = "Alle Aufzeichnungen gel\195\182scht."
	L["You can't clear your transcripts while logging an encounter."] = "Du kannst deine Aufzeichnungen nicht l\195\182schen, w\195\164hrend du eine Begegnung aufnimmst."
	L["|cffFF0000Recording|r: "] = "|cffFF0000Aufzeichnend|r: "
	L["|cff696969Idle|r"] = "|cff696969Leerlauf|r"
	L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55fKlicke|r um eine Aufzeichnung zu starten/stoppen."
	L["|cffFF0000Recording|r"] = "|cffFF0000Aufzeichnend|r"
end
L = AL:NewLocale("Transcriptor", "zhTW")
if L then
	L["You are already logging an encounter."] = "你已經準備記錄戰鬥"
	L["Beginning Transcript: "] = "開始記錄於: "
	L["You are not logging an encounter."] = "你不處於記錄狀態"
	L["Ending Transcript: "] = "結束記錄於: "
	L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "記錄儲存於 WoW\\WTF\\Account\\<名字>\\SavedVariables\\Transcriptor.lua"
	L["You are not logging an encounter."] = "你沒有記錄此次戰鬥"
	L["All transcripts cleared."] = "所有記錄已清除"
	L["You can't clear your transcripts while logging an encounter."] = "正在記錄中，你不能清除。"
	L["|cffFF0000Recording|r: "] = "|cffFF0000記錄中|r: "
	L["|cff696969Idle|r"] = "|cff696969閒置|r"
	L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f點擊|r開始/停止記錄戰鬥"
	L["|cffFF0000Recording|r"] = "|cffFF0000記錄中|r"
end
L = AL:NewLocale("Transcriptor", "zhCN")
if L then
	L["You are already logging an encounter."] = "你已经准备记录战斗"
	L["Beginning Transcript: "] = "开始记录于: "
	L["You are not logging an encounter."] = "你不处于记录状态"
	L["Ending Transcript: "] = "结束记录于："
	L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "记录保存于WoW\\WTF\\Account\\<名字>\\SavedVariables\\Transcriptor.lua中,你可以上传于Cwowaddon.com论坛,提供最新的BOSS数据."
	L["You are not logging an encounter."] = "你没有记录此次战斗"
	L["Added Note: "] = "添加书签于: "
	L["All transcripts cleared."] = "所有记录已清除"
	L["You can't clear your transcripts while logging an encounter."] = "正在记录中,你不能清除."
	L["|cffFF0000Recording|r: "] = "|cffFF0000记录中|r: "
	L["|cff696969Idle|r"] = "|cff696969空闲|r"
	L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f点击|r开始/停止记录战斗."
	L["|cffFF0000Recording|r"] = "|cffFF0000记录中|r"
end
L = AL:NewLocale("Transcriptor", "koKR")
if L then
	L["Beginning Transcript: "] = "기록 시작됨: "
	L["Ending Transcript: "] = "기록 종료: "
	L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "리로드 하기 전까진 WoW\\WTF\\Account\\<아이디>\\SavedVariables\\Transcriptor.lua 에 기록이 저장됩니다."
	L["All transcripts cleared."] = "모든 기록 초기화 완료"
	L["You can't clear your transcripts while logging an encounter."] = "전투 기록중엔 기록을 초기화 할 수 없습니다."
	L["|cffFF0000Recording|r: "] = "|cffFF0000기록중|r: "
	L["|cff696969Idle|r"] = "|cff696969무시|r"
	L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f클릭|r: 전투 기록 시작 / 멈춤."
	L["|cffFF0000Recording|r"] = "|cffFF0000기록중|r"
end

L = AL:GetLocale("Transcriptor")

--------------------------------------------------------------------------------
-- Events
--

-- The builtin strjoin doesn't handle nils ..
local function strjoin(delimiter, ...)
	local ret = nil
	for i = 1, select("#", ...) do
		ret = (ret or "") .. tostring((select(i, ...))) .. ":"
	end
	return ret
end

local sh = {}
function sh.UPDATE_WORLD_STATES()
	local ret = nil
	for i = 1, GetNumWorldStateUI() do
		local m = strjoin(":", GetWorldStateUIInfo(i))
		if m and m:trim() ~= "0:" then
			ret = (ret or "") .. "|" .. m
		end
	end
	return ret
end
sh.WORLD_STATE_UI_TIMER_UPDATE = sh.UPDATE_WORLD_STATES
function sh.COMBAT_LOG_EVENT_UNFILTERED(_, ...) return strjoin(":", ...) end
function sh.PLAYER_REGEN_DISABLED() return " ++ > Regen Disabled : Entering combat! ++ > " end
function sh.PLAYER_REGEN_ENABLED() return " -- < Regen Enabled : Leaving combat! -- < " end
function sh.UNIT_SPELLCAST_STOP(unit) return UnitName(unit) end
sh.UNIT_SPELLCAST_CHANNEL_STOP = sh.UNIT_SPELLCAST_STOP
sh.UNIT_SPELLCAST_INTERRUPTED = sh.UNIT_SPELLCAST_STOP

function sh.PLAYER_TARGET_CHANGED()
	if UnitExists("target") and not UnitInRaid("target") then
		local level = UnitLevel("target") or "nil"
		local reaction = "Hostile"
		if UnitIsFriend("target", "player") then reaction = "Friendly" end
		local classification = UnitClassification("target") or "nil"
		local creatureType = UnitCreatureType("target") or "nil"
		local typeclass
		if classification == "normal" then typeclass = creatureType else typeclass = (classification.." "..creatureType) end
		local name = UnitName("target") or "nil"
		local mobid = "nil"
		local guid = UnitGUID("target")
		if guid then
			mobid = tonumber(guid:sub(-12, -7), 16)
		end
		return (fmt("%s %s (%s) - %s : %s : %s", tostring(level), tostring(reaction), tostring(typeclass), tostring(name), tostring(guid), tostring(mobid)))
	end
end
function sh.UNIT_SPELLCAST_START(unit)
	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	if not spell then return end
	local time = ((endTime - startTime) / 1000)
	return fmt("[%s][%s][%s][%s][%s][%s sec]", UnitName(unit), tostring(spell), tostring(rank), tostring(displayName), tostring(icon), tostring(time))
end
function sh.UNIT_SPELLCAST_CHANNEL_START(unit)
	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	if not spell then return end
	local time = ((endTime - startTime) / 1000)
	return fmt("[%s][%s][%s][%s][%s][%s sec]", UnitName(unit), tostring(spell), tostring(rank), tostring(displayName), tostring(icon), tostring(time))
end
function sh.UNIT_SPELLCAST_SUCCEEDED(unit, ...) return strjoin(":", UnitName(unit), ...) end

local aliases = {
	["COMBAT_LOG_EVENT_UNFILTERED"] = "CLEU",
	["PLAYER_REGEN_DISABLED"] = "REGEN_DISABLED",
	["PLAYER_REGEN_ENABLED"] = "REGEN_ENABLED",
	["CHAT_MSG_MONSTER_EMOTE"] = "MONSTER_EMOTE",
	["CHAT_MSG_MONSTER_SAY"] = "MONSTER_SAY",
	["CHAT_MSG_MONSTER_WHISPER"] = "MONSTER_WHISPER",
	["CHAT_MSG_MONSTER_YELL"] = "MONSTER_YELL",
	["CHAT_MSG_RAID_WARNING"] = "RAID_WARNING",
	["CHAT_MSG_RAID_BOSS_EMOTE"] = "RAID_BOSS_EMOTE",
	["CHAT_MSG_RAID_BOSS_WHISPER"] = "RAID_BOSS_WHISPER",
	["UNIT_SPELLCAST_START"] = "CAST_START",
	["UNIT_SPELLCAST_STOP"] = "CAST_STOP",
	["UNIT_SPELLCAST_SUCCEEDED"] = "CAST_SUCCEEDED",
	["UNIT_SPELLCAST_INTERRUPTED"] = "CAST_INTERRUPTED",
	["UNIT_SPELLCAST_CHANNEL_START"] = "CAST_CHANNEL_START",
	["UNIT_SPELLCAST_CHANNEL_STOP"] = "CAST_CHANNEL_STOP",
	["UNIT_SPELLCAST_INTERRUPTIBLE"] = "CAST_INTERRUPTIBLE",
	["UNIT_SPELLCAST_NOT_INTERRUPTIBLE"] = "CAST_NOT_INTERRUPTIBLE",
	["INSTANCE_ENCOUNTER_ENGAGE_UNIT"] = "ENGAGE",
	["WORLD_STATE_UI_TIMER_UPDATE"] = "WORLD_TIMER",
	["UPDATE_WORLD_STATES"] = "WORLD_STATE",
}

local lineFormat = "<%s> %s"
local totalFormat = "[%s] %s"
local eventFrame = CreateFrame("Frame")
local function eventHandler(self, event, ...)
	if TranscriptDB.ignoredEvents[event] then return end
	local line = nil
	if sh[event] and event:find("^UNIT_SPELLCAST") then
		local unit = ...
		if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) or UnitIsFriend("player", unit) then return end
		line = sh[event](..., "Possible Target<"..(UnitName(unit.."target") or "nil")..">")
	elseif sh[event] then
		line = sh[event](...)
	else
		line = strjoin(":", event, ...)
	end
	if type(line) ~= "string" or line:len() < 5 then return end
	local e = aliases[event] or event
	local t = GetTime() - logStartTime
	insert(currentLog.total, lineFormat:format(fmt("%.1f", t), totalFormat:format(e, line)))
	-- We only have CLEU in the total log, it's way too much information to log twice.
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then return end
	if type(currentLog[e]) ~= "table" then currentLog[e] = {} end
	insert(currentLog[e], lineFormat:format(fmt("%.1f", t), line))
end
eventFrame:SetScript("OnEvent", eventHandler)

local wowEvents = {
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"CHAT_MSG_MONSTER_EMOTE",
	"CHAT_MSG_MONSTER_SAY",
	"CHAT_MSG_MONSTER_WHISPER",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"CHAT_MSG_RAID_BOSS_WHISPER",
	"PLAYER_TARGET_CHANGED",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UPDATE_WORLD_STATES",
	"WORLD_STATE_UI_TIMER_UPDATE",
	"COMBAT_LOG_EVENT_UNFILTERED",
	"INSTANCE_ENCOUNTER_ENGAGE_UNIT",
}
local ace2Events = {
	"BigWigs_Message",
}
local ace3Events = {
	"BigWigs_Message",
}

--------------------------------------------------------------------------------
-- Addon
--

local Transcriptor = {}

local menu = {}
local popupFrame = CreateFrame("Frame", "TranscriptorMenu", eventFrame, "UIDropDownMenuTemplate")
local function openMenu(frame)
	EasyMenu(menu, popupFrame, frame, 20, 4, "MENU")
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Transcriptor", {
	type = "data source",
	text = L["|cff696969Idle|r"],
	icon = "Interface\\AddOns\\Transcriptor\\icon_off",
	OnTooltipShow = function(tt)
		if logging then
			tt:AddLine(logName, 1, 1, 1, 1)
		else
			tt:AddLine(L["|cff696969Idle|r"], 1, 1, 1, 1)
		end
		tt:AddLine(" ")
		tt:AddLine(L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."], 0.2, 1, 0.2, 1)
	end,
	OnClick = function(self, button)
		if button == "LeftButton" then
			if not logging then
				Transcriptor:StartLog()
			else
				Transcriptor:StopLog()
			end
		elseif button == "RightButton" then
			openMenu(self)
		elseif button == "MiddleButton" and IsAltKeyDown() then
			Transcriptor:ClearAll()
		end
	end,
})

local function insertMenuItems(tbl)
	for i, v in next, tbl do
		table.insert(menu, {
			text = v,
			tooltipTitle = v,
			tooltipText = ("Disable logging of %s events."):format(v),
			func = function() TranscriptDB.ignoredEvents[v] = not TranscriptDB.ignoredEvents[v] end,
			checked = function() return TranscriptDB.ignoredEvents[v] end,
		})
	end
end

local init = CreateFrame("Frame")
init:SetScript("OnEvent", function(self, event, addon)
	if addon:lower() ~= "transcriptor" then return end
	TranscriptDB = TranscriptDB or {}
	if not TranscriptDB.ignoredEvents then TranscriptDB.ignoredEvents = {} end

	insertMenuItems(wowEvents)
	insertMenuItems(ace2Events)
	insertMenuItems(ace3Events)

	SlashCmdList["TRANSCRIPTOR"] = function(input)
		if type(input) == "string" and input == "clear" then
			Transcriptor:ClearAll()
		else
			if not logging then
				Transcriptor:StartLog()
			else
				Transcriptor:StopLog()
			end
		end
	end
	SLASH_TRANSCRIPTOR1 = "/transcriptor"
	SLASH_TRANSCRIPTOR2 = "/transcript"
	SLASH_TRANSCRIPTOR3 = "/ts"
end)
init:RegisterEvent("ADDON_LOADED")

--------------------------------------------------------------------------------
-- Logging
--

local ae2 = AceLibrary and AceLibrary:HasInstance("AceEvent-2.0") and AceLibrary("AceEvent-2.0") or nil
local function ace2EventHandler(...)
	eventHandler(eventFrame, ae2.currentEvent, ...)
end
local dummyAddon = {}
if ae2 then ae2:embed(dummyAddon) end

local ae3 = LibStub and LibStub("AceEvent-3.0", true) or nil
local dummyAce3Addon = {}
if ae3 then ae3:Embed(dummyAce3Addon) end
local function ace3EventHandler(...)
	eventHandler(eventFrame, ...)
end


local logNameFormat = "[%s] - %s/%s/%s@%d/%d (r%d)"
function Transcriptor:StartLog(silent)
	if logging then
		print(L["You are already logging an encounter."])
	else
		ldb.text = L["|cffFF0000Recording|r"]
		ldb.icon = "Interface\\AddOns\\Transcriptor\\icon_on"

		logStartTime = GetTime()
		local dD = GetDungeonDifficulty()
		local rD = GetRaidDifficulty()
		logName = logNameFormat:format(date("%H:%M:%S"), GetZoneText(), GetRealZoneText(), GetSubZoneText(), dD, rD, revision or 1)

		if type(TranscriptDB[logName]) ~= "table" then TranscriptDB[logName] = {} end
		if type(TranscriptDB.ignoredEvents) ~= "table" then TranscriptDB.ignoredEvents = {} end
		currentLog = TranscriptDB[logName]

		if type(currentLog.total) ~= "table" then currentLog.total = {} end
		--Register Events to be Tracked
		for i, event in next, wowEvents do
			eventFrame:RegisterEvent(event)
		end
		if dummyAddon.RegisterEvent then
			for i, event in next, ace2Events do
				dummyAddon:RegisterEvent(event, ace2EventHandler)
			end
		end
		if dummyAce3Addon.RegisterMessage then
			for i, event in next, ace3Events do
				dummyAce3Addon:RegisterMessage(event, ace3EventHandler)
			end
		end
		logging = 1

		--Notify Log Start
		if not silent then
			print(L["Beginning Transcript: "]..logName)
			print(L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."])
		end
	end
end

function Transcriptor:Clear(log)
	if logging then
		print(L["You can't clear your transcripts while logging an encounter."])
	elseif TranscriptDB[log] then
		TranscriptDB[log] = nil
	end
end
function Transcriptor:Get(log) return TranscriptDB[log] end
function Transcriptor:GetAll() return TranscriptDB end
function Transcriptor:IsLogging() return logging end
function Transcriptor:StopLog(silent)
	if not logging then
		print(L["You are not logging an encounter."])
	else
		ldb.text = L["|cff696969Idle|r"]
		ldb.icon = "Interface\\AddOns\\Transcriptor\\icon_off"
		--Clear Events
		eventFrame:UnregisterAllEvents()
		if dummyAddon.UnregisterAllEvents then
			dummyAddon:UnregisterAllEvents()
		end
		if dummyAce3Addon.UnregisterAllMessages then
			dummyAce3Addon:UnregisterAllMessages()
		end
		--Notify Stop
		if not silent then
			print(L["Ending Transcript: "]..logName)
			print(L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."])
		end
		--Clear Log Path
		logName = nil
		currentLog = nil
		logging = nil
	end
end

function Transcriptor:ClearAll()
	if not logging then
		TranscriptDB = {}
		TranscriptDB.ignoredEvents = {}
		print(L["All transcripts cleared."])
	else
		print(L["You can't clear your transcripts while logging an encounter."])
	end
end

_G.Transcriptor = Transcriptor

