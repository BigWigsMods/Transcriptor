Transcriptor = AceLibrary("AceAddon-2.0"):new("AceDB-2.0", "AceEvent-2.0", "AceConsole-2.0", "AceDebug-2.0", "FuBarPlugin-2.0")
local Transcriptor = Transcriptor

local _G = getfenv(0)
local logName = nil
local currentLog = nil
local logStartTime = nil
local logging = nil
local tableins = table.insert
local tostring = tostring
local fmt = string.format

local L = AceLibrary("AceLocale-2.2"):new("Transcriptor")

-- localization
L:RegisterTranslations("enUS", function() return {
	["Start"] = true,
	["Start transcribing."] = true,
	["Stop"] = true,
	["Stop transcribing."] = true,
	["Insert Note"] = true,
	["Insert a note into the currently running transcript."] = true,
	["Events"] = true,
	["Toggle which events to log data from."] = true,
	["Time format"] = true,
	["Change the format of the log timestamps (epoch is preferred)."] = true,
	["Clear Logs"] = true,
	["Clears all the logged data from the Saved Variables database."] = true,
	["Toggle logging of %s."] = true,
	["You are already logging an encounter."] = true,
	["Skipped Registration: "] = true,
	["Beginning Transcript: "] = true,
	["You are not logging an encounter."] = true,
	["Ending Transcript: "] = true,
	["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = true,
	["You are not logging an encounter."] = true,
	["Added Note: "] = true,
	["All transcripts cleared."] = true,
	["You can't clear your transcripts while logging an encounter."] = true,
	["|cffFF0000Recording|r: "] = true,
	["|cff696969Idle|r"] = true,
	["|cffeda55fClick|r to start or stop transcribing an encounter."] = true,
	["|cffeda55fCtrl-Click|r to add a bookmark note."] = true,
	["|cffFF0000Recording|r"] = true,
	["!! Bookmark !!"] = true,
	["Bookmark added to the current log."] = true,
}end)

L:RegisterTranslations("koKR", function() return {
	["Start"] = "시작",
	["Start transcribing."] = "기록을 시작합니다.",
	["Stop"] = "멈춤",
	["Stop transcribing."] = "기록을 멈춥니다.",
	["Insert Note"] = "메모 삽입",
	["Insert a note into the currently running transcript."] = "현재 기록에 메모를 추가합니다.",
	["Events"] = "이벤트",
	["Toggle which events to log data from."] = "기록할 이벤트를 선택합니다.",
	["Time format"] = "시간표시 형식",
	["Change the format of the log timestamps (epoch is preferred)."] = "기록할 시간표시 형식을 선택합니다. (epoch 방식 지원)",
	["Clear Logs"] = "기록 초기화",
	["Clears all the logged data from the Saved Variables database."] = "기록된 모든 데이터를 초기화 합니다.",
	--["Toggle logging of %s."] = true,
	--["You are already logging an encounter."] = true,
	--["Skipped Registration: "] = true,
	["Beginning Transcript: "] = "기록 시작됨: ",
	--["You are not logging an encounter."] = true,
	["Ending Transcript: "] = "기록 종료: ",
	["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "리로드 하기 전까진 WoW\\WTF\\Account\\<아이디>\\SavedVariables\\Transcriptor.lua 에 기록이 저장됩니다.",
	--["You are not logging an encounter."] = true,
	["Added Note: "] = "메모 삽입: ",
	["All transcripts cleared."] = "모든 기록 초기화 완료",
	["You can't clear your transcripts while logging an encounter."] = "전투 기록중엔 기록을 초기화 할 수 없습니다.",
	["|cffFF0000Recording|r: "] = "|cffFF0000기록중|r: ",
	["|cff696969Idle|r"] = "|cff696969무시|r",
	["|cffeda55fClick|r to start or stop transcribing an encounter."] = "|cffeda55f클릭|r: 전투 기록 시작 / 멈춤.",
	["|cffeda55fCtrl-Click|r to add a bookmark note."] = "|cffeda55fCtrl-클릭|r: 메모 삽입.",
	["|cffFF0000Recording|r"] = "|cffFF0000기록중|r",
	["!! Bookmark !!"] = "!! 메모 !!",
	["Bookmark added to the current log."] = "현재 기록에 메모가 삽입되었습니다.",
}end)

L:RegisterTranslations("zhCN", function() return {
	["Start"] = "开始",
	["Start transcribing."] = "开始记录战斗",
	["Stop"] = "停止",
	["Stop transcribing."] = "停止记录",
	["Insert Note"] = "书签",
	["Insert a note into the currently running transcript."] = "为正在记录战斗文本加上一书签",
	["Events"] = "事件",
	["Toggle which events to log data from."] = "选择要记录数据的事件",
	["Time format"] = "时间格式",
	["Change the format of the log timestamps (epoch is preferred)."] = "改变记录的时间格式",
	["Clear Logs"] = "清除记录",
	["Clears all the logged data from the Saved Variables database."] = "清空所有BOSS战记录",
	["Toggle logging of %s."] = "切换%s的记录",
	["You are already logging an encounter."] = "你已经准备记录战斗",
	["Skipped Registration: "] = "跳过注册: ",
	["Beginning Transcript: "] = "开始记录于: ",
	["You are not logging an encounter."] = "你不处于记录状态",
	["Ending Transcript: "] = "结束记录于：",
	["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "记录保存于WoW\\WTF\\Account\\<名字>\\SavedVariables\\Transcriptor.lua中,你可以上传于Cwowaddon.com论坛,提供最新的BOSS数据.",
	["You are not logging an encounter."] = "你没有记录此次战斗",
	["Added Note: "] = "添加书签于: ",
	["All transcripts cleared."] = "所有记录已清除",
	["You can't clear your transcripts while logging an encounter."] = "正在记录中,你不能清除.",
	["|cffFF0000Recording|r: "] = "|cffFF0000记录中|r: ",
	["|cff696969Idle|r"] = "|cff696969空闲|r",
	["|cffeda55fClick|r to start or stop transcribing an encounter."] = "|cffeda55f点击|r开始/停止记录战斗.",
	["|cffeda55fCtrl-Click|r to add a bookmark note."] = "|cffeda55fCtrl-点击|r增加一书签标注.",
	["|cffFF0000Recording|r"] = "|cffFF0000记录中|r",
	["!! Bookmark !!"] = "!! 书签 !!",
	["Bookmark added to the current log."] = "当前战斗记录已增加一书签",
} end )

L:RegisterTranslations("zhTW", function() return {
	["Start"] = "開始",
	["Start transcribing."] = "開始記錄戰斗",
	["Stop"] = "停止",
	["Stop transcribing."] = "停止記錄",
	["Insert Note"] = "書簽",
	["Insert a note into the currently running transcript."] = "為正在記錄戰斗文本加上一書簽",
	["Events"] = "事件",
	["Toggle which events to log data from."] = "選擇要記錄數據的事件",
	["Time format"] = "時間格式",
	["Change the format of the log timestamps (epoch is preferred)."] = "改變記錄的時間格式",
	["Clear Logs"] = "清除記錄",
	["Clears all the logged data from the Saved Variables database."] = "清空所有BOSS戰記錄",
	["Toggle logging of %s."] = "切換%s的記錄",
	["You are already logging an encounter."] = "你已經準備記錄戰斗",
	["Skipped Registration: "] = "跳過注冊: ",
	["Beginning Transcript: "] = "開始記錄于: ",
	["You are not logging an encounter."] = "你不處于記錄狀態",
	["Ending Transcript: "] = "結束記錄于：",
	["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "記錄保存于WoW\\WTF\\Account\\<名字>\\SavedVariables\\Transcriptor.lua中,你可以上傳于Cwowaddon.com論壇,提供最新的BOSS數據.",
	["You are not logging an encounter."] = "你沒有記錄此次戰斗",
	["Added Note: "] = "添加書簽于: ",
	["All transcripts cleared."] = "所有記錄已清除",
	["You can't clear your transcripts while logging an encounter."] = "正在記錄中,你不能清除.",
	["|cffFF0000Recording|r: "] = "|cffFF0000記錄中|r: ",
	["|cff696969Idle|r"] = "|cff696969空閑|r",
	["|cffeda55fClick|r to start or stop transcribing an encounter."] = "|cffeda55f點擊|r開始/停止記錄戰斗.",
	["|cffeda55fCtrl-Click|r to add a bookmark note."] = "|cffeda55fCtrl-點擊|r增加一書簽標注.",
	["|cffFF0000Recording|r"] = "|cffFF0000記錄中|r",
	["!! Bookmark !!"] = "!! 書簽 !!",
	["Bookmark added to the current log."] = "當前戰斗記錄已增加一書簽",
} end )

L:RegisterTranslations("deDE", function() return {
	["Start"] = "Start",
	["Start transcribing."] = "Aufzeichnung starten.",
	["Stop"] = "Stop",
	["Stop transcribing."] = "Aufzeichnung stoppen.",
	["Insert Note"] = "Notiz einf\195\188gen",
	["Insert a note into the currently running transcript."] = "Eine Notiz in die aktuell laufende Aufzeichnung einf\195\188gen.",
	["Events"] = "Ereignisse",
	["Toggle which events to log data from."] = "Ein- bzw. Ausschalten, welche Ereignisse aufgezeichnet werden sollen.",
	["Time format"] = "Zeitformat",
	["Change the format of the log timestamps (epoch is preferred)."] = "Das Zeitformat der Aufzeichnung \195\164ndern ('epoch' bevorzugt).",
	["Clear Logs"] = "Aufzeichnungen l\195\182schen",
	["Clears all the logged data from the Saved Variables database."] = "L\195\182scht alle aufgezeichneten Daten aus den Saved Variables.",
	["Toggle logging of %s."] = "Aufzeichnung von %s ein/ausschalten.",
	["You are already logging an encounter."] = "Du zeichnest bereits einen Begegnung auf.",
	["Skipped Registration: "] = "Eintragung \195\188bersprungen: ",
	["Beginning Transcript: "] = "Beginne Aufzeichnung: ",
	["You are not logging an encounter."] = "Du zeichnest keine Begegnung auf.",
	["Ending Transcript: "] = "Beende Aufzeichnung: ",
	["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Aufzeichnungen werden gespeichert nach WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua sobald du reloggst oder das Interface neu l\195\164dst.",
	["You are not logging an encounter."] = "Du zeichnest keine Begegnung auf.",
	["Added Note: "] = "Notiz hinzugef\195\188gt: ",
	["All transcripts cleared."] = "Alle Aufzeichnungen gel\195\182scht.",
	["You can't clear your transcripts while logging an encounter."] = "Du kannst deine Aufzeichnungen nicht l\195\182schen, w\195\164hrend du eine Begegnung aufnimmst.",
	["|cffFF0000Recording|r: "] = "|cffFF0000Aufzeichnend|r: ",
	["|cff696969Idle|r"] = "|cff696969Leerlauf|r",
	["|cffeda55fClick|r to start or stop transcribing an encounter."] = "|cffeda55fKlicke|r um eine Aufzeichnung zu starten/stoppen.",
	["|cffeda55fCtrl-Click|r to add a bookmark note."] = "|cffeda55fSTRG-Klick|r um ein Lesezeichen zur aktuellen Aufzeichnung hinzuzuf\195\188gen.",
	["|cffFF0000Recording|r"] = "|cffFF0000Aufzeichnend|r",
	["!! Bookmark !!"] = "!! Lesezeichen !!",
	["Bookmark added to the current log."] = "Lesezeichen zur aktuellen Aufzeichnung hinzugef\195\188gt.",
}end)

--[[
-- Be sure to change the revision number if you add ANY new events.
-- This will cause the user's local database to be refreshed.
--]]
local currentrevision = "2G"
local defaultevents = {
	["PLAYER_REGEN_DISABLED"] = 1,
	["PLAYER_REGEN_ENABLED"] = 1,
	["CHAT_MSG_MONSTER_EMOTE"] = 1,
	["CHAT_MSG_MONSTER_SAY"] = 1,
	["CHAT_MSG_MONSTER_WHISPER"] = 1,
	["CHAT_MSG_MONSTER_YELL"] = 1,
	["CHAT_MSG_RAID_BOSS_EMOTE"] = 1,
	["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_AURA_GONE_OTHER"] = 1,
	["CHAT_MSG_SPELL_AURA_GONE_SELF"] = 1,
	["CHAT_MSG_SPELL_AURA_GONE_PARTY"] = 1,
	["PLAYER_TARGET_CHANGED"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"] = 1,
	["BigWigs_Message"] = 1,
	["CHAT_MSG_COMBAT_FRIENDLY_DEATH"] = 1,
	["CHAT_MSG_COMBAT_HOSTILE_DEATH"] = 1,
	["UNIT_SPELLCAST_START"] = 1,
	["UNIT_SPELLCAST_STOP"] = 1,
	["UNIT_SPELLCAST_SUCCEEDED"] = 1,
	["UNIT_SPELLCAST_INTERRUPTED"] = 1,
	["UNIT_SPELLCAST_CHANNEL_START"] = 1,
	["UNIT_SPELLCAST_CHANNEL_STOP"] = 1,
	["UPDATE_WORLD_STATES"] = 1,
	["COMBAT_LOG_EVENT_UNFILTERED"] = 1,
}

local function DisableIfNotLogging()
	return not logging
end

local function DisableIfLogging()
	return logging
end

local options = {
	type = "group",
	handler = Transcriptor,
	args = {
		start = {
			name = L["Start"], type = "execute",
			desc = L["Start transcribing."],
			func = "StartLog",
			disabled = DisableIfLogging,
			order = 1,
		},
		stop = {
			name = L["Stop"], type = "execute",
			desc = L["Stop transcribing."],
			func = "StopLog",
			disabled = DisableIfNotLogging,
			order = 2,
		},
		spacer = {
			type = "header",
			name = " ",
			order = 50,
		},
		note = {
			name = L["Insert Note"], type = "text",
			desc = L["Insert a note into the currently running transcript."],
			get = false,
			set = "InsNote",
			usage = "<note>",
			disabled = DisableIfNotLogging,
			order = 100,
		},
		events = {
			name = L["Events"], type = "group",
			desc = L["Toggle which events to log data from."],
			pass = true,
			get = function(key)
				return _G.TranscriptDB.events[key]
			end,
			set = function(key, value)
				_G.TranscriptDB.events[key] = value
			end,
			args = {},
			disabled = DisableIfLogging,
			order = 101,
		},
		timeformat = {
			name = L["Time format"], type = "text",
			desc = L["Change the format of the log timestamps (epoch is preferred)."],
			get = "GetTimeFormat",
			set = "SetTimeFormat",
			validate = { "H:M:S", "Epoch + T(S)" },
			disabled = DisableIfLogging,
			order = 102,
		},
		clear = {
			name = L["Clear Logs"], type = "execute",
			desc = L["Clears all the logged data from the Saved Variables database."],
			func = "ClearLogs",
			disabled = DisableIfLogging,
			order = 103,
		},
	},
}

--[[------------------------------------------------
	Basic Functions
------------------------------------------------]]--

function Transcriptor:OnInitialize()
	self:RegisterDB("TranscriptorIconDB")

	self:SetupDB()
	self:RegisterChatCommand("/transcriptor", options, "TRANSCRIPTOR")

	self.OnMenuRequest = options
	self.hasIcon = "Interface\\Addons\\Transcriptor\\icon_off"
	self.defaultMinimapPosition = 200
	self.clickableTooltip = true
	self.cannotDetachTooltip = true
	self.hideWithoutStandby = true
	self.hasNoColor = true
	self.blizzardTooltip = true
end

function Transcriptor:SetupDB()
	if type(_G.TranscriptDB) ~= "table" then _G.TranscriptDB = {} end
	if type(_G.TranscriptDB.events) ~= "table" then _G.TranscriptDB.events = defaultevents end
	if type(_G.TranscriptDB.revision) ~= "string" then _G.TranscriptDB.revision = currentrevision end
	if type(_G.TranscriptDB.timeStampFormat) ~= "string" then _G.TranscriptDB.timeStampFormat = "Epoch + T(S)" end
	if _G.TranscriptDB.revision ~= currentrevision then
		_G.TranscriptDB.events = defaultevents
		_G.TranscriptDB.revision = currentrevision
	end

	local opt = options.args.events.args
	for e,_ in pairs(_G.TranscriptDB.events) do
		opt[e] = {
			name = e, type = "toggle",
			desc = fmt(L["Toggle logging of %s."], e),
		}
	end
end

function Transcriptor:OnEnable()
	logging = nil
end

function Transcriptor:OnDisable()
	if logging then
		self:StopLog()
	end
end

--[[------------------------------------------------
	Core Functions
------------------------------------------------]]--

function Transcriptor:GetTimeFormat()
	return _G.TranscriptDB and _G.TranscriptDB.timeStampFormat or "Epoch + T(S)"
end

function Transcriptor:SetTimeFormat(format)
	if _G.TranscriptDB then _G.TranscriptDB.timeStampFormat = format end
end

TranscriptorTimeFunc = {}
TranscriptorTimeFunc["Epoch + T(S)"] = function()
	return fmt("%.1f", GetTime() - logStartTime)
end
TranscriptorTimeFunc["H:M:S"] = function()
	return date("%H:%M:%S")
end

function Transcriptor:GetTime()
	return TranscriptorTimeFunc[_G.TranscriptDB.timeStampFormat]()
end

function Transcriptor:StartLog()
	if logging then
		self:Print(L["You are already logging an encounter."])
	else
		-- Set the Log Path
		logStartTime = GetTime()

		-- Note that we do not use the time format here, so we have some idea of
		-- when the logging actually started.
		logName = "["..date("%H:%M:%S").."] - "..GetRealZoneText().." : "..GetSubZoneText()

		if type(_G.TranscriptDB[logName]) ~= "table" then _G.TranscriptDB[logName] = {} end
		currentLog = _G.TranscriptDB[logName]

		if type(currentLog.total) ~= "table" then currentLog.total = {} end
		--Register Events to be Tracked
		for event,status in pairs(_G.TranscriptDB.events) do
			if status then
				self:RegisterEvent(event)
			else
				self:Debug(L["Skipped Registration: "]..event)
			end
		end
		--Notify Log Start
		self:Print(L["Beginning Transcript: "]..logName)
		logging = 1

		self:UpdateDisplay()
	end
end

function Transcriptor:StopLog()
	if not logging then
		self:Print(L["You are not logging an encounter."])
	else
		--Clear Events
		self:UnregisterAllEvents()
		--Notify Stop
		self:Print(L["Ending Transcript: "]..logName)
		--Clear Log Path
		logName = nil
		currentLog = nil
		logging = nil

		self:UpdateDisplay()

		self:Print(L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."])
	end
end

function Transcriptor:InsNote(note)
	if not logging then
		self:Print(L["You are not logging an encounter."])
	else
		self:Debug(L["Added Note: "]..note)
		tableins(currentLog.total, "<"..self:GetTime().."> ** Note: "..note.." **")
	end
end

function Transcriptor:ClearLogs()
	if not logging then
		_G.TranscriptDB = {}
		self:SetupDB()
		self:Print(L["All transcripts cleared."])
	else
		self:Print(L["You can't clear your transcripts while logging an encounter."])
	end
end

--[[------------------------------------------------
	FuBar Events
------------------------------------------------]]--

function Transcriptor:OnTooltipUpdate()
	GameTooltip:AddLine("Transcriptor")
	GameTooltip:AddLine(" ")
	if logging then
		GameTooltip:AddDoubleLine(L["|cffFF0000Recording|r: "]..logName)
	else
		GameTooltip:AddDoubleLine(L["|cff696969Idle|r"])
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["|cffeda55fClick|r to start or stop transcribing an encounter."], 0.2, 1, 0.2)
	GameTooltip:AddLine(L["|cffeda55fCtrl-Click|r to add a bookmark note."], 0.2, 1, 0.2)
end

function Transcriptor:OnTextUpdate()
	if logging then
		self:SetText(L["|cffFF0000Recording|r"])
		self:SetIcon("Interface\\AddOns\\Transcriptor\\icon_on")
	else
		self:SetText(L["|cff696969Idle|r"])
		self:SetIcon("Interface\\AddOns\\Transcriptor\\icon_off")
	end
end

function Transcriptor:OnClick()
	if IsControlKeyDown() and logging then
		self:InsNote(L["!! Bookmark !!"])
		self:Print(L["Bookmark added to the current log."])
	else
		if not logging then
			self:StartLog()
		else
			self:StopLog()
		end
	end
end

--[[------------------------------------------------
	Events
------------------------------------------------]]--
-- Boss raid events.
function Transcriptor:PLAYER_REGEN_DISABLED()
	self:Debug("--| Regen Disabled : Entered Combat |--")
	tableins(currentLog.total, "<"..self:GetTime().."> --| Regen Disabled : Entered Combat |--")
end

function Transcriptor:PLAYER_REGEN_ENABLED()
	self:Debug("--| Regen Enabled : Left Combat |--")
	tableins(currentLog.total, "<"..self:GetTime().."> --| Regen Enabled : Left Combat |--")
end

function Transcriptor:CHAT_MSG_MONSTER_EMOTE()
	if type(currentLog.emote) ~= "table" then currentLog.emote = {} end
	self:Debug("Monster Emote: ["..arg2.."]: "..arg1)
	local msg = ("Emote ["..arg2.."]: "..arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[emote]-")
	tableins(currentLog.emote, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_RAID_BOSS_EMOTE(...)
	if type(currentLog.raidBossEmote) ~= "table" then currentLog.raidBossEmote = {} end
	local msg = strjoin(":", ...)
	msg = "Raid boss emote ["..msg.."]"
	self:Debug(msg)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[raidBossEmote]-")
	tableins(currentLog.raidBossEmote, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_SAY()
	if type(currentLog.say) ~= "table" then currentLog.say = {} end
	self:Debug("Monster Say: ["..arg2.."]: "..arg1)
	local msg
	if arg3 then
		msg = ("Say ["..arg2.."]: "..arg1.." ("..arg3..")")
	else
		msg = ("Say ["..arg2.."]: "..arg1)
	end
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[say]-")
	tableins(currentLog.say, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_WHISPER()
	if type(currentLog.whisper) ~= "table" then currentLog.whisper = {} end
	self:Debug("Monster Whisper: ["..arg2.."]: "..arg1)
	local msg = ("Whisper ["..arg2.."]: "..arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[whisper]-")
	tableins(currentLog.whisper, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_YELL()
	if type(currentLog.yell) ~= "table" then currentLog.yell = {} end
	self:Debug("Monster Yell: ["..arg2.."]: "..arg1)
	local msg = ("Yell ["..arg2.."]: "..arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[yell]-")
	tableins(currentLog.yell, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE()
	if type(currentLog.spell_CvCdmg) ~= "table" then currentLog.spell_CvCdmg = {} end
	self:Debug("Creature vs Creature Dmg: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_CvCdmg]-")
	tableins(currentLog.spell_CvCdmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE()
	if type(currentLog.spell_CvSdmg) ~= "table" then currentLog.spell_CvSdmg = {} end
	self:Debug("Creature vs Self Dmg: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_CvSdmg]-")
	tableins(currentLog.spell_CvSdmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE()
	if type(currentLog.spell_CvPdmg) ~= "table" then currentLog.spell_CvPdmg = {} end
	self:Debug("Creature vs Party Dmg: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_CvPdmg]-")
	tableins(currentLog.spell_CvPdmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF()
	if type(currentLog.spell_CvCbuff) ~= "table" then currentLog.spell_CvCbuff = {} end
	self:Debug("Creature vs Creature Buff: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_CvCbuff]-")
	tableins(currentLog.spell_CvCbuff, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE()
	if type(currentLog.spell_perHostPlyrDmg) ~= "table" then currentLog.spell_perHostPlyrDmg = {} end
	self:Debug("Peridoic Hostile Player Damage: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perHostPlyrDmg]-")
	tableins(currentLog.spell_perHostPlyrDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS()
	if type(currentLog.spell_perCbuffs) ~= "table" then currentLog.spell_perCbuffs = {} end
	self:Debug("Peridoic Creature Buffs: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perCbuffs]-")
	tableins(currentLog.spell_perCbuffs, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE()
	if type(currentLog.spell_selfDmg) ~= "table" then currentLog.spell_selfDmg = {} end
	self:Debug("Peridoic Self Damage: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_selfDmg]-")
	tableins(currentLog.spell_selfDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE()
	if type(currentLog.spell_friendDmg) ~= "table" then currentLog.spell_friendDmg = {} end
	self:Debug("Peridoic Friendly Player Damage: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_friendDmg]-")
	tableins(currentLog.spell_friendDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE()
	if type(currentLog.spell_partyDmg) ~= "table" then currentLog.spell_partyDmg = {} end
	self:Debug("Peridoic Party Damage: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_partyDmg]-")
	tableins(currentLog.spell_partyDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_AURA_GONE_OTHER()
	if type(currentLog.spell_auraGone) ~= "table" then currentLog.spell_auraGone = {} end
	self:Debug("Aura Gone Other: "..arg1)

	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_auraGoneOther]-")
	tableins(currentLog.spell_auraGone, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_AURA_GONE_PARTY()
	if type(currentLog.spell_auraGoneParty) ~= "table" then currentLog.spell_auraGoneParty = {} end
	self:Debug("Aura Gone Party: "..arg1)

	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_auraGoneParty]-")
	tableins(currentLog.spell_auraGoneParty, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_AURA_GONE_SELF()
	if type(currentLog.spell_auraGoneSelf) ~= "table" then currentLog.spell_auraGoneSelf = {} end
	self:Debug("Aura Gone Self: "..arg1)

	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_auraGoneSelf]-")
	tableins(currentLog.spell_auraGoneSelf, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:PLAYER_TARGET_CHANGED()
	if type(currentLog.PTC) ~= "table" then currentLog.PTC = {} end
	if (not UnitInRaid("target")) and UnitExists("target") then
		local level = UnitLevel("target")
		if UnitIsPlusMob("target") then level = ("+"..level) end
		local reaction
		if UnitIsFriend("target", "player") then reaction = "Friendly" else reaction = "Hostile" end
		local classification = UnitClassification("target")
		local creatureType = UnitCreatureType("target")
		local typeclass
		if classification == "normal" then typeclass = creatureType else typeclass = (tostring(classification).." "..creatureType) end
		local name = UnitName("target")

		local msg = (fmt("%s %s (%s) - %s", level, reaction, typeclass, name))
		self:Debug("Target Changed: "..msg)
		tableins(currentLog.total, "<"..self:GetTime().."> Target Changed: "..msg.."-[PTC]-")
		tableins(currentLog.PTC, "<"..self:GetTime().."> Target Changed: "..msg)
	end
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE()
	if type(currentLog.spell_perCdmg) ~= "table" then currentLog.spell_perCdmg = {} end
	self:Debug("Peridoic Creature Damage: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perCdmg]-")
	tableins(currentLog.spell_perCdmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:BigWigs_Message(arg1)
	if type(currentLog.BW_Msg) ~= "table" then currentLog.BW_Msg = {} end
	self:Debug("BigWigs Message: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> *** "..msg.." ***")
	tableins(currentLog.BW_Msg, "<"..self:GetTime().."> *** "..msg.." ***")
end

function Transcriptor:CHAT_MSG_COMBAT_FRIENDLY_DEATH()
	if type(currentLog.friendDies) ~= "table" then currentLog.friendDies = {} end
	self:Debug("Friendly Death: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[friendDies]-")
	tableins(currentLog.friendDies, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_COMBAT_HOSTILE_DEATH()
	if type(currentLog.hostileDies) ~= "table" then currentLog.hostileDies = {} end
	self:Debug("Hostile Death: "..arg1)
	local msg = (arg1)
	tableins(currentLog.total, "<"..self:GetTime().."> "..msg.." -[hostileDies]-")
	tableins(currentLog.hostileDies, "<"..self:GetTime().."> "..msg)
end

--enemy cast bar logging
function Transcriptor:UNIT_SPELLCAST_START( unit )
	if type(currentLog.spellcastStart) ~= "table" then currentLog.spellcastStart = {} end
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) or UnitIsFriend("player", unit ) then
		return
	end
	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	local time = ((tostring(endTime) - tostring(startTime)) / 1000)
	local cast = fmt("[%s][%s][%s][%s][%s][%s sec]", UnitName(unit), tostring(spell), tostring(rank), tostring(displayName), tostring(icon), time)
	self:Debug( "Spellcast Start: " .. cast )
	tableins(currentLog.total, "<"..self:GetTime().."> "..cast.." -[spellcastStart]-")
	tableins(currentLog.spellcastStart, "<"..self:GetTime().."> "..cast)
end

function Transcriptor:UNIT_SPELLCAST_CHANNEL_START( unit )
	if type(currentLog.channelStart) ~= "table" then currentLog.channelStart = {} end
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) or UnitIsFriend("player", unit ) then
		return
	end
	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	local time = ((tostring(endTime) - tostring(startTime)) / 1000)
	local cast = fmt("[%s][%s][%s][%s][%s][%s sec]", UnitName(unit), tostring(spell), tostring(rank), tostring(displayName), tostring(icon), time)
	self:Debug( "Channel Start: " .. cast )
	tableins(currentLog.total, "<"..self:GetTime().."> "..cast.." -[channelStart]-")
	tableins(currentLog.channelStart, "<"..self:GetTime().."> "..cast)
end

function Transcriptor:UNIT_SPELLCAST_STOP( unit )
	if type(currentLog.spellcastStop) ~= "table" then currentLog.spellcastStop = {} end
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) or UnitIsFriend("player", unit ) then
		return
	end
	self:Debug("Cast Stop: " .. UnitName(unit) )
	tableins(currentLog.total, "<"..self:GetTime().."> "..UnitName(unit).." -[spellcastStop]-")
	tableins(currentLog.spellcastStop, "<"..self:GetTime().."> "..UnitName(unit))
end

function Transcriptor:UNIT_SPELLCAST_CHANNEL_STOP( unit )
	if type(currentLog.channelStop) ~= "table" then currentLog.channelStop = {} end
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) or UnitIsFriend("player", unit ) then
		return
	end
	self:Debug("Channel Stop: " .. UnitName(unit) )
	tableins(currentLog.total, "<"..self:GetTime().."> "..UnitName(unit).." -[channelStop]-")
	tableins(currentLog.channelStop, "<"..self:GetTime().."> "..UnitName(unit))
end

function Transcriptor:UNIT_SPELLCAST_INTERRUPTED( unit )
	if type(currentLog.spellcastInterrupt) ~= "table" then currentLog.spellcastInterrupt = {} end
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) or UnitIsFriend("player", unit ) then
		return
	end
	self:Debug("Cast Interrupted: " .. UnitName(unit) )
	tableins(currentLog.total, "<"..self:GetTime().."> "..UnitName(unit).." -[spellcastInterrupt]-")
	tableins(currentLog.spellcastInterrupt, "<"..self:GetTime().."> "..UnitName(unit))
end

function Transcriptor:UNIT_SPELLCAST_SUCCEEDED( unit, spell, rank )
	if type(currentLog.spellcastSuccess) ~= "table" then currentLog.spellcastSuccess = {} end
	if not UnitExists(unit) or UnitInRaid(unit) or UnitInParty(unit) or UnitIsFriend("player", unit ) then
		return
	end
	local cast = fmt("[%s][%s][%s]", UnitName(unit), tostring(spell), tostring(rank))
	self:Debug( "Cast Success: " .. cast )
	tableins(currentLog.total, "<"..self:GetTime().."> "..cast.." -[spellcastSuccess]-")
	tableins(currentLog.spellcastSuccess, "<"..self:GetTime().."> "..cast)
end

function Transcriptor:UPDATE_WORLD_STATES()
--uiType, state, text, icon, isFlashing, dynamicIcon, tooltip, dynamicTooltip, extendedUI, extendedUIState1, extendedUIState2, extendedUIState3 = GetWorldStateUIInfo(index)
	local uiType, state, text, icon, isFlashing, dynamicIcon, tooltip, dynamicTooltip, extendedUI, extendedUIState1, extendedUIState2, extendedUIState3 = GetWorldStateUIInfo(3)
	if type(currentLog.world) ~= "table" then currentLog.world = {} end
	if uiType then uiType = fmt("uiType(%d),", uiType) else uiType = "_," end
	if state then state = fmt("state(%d),", state) else state = "_," end
	if text and text ~= nil then text = fmt("text(%s),", tostring(text)) else text = "_," end
	if icon and icon ~= nil then icon = fmt("icon(%s),", tostring(icon)) else icon = "_," end
	if isFlashing and isFlashing ~= "" then isFlashing = fmt("isFlashing(%s),", tostring(isFlashing)) else isFlashing = "_," end
	if dynamicIcon and dynamicIcon ~= nil then dynamicIcon = fmt("dynamicIcon(%s),", tostring(dynamicIcon)) else dynamicIcon = "_," end
	if tooltip and tooltip ~= "" then tooltip = fmt("tooltip(%s),", tostring(tooltip)) else tooltip = "_," end
	if dynamicTooltip and dynamicTooltip ~= "" then dynamicTooltip = fmt("dynamicTooltip(%s),", tostring(dynamicTooltip)) else dynamicTooltip = "_," end
	if extendedUI and extendedUI ~= 0 then extendedUI = fmt("extendedUI(%s),", tostring(extendedUI)) else extendedUI = "_," end
	if extendedUIState1 and extendedUIState1 ~= 0 then extendedUIState1 = fmt("extendedUIState1(%s),", tostring(extendedUIState1)) else extendedUIState1 = "_," end
	if extendedUIState2 and extendedUIState2 ~= 0 then extendedUIState2 = fmt("extendedUIState2(%s),", tostring(extendedUIState2)) else extendedUIState2 = "_," end
	if extendedUIState3 and extendedUIState3 ~= nil then extendedUIState3 = fmt("extendedUIState3(%s)", tostring(extendedUIState3)) else extendedUIState3 = "_" end
	local update = fmt("%s%s%s%s%s%s%s%s%s%s%s%s", uiType, state, text, icon, isFlashing, dynamicIcon, tooltip, dynamicTooltip, extendedUI, extendedUIState1, extendedUIState2, extendedUIState3)
	self:Debug("World State Change: " .. update)
	tableins(currentLog.total, "<"..self:GetTime().."> "..update.." -[World]-")
	tableins(currentLog.world, "<"..self:GetTime().."> "..update)
end

function Transcriptor:COMBAT_LOG_EVENT_UNFILTERED(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, a, b, c, d, e)
	local curtime = self:GetTime()

	if type(currentLog.combatLog) ~= "table" then currentLog.combatLog = {} end
	local msg = event..":"..tostring(srcGUID)..":"..tostring(srcName)..":"..tostring(srcFlags)..":"..tostring(dstGUID)..":"..tostring(dstName)..":"..tostring(dstFlags)..":"..tostring(a)..":"..tostring(b)..":"..tostring(c)..":"..tostring(d)..":"..tostring(e)

	tableins(currentLog.total, "<"..curtime.."> "..msg.." -[World]-")
	tableins(currentLog.combatLog, "<"..curtime.."> "..msg)
end
