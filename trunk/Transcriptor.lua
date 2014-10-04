local revision = tonumber(("$Revision$"):sub(12, -3))

local logName = nil
local currentLog = nil
local logStartTime = nil
local logging = nil
local tinsert = table.insert
local format = string.format
local tostringall = tostringall
local type = type
local date = date
local combatLogActive = nil
local wowVersion, buildRevision, _, buildTOC = GetBuildInfo() -- Note that both returns here are strings, not numbers.

local origPrint = print
local function print(msg)
	return origPrint("|cffffff00" .. msg .. "|r")
end

--------------------------------------------------------------------------------
-- Localization
--

local encounterChecker = CreateFrame("Frame")
encounterChecker:Hide() -- Show for encounter debugging
encounterChecker:SetScript("OnUpdate", function(self)
	if not self.combat and IsEncounterInProgress() then
		print("Transcriptor: ++ ENTERING ENCOUNTER ++")
		self.combat = true
	elseif self.combat and not IsEncounterInProgress() then
		print("Transcriptor: -- LEAVING ENCOUNTER --")
		self.combat = nil
	end
end)

local L = {}
L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."
L["You are already logging an encounter."] = "You are already logging an encounter."
L["Beginning Transcript: "] = "Beginning Transcript: "
L["You are not logging an encounter."] = "You are not logging an encounter."
L["Ending Transcript: "] = "Ending Transcript: "
L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."
L["All transcripts cleared."] = "All transcripts cleared."
L["You can't clear your transcripts while logging an encounter."] = "You can't clear your transcripts while logging an encounter."
L["|cff696969Idle|r"] = "|cff696969Idle|r"
L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."
L["|cffFF0000Recording|r"] = "|cffFF0000Recording|r"
L["Transcriptor will not log CLEU."] = "Transcriptor will not log CLEU."
L["Transcriptor will log CLEU."] = "Transcriptor will log CLEU."

do
	local locale = GetLocale()
	if locale == "deDE" then
		L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "Um die besten Logs zu bekommen, solltest du Transcriptor zwischen Wipes oder Bosskills stoppen bzw. starten."
		L["You are already logging an encounter."] = "Du zeichnest bereits einen Begegnung auf."
		L["Beginning Transcript: "] = "Beginne Aufzeichnung: "
		L["You are not logging an encounter."] = "Du zeichnest keine Begegnung auf."
		L["Ending Transcript: "] = "Beende Aufzeichnung: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Aufzeichnungen werden gespeichert nach WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua sobald du reloggst oder das Interface neu lädst."
		L["All transcripts cleared."] = "Alle Aufzeichnungen gelöscht."
		L["You can't clear your transcripts while logging an encounter."] = "Du kannst deine Aufzeichnungen nicht löschen, während du eine Begegnung aufnimmst."
		L["|cff696969Idle|r"] = "|cff696969Leerlauf|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55fKlicken|r, um eine Aufzeichnung zu starten oder zu stoppen. |cffeda55fRechts-Klicken|r, um Events zu konfigurieren. |cffeda55fAlt-Mittel-Klicken|r, um alle Aufzeichnungen zu löschen."
		L["|cffFF0000Recording|r"] = "|cffFF0000Aufzeichnung|r"
		L["Transcriptor will not log CLEU."] = "Transcriptor wird CLEU nicht aufzeichnen."
		L["Transcriptor will log CLEU."] = "Transcriptor wird CLEU aufzeichnen."
	elseif locale == "zhTW" then
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
	elseif locale == "zhCN" then
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
	elseif locale == "koKR" then
		L["Beginning Transcript: "] = "기록 시작됨: "
		L["Ending Transcript: "] = "기록 종료: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "UI 재시작 후에 WoW\\WTF\\Account\\<아이디>\\SavedVariables\\Transcriptor.lua 에 기록이 저장됩니다."
		L["All transcripts cleared."] = "모든 기록 초기화 완료"
		L["You can't clear your transcripts while logging an encounter."] = "전투 기록중엔 기록을 초기화 할 수 없습니다."
		L["|cffFF0000Recording|r: "] = "|cffFF0000기록중|r: "
		L["|cff696969Idle|r"] = "|cff696969무시|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f클릭|r 전투 기록 시작/정지. |cffeda55f우-클릭|r 이벤트 설정. |cffeda55f알트-중앙 클릭|r 기록된 자료 삭제."
		L["|cffFF0000Recording|r"] = "|cffFF0000기록중|r"
	elseif locale == "ruRU" then
		L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "Чтобы получить лучшие записи боя, не забудьте остановить и запустить Transcriptor между вайпом или убийством босса."
		L["You are already logging an encounter."] = "Вы уже записываете бой."
		L["Beginning Transcript: "] = "Начало записи: "
		L["You are not logging an encounter."] = "Вы не записываете бой."
		L["Ending Transcript: "] = "Окончание записи: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Записи боя будут записаны в WoW\\WTF\\Account\\<название>\\SavedVariables\\Transcriptor.lua после того как вы перезайдете или перезагрузите пользовательский интерфейс."
		L["All transcripts cleared."] = "Все записи очищены."
		L["You can't clear your transcripts while logging an encounter."] = "Вы не можите очистить ваши записи пока идет запись боя."
		L["|cff696969Idle|r"] = "|cff696969Ожидание|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55fЛКМ|r - запустить или остановить запись.\n|cffeda55fПКМ|r - настройка событий.\n|cffeda55fAlt-СКМ|r - очистить все сохраненные записи."
		L["|cffFF0000Recording|r"] = "|cffFF0000Запись|r"
		L["Transcriptor will not log CLEU."] = "Transcriptor не будет записывать CLEU."
		L["Transcriptor will log CLEU."] = "Transcriptor будет записывать CLEU."
	end
end

--------------------------------------------------------------------------------
-- Utility
--

function GetMapID(name)
	name = name:lower()
	for i=1,2000 do
		local fetchedName = GetMapNameByID(i)
		if fetchedName then
			local lowerFetchedName = fetchedName:lower()
			if lowerFetchedName:find(name) then
				print(fetchedName..": "..i)
			end
		end
	end
end
function GetBossID(name)
	name = name:lower()
	for i=1,2000 do
		local fetchedName = EJ_GetEncounterInfo(i)
		if fetchedName then
			local lowerFetchedName = fetchedName:lower()
			if lowerFetchedName:find(name) then
				print(fetchedName..": "..i)
			end
		end
	end
end
function GetSectionID(name)
	name = name:lower()
	for i=1,15000 do
		local fetchedName = EJ_GetSectionInfo(i)
		if fetchedName then
			local lowerFetchedName = fetchedName:lower()
			if lowerFetchedName:find(name) then
				print(fetchedName..": "..i)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Events
--

local eventFrame = CreateFrame("Frame")

local sh = {}
function sh.UPDATE_WORLD_STATES()
	local ret = nil
	for i = 1, GetNumWorldStateUI() do
		local m = strjoin("#", tostringall(GetWorldStateUIInfo(i)))
		if m and m:trim() ~= "0#" then
			ret = (ret or "") .. "|" .. m
		end
	end
	return ret
end
sh.WORLD_STATE_UI_TIMER_UPDATE = sh.UPDATE_WORLD_STATES

function sh.COMBAT_LOG_EVENT_UNFILTERED(_, ...)
	if combatLogActive then
		eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		return
	end
	return strjoin("#", tostringall(...))
end
function sh.PLAYER_REGEN_DISABLED() return " ++ > Regen Disabled : Entering combat! ++ > " end
function sh.PLAYER_REGEN_ENABLED() return " -- < Regen Enabled : Leaving combat! -- < " end
function sh.UNIT_SPELLCAST_STOP(unit, ...)
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) then return end
	if not unit:find("pet%d?%d?$") then
		return UnitName(unit) .. " [[" .. strjoin(":", tostringall(unit, ...)) .. "]]"
	end
end
sh.UNIT_SPELLCAST_CHANNEL_STOP = sh.UNIT_SPELLCAST_STOP
sh.UNIT_SPELLCAST_INTERRUPTED = sh.UNIT_SPELLCAST_STOP
sh.UNIT_SPELLCAST_SUCCEEDED = sh.UNIT_SPELLCAST_STOP
function sh.UNIT_SPELLCAST_START(unit, ...)
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) then return end
	local _, _, _, icon, startTime, endTime = UnitCastingInfo(unit)
	local time = ((endTime or 0) - (startTime or 0)) / 1000
	icon = icon and icon:gsub(".*\\([^\\]+)$", "%1") or "no icon"
	if not unit:find("pet%d?%d?$") then
		return UnitName(unit) .. " - " .. icon .. " - " .. time .. "sec [[" .. strjoin(":", tostringall(unit, ...)) .. "]]"
	end
end
function sh.UNIT_SPELLCAST_CHANNEL_START(unit, ...)
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) then return end
	local _, _, _, icon, startTime, endTime = UnitChannelInfo(unit)
	local time = ((endTime or 0) - (startTime or 0)) / 1000
	icon = icon and icon:gsub(".*\\([^\\]+)$", "%1") or "no icon"
	if not unit:find("pet%d?%d?$") then
		return UnitName(unit) .. " - " .. icon .. " - " .. time .. "sec [[" .. strjoin(":", tostringall(unit, ...)) .. "]]"
	end
end

function sh.PLAYER_TARGET_CHANGED()
	if UnitExists("target") and not UnitInRaid("target") and not UnitInParty("target") then
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
			--mobid probably completely redundant and worth removing actually in 6.0 since CID is in the GUID already converted.
			if buildTOC == 60000 then
				local type, _, _, _, _, cid = strsplit("-", guid)
				if type and (type == "Creature" or type == "Vehicle" or type == "Pet") then
					mobid = tonumber(cid)
				else
					mobid = 0
				end
			else
				mobid = tonumber(guid:sub(6, 10), 16)
			end
		end
		return (format("%s %s (%s) - %s # %s # %s", tostring(level), tostring(reaction), tostring(typeclass), tostring(name), tostring(guid), tostring(mobid)))
	end
end

function sh.INSTANCE_ENCOUNTER_ENGAGE_UNIT(...)
	return strjoin("#", tostringall("Fake Args:",
		UnitExists("boss1"), UnitIsVisible("boss1"), UnitName("boss1"), UnitGUID("boss1"), UnitClassification("boss1"), UnitHealth("boss1"),
		UnitExists("boss2"), UnitIsVisible("boss2"), UnitName("boss2"), UnitGUID("boss2"), UnitClassification("boss2"), UnitHealth("boss2"),
		UnitExists("boss3"), UnitIsVisible("boss3"), UnitName("boss3"), UnitGUID("boss3"), UnitClassification("boss3"), UnitHealth("boss3"),
		UnitExists("boss4"), UnitIsVisible("boss4"), UnitName("boss4"), UnitGUID("boss4"), UnitClassification("boss4"), UnitHealth("boss4"),
		UnitExists("boss5"), UnitIsVisible("boss5"), UnitName("boss5"), UnitGUID("boss5"), UnitClassification("boss5"), UnitHealth("boss5"),
		"Real Args:", ...)
	)
end
--in 6.0, IEEU is no longer seems to be used for mid combat join/leave of bosses. UNIT_TARGETABLE_CHANGED is.
function sh.UNIT_TARGETABLE_CHANGED(...)
	return strjoin("#", tostringall("Fake Args:",
		UnitExists("boss1"), UnitIsVisible("boss1"), UnitName("boss1"), UnitGUID("boss1"), UnitClassification("boss1"), UnitHealth("boss1"),
		UnitExists("boss2"), UnitIsVisible("boss2"), UnitName("boss2"), UnitGUID("boss2"), UnitClassification("boss2"), UnitHealth("boss2"),
		UnitExists("boss3"), UnitIsVisible("boss3"), UnitName("boss3"), UnitGUID("boss3"), UnitClassification("boss3"), UnitHealth("boss3"),
		UnitExists("boss4"), UnitIsVisible("boss4"), UnitName("boss4"), UnitGUID("boss4"), UnitClassification("boss4"), UnitHealth("boss4"),
		UnitExists("boss5"), UnitIsVisible("boss5"), UnitName("boss5"), UnitGUID("boss5"), UnitClassification("boss5"), UnitHealth("boss5"),
		"Real Args:", ...)
	)
end
function sh.ENCOUNTER_START(...)
	if encounterChecker:IsShown() then
		print("Transcriptor: ++ ENTERING ENCOUNTER (EVENT) ++")
	end
	--encounter ID, encounter name (localized), difficulty ID, group size
	return strjoin("#", tostringall(...))
end
function sh.ENCOUNTER_END(...)
	if encounterChecker:IsShown() then
		print("Transcriptor: -- LEAVING ENCOUNTER (EVENT) --")
	end
	--encounter ID, encounter name (localized), difficulty ID, group size, success
	return strjoin("#", tostringall(...))
end
local allowedPowerUnits = {boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true}
function sh.UNIT_POWER(unit, typeName)
	if not allowedPowerUnits[unit] then return end
	local typeIndex = UnitPowerType(unit)
	local mainPower = UnitPower(unit)
	local maxPower = UnitPowerMax(unit)
	local alternatePower = UnitPower(unit, ALTERNATE_POWER_INDEX)
	local alternatePowerMax = UnitPowerMax(unit, ALTERNATE_POWER_INDEX)
	return strjoin("#", typeName, typeIndex, mainPower, maxPower, alternatePower, alternatePowerMax)
end

function sh.SCENARIO_UPDATE(newStep)
	--Proving Grounds
	local ret = ""
	if C_Scenario.GetInfo() == "Proving Grounds" then
		local diffID, currWave, maxWave, duration = C_Scenario.GetProvingGroundsInfo()
		ret = "currentMedal:"..diffID.." currWave: "..currWave.." maxWave: "..maxWave.." duration: "..duration
	end

	local ret2 = "#newStep#" .. tostring(newStep)
	ret2 = ret2 .. "#Info#" .. strjoin("#", tostringall(C_Scenario.GetInfo()))
	ret2 = ret2 .. "#StepInfo#" .. strjoin("#", tostringall(C_Scenario.GetStepInfo()))
	if C_Scenario.GetBonusStepInfo then
		ret2 = ret2 .. "#BonusStepInfo#" .. strjoin("#", tostringall(C_Scenario.GetBonusStepInfo()))
	end

	local ret3 = ""
	local _, _, numCriteria = C_Scenario.GetStepInfo()
	for i = 1, numCriteria do
		ret3 = ret3 .. "#CriteriaInfo" .. i .. "#" .. strjoin("#", tostringall(C_Scenario.GetCriteriaInfo(i)))
	end
	
	local ret4 = ""
	if C_Scenario.GetBonusStepInfo then
		local _, _, numBonusCriteria, _ = C_Scenario.GetBonusStepInfo()
		for i = 1, numBonusCriteria do
			ret4 = ret4 .. "#BonusCriteriaInfo" .. i .. "#" .. strjoin("#", tostringall(C_Scenario.GetBonusCriteriaInfo(i)))
		end
	end

	return ret .. ret2 .. ret3 .. ret4
end

function sh.SCENARIO_CRITERIA_UPDATE(criteriaID)
	local ret = "criteriaID#" .. tostring(criteriaID)
	ret = ret .. "#Info#" .. strjoin("#", tostringall(C_Scenario.GetInfo()))
	ret = ret .. "#StepInfo#" .. strjoin("#", tostringall(C_Scenario.GetStepInfo()))
	if C_Scenario.GetBonusStepInfo then
		ret = ret .. "#BonusStepInfo#" .. strjoin("#", tostringall(C_Scenario.GetBonusStepInfo()))
	end

	local ret2 = ""
	local _, _, numCriteria = C_Scenario.GetStepInfo()
	for i = 1, numCriteria do
		ret2 = ret2 .. "#CriteriaInfo" .. i .. "#" .. strjoin("#", tostringall(C_Scenario.GetCriteriaInfo(i)))
	end

	local ret3 = ""
	if C_Scenario.GetBonusStepInfo then
		local _, _, numBonusCriteria, _ = C_Scenario.GetBonusStepInfo()
		for i = 1, numBonusCriteria do
			ret3 = ret3 .. "#BonusCriteriaInfo" .. i .. "#" .. strjoin("#", tostringall(C_Scenario.GetBonusCriteriaInfo(i)))
		end
	end

	return ret .. ret2 .. ret3
end

function sh.ZONE_CHANGED(...)
	return strjoin("#", GetZoneText() or "?", GetRealZoneText() or "?", GetSubZoneText() or "?", ...)
end
sh.ZONE_CHANGED_INDOORS = sh.ZONE_CHANGED
sh.ZONE_CHANGED_NEW_AREA = sh.ZONE_CHANGED

local function eventHandler(self, event, ...)
	if TranscriptDB.ignoredEvents[event] then return end
	local line
	if sh[event] then
		line = sh[event](...)
	else
		line = strjoin("#", tostringall(event, ...))
	end
	if not line then return end
	local t = GetTime() - logStartTime
	local passed = format("%.1f", t)
	local time = date("%H:%M:%S")
	-- We only have CLEU in the total log, it's way too much information to log twice.
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		tinsert(currentLog.total, "<"..passed.." "..time.."> [CLEU] "..line)
		return
	else
		tinsert(currentLog.total, "<"..passed.." "..time.."> ["..event.."] "..line)
	end
	if type(currentLog[event]) ~= "table" then currentLog[event] = {} end
	tinsert(currentLog[event], "<"..passed.." "..time.."> "..line)
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
	"RAID_BOSS_EMOTE",
	"RAID_BOSS_WHISPER",
	"PLAYER_TARGET_CHANGED",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_POWER",
	"UPDATE_WORLD_STATES",
	"WORLD_STATE_UI_TIMER_UPDATE",
	"COMBAT_LOG_EVENT_UNFILTERED",
	"INSTANCE_ENCOUNTER_ENGAGE_UNIT",
	"UNIT_TARGETABLE_CHANGED",
	"ENCOUNTER_START",
	"ENCOUNTER_END",
	"SCENARIO_UPDATE",
	"SCENARIO_CRITERIA_UPDATE",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
}
local bwEvents = {
	"BigWigs_Message",
	"BigWigs_StartBar",
}
local dbmEvents = {
	"DBM_Announce",
	"DBM_SpecWarn",
	"DBM_TimerStart",
	"DBM_TimerStop",
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
		tinsert(menu, {
			text = v,
			tooltipTitle = v,
			tooltipText = format("Disable logging of %s events.", v),
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
	insertMenuItems(bwEvents)
	insertMenuItems(dbmEvents)

	hooksecurefunc("LoggingCombat", function(input)
		-- Hopefully no idiots are passing in nil as meaning false
		if type(input) ~= "boolean" then return end
		if input then
			eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			combatLogActive = true
			print(L["Transcriptor will not log CLEU."])
		else
			combatLogActive = nil
			if logging and not TranscriptDB.ignoredEvents.COMBAT_LOG_EVENT_UNFILTERED then
				eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
				print(L["Transcriptor will log CLEU."])
			end
		end
	end)

	SlashCmdList["TRANSCRIPTOR"] = function(input)
		if type(input) == "string" and input:lower() == "clear" then
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

local function BossModEventHandler(...)
	eventHandler(eventFrame, ...)
end

local logNameFormat = "[%s]@[%s] - %d/%d/%s/%s/%s@%s (r%d) (%s.%s)"
function Transcriptor:StartLog(silent)
	if logging then
		print(L["You are already logging an encounter."])
	else
		ldb.text = L["|cffFF0000Recording|r"]
		ldb.icon = "Interface\\AddOns\\Transcriptor\\icon_on"

		logStartTime = GetTime()
		local _, _, diff = GetInstanceInfo()
		if diff == 1 then
			diff = "5M"
		elseif diff == 2 then
			diff = "HC5M"
		elseif diff == 3 then
			diff = "10M"
		elseif diff == 4 then
			diff = "25M"
		elseif diff == 5 then
			diff = "HC10M"
		elseif diff == 6 then
			diff = "HC25M"
		elseif diff == 7 or diff == 17 then
			diff = "LFR"
		elseif diff == 14 then
			diff = (buildTOC == 60000) and "Normal" or "Flex"
		elseif diff == 15 then
			diff = "Heroic"
		elseif diff == 16 then
			diff = "Mythic"
		else
			diff = tostring(diff)
		end
		SetMapToCurrentZone() -- Update map ID
		logName = format(logNameFormat, date("%Y-%m-%d"), date("%H:%M:%S"), GetCurrentMapAreaID(), select(8, GetInstanceInfo()), GetZoneText() or "?", GetRealZoneText() or "?", GetSubZoneText() or "none", diff, revision or 1, tostring(wowVersion), tostring(buildRevision))

		if type(TranscriptDB[logName]) ~= "table" then TranscriptDB[logName] = {} end
		if type(TranscriptDB.ignoredEvents) ~= "table" then TranscriptDB.ignoredEvents = {} end
		currentLog = TranscriptDB[logName]

		if type(currentLog.total) ~= "table" then currentLog.total = {} end
		--Register Events to be Tracked
		for i, event in next, wowEvents do
			if not TranscriptDB.ignoredEvents[event] then
				eventFrame:RegisterEvent(event)
			end
		end
		if BigWigsLoader then
			for i, event in next, bwEvents do
				if not TranscriptDB.ignoredEvents[event] then
					BigWigsLoader.RegisterMessage(eventFrame, event, BossModEventHandler)
				end
			end
		end
		if DBM then
			for i, event in next, dbmEvents do
				if not TranscriptDB.ignoredEvents[event] then
					DBM:RegisterCallback(event, BossModEventHandler)
				end
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
		if BigWigsLoader then
			BigWigsLoader.SendMessage(eventFrame, "BigWigs_OnPluginDisable", eventFrame)
		end
		if DBM and DBM.UnregisterCallback then
			for i, event in pairs(dbmEvents) do
				DBM:UnregisterCallback(event)
			end
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
		local t2 = {}
		for k,v in pairs(TranscriptDB.ignoredEvents) do
			t2[k] = v
		end
		TranscriptDB = {}
		TranscriptDB.ignoredEvents = t2
		print(L["All transcripts cleared."])
	else
		print(L["You can't clear your transcripts while logging an encounter."])
	end
end

_G.Transcriptor = Transcriptor
