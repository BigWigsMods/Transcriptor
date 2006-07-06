--[[--------------------------------------------------------------------------------
  Class Setup
-----------------------------------------------------------------------------------]]

local logName
local currentLog

----[[ !! Be sure to change the revision number if you add ANY new events.  This will cause the user's local database to be refresehed !! ]]----
local currentrevision = "01e"
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
	["BIGWIGS_MESSAGE"] = 1,
	["PLAYER_TARGET_CHANGED"] = 1,
	["CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"] = 1
}

Transcriptor = AceAddonClass:new({
    name          = "Transcriptor",
    description   = "Boss Encounter logging Utility",
    version       = "0.1",
    releaseDate   = "06-22-2006",
    aceCompatible = "103",
    author        = "Kyahx",
    website       = "http://www.wowace.com",
    category      = "raid",
    db            = AceDbClass:new("TranscriptDB"),
    cmd           = AceChatCmdClass:new({'/transcript','/ts'}, {
						{
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
	if not TranscriptDB.events then TranscriptDB.events = defaultevents end
	if not TranscriptDB.revision then TranscriptDB.revision = currentrevision end
	if TranscriptDB.revision ~= currentrevision then
		TranscriptDB.events = defaultevents
		TranscriptDB.revision = currentrevision
	end
	self.logging = nil
end


--[[--------------------------------------------------------------------------------
  Addon Enabling/Disabling
-----------------------------------------------------------------------------------]]

function Transcriptor:Enable()
end

function Transcriptor:Disable()
	if self.logging then
		self:StopLog()
	end
end


--[[--------------------------------------------------------------------------------
  Starting and Stopping Log
-----------------------------------------------------------------------------------]]

function Transcriptor:StartLog()
	if self.logging then
		self.cmd:msg("You are already logging an encounter.")
	else
		--Set the Log Path
		logName = "["..date("%H:%M:%S").."] - "..GetRealZoneText().." : "..GetSubZoneText()
		if not TranscriptDB[logName] then TranscriptDB[logName] = {} end
		currentLog = TranscriptDB[logName]
		if not currentLog.total then currentLog.total = {} end
		--Register Events to be Tracked
		for event,status in TranscriptDB.events do
			if status == 1 then
				self:RegisterEvent(event)
			else
				self:debug("Skipped Registration: "..event)
			end
		end
		--Notify Log Start
		self.cmd:msg("Begining Transcrip: "..logName)
		self.logging = 1
		if TSMenuFu then TSMenuFu:UpdateText(); TSMenuFu:UpdateTooltip() end
	end
end

function Transcriptor:StopLog()
	if not self.logging then
		self.cmd:msg("You are not logging an encounter.")
	else
		--Clear Events
		self:UnregisterAllEvents()
		--Notify Stop
		self.cmd:msg("Ending Transcrip: "..logName)
		--Clear Log Path
		logName = nil
		currentLog = nil
		self.logging = nil
		if TSMenuFu then TSMenuFu:UpdateText(); TSMenuFu:UpdateTooltip() end
	end
end

function Transcriptor:InsNote(note)
	if not self.logging then
		self.cmd:msg("You are not logging an encounter.")
	else
		self:debug("Added Note: "..note)
		table.insert(currentLog.total, "<"..date("%H:%M:%S").."> ** Note: "..note.." **")
	end
end

function Transcriptor:ClearLogs()
	if not self.logging then
		TranscriptDB = {}
		self:Initialize()
		self.cmd:msg("All transcripts cleared.")
	else
		self.cmd:msg("You can't clear your transcripts while logging an encounter.")
	end
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
	self:debug("Monster Emote: ["..arg2.."]: "..arg1)
	local msg = ("Emote ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[emote]-")
	table.insert(currentLog.emote, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_SAY()
	if not currentLog.say then currentLog.say = {} end
	self:debug("Monster Say: ["..arg2.."]: "..arg1)
	local msg
	if arg3 then
		msg = ("Say ["..arg2.."]: "..arg1.." ("..arg3..")")
	else
		msg = ("Say ["..arg2.."]: "..arg1)
	end
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[say]-")
	table.insert(currentLog.say, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_WHISPER()
	if not currentLog.whisper then currentLog.whisper = {} end
	self:debug("Monster Whisper: ["..arg2.."]: "..arg1)
	local msg = ("Whisper ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[whisper]-")
	table.insert(currentLog.whisper, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_MONSTER_YELL()
	if not currentLog.yell then currentLog.yell = {} end
	self:debug("Monster Yell: ["..arg2.."]: "..arg1)
	local msg = ("Yell ["..arg2.."]: "..arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[yell]-")
	table.insert(currentLog.yell, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE()
	if not currentLog.spell_CvCdmg then currentLog.spell_CvCdmg = {} end
	self:debug("Creature vs Creature Dmg: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_CvCdmg]-")
	table.insert(currentLog.spell_CvCdmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF()
	if not currentLog.spell_CvCbuff then currentLog.spell_CvCbuff = {} end
	self:debug("Creature vs Creature Buff: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_CvCbuff]-")
	table.insert(currentLog.spell_CvCbuff, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE()
	if not currentLog.spell_perHostPlyrDmg then currentLog.spell_perHostPlyrDmg = {} end
	self:debug("Peridoic Hostile Player Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_perHostPlyrDmg]-")
	table.insert(currentLog.spell_perHostPlyrDmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS()
	if not currentLog.spell_perCbuffs then currentLog.spell_perCbuffs = {} end
	self:debug("Peridoic Creature Buffs: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_perCbuffs]-")
	table.insert(currentLog.spell_perCbuffs, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE()
	if not currentLog.spell_selfDmg then currentLog.spell_selfDmg = {} end
	self:debug("Peridoic Self Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_selfDmg]-")
	table.insert(currentLog.spell_selfDmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE()
	if not currentLog.spell_friendDmg then currentLog.spell_friendDmg = {} end
	self:debug("Peridoic Friendly Player Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_friendDmg]-")
	table.insert(currentLog.spell_friendDmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE()
	if not currentLog.spell_partyDmg then currentLog.spell_partyDmg = {} end
	self:debug("Peridoic Party Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_partyDmg]-")
	table.insert(currentLog.spell_partyDmg, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:CHAT_MSG_SPELL_AURA_GONE_OTHER()
	if not currentLog.spell_auraGone then currentLog.spell_auraGone = {} end
	self:debug("Aura Gone: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_auraGone]-")
	table.insert(currentLog.spell_auraGone, "<"..date("%H:%M:%S").."> "..msg)
end

function Transcriptor:BIGWIGS_MESSAGE(arg1)
	if not currentLog.BW_Msg then currentLog.BW_Msg = {} end
	self:debug("BigWigs Message: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> *** "..msg.." ***")
	table.insert(currentLog.BW_Msg, "<"..date("%H:%M:%S").."> *** "..msg.." ***")
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
		self:debug("Target Changed: "..msg)
		table.insert(currentLog.total, "<"..date("%H:%M:%S").."> Target Changed: "..msg.."-[PTC]-")
		table.insert(currentLog.PTC, "<"..date("%H:%M:%S").."> Target Changed: "..msg)
	end
end

function Transcriptor:CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE()
	if not currentLog.spell_perCdmg then currentLog.spell_perCdmg = {} end
	self:debug("Peridoic Creature Damage: "..arg1)
	local msg = (arg1)
	table.insert(currentLog.total, "<"..date("%H:%M:%S").."> "..msg.." -[spell_perCdmg]-")
	table.insert(currentLog.spell_perCdmg, "<"..date("%H:%M:%S").."> "..msg)
end

--[[--------------------------------------------------------------------------------
  Create and Register Addon Object
-----------------------------------------------------------------------------------]]

Transcriptor:RegisterForLoad()

--[[--------------------------------------------------------------------------------
  Requested Events to Add:
	None ATM
-----------------------------------------------------------------------------------]]
