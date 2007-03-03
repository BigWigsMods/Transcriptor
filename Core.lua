
Transcriptor = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceConsole-2.0", "AceDebug-2.0", "FuBarPlugin-2.0")
local Transcriptor = Transcriptor

local tablet = AceLibrary("Tablet-2.0")

local _G = getfenv(0)
local logName
local currentLog
local logStartTime

--[[
-- Be sure to change the revision number if you add ANY new events.
-- This will cause the user's local database to be refreshed.
--]]
local currentrevision = "2D"
local defaultevents = {
	["PLAYER_REGEN_DISABLED"] = 1,
	["PLAYER_REGEN_ENABLED"] = 1,
	["CHAT_MSG_MONSTER_EMOTE"] = 1,
	["CHAT_MSG_MONSTER_SAY"] = 1,
	["CHAT_MSG_MONSTER_WHISPER"] = 1,
	["CHAT_MSG_MONSTER_YELL"] = 1,
	["CHAT_MSG_RAID_BOSS_EMOTE"] = 1,
	["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE"] = 1,
	["CHAT_MSG_SPELL_AURA_GONE_OTHER"] = 1,
	["PLAYER_TARGET_CHANGED"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"] = 1,
	["BigWigs_Message"] = 1,
	["CHAT_MSG_COMBAT_FRIENDLY_DEATH"] = 1,
	["CHAT_MSG_COMBAT_HOSTILE_DEATH"] = 1
}

local options = {
	type = 'group',
	args = {
		start = {
			name = "Start", type = 'execute',
			desc = "Start transcribing encounter.",
			func = function() Transcriptor:StartLog() end,
			disabled = function() return Transcriptor.logging end,
		},
		stop = {
			name = "Stop", type = 'execute',
			desc = "Stop transcribing encounter.",
			func = function() self:StopLog() end,
			disabled = function() return not Transcriptor.logging end,
		},
		note = {
			name = "Insert Note", type = 'text',
			desc = "Insert a note into the currently running transcript.",
			get = false,
			set = function(text) Transcriptor:InsNote(text) end,
			usage = "<note>",
		},
		clear = {
			name = "Clear Logs", type = 'execute',
			desc = "Clear",
			func = function()
				Transcriptor:ClearLogs()
			end,
		},
		events = {
			name = "Events", type = 'group',
			desc = "Various events that can be logged.",
			args = {},
		},
		timeformat = {
			name = "Time format", type = 'text',
			desc = "Change the format of the log timestamps.",
			get = function() return Transcriptor:GetTimeFormat() end,
			set = function(v) Transcriptor:SetTimeFormat(v) end,
			validate = { "H:M:S", "Epoch + T(S)" },
		},
	},
}

--[[------------------------------------------------
	Basic Functions
------------------------------------------------]]--

function Transcriptor:OnInitialize()
	self:SetupDB()
	self:RegisterChatCommand({ "/transcriptor", "/ts" }, options, "TRANSCRIPTOR")

	self.OnMenuRequest = options
	self.hasIcon = "Interface\\Addons\\Transcriptor\\icon_off"
	self.defaultMinimapPosition = 200
	self.clickableTooltip = true
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
			name = e, type = 'toggle',
			desc = "Toggle logging of this event.",
			get = function() return _G.TranscriptDB.events[e] end,
			set = function() _G.TranscriptDB.events[e] = not _G.TranscriptDB.events[e] end
		}
	end
end

function Transcriptor:OnEnable()
	self.logging = nil
end

function Transcriptor:OnDisable()
	if self.logging then
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
	return string.format("%.1f", GetTime() - logStartTime)
end
TranscriptorTimeFunc["H:M:S"] = function()
	return date("%H:%M:%S")
end

function Transcriptor:GetTime()
	return TranscriptorTimeFunc[_G.TranscriptDB.timeStampFormat]()
end

function Transcriptor:StartLog()
	if self.logging then
		self:Print("You are already logging an encounter.")
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
				self:Debug("Skipped Registration: "..event)
			end
		end
		--Notify Log Start
		self:Print("Beginning Transcript: "..logName)
		self.logging = 1

		self:UpdateDisplay()
	end
end

function Transcriptor:StopLog()
	if not self.logging then
		self:Print("You are not logging an encounter.")
	else
		--Clear Events
		self:UnregisterAllEvents()
		--Notify Stop
		self:Print("Ending Transcript: "..logName)
		--Clear Log Path
		logName = nil
		currentLog = nil
		self.logging = nil

		self:UpdateDisplay()
	end
end

function Transcriptor:InsNote(note)
	if not self.logging then
		self:Print("You are not logging an encounter.")
	else
		self:Debug("Added Note: "..note)
		table.insert(currentLog.total, "<"..self:GetTime().."> ** Note: "..note.." **")
	end
end

function Transcriptor:ClearLogs()
	if not self.logging then
		_G.TranscriptDB = {}
		self:SetupDB()
		self:Print("All transcripts cleared.")
	else
		self:Print("You can't clear your transcripts while logging an encounter.")
	end
end

--[[------------------------------------------------
	FuBar Events
------------------------------------------------]]--

function Transcriptor:OnTooltipUpdate()
	local cat = tablet:AddCategory(
		"columns", 1,
		"child_textR", 1,
		"child_textG", 1,
		"child_textB", 1
	)

	local text
	if self.logging then
		text = "|cffFF0000Recording|r: "..logName
	else
		text = "|cff696969Idle|r"
	end
	cat:AddLine(
		"text", text,
		"func", Transcriptor.OnClick,
		"arg1", self,
		"wrap", true
	)

	tablet:SetHint("|cffeda55fClick|r to start or stop transcribing an encounter. |cffeda55fCtrl-Click|r to add a bookmark note.")
end

function Transcriptor:OnTextUpdate()
	if self.logging then
		self:SetText("|cffFF0000Recording|r")
		self:SetIcon("Interface\\AddOns\\Transcriptor\\icon_on.tga")
	else
		self:SetText("|cff696969Idle|r")
		self:SetIcon("Interface\\AddOns\\Transcriptor\\icon_off.tga")
	end
end

function Transcriptor:OnClick()
	if IsControlKeyDown() and self.logging then
		self:InsNote("!! Bookmark !!")
		self:Print("Bookmark added to the current log.")
	else
		if not self.logging then
			self:StartLog()
		else
			self:StopLog()
		end
	end
end

--[[------------------------------------------------
	Events
------------------------------------------------]]--

function Transcriptor:PLAYER_REGEN_DISABLED()
	self:Debug("--| Regen Disabled : Entered Combat |--")
	table.insert(currentLog.total, "<"..self:GetTime().."> --| Regen Disabled : Entered Combat |--")
end

function Transcriptor:PLAYER_REGEN_ENABLED()
	self:Debug("--| Regen Enabled : Left Combat |--")
	table.insert(currentLog.total, "<"..self:GetTime().."> --| Regen Enabled : Left Combat |--")
end

function Transcriptor:CHAT_MSG_MONSTER_EMOTE()
	if type(currentLog.emote) ~= "table" then currentLog.emote = {} end
	self:Debug("Monster Emote: ["..arg2.."]: "..arg1)
	local msg = ("Emote ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[emote]-")
	table.insert(currentLog.emote, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_RAID_BOSS_EMOTE(...)
	if type(currentLog.raidBossEmote) ~= "table" then currentLog.raidBossEmote = {} end
	local msg = strjoin(":", ...)
	msg = "Raid boss emote ["..msg.."]"
	self:Debug(msg)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[raidBossEmote]-")
	table.insert(currentLog.raidBossEmote, "<"..self:GetTime().."> "..msg)
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
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[say]-")
	table.insert(currentLog.say, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_WHISPER()
	if type(currentLog.whisper) ~= "table" then currentLog.whisper = {} end
	self:Debug("Monster Whisper: ["..arg2.."]: "..arg1)
	local msg = ("Whisper ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[whisper]-")
	table.insert(currentLog.whisper, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_YELL()
	if type(currentLog.yell) ~= "table" then currentLog.yell = {} end
	self:Debug("Monster Yell: ["..arg2.."]: "..arg1)
	local msg = ("Yell ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[yell]-")
	table.insert(currentLog.yell, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE()
	if type(currentLog.spell_CvCdmg) ~= "table" then currentLog.spell_CvCdmg = {} end
	self:Debug("Creature vs Creature Dmg: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_CvCdmg]-")
	table.insert(currentLog.spell_CvCdmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF()
	if type(currentLog.spell_CvCbuff) ~= "table" then currentLog.spell_CvCbuff = {} end
	self:Debug("Creature vs Creature Buff: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_CvCbuff]-")
	table.insert(currentLog.spell_CvCbuff, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE()
	if type(currentLog.spell_perHostPlyrDmg) ~= "table" then currentLog.spell_perHostPlyrDmg = {} end
	self:Debug("Peridoic Hostile Player Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perHostPlyrDmg]-")
	table.insert(currentLog.spell_perHostPlyrDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS()
	if type(currentLog.spell_perCbuffs) ~= "table" then currentLog.spell_perCbuffs = {} end
	self:Debug("Peridoic Creature Buffs: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perCbuffs]-")
	table.insert(currentLog.spell_perCbuffs, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE()
	if type(currentLog.spell_selfDmg) ~= "table" then currentLog.spell_selfDmg = {} end
	self:Debug("Peridoic Self Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_selfDmg]-")
	table.insert(currentLog.spell_selfDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE()
	if type(currentLog.spell_friendDmg) ~= "table" then currentLog.spell_friendDmg = {} end
	self:Debug("Peridoic Friendly Player Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_friendDmg]-")
	table.insert(currentLog.spell_friendDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE()
	if type(currentLog.spell_partyDmg) ~= "table" then currentLog.spell_partyDmg = {} end
	self:Debug("Peridoic Party Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_partyDmg]-")
	table.insert(currentLog.spell_partyDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_AURA_GONE_OTHER()
	if type(currentLog.spell_auraGone) ~= "table" then currentLog.spell_auraGone = {} end
	self:Debug("Aura Gone: "..arg1)

	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_auraGone]-")
	table.insert(currentLog.spell_auraGone, "<"..self:GetTime().."> "..msg)
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
		if classification == "normal" then typeclass = creatureType else typeclass = (classification.." "..creatureType) end
		local name = UnitName("target")

		local msg = (string.format("%s %s (%s) - %s", level, reaction, typeclass, name))	
		self:Debug("Target Changed: "..msg)
		table.insert(currentLog.total, "<"..self:GetTime().."> Target Changed: "..msg.."-[PTC]-")
		table.insert(currentLog.PTC, "<"..self:GetTime().."> Target Changed: "..msg)
	end
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE()
	if type(currentLog.spell_perCdmg) ~= "table" then currentLog.spell_perCdmg = {} end
	self:Debug("Peridoic Creature Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perCdmg]-")
	table.insert(currentLog.spell_perCdmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:BigWigs_Message(arg1)
	if type(currentLog.BW_Msg) ~= "table" then currentLog.BW_Msg = {} end
	self:Debug("BigWigs Message: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> *** "..msg.." ***")
	table.insert(currentLog.BW_Msg, "<"..self:GetTime().."> *** "..msg.." ***")
end

function Transcriptor:CHAT_MSG_COMBAT_FRIENDLY_DEATH()
	if type(currentLog.friendDies) ~= "table" then currentLog.friendDies = {} end
	self:Debug("Friendly Death: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[friendDies]-")
	table.insert(currentLog.friendDies, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_COMBAT_HOSTILE_DEATH()
	if type(currentLog.hostileDies) ~= "table" then currentLog.hostileDies = {} end
	self:Debug("Hostile Death: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[hostileDies]-")
	table.insert(currentLog.hostileDies, "<"..self:GetTime().."> "..msg)
end

