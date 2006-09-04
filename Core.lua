Transcriptor = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceConsole-2.0", "AceDebug-2.0", "FuBarPlugin-2.0")
local dewdrop = AceLibrary("Dewdrop-2.0")
local tablet = AceLibrary("Tablet-2.0")

local logName
local currentLog
local logStartTime

local icon_on = "Interface\\AddOns\\Transcriptor\\icon_on.tga"
local icon_off = "Interface\\AddOns\\Transcriptor\\icon_off.tga"

local statustext = "Transcriptor - |cff696969Idle|r"

----[[ !! Be sure to change the revision number if you add ANY new events.  This will cause the user's local database to be refresehed !! ]]----
local currentrevision = "2B"
local defaultevents = {
	["PLAYER_REGEN_DISABLED"] = 1,
	["PLAYER_REGEN_ENABLED"] = 1,
	["CHAT_MSG_MONSTER_EMOTE"] = 1,
	["CHAT_MSG_MONSTER_SAY"] = 1,
	["CHAT_MSG_MONSTER_WHISPER"] = 1,
	["CHAT_MSG_MONSTER_YELL"] = 1,
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
	["CHAT_MSG_COMBAT_FRIENDLY_DEATH"] = 1
}

local EventsTable = {}

--[[------------------------------------------------
	Basic Functions
------------------------------------------------]]--

function Transcriptor:OnInitialize()
	self:SetupDB()
	self.consoleOptions = {
		type = 'group',
		args = {
			start = {
				name = "Start", type = 'execute',
				desc = "Start transcribing encounter.",
				func = function() self:StartLog() end,
				disabled = function() return self.logging end,
			},
			stop = {
				name = "Stop", type = 'execute',
				desc = "Stop transcribing encounter.",
				func = function() self:StopLog() end,
				disabled = function() return not self.logging end,
			},
			note = {
				name = "Insert Note", type = 'text',
				desc = "Insert a note into the currently running transcript.",
				get = false,
				set = function(text) self:InsNote(text) end,
				usage = "<note>",
			},
			clear = {
				name = "Clear Logs", type = 'execute',
				desc = "Clear",
				func = function()
					self:ClearLogs()
				end,
			},
			events = {
				name = "Events", type = 'group',
				desc = "Various events that can be logged.",
				args = EventsTable,
			},
			timeformat = {
				name = "Time format", type = 'text',
				desc = "Change the format of the log timestamps.",
				get = function() return self:GetTimeFormat() end,
				set = function(v) self:SetTimeFormat(v) end,
				validate = { "H:M:S", "Epoch + T(S)" },
			},
		},
	}

	self:RegisterChatCommand({ "/transcriptor", "/ts" }, self.consoleOptions)
	
	self.OnMenuRequest = self.consoleOptions
	self.name = "Transcriptor"
	self.hasIcon = "Interface\\Addons\\Transcriptor\\icon_off"
	self.defaultMinimapPosition = 200
end

function Transcriptor:SetupDB()
	if not TranscriptDB then TranscriptDB = {} end
	if not TranscriptDB.events then TranscriptDB.events = defaultevents end
	if not TranscriptDB.revision then TranscriptDB.revision = currentrevision end
	if not TranscriptDB.timeStampFormat then TranscriptDB.timeStampFormat = "Epoch + T(S)" end
	if TranscriptDB.revision ~= currentrevision then
		TranscriptDB.events = defaultevents
		TranscriptDB.revision = currentrevision
	end

	for e,_ in TranscriptDB.events do
		local event = e
		EventsTable[event] = {
			name = event, type = 'toggle',
			desc = "Toggle logging of this event.",
			get = function() return TranscriptDB.events[event] end,
			set = function() TranscriptDB.events[event] = not TranscriptDB.events[event] end
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
	
	self:UnregisterAllEvents()
end

--[[------------------------------------------------
	Core Functions
------------------------------------------------]]--

function Transcriptor:GetTimeFormat()
	return TranscriptDB and TranscriptDB.timeStampFormat or "Epoch + T(S)"
end

function Transcriptor:SetTimeFormat(format)
	if TranscriptDB then TranscriptDB.timeStampFormat = format end
end

TranscriptorTimeFunc = {}
TranscriptorTimeFunc["Epoch + T(S)"] = function()
	return string.format("%.1f", GetTime() - logStartTime)
end
TranscriptorTimeFunc["H:M:S"] = function()
	return date("%H:%M:%S")
end

function Transcriptor:GetTime()
	return TranscriptorTimeFunc[TranscriptDB.timeStampFormat]()
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
		if not TranscriptDB[logName] then TranscriptDB[logName] = {} end
		currentLog = TranscriptDB[logName]
		if not currentLog.total then currentLog.total = {} end
		--Register Events to be Tracked
		for event,status in TranscriptDB.events do
			if status == 1 then
				self:RegisterEvent(event)
			else
				self:Debug("Skipped Registration: "..event)
			end
		end
		--Notify Log Start
		self:Print("Beginning Transcript: "..logName)
		self.logging = 1
	end
	
	self:UpdateText()
	self:UpdateTooltip()
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
	end
	
	self:UpdateText()
	self:UpdateTooltip()
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
		TranscriptDB = {}
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
		"arg1", Transcriptor
	)

	tablet:SetHint("Click to start or stop transcribing an encounter. Control-Click to add a bookmark note to the current encounter.")
end

function Transcriptor:UpdateText()
	if self.logging then
		statustext = "Transcriptor - |cffFF0000Recording|r"
		self:SetIcon(icon_on)
	else
		statustext = "Transcriptor - |cff696969Idle|r"
		self:SetIcon(icon_off)
	end
	self:SetText(statustext)
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
	self:Debug("--|  Regen Disabled : Entered Combat |--")
	table.insert(currentLog.total, "<"..self:GetTime().."> --|  Regen Disabled : Entered Combat |--")
end

function Transcriptor:PLAYER_REGEN_ENABLED()
	self:Debug("--|  Regen Enabled : Left Combat |--")
	table.insert(currentLog.total, "<"..self:GetTime().."> --|  Regen Enabled : Left Combat |--")
end

function Transcriptor:CHAT_MSG_MONSTER_EMOTE()
	if not currentLog.emote then currentLog.emote = {} end
	self:Debug("Monster Emote: ["..arg2.."]: "..arg1)
	local msg = ("Emote ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[emote]-")
	table.insert(currentLog.emote, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_SAY()
	if not currentLog.say then currentLog.say = {} end
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
	if not currentLog.whisper then currentLog.whisper = {} end
	self:Debug("Monster Whisper: ["..arg2.."]: "..arg1)
	local msg = ("Whisper ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[whisper]-")
	table.insert(currentLog.whisper, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_YELL()
	if not currentLog.yell then currentLog.yell = {} end
	self:Debug("Monster Yell: ["..arg2.."]: "..arg1)
	local msg = ("Yell ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[yell]-")
	table.insert(currentLog.yell, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE()
	if not currentLog.spell_CvCdmg then currentLog.spell_CvCdmg = {} end
	self:Debug("Creature vs Creature Dmg: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_CvCdmg]-")
	table.insert(currentLog.spell_CvCdmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF()
	if not currentLog.spell_CvCbuff then currentLog.spell_CvCbuff = {} end
	self:Debug("Creature vs Creature Buff: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_CvCbuff]-")
	table.insert(currentLog.spell_CvCbuff, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE()
	if not currentLog.spell_perHostPlyrDmg then currentLog.spell_perHostPlyrDmg = {} end
	self:Debug("Peridoic Hostile Player Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perHostPlyrDmg]-")
	table.insert(currentLog.spell_perHostPlyrDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS()
	if not currentLog.spell_perCbuffs then currentLog.spell_perCbuffs = {} end
	self:Debug("Peridoic Creature Buffs: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perCbuffs]-")
	table.insert(currentLog.spell_perCbuffs, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE()
	if not currentLog.spell_selfDmg then currentLog.spell_selfDmg = {} end
	self:Debug("Peridoic Self Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_selfDmg]-")
	table.insert(currentLog.spell_selfDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE()
	if not currentLog.spell_friendDmg then currentLog.spell_friendDmg = {} end
	self:Debug("Peridoic Friendly Player Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_friendDmg]-")
	table.insert(currentLog.spell_friendDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE()
	if not currentLog.spell_partyDmg then currentLog.spell_partyDmg = {} end
	self:Debug("Peridoic Party Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_partyDmg]-")
	table.insert(currentLog.spell_partyDmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_AURA_GONE_OTHER()
	if not currentLog.spell_auraGone then currentLog.spell_auraGone = {} end
	self:Debug("Aura Gone: "..arg1)

	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_auraGone]-")
	table.insert(currentLog.spell_auraGone, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:PLAYER_TARGET_CHANGED()
	if not currentLog.PTC then currentLog.PTC = {} end
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
	if not currentLog.spell_perCdmg then currentLog.spell_perCdmg = {} end
	self:Debug("Peridoic Creature Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[spell_perCdmg]-")
	table.insert(currentLog.spell_perCdmg, "<"..self:GetTime().."> "..msg)
end

function Transcriptor:BigWigs_Message(arg1)
	if not currentLog.BW_Msg then currentLog.BW_Msg = {} end
	self:Debug("BigWigs Message: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> *** "..msg.." ***")
	table.insert(currentLog.BW_Msg, "<"..self:GetTime().."> *** "..msg.." ***")
end

function Transcriptor:CHAT_MSG_COMBAT_FRIENDLY_DEATH()
	if not currentLog.friendDies then currentLog.friendDies = {} end
	self:Debug("Friendly Death: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..self:GetTime().."> "..msg.." -[friendDies]-")
	table.insert(currentLog.friendDies, "<"..self:GetTime().."> "..msg)
end
