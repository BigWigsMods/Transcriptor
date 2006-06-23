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
		self:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
		self:RegisterEvent("CHAT_MSG_MONSTER_SAY")
		self:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
		self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
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
		currentLog.total[date("%H:%M:%S")] = ("** Note: "..note.." **")
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

function Transcriptor:CHAT_MSG_MONSTER_EMOTE()
	if not currentLog.emote then currentLog.emote = {} end
	self:debug("Moster Emote ["..arg2.."]: "..arg1)
	currentLog.total[date("%H:%M:%S")] = ("Emote ["..arg2.."]: "..arg1)
	currentLog.emote[date("%H:%M:%S")] = ("Emote ["..arg2.."]: "..arg1)
end

function Transcriptor:CHAT_MSG_MONSTER_SAY()
	if not currentLog.say then currentLog.say = {} end
	self:debug("Moster Say ["..arg2.."]: "..arg1)
	if arg3 then
		currentLog.total[date("%H:%M:%S")] = ("Say ["..arg2.."]: ("..arg3..") "..arg1)
		currentLog.say[date("%H:%M:%S")] = ("Say ["..arg2.."]: ("..arg3..") "..arg1)
	else
		currentLog.total[date("%H:%M:%S")] = ("Say ["..arg2.."]: "..arg1)
		currentLog.say[date("%H:%M:%S")] = ("Say ["..arg2.."]: "..arg1)
	end
end

function Transcriptor:CHAT_MSG_MONSTER_WHISPER()
	if not currentLog.whisper then currentLog.whisper = {} end
	self:debug("Moster Whisper ["..arg2.."]: "..arg1)
	currentLog.total[date("%H:%M:%S")] = ("Whisper ["..arg2.."]: "..arg1)
	currentLog.whisper[date("%H:%M:%S")] = ("Whisper ["..arg2.."]: "..arg1)
end

function Transcriptor:CHAT_MSG_MONSTER_YELL()
	if not currentLog.yell then currentLog.yell = {} end
	self:debug("Moster Yell ["..arg2.."]: "..arg1)
	currentLog.total[date("%H:%M:%S")] = ("Yell ["..arg2.."]: "..arg1)
	currentLog.yell[date("%H:%M:%S")] = ("Yell ["..arg2.."]: "..arg1)
end

--[[--------------------------------------------------------------------------------
  Create and Register Addon Object
-----------------------------------------------------------------------------------]]

Transcriptor:RegisterForLoad()
