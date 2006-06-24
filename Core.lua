--[[--------------------------------------------------------------------------------
  Class Setup
-----------------------------------------------------------------------------------]]

local logName
local currentLog
local logging

Transcriptor = AceAddonClass:new({
    name          = "Transcriptor",
    description   = "Boss Encounter Logging Utility",
    version       = "0.1",
    releaseDate   = "06-22-2006",
    aceCompatible = "103",
    author        = "Kyahx",
    website       = "http://www.wowace.com",
    category      = "raid",
    db            = AceDbClass:new("TranscriptDB"),
    cmd           = AceChatCmdClass:new({'/transcript','/ts'}, {{
						option	= "start",
						desc	= "Start Transcribing Encounter",
						method	= "StartLog"
						},
						{
						option	= "stop",
						desc	= "Stop Transcribing Encounter",
						method	= "StopLog"
						},
						{
						option	= "note",
						desc	= "Insert a note into the currently running transcript.",
						method	= "InsNote",
						input	= true,
						},
						{
						option	= "clear",
						desc	= "Completely clear the TranscriptDB",
						method	= "ClearLogs"
						}
	})
})

function Transcriptor:Initialize()
	if not TranscriptDB then TranscriptDB = {} end
end


--[[--------------------------------------------------------------------------------
  Addon Enabling/Disabling
-----------------------------------------------------------------------------------]]

function Transcriptor:Enable()
end

function Transcriptor:Disable()
	if logging then
		self:StopLog()
	end
end


--[[--------------------------------------------------------------------------------
  Starting and Stopping Log
-----------------------------------------------------------------------------------]]

function Transcriptor:StartLog()
	if logging then
		self.cmd:msg("You are already logging an encounter.")
	else
		--Set the Log Path
		logName = "["..date("%H:%M:%S").."] - "..GetRealZoneText().." : "..GetSubZoneText()
		if not TranscriptDB[logName] then TranscriptDB[logName] = {} end
		currentLog = TranscriptDB[logName]
		if not currentLog.total then currentLog.total = {} end
		--Register Events to be Tracked
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
		self:RegisterEvent("CHAT_MSG_MONSTER_SAY")
		self:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
		self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
		self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
		self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF")
		self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
		self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS")
		self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")
		self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE")
		self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE")
		--Notify Log Start
		self.cmd:msg("Begining Transcrip: "..logName)
		logging = 1
	end
end

function Transcriptor:StopLog()
	if not logging then
		self.cmd:msg("You are not logging an encounter.")
	else
		--Clear Events
		self:UnregisterAllEvents()
		--Notify Stop
		self.cmd:msg("Ending Transcrip: "..logName)
		--Clear Log Path
		logName = nil
		currentLog = nil
		logging = nil
	end
end

function Transcriptor:InsNote(note)
	if not logging then
		self.cmd:msg("You are not logging an encounter.")
	else
		self:debug("Added Note: "..note)
		table.insert(currentLog.total, "<"..date("%H:%M:%S").."> ** Note: "..note.." **")
	end
end

function Transcriptor:ClearLogs()
	TranscriptDB = {}
	self.cmd:msg("All transcripts cleared.")
end

--[[--------------------------------------------------------------------------------
  Chat Event Handlers
--	Don't forget to add the event to the StartLog() function for
--	any events you add.
-----------------------------------------------------------------------------------]]

function Transcriptor:PLAYER_REGEN_DISABLED()
	self:debug("--|  Regen Disabled : Entered Combat |--")
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> --|  Regen Disabled : Entered Combat |--")
end

function Transcriptor:PLAYER_REGEN_ENABLED()
	self:debug("--|  Regen Enabled : Left Combat |--")
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> --|  Regen Enabled : Left Combat |--")
end

function Transcriptor:CHAT_MSG_MONSTER_EMOTE()
	if not currentLog.emote then currentLog.emote = {} end
	self:debug("Moster Emote: ["..arg2.."]: "..arg1)
	local msg = ("Emote ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.emote, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_SAY()
	if not currentLog.say then currentLog.say = {} end
	self:debug("Moster Say: ["..arg2.."]: "..arg1)
	local msg
	if arg3 then
		msg = ("Say ["..arg2.."]: "..arg1.." ("..arg3..")")
	else
		msg = ("Say ["..arg2.."]: "..arg1)
	end
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.say, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_WHISPER()
	if not currentLog.whisper then currentLog.whisper = {} end
	self:debug("Moster Whisper: ["..arg2.."]: "..arg1)
	local msg = ("Whisper ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.whisper, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_YELL()
	if not currentLog.yell then currentLog.yell = {} end
	self:debug("Moster Yell: ["..arg2.."]: "..arg1)
	local msg = ("Yell ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.yell, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE()
	if not currentLog.spell_CvCdmg then currentLog.spell_CvCdmg = {} end
	self:debug("Creature vs Creature Dmg: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.spell_CvCdmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF()
	if not currentLog.spell_CvCbuff then currentLog.spell_CvCbuff = {} end
	self:debug("Creature vs Creature Buff: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.spell_CvCbuff, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE()
	if not currentLog.spell_perHostPlyrDmg then currentLog.spell_perHostPlyrDmg = {} end
	self:debug("Peridoic Hostile Player Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.spell_perHostPlyrDmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS()
	if not currentLog.spell_perCbuffs then currentLog.spell_perCbuffs = {} end
	self:debug("Peridoic Creature Buffs: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.spell_perCbuffs, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE()
	if not currentLog.spell_selfDmg then currentLog.spell_selfDmg = {} end
	self:debug("Peridoic Self Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.spell_selfDmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE()
	if not currentLog.spell_friendDmg then currentLog.spell_friendDmg = {} end
	self:debug("Peridoic Friendly Player Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.spell_friendDmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE()
	if not currentLog.spell_partyDmg then currentLog.spell_partyDmg = {} end
	self:debug("Peridoic Party Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg)
	table.insert(currentLog.spell_partyDmg, "<"..date("%H:%M:%S").."> "..msg)
end

--[[--------------------------------------------------------------------------------
  Create and Register Addon Object
-----------------------------------------------------------------------------------]]

Transcriptor:RegisterForLoad()

--[[--------------------------------------------------------------------------------
  Requested Events to Add:
	None ATM
-----------------------------------------------------------------------------------]]
