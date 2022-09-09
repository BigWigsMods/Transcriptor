
local Transcriptor = {}

local playerSpellBlacklist
local badSourcelessPlayerSpellList
local specialEvents
local data = {}

do
	local n, tbl = ...
	playerSpellBlacklist = tbl.blacklist
	specialEvents = tbl.specialEvents
	tbl.data = data
end

local logName = nil
local currentLog = nil
local logStartTime = nil
local logging = nil
local compareSuccess = nil
local compareUnitSuccess = nil
local compareEmotes = nil
local compareStart = nil
local compareAuraApplied = nil
local compareStartTime = nil
local collectNameplates = nil
local collectPlayerAuras = nil
local hiddenUnitAuraCollector = nil
local playerSpellCollector = nil
local hiddenAuraPermList = {
	[5384] = true, -- Feign Death
	[209997] = true, -- Play Dead (Hunter Pet)
}
local previousSpecialEvent = nil
local hiddenAuraEngageList = nil
local shouldLogFlags = false
local inEncounter, blockingRelease, limitingRes = false, false, false
local mineOrPartyOrRaid = 7 -- COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID

local band = bit.band
local tinsert = table.insert
local format, find, strjoin = string.format, string.find, string.join
local tostring, tostringall = tostring, tostringall
local type, next, print = type, next, print
local date = date
local debugprofilestop, wipe = debugprofilestop, wipe

local C_Scenario, C_DeathInfo_GetSelfResurrectOptions, Enum = C_Scenario, C_DeathInfo.GetSelfResurrectOptions, Enum
local IsEncounterInProgress, IsEncounterLimitingResurrections, IsEncounterSuppressingRelease = IsEncounterInProgress, IsEncounterLimitingResurrections, IsEncounterSuppressingRelease
local IsAltKeyDown, EJ_GetEncounterInfo, C_EncounterJournal_GetSectionInfo, C_Map_GetMapInfo = IsAltKeyDown, EJ_GetEncounterInfo, C_EncounterJournal.GetSectionInfo, C_Map.GetMapInfo
local UnitInRaid, UnitInParty, UnitIsFriend, UnitCastingInfo, UnitChannelInfo = UnitInRaid, UnitInParty, UnitIsFriend, UnitCastingInfo, UnitChannelInfo
local UnitCanAttack, UnitExists, UnitIsVisible, UnitGUID, UnitClassification = UnitCanAttack, UnitExists, UnitIsVisible, UnitGUID, UnitClassification
local UnitName, UnitPower, UnitPowerMax, UnitPowerType, UnitHealth = UnitName, UnitPower, UnitPowerMax, UnitPowerType, UnitHealth
local UnitLevel, UnitCreatureType = UnitLevel, UnitCreatureType
local GetInstanceInfo = GetInstanceInfo
local GetZoneText, GetRealZoneText, GetSubZoneText, GetSpellInfo = GetZoneText, GetRealZoneText, GetSubZoneText, GetSpellInfo
local GetBestMapForUnit = C_Map.GetBestMapForUnit

-- GLOBALS: TranscriptDB BigWigsLoader DBM CLOSE SlashCmdList SLASH_TRANSCRIPTOR1 SLASH_TRANSCRIPTOR2 SLASH_TRANSCRIPTOR3 EasyMenu CloseDropDownMenus
-- GLOBALS: GetMapID GetBossID GetSectionID

do
	local origPrint = print
	function print(msg, ...)
		return origPrint(format("|cffffff00%s|r", tostring(msg)), tostringall(...))
	end

	local origUnitName = UnitName
	function UnitName(name)
		return origUnitName(name) or "??"
	end
end

local function MobId(guid, extra)
	if not guid then return 1 end
	local _, _, _, _, _, strId, unq = strsplit("-", guid)
	if extra then
		local id = tonumber(strId)
		if id then
			return strId.."-"..unq
		else
			return 1
		end
	else
		return tonumber(strId) or 1
	end
end

local function InsertSpecialEvent(name)
	if type(name) == "function" then
		name = name()
	end
	if not name then return end
	local t = debugprofilestop()
	previousSpecialEvent = {t, name}
	if compareSuccess then
		for id,tbl in next, compareSuccess do
			for npcId, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareStart then
		for id,tbl in next, compareStart do
			for npcId, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareAuraApplied then
		for id,tbl in next, compareAuraApplied do
			for npcId, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareUnitSuccess then
		for id,tbl in next, compareUnitSuccess do
			for npcId, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
	if compareEmotes then
		for id,tbl in next, compareEmotes do
			for npcName, list in next, tbl do
				list[#list+1] = {t, name}
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Utility
--

function GetMapArtID(name)
	name = name:lower()
	for i=1,3000 do
		local fetchedTbl = C_Map.GetMapInfo(i)
		if fetchedTbl and fetchedTbl.name then
			local lowerFetchedName = fetchedTbl.name:lower()
			if find(lowerFetchedName, name, nil, true) then
				print(fetchedTbl.name..": "..i)
			end
		end
	end
end
function GetInstanceID(name)
	name = name:lower()
	for i=1,3000 do
		local fetchedName = GetRealZoneText(i)
		local lowerFetchedName = fetchedName:lower()
		if find(lowerFetchedName, name, nil, true) then
			print(fetchedName..": "..i)
		end
	end
end
function GetBossID(name)
	name = name:lower()
	for i=1,3000 do
		local fetchedName = EJ_GetEncounterInfo(i)
		if fetchedName then
			local lowerFetchedName = fetchedName:lower()
			if find(lowerFetchedName, name, nil, true) then
				print(fetchedName..": "..i)
			end
		end
	end
end
function GetSectionID(name)
	name = name:lower()
	for i=1,15000 do
		local tbl = C_EncounterJournal_GetSectionInfo(i)
		if tbl then
			local fetchedName = tbl.title
			local lowerFetchedName = fetchedName:lower()
			if find(lowerFetchedName, name, nil, true) then
				print(fetchedName..": "..i)
			end
		end
	end
end

do
	-- Create UI spell display, copied from BasicChatMods
	local frame, editBox = {}, {}
	for i = 1, 4 do
		if BackdropTemplateMixin then -- XXX Shadowlands change
			frame[i] = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
			frame[i].backdropInfo  = {bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true, tileSize = 16, edgeSize = 16,
				insets = {left = 1, right = 1, top = 1, bottom = 1}}
			frame[i]:ApplyBackdrop()
		else
			frame[i] = CreateFrame("Frame", nil, UIParent)
			frame[i]:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true, tileSize = 16, edgeSize = 16,
				insets = {left = 1, right = 1, top = 1, bottom = 1}}
			)
		end
		frame[i]:SetBackdropColor(0,0,0,1)
		frame[i]:SetWidth(650)
		frame[i]:SetHeight(450)
		frame[i]:Hide()
		frame[i]:SetFrameStrata("DIALOG")

		local scrollArea = CreateFrame("ScrollFrame", "TranscriptorDevScrollArea"..i, frame[i], "UIPanelScrollFrameTemplate")
		scrollArea:SetPoint("TOPLEFT", frame[i], "TOPLEFT", 8, -5)
		scrollArea:SetPoint("BOTTOMRIGHT", frame[i], "BOTTOMRIGHT", -30, 5)

		editBox[i] = CreateFrame("EditBox", nil, frame[i])
		editBox[i]:SetMultiLine(true)
		editBox[i]:EnableMouse(true)
		editBox[i]:SetAutoFocus(false)
		editBox[i]:SetFontObject(ChatFontNormal)
		editBox[i]:SetWidth(620)
		editBox[i]:SetHeight(450)
		editBox[i]:SetScript("OnEscapePressed", function(f) f:GetParent():GetParent():Hide() f:SetText("") end)
		if i % 2 ~= 0 then
			editBox[i]:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
			editBox[i]:SetScript("OnHyperlinkEnter", function(self, link, text)
				if link and find(link, "spell", nil, true) then
					local spellId = link:match("(%d+)")
					if spellId then
						GameTooltip:SetOwner(frame[i], "ANCHOR_LEFT", 0, -500)
						GameTooltip:SetSpellByID(spellId)
					end
				end
			end)
			editBox[i]:SetHyperlinksEnabled(true)
		end

		scrollArea:SetScrollChild(editBox[i])

		local close = CreateFrame("Button", nil, frame[i], "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", frame[i], "TOPRIGHT", 0, 25)
	end

	local function GetLogSpells()
		if InCombatLockdown() or UnitAffectingCombat("player") or IsFalling() then return end

		local total, totalSorted = {}, {}
		local auraTbl, castTbl, summonTbl = {}, {}, {}
		local aurasSorted, castsSorted, summonSorted = {}, {}, {}
		local playerCastList = {}
		local ignoreList = {
			[43681] = true, -- Inactive (PvP)
			[94028] = true, -- Inactive (PvP)
			[66186] = true, -- Napalm (IoC PvP)
			[66195] = true, -- Napalm (IoC PvP)
			[66268] = true, -- Place Seaforium Bomb (IoC PvP)
			[66271] = true, -- Carrying Seaforium (IoC PvP)
			[66456] = true, -- Glaive Throw (IoC PvP)
			[66518] = true, -- Airship Cannon (IoC PvP)
			[66541] = true, -- Incendiary Rocket (IoC PvP)
			[66542] = true, -- Incendiary Rocket (IoC PvP)
			[66657] = true, -- Parachute (IoC PvP)
			[66674] = true, -- Place Huge Seaforium Bomb (IoC PvP)
			[67195] = true, -- Blade Salvo (IoC PvP)
			[67200] = true, -- Blade Salvo (IoC PvP)
			[67440] = true, -- Hurl Boulder (IoC PvP)
			[67441] = true, -- Ram (IoC PvP)
			[67452] = true, -- Rocket Blast (IoC PvP)
			[67461] = true, -- Fire Cannon (IoC PvP)
			[67796] = true, -- Ram (IoC PvP)
			[67797] = true, -- Steam Rush (IoC PvP)
			[68077] = true, -- Repair Cannon (IoC PvP)
			[68298] = true, -- Parachute (IoC PvP)
			[68377] = true, -- Carrying Huge Seaforium (IoC PvP)
			[270620] = true, -- Psionic Blast (Zek'voz/Uldir || Mind Controlled player)
			[272407] = true, -- Oblivion Sphere (Mythrax/Uldir || Orb spawning on player)
			[263372] = true, -- Power Matrix (G'huun/Uldir || Holding the orb)
			[263436] = true, -- Imperfect Physiology (G'huun/Uldir || After the orb)
			[263373] = true, -- Deposit Power Matrix (G'huun/Uldir)
			[263416] = true, -- Throw Power Matrix (G'huun/Uldir)
			[269455] = true, -- Collect Power Matrix (G'huun/Uldir)
		}
		local npcIgnoreList = {
			[154297] = true, -- Ankoan Bladesman
			[154304] = true, -- Waveblade Shaman
			[150202] = true, -- Waveblade Hunter
		}
		local events = {
			"SPELL_AURA_[AR][^#]+#(%d+)#([^#]+%-[^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#([^#]+)#", -- SPELL_AURA_[AR] to filter _BROKEN
			"SPELL_CAST_[^#]+#(%d+)#([^#]+%-[^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#([^#]+)#",
			"SPELL_SUMMON#(%d+)#([^#]+%-[^#]+)#([^#]+)#([^#]*)#([^#]+)#(%d+)#([^#]+)#"
		}
		local tables = {
			auraTbl,
			castTbl,
			summonTbl,
		}
		local sortedTables = {
			aurasSorted,
			castsSorted,
			summonSorted,
		}
		for logName, logTbl in next, TranscriptDB do
			if type(logTbl) == "table" then
				if logTbl.total then
					for i=1, #logTbl.total do
						local text = logTbl.total[i]

						for j = 1, 3 do
							local flagsText, srcGUID, name, destGUID, tarName, idText = text:match(events[j])
							local id = tonumber(idText)
							local flags = tonumber(flagsText)
							local tbl = tables[j]
							local sortedTbl = sortedTables[j]
							if id and flags and band(flags, mineOrPartyOrRaid) ~= 0 and not ignoreList[id] and not playerSpellBlacklist[id] and #sortedTbl < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
								if not total[id] or destGUIDType ~= "" then
									local srcGUIDType, _, _, _, _, npcIdStr = strsplit("-", srcGUID)
									local npcId = tonumber(npcIdStr)
									if not npcIgnoreList[npcId] then
										local destGUIDType = strsplit("-", destGUID)
										local trim = destGUID and find(destGUID, "^P[le][at]")
										if srcGUID == destGUID then
											tbl[id] = "|cFF81BEF7".. name:gsub("%-.+", "*") .."(".. srcGUIDType ..") >> ".. (trim and tarName:gsub("%-.+", "*") or tarName) .."(".. destGUIDType ..")|r"
										else
											tbl[id] = "|cFF3ADF00".. name:gsub("%-.+", "*") .."(".. srcGUIDType ..") >> ".. (trim and tarName:gsub("%-.+", "*") or tarName) .."(".. destGUIDType ..")|r"
										end
										if not total[id] then
											total[id] = true
											sortedTbl[#sortedTbl+1] = id
										end
									end
								end
							end
						end
					end
				end
				if logTbl.TIMERS and logTbl.TIMERS.PLAYER_SPELLS then
					for i=1, #logTbl.TIMERS.PLAYER_SPELLS do
						local text = logTbl.TIMERS.PLAYER_SPELLS[i]
						local spellId, _, _, player = strsplit("#", text)
						local id = tonumber(spellId)
						if id and not playerSpellBlacklist[id] and not playerCastList[id] and not total[id] then
							playerCastList[id] = player
							total[id] = true
						end
					end
				end
			end
		end

		sort(aurasSorted)
		local text = "-- AURAS\n"
		for i = 1, #aurasSorted do
			local id = aurasSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, auraTbl[id])
		end

		sort(castsSorted)
		text = text.. "\n-- CASTS\n"
		for i = 1, #castsSorted do
			local id = castsSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, castTbl[id])
		end

		sort(summonSorted)
		text = text.. "\n-- SUMMONS\n"
		for i = 1, #summonSorted do
			local id = summonSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, summonTbl[id])
		end

		text = text.. "\n-- PLAYER_CASTS\n"
		for k, v in next, playerCastList do
			local name = GetSpellInfo(k)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, k, k, name, v)
		end

		-- Display newly found spells for analysis
		editBox[1]:SetText(text)
		frame[1]:ClearAllPoints()
		frame[1]:SetPoint("BOTTOMRIGHT", UIParent, "CENTER")
		frame[1]:Show()

		for k, v in next, playerSpellBlacklist do
			if GetSpellInfo(k) then -- Filter out removed spells when a new patch hits
				total[k] = true
			end
		end
		for k, v in next, total do
			totalSorted[#totalSorted+1] = k
		end
		sort(totalSorted)
		text = "local n, tbl = ...\ntbl.blacklist = {\n"
		for i = 1, #totalSorted do
			local id = totalSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s[%d] = true, -- %s\n", text, id, name)
		end
		text = text .. "}"
		-- Display full blacklist for copying into Transcriptor
		editBox[2]:SetText(text)
		frame[2]:ClearAllPoints()
		frame[2]:SetPoint("BOTTOMLEFT", UIParent, "CENTER")
		frame[2]:Show()

		---------------------------------------------------------------------------------
		-- SOURCELESS
		---------------------------------------------------------------------------------

		total, totalSorted = {}, {}
		auraTbl, castTbl, summonTbl = {}, {}, {}
		aurasSorted, castsSorted, summonSorted = {}, {}, {}
		ignoreList = {
			[236283] = true, -- Belac's Prisoner
			[236516] = true, -- Twilight Volley
			[236519] = true, -- Moon Burn
			[237351] = true, -- Lunar Barrage
			[240706] = true, -- Arcane Ward
			[241032] = true, -- Desolation of the Moon
			[241169] = true, -- Umbra Destruction
			[236011] = true, -- Tormented Cries
			[236241] = true, -- Soul Rot
			[236459] = true, -- Soulbind
			[235534] = true, -- Creator's Grace
			[235538] = true, -- Demon's Vigor
			[236420] = true, -- Aegwynn's Ward
			[240209] = true, -- Unstable Soul
			[240249] = true, -- Molten Fel
			[243267] = true, -- Velen's Light
			[231768] = true, -- Drenching Waters
			[231770] = true, -- Drenched
			[232732] = true, -- Slicing Tornado
			[232913] = true, -- Befouling Ink
			[234621] = true, -- Devouring Maw
			[236329] = true, -- Star Burn
			[243294] = true, -- Fel Slicer
			[238442] = true, -- Spear of Anguish
			[241593] = true, -- Aegwynn's Ward
			[236555] = true, -- Deceiver's Veil
			[241721] = true, -- Illidan's Sightless Gaze
			[241822] = true, -- Choking Shadow
			[242696] = true, -- Deceiver's Veil
			[230345] = true, -- Crashing Comet
			[230348] = true, -- Fel Pool
			[233901] = true, -- Suffocating Dark
		}
		local eventsNoSource = {
			"SPELL_AURA_[AR][^#]+#(%d+)##([^#]+)#([^#]+%-[^#]+)#([^#]+)#(%d+)#([^#]+)#", -- SPELL_AURA_[AR] to filter _BROKEN
			"SPELL_CAST_[^#]+#(%d+)##([^#]+)#([^#]+%-[^#]+)#([^#]+)#(%d+)#([^#]+)#",
			"SPELL_SUMMON#(%d+)##([^#]+)#([^#]+%-[^#]+)#([^#]+)#(%d+)#([^#]+)#"
		}
		tables = {
			auraTbl,
			castTbl,
			summonTbl,
		}
		sortedTables = {
			aurasSorted,
			castsSorted,
			summonSorted,
		}
		for logName, logTbl in next, TranscriptDB do
			if type(logTbl) == "table" and logTbl.total then
				for i=1, #logTbl.total do
					local text = logTbl.total[i]

					for j = 1, 3 do
						local flagsText, name, destGUID, tarName, idText = text:match(eventsNoSource[j])
						local id = tonumber(idText)
						local flags = tonumber(flagsText)
						local tbl = tables[j]
						local sortedTbl = sortedTables[j]
						if name == "nil" and id and flags and band(flags, mineOrPartyOrRaid) ~= 0 and not ignoreList[id] and not badSourcelessPlayerSpellList[id] and not total[id] and #sortedTbl < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
							tbl[id] = tarName:gsub("%-.+", "*")
							total[id] = true
							sortedTbl[#sortedTbl+1] = id
						end
					end
				end
			end
		end

		sort(aurasSorted)
		local text = "-- AURAS\n"
		for i = 1, #aurasSorted do
			local id = aurasSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, auraTbl[id])
		end

		sort(castsSorted)
		text = text.. "\n-- CASTS\n"
		for i = 1, #castsSorted do
			local id = castsSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, castTbl[id])
		end

		sort(summonSorted)
		text = text.. "\n-- SUMMONS\n"
		for i = 1, #summonSorted do
			local id = summonSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s%d || |cFFFFFF00|Hspell:%d|h%s|h|r || %s\n", text, id, id, name, summonTbl[id])
		end

		-- Display newly found spells for analysis
		editBox[3]:SetText(text)
		frame[3]:ClearAllPoints()
		frame[3]:SetPoint("TOPRIGHT", UIParent, "CENTER")
		frame[3]:Show()

		for k, v in next, badSourcelessPlayerSpellList do
			total[k] = true
		end
		for k, v in next, total do
			totalSorted[#totalSorted+1] = k
		end
		sort(totalSorted)
		text = ""
		for i = 1, #totalSorted do
			local id = totalSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s[%d] = true, -- %s\n", text, id, name)
		end

		-- Display full blacklist for copying into Transcriptor
		editBox[4]:SetText(text)
		frame[4]:ClearAllPoints()
		frame[4]:SetPoint("TOPLEFT", UIParent, "CENTER")
		frame[4]:Show()
	end
	SlashCmdList["GETSPELLS"] = GetLogSpells
	SLASH_GETSPELLS1 = "/getspells"
end

--------------------------------------------------------------------------------
-- Localization
--

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
L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"

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
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
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
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
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
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
	elseif locale == "koKR" then
		L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "최상의 기록을 얻으려면 전멸이나 우두머리 처치 후에 Transcriptor를 중지하고 시작하는 걸 기억하세요."
		L["You are already logging an encounter."] = "이미 우두머리 전투를 기록 중입니다."
		L["Beginning Transcript: "] = "기록 시작: "
		L["You are not logging an encounter."] = "우두머리 전투를 기록하고 있지 않습니다."
		L["Ending Transcript: "] = "기록 종료: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "재기록하거나 사용자 인터페이스를 다시 불러오면 WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua에 기록이 저장됩니다."
		L["All transcripts cleared."] = "모든 기록이 초기화되었습니다."
		L["You can't clear your transcripts while logging an encounter."] = "우두머리 전투를 기록 중일 때는 기록을 초기화 할 수 없습니다."
		L["|cff696969Idle|r"] = "|cff696969대기|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f클릭|r - 기록을 시작하거나 중지합니다.\n|cffeda55f오른쪽-클릭|r - 이벤트를 구성합니다.\n|cffeda55fAlt-가운데 클릭|r - 저장된 모든 기록을 초기화합니다."
		L["|cffFF0000Recording|r"] = "|cffFF0000기록 중|r"
		L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - 비활성된 이벤트"
	elseif locale == "ruRU" then
		L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."] = "Чтобы получить лучшие записи боя, не забудьте остановить и запустить Transcriptor между вайпом или убийством босса."
		L["You are already logging an encounter."] = "Вы уже записываете бой."
		L["Beginning Transcript: "] = "Начало записи: "
		L["You are not logging an encounter."] = "Вы не записываете бой."
		L["Ending Transcript: "] = "Окончание записи: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "Записи боя будут записаны в WoW\\WTF\\Account\\<название>\\SavedVariables\\Transcriptor.lua после того как вы перезайдете или перезагрузите пользовательский интерфейс."
		L["All transcripts cleared."] = "Все записи очищены."
		L["You can't clear your transcripts while logging an encounter."] = "Вы не можете очистить ваши записи пока идет запись боя."
		L["|cff696969Idle|r"] = "|cff696969Ожидание|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55fЛКМ|r - запустить или остановить запись.\n|cffeda55fПКМ|r - настройка событий.\n|cffeda55fAlt-СКМ|r - очистить все сохраненные записи."
		L["|cffFF0000Recording|r"] = "|cffFF0000Запись|r"
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
	end
end

--------------------------------------------------------------------------------
-- Events
--

local eventFrame = CreateFrame("Frame")
eventFrame:Hide()
local sh = {}

--[[
	UIWidget

	see https://wow.gamepedia.com/UPDATE_UI_WIDGET

	widgetID =
		The Black Morass: 507 (health), 527 (waves)
		The Violet Hold (WotLK): 565 (health), 566 (waves)
]]
do
	local blackList = {
		[1309] = true, -- C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(1309)
		[1311] = true, -- C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(1311)
		[1313] = true, -- C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(1313)
		[1315] = true, -- C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(1315)
		[1317] = true, -- C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(1317)
		[1319] = true, -- C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(1319)

		--[[ Shadowlands - Castle Nathria ]]--
		[2436] = true, -- Lady Inerva Darkvein, static icon (widgetType:13)
		[2437] = true, -- Lady Inerva Darkvein, static icon (widgetType:13)
		[2438] = true, -- Lady Inerva Darkvein, static icon (widgetType:13)
		[2439] = true, -- Lady Inerva Darkvein, static icon (widgetType:13)

		[3457] = true, -- Stone Soup
	}

	-- Each widgetType has a different function to get all data for the widget.
	-- Those function names are consistent with the enum.
	local widgetFuncs = {}
	for name,n in pairs(Enum.UIWidgetVisualizationType) do
		widgetFuncs[n] = C_UIWidgetManager["Get"..name.. "WidgetVisualizationInfo"] or C_UIWidgetManager["Get"..name.."VisualizationInfo"]
	end

	function sh.UPDATE_UI_WIDGET(tbl)
		if blackList[tbl.widgetID] then return end

		-- Store widget data, so we're able to only add changes to the log
		if not currentLog.WIDGET then currentLog.WIDGET = {} end

		local txt
		if not currentLog.WIDGET[tbl.widgetID] then -- New widget in this log
			currentLog.WIDGET[tbl.widgetID] = {}
			for k, v in next, tbl do
				if not txt then
					txt = format("%s:%s", k, v)
				else
					txt = format("%s, %s:%s", txt, k, v)
				end
			end
		else -- Shorter output with just the id
			txt = format("%s:%s", "widgetID", tbl.widgetID)
		end

		if tbl.widgetType and widgetFuncs[tbl.widgetType] then
			local t = widgetFuncs[tbl.widgetType](tbl.widgetID)
			if t then
				for k, v in next, t do
					if type(v) == "table" then -- We don't care about data in tables
						v = "table"
					elseif type(v) == "boolean" then -- Needs to be done manually in Lua 5.1
						v = tostring(v)
					end

					-- Only add data to log if it's new or it changed to reduce spam
					if not currentLog.WIDGET[tbl.widgetID][k] or currentLog.WIDGET[tbl.widgetID][k] ~= v then
						currentLog.WIDGET[tbl.widgetID][k] = v
						txt = format("%s, %s:%s", txt, k, v)
					end
				end
			end
		end

		return txt
	end
end

do
	badSourcelessPlayerSpellList = {
		[81782] = true, -- Power Word: Barrier
	}
	local badPlayerFilteredEvents = {
		["SPELL_CAST_SUCCESS"] = true,
		["SPELL_AURA_APPLIED"] = true,
		["SPELL_AURA_APPLIED_DOSE"] = true,
		["SPELL_AURA_REFRESH"] = true,
		["SPELL_AURA_REMOVED"] = true,
		["SPELL_AURA_REMOVED_DOSE"] = true,
		["SPELL_CAST_START"] = true,
		["SPELL_SUMMON"] = true,
		--"<87.10 17:55:03> [CLEU] SPELL_AURA_BROKEN_SPELL#Creature-0-3771-1676-28425-118022-000004A6B5#Infernal Chaosbringer#Player-XYZ#XYZ#115191#Stealth#242906#Immolation Aura", -- [148]
		--"<498.56 22:02:38> [CLEU] SPELL_AURA_BROKEN_SPELL#Creature-0-3895-1676-10786-106551-00008631CC-TSGuardian#Hati#Creature-0-3895-1676-10786-120697-000086306F#Worshiper of Elune#206961#Tremble Before Me#118459#Beast Cleave", -- [8039]
		--["SPELL_AURA_BROKEN_SPELL"] = true,
	}
	local badPlayerEvents = {
		["SPELL_DAMAGE"] = true,
		["SPELL_MISSED"] = true,

		["SWING_DAMAGE"] = true,
		["SWING_MISSED"] = true,

		["RANGE_DAMAGE"] = true,
		["RANGE_MISSED"] = true,

		["SPELL_PERIODIC_DAMAGE"] = true,
		["SPELL_PERIODIC_MISSED"] = true,

		["DAMAGE_SPLIT"] = true,

		["SPELL_HEAL"] = true,
		["SPELL_PERIODIC_HEAL"] = true,

		["SPELL_ENERGIZE"] = true,
		["SPELL_PERIODIC_ENERGIZE"] = true,
	}
	local badEvents = {
		["SPELL_ABSORBED"] = true,
		["SPELL_CAST_FAILED"] = true,
	}
	local guardian = 8192 -- COMBATLOG_OBJECT_TYPE_GUARDIAN
	local dmgCache, dmgPrdcCache = {}, {}
	local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
	-- Note some things we are trying to avoid filtering:
	-- BRF/Kagraz - Player damage with no source "SPELL_DAMAGE##nil#Player-GUID#PLAYER#154938#Molten Torrent#"
	-- HFC/Socrethar - Player cast on friendly vehicle "SPELL_CAST_SUCCESS#Player-GUID#PLAYER#Vehicle-0-3151-1448-8853-90296-00001D943C#Soulbound Construct#190466#Incomplete Binding"
	-- HFC/Zakuun - Player boss debuff cast on self "SPELL_AURA_APPLIED#Player-GUID#PLAYER#Player-GUID#PLAYER#189030#Befouled#DEBUFF#"
	-- ToS/Sisters - Boss pet marked as guardian "SPELL_CAST_SUCCESS#Creature-0-3895-1676-10786-119205-0000063360#Moontalon##nil#236697#Deathly Screech"
	function sh.COMBAT_LOG_EVENT_UNFILTERED()
		local timeStamp, event, caster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, _, extraSpellId, amount = CombatLogGetCurrentEventInfo()

		if (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED") and not hiddenAuraPermList[spellId] then
			hiddenAuraPermList[spellId] = true
		end

		if badEvents[event] or
		   (event == "UNIT_DIED" and band(destFlags, mineOrPartyOrRaid) ~= 0 and band(destFlags, guardian) == guardian) or -- Guardian deaths, player deaths can explain debuff removal
		   (sourceName and badPlayerEvents[event] and band(sourceFlags, mineOrPartyOrRaid) ~= 0) or
		   (sourceName and badPlayerFilteredEvents[event] and playerSpellBlacklist[spellId] and band(sourceFlags, mineOrPartyOrRaid) ~= 0) or
		   (not sourceName and destName and badPlayerFilteredEvents[event] and badSourcelessPlayerSpellList[spellId] and band(destFlags, mineOrPartyOrRaid) ~= 0) or
		   -- Temporary (hopefully) hacks, due to srcFlags not correctly attributing as mineOrPartyOrRaid
		   (spellId == 120694 and sourceName == "Beast" and band(destFlags, mineOrPartyOrRaid) ~= 0) -- Dire Beast from summoned creature to player
		then
			return
		else
			--if (sourceName and badPlayerFilteredEvents[event] and playerSpellBlacklist[spellId] and band(sourceFlags, mineOrPartyOrRaid) == 0) then
			--	print("Transcriptor:", sourceName..":"..MobId(sourceGUID), "used spell", spellName..":"..spellId, "in event", event, "but isn't in our group.")
			--end

			if event == "SPELL_CAST_SUCCESS" and (not sourceName or (band(sourceFlags, mineOrPartyOrRaid) == 0 and not find(sourceGUID, "Player", nil, true))) then
				if not compareSuccess then compareSuccess = {} end
				if not compareSuccess[spellId] then compareSuccess[spellId] = {} end
				local npcId = MobId(sourceGUID, true)
				if not compareSuccess[spellId][npcId] then
					if previousSpecialEvent then
						compareSuccess[spellId][npcId] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2]}}
					else
						compareSuccess[spellId][npcId] = {compareStartTime}
					end
				end
				compareSuccess[spellId][npcId][#compareSuccess[spellId][npcId]+1] = debugprofilestop()
			end
			if event == "SPELL_CAST_START" and (not sourceName or (band(sourceFlags, mineOrPartyOrRaid) == 0 and not find(sourceGUID, "Player", nil, true))) then
				if not compareStart then compareStart = {} end
				if not compareStart[spellId] then compareStart[spellId] = {} end
				local npcId = MobId(sourceGUID, true)
				if not compareStart[spellId][npcId] then
					if previousSpecialEvent then
						compareStart[spellId][npcId] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2]}}
					else
						compareStart[spellId][npcId] = {compareStartTime}
					end
				end
				compareStart[spellId][npcId][#compareStart[spellId][npcId]+1] = debugprofilestop()
			end
			if event == "SPELL_AURA_APPLIED" and (not sourceName or (band(sourceFlags, mineOrPartyOrRaid) == 0 and not find(sourceGUID, "Player", nil, true))) then
				if not compareAuraApplied then compareAuraApplied = {} end
				if not compareAuraApplied[spellId] then compareAuraApplied[spellId] = {} end
				local npcId = MobId(sourceGUID, true)
				if not compareAuraApplied[spellId][npcId] then
					if previousSpecialEvent then
						compareAuraApplied[spellId][npcId] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2]}}
					else
						compareAuraApplied[spellId][npcId] = {compareStartTime}
					end
				end
				compareAuraApplied[spellId][npcId][#compareAuraApplied[spellId][npcId]+1] = debugprofilestop()
			end

			if sourceName and badPlayerFilteredEvents[event] and band(sourceFlags, mineOrPartyOrRaid) ~= 0 then
				if not collectPlayerAuras then collectPlayerAuras = {} end
				if not collectPlayerAuras[spellId] then collectPlayerAuras[spellId] = {} end
				if not collectPlayerAuras[spellId][event] then collectPlayerAuras[spellId][event] = true end
			end

			if event == "UNIT_DIED" then
				local name = specialEvents.UNIT_DIED[MobId(destGUID)]
				if name then
					InsertSpecialEvent(name)
				end
			elseif specialEvents[event] and specialEvents[event][spellId] then
				local name = specialEvents[event][spellId][MobId(sourceGUID)]
				if name then
					InsertSpecialEvent(name)
				end
			end

			if event == "SPELL_DAMAGE" or event == "SPELL_MISSED" then
				if dmgPrdcCache.spellId then
					if dmgPrdcCache.count == 1 then
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
					else
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_PERIODIC_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.count, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
					end
					dmgPrdcCache.spellId = nil
				end

				if spellId == dmgCache.spellId then
					if timeStamp - dmgCache.timeStamp > 0.2 then
						if dmgCache.count == 1 then
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.count, dmgCache.spellId, dmgCache.spellName)
						end
						dmgCache.spellId = spellId
						dmgCache.sourceGUID = sourceGUID
						dmgCache.sourceName = sourceName or "nil"
						dmgCache.spellName = spellName
						dmgCache.timeStop = (debugprofilestop() / 1000) - logStartTime
						dmgCache.time = date("%H:%M:%S")
						dmgCache.timeStamp = timeStamp
						dmgCache.count = 1
						dmgCache.event = event
						dmgCache.destGUID = destGUID
						dmgCache.destName = destName
					else
						dmgCache.count = dmgCache.count + 1
					end
				else
					if dmgCache.spellId then
						if dmgCache.count == 1 then
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.count, dmgCache.spellId, dmgCache.spellName)
						end
					end
					dmgCache.spellId = spellId
					dmgCache.sourceGUID = sourceGUID
					dmgCache.sourceName = sourceName or "nil"
					dmgCache.spellName = spellName
					dmgCache.timeStop = (debugprofilestop() / 1000) - logStartTime
					dmgCache.time = date("%H:%M:%S")
					dmgCache.timeStamp = timeStamp
					dmgCache.count = 1
					dmgCache.event = event
					dmgCache.destGUID = destGUID
					dmgCache.destName = destName
				end
			elseif event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_PERIODIC_MISSED" then
				if dmgCache.spellId then
					if dmgCache.count == 1 then
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
					else
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.count, dmgCache.spellId, dmgCache.spellName)
					end
					dmgCache.spellId = nil
				end

				if spellId == dmgPrdcCache.spellId then
					if timeStamp - dmgPrdcCache.timeStamp > 0.2 then
						if dmgPrdcCache.count == 1 then
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_PERIODIC_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.count, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						end
						dmgPrdcCache.spellId = spellId
						dmgPrdcCache.sourceGUID = sourceGUID
						dmgPrdcCache.sourceName = sourceName or "nil"
						dmgPrdcCache.spellName = spellName
						dmgPrdcCache.timeStop = (debugprofilestop() / 1000) - logStartTime
						dmgPrdcCache.time = date("%H:%M:%S")
						dmgPrdcCache.timeStamp = timeStamp
						dmgPrdcCache.count = 1
						dmgPrdcCache.event = event
						dmgPrdcCache.destGUID = destGUID
						dmgPrdcCache.destName = destName
					else
						dmgPrdcCache.count = dmgPrdcCache.count + 1
					end
				else
					if dmgPrdcCache.spellId then
						if dmgPrdcCache.count == 1 then
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						else
							currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_PERIODIC_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.count, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
						end
					end
					dmgPrdcCache.spellId = spellId
					dmgPrdcCache.sourceGUID = sourceGUID
					dmgPrdcCache.sourceName = sourceName or "nil"
					dmgPrdcCache.spellName = spellName
					dmgPrdcCache.timeStop = (debugprofilestop() / 1000) - logStartTime
					dmgPrdcCache.time = date("%H:%M:%S")
					dmgPrdcCache.timeStamp = timeStamp
					dmgPrdcCache.count = 1
					dmgPrdcCache.event = event
					dmgPrdcCache.destGUID = destGUID
					dmgPrdcCache.destName = destName
				end
			else
				if dmgCache.spellId then
					if dmgCache.count == 1 then
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.event, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.destGUID, dmgCache.destName, dmgCache.spellId, dmgCache.spellName)
					else
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgCache.timeStop, dmgCache.time, dmgCache.sourceGUID, dmgCache.sourceName, dmgCache.count, dmgCache.spellId, dmgCache.spellName)
					end
					dmgCache.spellId = nil
				elseif dmgPrdcCache.spellId then
					if dmgPrdcCache.count == 1 then
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s#%s#%s#%s#%s#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.event, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.destGUID, dmgPrdcCache.destName, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
					else
						currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] SPELL_PERIODIC_DAMAGE[CONDENSED]#%s#%s#%d Targets#%d#%s", dmgPrdcCache.timeStop, dmgPrdcCache.time, dmgPrdcCache.sourceGUID, dmgPrdcCache.sourceName, dmgPrdcCache.count, dmgPrdcCache.spellId, dmgPrdcCache.spellName)
					end
					dmgPrdcCache.spellId = nil
				end

				if shouldLogFlags and (sourceName or destName) and badPlayerFilteredEvents[event] then
					return strjoin("#", tostringall(event, sourceName and sourceFlags or destFlags, sourceGUID, sourceName, destGUID, destName, spellId, spellName, extraSpellId, amount))
				else
					return strjoin("#", tostringall(event, sourceGUID, sourceName, destGUID, destName, spellId, spellName, extraSpellId, amount))
				end
			end
		end
	end
end

function sh.PLAYER_REGEN_DISABLED()
	return "+Entering combat!"
end
function sh.PLAYER_REGEN_ENABLED()
	return "-Leaving combat!"
end

do
	local UnitIsUnit = UnitIsUnit
	local wantedUnits = {
		target = true, focus = true,
		nameplate1 = true, nameplate2 = true, nameplate3 = true, nameplate4 = true, nameplate5 = true, nameplate6 = true, nameplate7 = true, nameplate8 = true, nameplate9 = true, nameplate10 = true,
		nameplate11 = true, nameplate12 = true, nameplate13 = true, nameplate14 = true, nameplate15 = true, nameplate16 = true, nameplate17 = true, nameplate18 = true, nameplate19 = true, nameplate20 = true,
		nameplate21 = true, nameplate22 = true, nameplate23 = true, nameplate24 = true, nameplate25 = true, nameplate26 = true, nameplate27 = true, nameplate28 = true, nameplate29 = true, nameplate30 = true,
		nameplate31 = true, nameplate32 = true, nameplate33 = true, nameplate34 = true, nameplate35 = true, nameplate36 = true, nameplate37 = true, nameplate38 = true, nameplate39 = true, nameplate40 = true,
	}
	local bossUnits = {
		boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
		boss6 = true, boss7 = true, boss8 = true, boss9 = true, boss10 = true,
		boss11 = true, boss12 = true, boss13 = true, boss14 = true, boss15 = true,
		arena1 = true, arena2 = true, arena3 = true, arena4 = true, arena5 = true,
	}
	local raidList = {
		raid1 = true, raid2 = true, raid3 = true, raid4 = true, raid5 = true, raid6 = true, raid7 = true, raid8 = true, raid9 = true, raid10 = true,
		raid11 = true, raid12 = true, raid13 = true, raid14 = true, raid15 = true, raid16 = true, raid17 = true, raid18 = true, raid19 = true, raid20 = true,
		raid21 = true, raid22 = true, raid23 = true, raid24 = true, raid25 = true, raid26 = true, raid27 = true, raid28 = true, raid29 = true, raid30 = true,
		raid31 = true, raid32 = true, raid33 = true, raid34 = true, raid35 = true, raid36 = true, raid37 = true, raid38 = true, raid39 = true, raid40 = true
	}
	local function safeUnit(unit)
		if bossUnits[unit] then -- Accept any boss unit
			return true
		elseif wantedUnits[unit] and not UnitIsUnit("player", unit) and not UnitInRaid(unit) and not UnitInParty(unit) then
			for k in next, bossUnits do
				if UnitIsUnit(unit, k) then -- Reject if the unit is also a boss unit
					return false
				end
			end
			return true
		end
	end

	function sh.UNIT_SPELLCAST_STOP(unit, castId, spellId, ...)
		if safeUnit(unit) then
			return format("%s(%s) -%s- [[%s]]", UnitName(unit), UnitName(unit.."target"), GetSpellInfo(spellId), strjoin(":", tostringall(unit, castId, spellId, ...)))
		end
	end
	sh.UNIT_SPELLCAST_CHANNEL_STOP = sh.UNIT_SPELLCAST_STOP

	function sh.UNIT_SPELLCAST_INTERRUPTED(unit, castId, spellId, ...)
		if safeUnit(unit) then
			if specialEvents.UNIT_SPELLCAST_INTERRUPTED[spellId] then
				local name = specialEvents.UNIT_SPELLCAST_INTERRUPTED[spellId][MobId(UnitGUID(unit))]
				if name then
					InsertSpecialEvent(name)
				end
			end

			return format("%s(%s) -%s- [[%s]]", UnitName(unit), UnitName(unit.."target"), GetSpellInfo(spellId), strjoin(":", tostringall(unit, castId, spellId, ...)))
		end
	end

	local prevCast = nil
	function sh.UNIT_SPELLCAST_SUCCEEDED(unit, castId, spellId, ...)
		if safeUnit(unit) then
			if castId ~= prevCast then
				prevCast = castId
				if not compareUnitSuccess then compareUnitSuccess = {} end
				if not compareUnitSuccess[spellId] then compareUnitSuccess[spellId] = {} end
				local npcId = MobId(UnitGUID(unit), true)
				if not compareUnitSuccess[spellId][npcId] then
					if previousSpecialEvent then
						compareUnitSuccess[spellId][npcId] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2]}}
					else
						compareUnitSuccess[spellId][npcId] = {compareStartTime}
					end
				end
				compareUnitSuccess[spellId][npcId][#compareUnitSuccess[spellId][npcId]+1] = debugprofilestop()

				if specialEvents.UNIT_SPELLCAST_SUCCEEDED[spellId] then
					local npcIdBasic = MobId((UnitGUID(unit)))
					local name = specialEvents.UNIT_SPELLCAST_SUCCEEDED[spellId][npcIdBasic]
					if name then
						InsertSpecialEvent(name)
					end
				end
			end

			return format("%s(%s) -%s- [[%s]]", UnitName(unit), UnitName(unit.."target"), GetSpellInfo(spellId), strjoin(":", tostringall(unit, castId, spellId, ...)))
		elseif raidList[unit] and not playerSpellBlacklist[spellId] then
			if not playerSpellCollector[spellId] then
				playerSpellCollector[spellId] = strjoin("#", tostringall(spellId, GetSpellInfo(spellId), unit, UnitName(unit)))
			end
			return format("PLAYER_SPELL(%s) -%s- [[%s]]", UnitName(unit), GetSpellInfo(spellId), strjoin(":", tostringall(unit, castId, spellId, ...)))
		end
	end
	function sh.UNIT_SPELLCAST_START(unit, castId, spellId, ...)
		if safeUnit(unit) then
			local _, _, _, startTime, endTime = UnitCastingInfo(unit)
			local time = ((endTime or 0) - (startTime or 0)) / 1000
			return format("%s(%s) - %s - %ss [[%s]]", UnitName(unit), UnitName(unit.."target"), GetSpellInfo(spellId), time, strjoin(":", tostringall(unit, castId, spellId, ...)))
		end
	end
	function sh.UNIT_SPELLCAST_CHANNEL_START(unit, castId, spellId, ...)
		if safeUnit(unit) then
			local _, _, _, startTime, endTime = UnitChannelInfo(unit)
			local time = ((endTime or 0) - (startTime or 0)) / 1000
			return format("%s(%s) - %s - %ss [[%s]]", UnitName(unit), UnitName(unit.."target"), GetSpellInfo(spellId), time, strjoin(":", tostringall(unit, castId, spellId, ...)))
		end
	end

	function sh.UNIT_TARGET(unit)
		if safeUnit(unit) then
			return format("%s#%s#Target: %s#TargetOfTarget: %s", unit, tostring(UnitName(unit)), tostring(UnitName(unit.."target")), tostring(UnitName(unit.."targettarget")))
		end
	end
end

function sh.PLAYER_TARGET_CHANGED()
	local guid = UnitGUID("target")
	if guid and not UnitInRaid("target") and not UnitInParty("target") then
		local level = UnitLevel("target") or "nil"
		local reaction = "Hostile"
		if UnitIsFriend("target", "player") then reaction = "Friendly" end
		local classification = UnitClassification("target") or "nil"
		local creatureType = UnitCreatureType("target") or "nil"
		local typeclass = classification == "normal" and creatureType or (classification.." "..creatureType)
		local name = UnitName("target")
		return (format("%s %s (%s) - %s # %s", tostring(level), tostring(reaction), tostring(typeclass), tostring(name), tostring(guid)))
	end
end

function sh.INSTANCE_ENCOUNTER_ENGAGE_UNIT(...)
	return strjoin("#", tostringall("Fake Args:",
		"boss1", UnitCanAttack("player", "boss1"), UnitExists("boss1"), UnitIsVisible("boss1"), UnitName("boss1"), UnitGUID("boss1"), UnitClassification("boss1"), UnitHealth("boss1"),
		"boss2", UnitCanAttack("player", "boss2"), UnitExists("boss2"), UnitIsVisible("boss2"), UnitName("boss2"), UnitGUID("boss2"), UnitClassification("boss2"), UnitHealth("boss2"),
		"boss3", UnitCanAttack("player", "boss3"), UnitExists("boss3"), UnitIsVisible("boss3"), UnitName("boss3"), UnitGUID("boss3"), UnitClassification("boss3"), UnitHealth("boss3"),
		"boss4", UnitCanAttack("player", "boss4"), UnitExists("boss4"), UnitIsVisible("boss4"), UnitName("boss4"), UnitGUID("boss4"), UnitClassification("boss4"), UnitHealth("boss4"),
		"boss5", UnitCanAttack("player", "boss5"), UnitExists("boss5"), UnitIsVisible("boss5"), UnitName("boss5"), UnitGUID("boss5"), UnitClassification("boss5"), UnitHealth("boss5"),
		"Real Args:", ...)
	)
end

function sh.UNIT_TARGETABLE_CHANGED(unit)
	return format("-%s- [CanAttack:%s#Exists:%s#IsVisible:%s#Name:%s#GUID:%s#Classification:%s#Health:%s]", tostringall(unit, UnitCanAttack("player", unit), UnitExists(unit), UnitIsVisible(unit), UnitName(unit), UnitGUID(unit), UnitClassification(unit), (UnitHealth(unit))))
end

do
	local allowedPowerUnits = {
		boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
		boss6 = true, boss7 = true, boss8 = true, boss9 = true, boss10 = true,
		boss11 = true, boss12 = true, boss13 = true, boss14 = true, boss15 = true,
		arena1 = true, arena2 = true, arena3 = true, arena4 = true, arena5 = true,
		arenapet1 = true, arenapet2 = true, arenapet3 = true, arenapet4 = true, arenapet5 = true
	}
	function sh.UNIT_POWER_UPDATE(unit, typeName)
		if not allowedPowerUnits[unit] then return end
		local powerType = format("TYPE:%s/%d", typeName, UnitPowerType(unit))
		local mainPower = format("MAIN:%d/%d", UnitPower(unit), UnitPowerMax(unit))
		local altPower = format("ALT:%d/%d", UnitPower(unit, 10), UnitPowerMax(unit, 10))
		return strjoin("#", unit, UnitName(unit), powerType, mainPower, altPower)
	end
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

function sh.CINEMATIC_START(...)
	local id = -(GetBestMapForUnit("player"))
	return strjoin("#", "uiMapID:", id, "Real Args:", tostringall(...))
end

function sh.CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if prefix == "Transcriptor" then
		return strjoin("#", "RAID_BOSS_WHISPER_SYNC", msg, sender)
	end
end

function sh.ENCOUNTER_START(...)
	compareStartTime = debugprofilestop()
	wipe(data)
	return strjoin("#", ...)
end

function sh.CHAT_MSG_RAID_BOSS_EMOTE(msg, npcName, ...)
	local id = msg:match("|Hspell:([^|]+)|h")
	if id then
		local spellId = tonumber(id)
		if spellId then
			if not compareEmotes then compareEmotes = {} end
			if not compareEmotes[spellId] then compareEmotes[spellId] = {} end
			if not compareEmotes[spellId][npcName] then
				if previousSpecialEvent then
					compareEmotes[spellId][npcName] = {{compareStartTime, previousSpecialEvent[1], previousSpecialEvent[2]}}
				else
					compareEmotes[spellId][npcName] = {compareStartTime}
				end
			end
			compareEmotes[spellId][npcName][#compareEmotes[spellId][npcName]+1] = debugprofilestop()
		end
	end
	return strjoin("#", msg, npcName, tostringall(...))
end

do
	local UnitAura = UnitAura
	function sh.UNIT_AURA(unit)
		for i = 1, 100 do
			local name, _, _, _, duration, _, _, _, _, spellId, _, bossDebuff = UnitAura(unit, i, "HARMFUL")
			if not spellId then
				break
			elseif not hiddenAuraEngageList[spellId] and not hiddenUnitAuraCollector[spellId] and not playerSpellBlacklist[spellId] then
				if UnitIsVisible(unit) then
					if bossDebuff then
						hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall("BOSS_DEBUFF", spellId, name, duration, unit, UnitName(unit)))
					else
						hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall(spellId, name, duration, unit, UnitName(unit)))
					end
				else -- If it's not visible it may not show up in CLEU, use this as an indicator of a false positive
					hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall("UNIT_NOT_VISIBLE", spellId, name, duration, unit, UnitName(unit)))
				end
			end
		end
		for i = 1, 100 do
			local name, _, _, _, duration, _, _, _, _, spellId, _, bossDebuff = UnitAura(unit, i, "HELPFUL")
			if not spellId then
				break
			elseif not hiddenAuraEngageList[spellId] and not hiddenUnitAuraCollector[spellId] and not playerSpellBlacklist[spellId] then
				if UnitIsVisible(unit) then
					if bossDebuff then
						hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall("BOSS_BUFF", spellId, name, duration, unit, UnitName(unit)))
					else
						hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall(spellId, name, duration, unit, UnitName(unit)))
					end
				else -- If it's not visible it may not show up in CLEU, use this as an indicator of a false positive
					hiddenUnitAuraCollector[spellId] = strjoin("#", tostringall("UNIT_NOT_VISIBLE", spellId, name, duration, unit, UnitName(unit)))
				end
			end
		end
	end
end

function sh.NAME_PLATE_UNIT_ADDED(unit)
	local guid = UnitGUID(unit)
	if not collectNameplates[guid] then
		collectNameplates[guid] = true
		local name = UnitName(unit)
		return strjoin("#", name, guid)
	end
end

local wowEvents = {
	-- Raids
	"CHAT_MSG_ADDON",
	"CHAT_MSG_RAID_WARNING",
	"COMBAT_LOG_EVENT_UNFILTERED",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"CHAT_MSG_MONSTER_EMOTE",
	"CHAT_MSG_MONSTER_SAY",
	"CHAT_MSG_MONSTER_WHISPER",
	"CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"CHAT_MSG_RAID_BOSS_WHISPER",
	"RAID_BOSS_EMOTE",
	"RAID_BOSS_WHISPER",
	"PLAYER_TARGET_CHANGED",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_POWER_UPDATE",
	"UPDATE_UI_WIDGET",
	"UNIT_AURA",
	"UNIT_TARGET",
	"INSTANCE_ENCOUNTER_ENGAGE_UNIT",
	"UNIT_TARGETABLE_CHANGED",
	"ENCOUNTER_START",
	"ENCOUNTER_END",
	"BOSS_KILL",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
	"NAME_PLATE_UNIT_ADDED",
	-- Scenarios
	"SCENARIO_UPDATE",
	"SCENARIO_CRITERIA_UPDATE",
	-- Movies
	"PLAY_MOVIE",
	"CINEMATIC_START",
	-- Battlegrounds
	"START_TIMER",
	"CHAT_MSG_BG_SYSTEM_HORDE",
	"CHAT_MSG_BG_SYSTEM_ALLIANCE",
	"CHAT_MSG_BG_SYSTEM_NEUTRAL",
	"ARENA_OPPONENT_UPDATE",
}
local eventCategories = {
	PLAYER_REGEN_DISABLED = "COMBAT",
	PLAYER_REGEN_ENABLED = "COMBAT",
	ENCOUNTER_START = "COMBAT",
	ENCOUNTER_END = "COMBAT",
	BOSS_KILL = "COMBAT",
	INSTANCE_ENCOUNTER_ENGAGE_UNIT = "COMBAT",
	UNIT_TARGETABLE_CHANGED = "COMBAT",
	CHAT_MSG_MONSTER_EMOTE = "MONSTER",
	CHAT_MSG_MONSTER_SAY = "MONSTER",
	CHAT_MSG_MONSTER_WHISPER = "MONSTER",
	CHAT_MSG_MONSTER_YELL = "MONSTER",
	CHAT_MSG_RAID_BOSS_EMOTE = "MONSTER",
	CHAT_MSG_RAID_BOSS_WHISPER = "MONSTER",
	RAID_BOSS_EMOTE = "MONSTER",
	RAID_BOSS_WHISPER = "MONSTER",
	UNIT_SPELLCAST_START = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_STOP = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_SUCCEEDED = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_INTERRUPTED = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_CHANNEL_START = "UNIT_SPELLCAST",
	UNIT_SPELLCAST_CHANNEL_STOP = "UNIT_SPELLCAST",
	UNIT_TARGET = "UNIT_SPELLCAST",
	ZONE_CHANGED = "ZONE_CHANGED",
	ZONE_CHANGED_INDOORS = "ZONE_CHANGED",
	ZONE_CHANGED_NEW_AREA = "ZONE_CHANGED",
	SCENARIO_UPDATE = "SCENARIO",
	SCENARIO_CRITERIA_UPDATE = "SCENARIO",
	PLAY_MOVIE = "MOVIE",
	CINEMATIC_START = "MOVIE",
	START_TIMER = "PVP",
	CHAT_MSG_BG_SYSTEM_HORDE = "PVP",
	CHAT_MSG_BG_SYSTEM_ALLIANCE = "PVP",
	CHAT_MSG_BG_SYSTEM_NEUTRAL = "PVP",
	ARENA_OPPONENT_UPDATE = "PVP",
	BigWigs_Message = "BigWigs",
	BigWigs_StartBar = "BigWigs",
	BigWigs_SetStage = "BigWigs",
	DBM_Announce = "DBM",
	DBM_Debug = "DBM",
	DBM_TimerStart = "DBM",
	DBM_TimerStop = "DBM",
	PLAYER_TARGET_CHANGED = "NONE",
	CHAT_MSG_ADDON = "NONE",
	CHAT_MSG_RAID_WARNING = "NONE",
	NAME_PLATE_UNIT_ADDED = "NONE",
}
local bwEvents = {
	"BigWigs_Message",
	"BigWigs_StartBar",
	"BigWigs_SetStage",
}
local dbmEvents = {
	"DBM_Announce",
	"DBM_Debug",
	"DBM_TimerStart",
	"DBM_TimerStop",
}

local function eventHandler(self, event, ...)
	if TranscriptIgnore[event] then return end
	local line
	if sh[event] then
		line = sh[event](...)
	else
		line = strjoin("#", tostringall(...))
	end
	if not line then return end
	local stop = debugprofilestop() / 1000
	local t = stop - logStartTime
	local time = date("%H:%M:%S")
	-- We only have CLEU in the total log, it's way too much information to log twice.
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [CLEU] %s", t, time, line)
	else
		local text = format("<%.2f %s> [%s] %s", t, time, event, line)
		currentLog.total[#currentLog.total+1] = text
		local cat = eventCategories[event] or event
		if cat ~= "NONE" then
			if type(currentLog[cat]) ~= "table" then currentLog[cat] = {} end
			tinsert(currentLog[cat], text)
		end
	end
end
eventFrame:SetScript("OnEvent", eventHandler)
eventFrame:SetScript("OnUpdate", function()
	if not inEncounter and IsEncounterInProgress() then
		inEncounter = true
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterInProgress()] true", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterInProgress()] true", t, time))
	elseif inEncounter and not IsEncounterInProgress() then
		inEncounter = false
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterInProgress()] false", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterInProgress()] false", t, time))
	end
	if not blockingRelease and IsEncounterSuppressingRelease() then
		blockingRelease = true
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterSuppressingRelease()] true", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterSuppressingRelease()] true", t, time))
	elseif blockingRelease and not IsEncounterSuppressingRelease() then
		blockingRelease = false
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterSuppressingRelease()] false", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterSuppressingRelease()] false", t, time))
	end
	if not limitingRes and IsEncounterLimitingResurrections() then
		limitingRes = true
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		local tbl = C_DeathInfo_GetSelfResurrectOptions()
		if tbl and tbl[1] then
			currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterLimitingResurrections()] true {%s}", t, time, tbl[1].name)
			if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
			tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterLimitingResurrections()] true {%s}", t, time, tbl[1].name))
		else
			currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterLimitingResurrections()] true", t, time)
			if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
			tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterLimitingResurrections()] true", t, time))
		end
	elseif limitingRes and not IsEncounterLimitingResurrections() then
		limitingRes = false
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		currentLog.total[#currentLog.total+1] = format("<%.2f %s> [IsEncounterLimitingResurrections()] false", t, time)
		if type(currentLog.COMBAT) ~= "table" then currentLog.COMBAT = {} end
		tinsert(currentLog.COMBAT, format("<%.2f %s> [IsEncounterLimitingResurrections()] false", t, time))
	end
end)

--------------------------------------------------------------------------------
-- Addon
--

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

Transcriptor.events = {}
local function insertMenuItems(tbl)
	for i, v in next, tbl do
		tinsert(menu, {
			text = v,
			func = function() TranscriptIgnore[v] = not TranscriptIgnore[v] end,
			checked = function() return TranscriptIgnore[v] end,
			isNotRadio = true,
			keepShownOnClick = 1,
		})
		tinsert(Transcriptor.events, v)
	end
end

local init = CreateFrame("Frame")
init:SetScript("OnEvent", function(self, event)
	if type(TranscriptDB) ~= "table" then TranscriptDB = {} end
	if type(TranscriptIgnore) ~= "table" then TranscriptIgnore = {} end

	tinsert(menu, { text = L["|cFFFFD200Transcriptor|r - Disabled Events"], fontObject = "GameTooltipHeader", notCheckable = 1 })
	insertMenuItems(wowEvents)
	if BigWigsLoader then insertMenuItems(bwEvents) end
	if DBM then insertMenuItems(dbmEvents) end
	tinsert(menu, { text = CLOSE, func = function() CloseDropDownMenus() end, notCheckable = 1 })

	C_ChatInfo.RegisterAddonMessagePrefix("Transcriptor")

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

	self:UnregisterEvent(event)
	self:RegisterEvent("PLAYER_LOGOUT")
	self:SetScript("OnEvent", function()
		if Transcriptor:IsLogging() then
			Transcriptor:StopLog()
		end
	end)
end)
init:RegisterEvent("PLAYER_LOGIN")

--------------------------------------------------------------------------------
-- Logging
--

local function BWEventHandler(event, module, ...)
	if module and module.baseName == "BigWigs_CommonAuras" then return end
	eventHandler(eventFrame, event, module and module.moduleName, ...)
end

local function DBMEventHandler(...)
	eventHandler(eventFrame, ...)
end

do
	-- Ripped from BigWigs
	local raidList = {
		"raid1", "raid2", "raid3", "raid4", "raid5", "raid6", "raid7", "raid8", "raid9", "raid10",
		"raid11", "raid12", "raid13", "raid14", "raid15", "raid16", "raid17", "raid18", "raid19", "raid20",
		"raid21", "raid22", "raid23", "raid24", "raid25", "raid26", "raid27", "raid28", "raid29", "raid30",
		"raid31", "raid32", "raid33", "raid34", "raid35", "raid36", "raid37", "raid38", "raid39", "raid40"
	}
	local partyList = {"player", "party1", "party2", "party3", "party4"}
	local GetNumGroupMembers, IsInRaid = GetNumGroupMembers, IsInRaid
	function Transcriptor:IterateGroup()
		local num = GetNumGroupMembers() or 0
		local i = 0
		local size = num > 0 and num+1 or 2
		local function iter(t)
			i = i + 1
			if i < size then
				return t[i]
			end
		end
		return iter, IsInRaid() and raidList or partyList
	end
end

do
	local difficultyTbl = {
		[1] = "5Normal",
		[2] = "5Heroic",
		[3] = "10Normal",
		[4] = "25Normal",
		[5] = "10Heroic",
		[6] = "25Heroic",
		[7] = "25LFR",
		[8] = "5Challenge",
		[14] = "Normal",
		[15] = "Heroic",
		[16] = "Mythic",
		[17] = "LFR",
		[18] = "40Event",
		[19] = "5Event",
		[23] = "5Mythic",
		[24] = "5Timewalking",
		[33] = "RaidTimewalking",
	}
	local wowVersion, buildRevision = GetBuildInfo() -- Note that both returns here are strings, not numbers.
	local logNameFormat = "[%s]@[%s] - Zone:%d Difficulty:%d,%s Type:%s " .. format("Version: %s.%s", wowVersion, buildRevision)
	function Transcriptor:StartLog(silent)
		if logging then
			print(L["You are already logging an encounter."])
		else
			ldb.text = L["|cffFF0000Recording|r"]
			ldb.icon = "Interface\\AddOns\\Transcriptor\\icon_on"
			shouldLogFlags = TranscriptIgnore.logFlags and true or false
			wipe(data)

			hiddenAuraEngageList = {}
			do
				local UnitAura, UnitPosition = UnitAura, UnitPosition
				local _, _, _, myInstance = UnitPosition("player")
				for unit in Transcriptor:IterateGroup() do
					local _, _, _, tarInstanceId = UnitPosition(unit)
					if tarInstanceId == myInstance then
						for i = 1, 100 do
							local _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i)
							if not spellId then
								break
							elseif not hiddenAuraEngageList[spellId] then
								hiddenAuraEngageList[spellId] = true
							end
						end
					end
				end
			end

			collectNameplates = {}
			hiddenUnitAuraCollector = {}
			playerSpellCollector = {}
			previousSpecialEvent = nil
			compareStartTime = debugprofilestop()
			logStartTime = compareStartTime / 1000
			local _, instanceType, diff, _, _, _, _, instanceId = GetInstanceInfo()
			local diffText = difficultyTbl[diff] or "None"
			logName = format(logNameFormat, date("%Y-%m-%d"), date("%H:%M:%S"), instanceId or 0, diff, diffText, instanceType)

			if type(TranscriptDB[logName]) ~= "table" then TranscriptDB[logName] = {} end
			if type(TranscriptIgnore) ~= "table" then TranscriptIgnore = {} end
			currentLog = TranscriptDB[logName]

			if type(currentLog.total) ~= "table" then currentLog.total = {} end
			--Register Events to be Tracked
			eventFrame:Show()
			for i, event in next, wowEvents do
				if not TranscriptIgnore[event] then
					eventFrame:RegisterEvent(event)
				end
			end
			if BigWigsLoader then
				for i, event in next, bwEvents do
					if not TranscriptIgnore[event] then
						BigWigsLoader.RegisterMessage(eventFrame, event, BWEventHandler)
					end
				end
			end
			if DBM then
				for i, event in next, dbmEvents do
					if not TranscriptIgnore[event] then
						DBM:RegisterCallback(event, DBMEventHandler)
					end
				end
			end
			logging = 1

			--Notify Log Start
			if not silent then
				print(L["Beginning Transcript: "]..logName)
				print(L["Remember to stop and start Transcriptor between each wipe or boss kill to get the best logs."])
			end
			return logName
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
function Transcriptor:GetCurrentLogName() return logging and logName end
function Transcriptor:AddCustomEvent(event, separateCategory, ...)
	if logging and not TranscriptIgnore[event] then
		local line = strjoin("#", tostringall(...))
		if not line then return end
		local stop = debugprofilestop() / 1000
		local t = stop - logStartTime
		local time = date("%H:%M:%S")
		local text = format("<%.2f %s> [%s] %s", t, time, event, line)
		currentLog.total[#currentLog.total+1] = text
		if separateCategory then
			if type(currentLog[separateCategory]) ~= "table" then currentLog[separateCategory] = {} end
			tinsert(currentLog[separateCategory], text)
		end
	end
end
function Transcriptor:IsLogging() return logging end
function Transcriptor:StopLog(silent)
	if not logging then
		print(L["You are not logging an encounter."])
	else
		ldb.text = L["|cff696969Idle|r"]
		ldb.icon = "Interface\\AddOns\\Transcriptor\\icon_off"

		--Clear Events
		eventFrame:Hide()
		for i, event in next, wowEvents do
			if not TranscriptIgnore[event] then
				eventFrame:UnregisterEvent(event)
			end
		end
		if BigWigsLoader then
			BigWigsLoader.SendMessage(eventFrame, "BigWigs_OnPluginDisable", eventFrame)
		end
		if DBM and DBM.UnregisterCallback then
			for i, event in next, dbmEvents do
				DBM:UnregisterCallback(event, DBMEventHandler)
			end
		end
		--Notify Stop
		if not silent then
			print(L["Ending Transcript: "]..logName)
			print(L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."])
		end

		if compareSuccess or compareStart or compareAuraApplied or compareUnitSuccess or compareEmotes then
			currentLog.TIMERS = {}
			if compareSuccess then
				currentLog.TIMERS.SPELL_CAST_SUCCESS = {}
				for id,tbl in next, compareSuccess do
					for npcId, list in next, tbl do
						local n = format("%s-%d-npc:%s", GetSpellInfo(id), id, npcId)
						local str
						for i = 2, #list do
							if not str then
								if type(list[1]) == "table" then
									local sincePull = list[i] - list[1][1]
									local sincePreviousEvent = list[i] - list[1][2]
									local previousEventName = list[1][3]
									str = format("%s = pull:%.1f/%s/%.1f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000)
								else
									local sincePull = list[i] - list[1]
									str = format("%s = pull:%.1f", n, sincePull/1000)
								end
							else
								if type(list[i]) == "table" then
									if type(list[i-1]) == "number" then
										local t = list[i][1]-list[i-1]
										str = format("%s, %s/%.1f", str, list[i][2], t/1000)
									elseif type(list[i-1]) == "table" then
										local t = list[i][1]-list[i-1][1]
										str = format("%s, %s/%.1f", str, list[i][2], t/1000)
									else
										str = format("%s, %s", str, list[i][2])
									end
								else
									if type(list[i-1]) == "table" then
										if type(list[i-2]) == "table" then
											if type(list[i-3]) == "table" then
												if type(list[i-4]) == "table" then
													local counter = 5
													while type(list[i-counter]) == "table" do
														counter = counter + 1
													end
													local tStage = list[i] - list[i-1][1]
													local t = list[i] - list[i-counter]
													str = format("%s, TooManyStages/%.1f/%.1f", str, tStage/1000, t/1000)
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local tStagePreviousMore = list[i] - list[i-3][1]
													local t = list[i] - list[i-4]
													str = format("%s, %.1f/%.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local tStagePrevious = list[i] - list[i-2][1]
												local t = list[i] - list[i-3]
												str = format("%s, %.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, t/1000)
											end
										else
											local tStage = list[i] - list[i-1][1]
											local t = list[i] - list[i-2]
											str = format("%s, %.1f/%.1f", str, tStage/1000, t/1000)
										end
									else
										local t = list[i] - list[i-1]
										str = format("%s, %.1f", str, t/1000)
									end
								end
							end
						end
						currentLog.TIMERS.SPELL_CAST_SUCCESS[#currentLog.TIMERS.SPELL_CAST_SUCCESS+1] = str
					end
				end
				table.sort(currentLog.TIMERS.SPELL_CAST_SUCCESS)
			end
			if compareStart then
				currentLog.TIMERS.SPELL_CAST_START = {}
				for id,tbl in next, compareStart do
					for npcId, list in next, tbl do
						local n = format("%s-%d-npc:%s", GetSpellInfo(id), id, npcId)
						local str
						for i = 2, #list do
							if not str then
								if type(list[1]) == "table" then
									local sincePull = list[i] - list[1][1]
									local sincePreviousEvent = list[i] - list[1][2]
									local previousEventName = list[1][3]
									str = format("%s = pull:%.1f/%s/%.1f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000)
								else
									local sincePull = list[i] - list[1]
									str = format("%s = pull:%.1f", n, sincePull/1000)
								end
							else
								if type(list[i]) == "table" then
									if type(list[i-1]) == "number" then
										local t = list[i][1]-list[i-1]
										str = format("%s, %s/%.1f", str, list[i][2], t/1000)
									elseif type(list[i-1]) == "table" then
										local t = list[i][1]-list[i-1][1]
										str = format("%s, %s/%.1f", str, list[i][2], t/1000)
									else
										str = format("%s, %s", str, list[i][2])
									end
								else
									if type(list[i-1]) == "table" then
										if type(list[i-2]) == "table" then
											if type(list[i-3]) == "table" then
												if type(list[i-4]) == "table" then
													local counter = 5
													while type(list[i-counter]) == "table" do
														counter = counter + 1
													end
													local tStage = list[i] - list[i-1][1]
													local t = list[i] - list[i-counter]
													str = format("%s, TooManyStages/%.1f/%.1f", str, tStage/1000, t/1000)
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local tStagePreviousMore = list[i] - list[i-3][1]
													local t = list[i] - list[i-4]
													str = format("%s, %.1f/%.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local tStagePrevious = list[i] - list[i-2][1]
												local t = list[i] - list[i-3]
												str = format("%s, %.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, t/1000)
											end
										else
											local tStage = list[i] - list[i-1][1]
											local t = list[i] - list[i-2]
											str = format("%s, %.1f/%.1f", str, tStage/1000, t/1000)
										end
									else
										local t = list[i] - list[i-1]
										str = format("%s, %.1f", str, t/1000)
									end
								end
							end
						end
						currentLog.TIMERS.SPELL_CAST_START[#currentLog.TIMERS.SPELL_CAST_START+1] = str
					end
				end
				table.sort(currentLog.TIMERS.SPELL_CAST_START)
			end
			if compareAuraApplied then
				currentLog.TIMERS.SPELL_AURA_APPLIED = {}
				for id,tbl in next, compareAuraApplied do
					for npcId, list in next, tbl do
						local n = format("%s-%d-npc:%s", GetSpellInfo(id), id, npcId)
						local str
						local zeroCounter = 1
						for i = 2, #list do
							if not str then
								if type(list[1]) == "table" then
									local sincePull = list[i] - list[1][1]
									local sincePreviousEvent = list[i] - list[1][2]
									local previousEventName = list[1][3]
									str = format("%s = pull:%.1f/%s/%.1f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000)
								else
									local sincePull = list[i] - list[1]
									str = format("%s = pull:%.1f", n, sincePull/1000)
								end
							else
								if type(list[i]) == "table" then
									if type(list[i-1]) == "number" then
										local t = list[i][1]-list[i-1]
										str = format("%s, %s/%.1f", str, list[i][2], t/1000)
									elseif type(list[i-1]) == "table" then
										local t = list[i][1]-list[i-1][1]
										str = format("%s, %s/%.1f", str, list[i][2], t/1000)
									else
										str = format("%s, %s", str, list[i][2])
									end
								else
									if type(list[i-1]) == "table" then
										if type(list[i-2]) == "table" then
											if type(list[i-3]) == "table" then
												if type(list[i-4]) == "table" then
													local counter = 5
													while type(list[i-counter]) == "table" do
														counter = counter + 1
													end
													local tStage = list[i] - list[i-1][1]
													local t = list[i] - list[i-counter]
													str = format("%s, TooManyStages/%.1f/%.1f", str, tStage/1000, t/1000)
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local tStagePreviousMore = list[i] - list[i-3][1]
													local t = list[i] - list[i-4]
													str = format("%s, %.1f/%.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local tStagePrevious = list[i] - list[i-2][1]
												local t = list[i] - list[i-3]
												str = format("%s, %.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, t/1000)
											end
										else
											local tStage = list[i] - list[i-1][1]
											local t = list[i] - list[i-2]
											str = format("%s, %.1f/%.1f", str, tStage/1000, t/1000)
										end
									else
										local t = list[i] - list[i-1]
										local shorten = format("%.1f", t/1000)
										if shorten == "0.0" then
											local typeNext = type(list[i+1])
											if typeNext == "number" then
												local nextT = list[i+1] - list[i]
												local nextShorten = format("%.1f", nextT/1000)
												if nextShorten == "0.0" then
													zeroCounter = zeroCounter + 1
												else
													str = format("%s[+%d]", str, zeroCounter)
													zeroCounter = 1
												end
											else
												str = format("%s[+%d]", str, zeroCounter)
												zeroCounter = 1
											end
										else
											str = format("%s, %.1f", str, t/1000)
										end
									end
								end
							end
						end
						currentLog.TIMERS.SPELL_AURA_APPLIED[#currentLog.TIMERS.SPELL_AURA_APPLIED+1] = str
					end
				end
				table.sort(currentLog.TIMERS.SPELL_AURA_APPLIED)
			end
			if compareUnitSuccess then
				currentLog.TIMERS.UNIT_SPELLCAST_SUCCEEDED = {}
				for id,tbl in next, compareUnitSuccess do
					for npcId, list in next, tbl do
						if not compareSuccess or not compareSuccess[id] or not compareSuccess[id][npcId] then
							local n = format("%s-%d-npc:%s", GetSpellInfo(id), id, npcId)
							local str
							for i = 2, #list do
								if not str then
									if type(list[1]) == "table" then
										local sincePull = list[i] - list[1][1]
										local sincePreviousEvent = list[i] - list[1][2]
										local previousEventName = list[1][3]
										str = format("%s = pull:%.1f/%s/%.1f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000)
									else
										local sincePull = list[i] - list[1]
										str = format("%s = pull:%.1f", n, sincePull/1000)
									end
								else
									if type(list[i]) == "table" then
										if type(list[i-1]) == "number" then
											local t = list[i][1]-list[i-1]
											str = format("%s, %s/%.1f", str, list[i][2], t/1000)
										elseif type(list[i-1]) == "table" then
											local t = list[i][1]-list[i-1][1]
											str = format("%s, %s/%.1f", str, list[i][2], t/1000)
										else
											str = format("%s, %s", str, list[i][2])
										end
									else
										if type(list[i-1]) == "table" then
											if type(list[i-2]) == "table" then
												if type(list[i-3]) == "table" then
													if type(list[i-4]) == "table" then
														local counter = 5
														while type(list[i-counter]) == "table" do
															counter = counter + 1
														end
														local tStage = list[i] - list[i-1][1]
														local t = list[i] - list[i-counter]
														str = format("%s, TooManyStages/%.1f/%.1f", str, tStage/1000, t/1000)
													else
														local tStage = list[i] - list[i-1][1]
														local tStagePrevious = list[i] - list[i-2][1]
														local tStagePreviousMore = list[i] - list[i-3][1]
														local t = list[i] - list[i-4]
														str = format("%s, %.1f/%.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
													end
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local t = list[i] - list[i-3]
													str = format("%s, %.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local t = list[i] - list[i-2]
												str = format("%s, %.1f/%.1f", str, tStage/1000, t/1000)
											end
										else
											local t = list[i] - list[i-1]
											str = format("%s, %.1f", str, t/1000)
										end
									end
								end
							end
							currentLog.TIMERS.UNIT_SPELLCAST_SUCCEEDED[#currentLog.TIMERS.UNIT_SPELLCAST_SUCCEEDED+1] = str
						end
					end
				end
				table.sort(currentLog.TIMERS.UNIT_SPELLCAST_SUCCEEDED)
			end
			if compareEmotes then
				currentLog.TIMERS.EMOTES = {}
				for id,tbl in next, compareEmotes do
					for npcName, list in next, tbl do
						local n = format("%s-%d-npc:%s", GetSpellInfo(id) or "?", id, npcName)
						local str
						for i = 2, #list do
							if not str then
								if type(list[1]) == "table" then
									local sincePull = list[i] - list[1][1]
									local sincePreviousEvent = list[i] - list[1][2]
									local previousEventName = list[1][3]
									str = format("%s = pull:%.1f/%s/%.1f", n, sincePull/1000, previousEventName, sincePreviousEvent/1000)
								else
									local sincePull = list[i] - list[1]
									str = format("%s = pull:%.1f", n, sincePull/1000)
								end
							else
								if type(list[i]) == "table" then
									if type(list[i-1]) == "number" then
										local t = list[i][1]-list[i-1]
										str = format("%s, %s/%.1f", str, list[i][2], t/1000)
									elseif type(list[i-1]) == "table" then
										local t = list[i][1]-list[i-1][1]
										str = format("%s, %s/%.1f", str, list[i][2], t/1000)
									else
										str = format("%s, %s", str, list[i][2])
									end
								else
									if type(list[i-1]) == "table" then
										if type(list[i-2]) == "table" then
											if type(list[i-3]) == "table" then
												if type(list[i-4]) == "table" then
													local counter = 5
													while type(list[i-counter]) == "table" do
														counter = counter + 1
													end
													local tStage = list[i] - list[i-1][1]
													local t = list[i] - list[i-counter]
													str = format("%s, TooManyStages/%.1f/%.1f", str, tStage/1000, t/1000)
												else
													local tStage = list[i] - list[i-1][1]
													local tStagePrevious = list[i] - list[i-2][1]
													local tStagePreviousMore = list[i] - list[i-3][1]
													local t = list[i] - list[i-4]
													str = format("%s, %.1f/%.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, tStagePreviousMore/1000, t/1000)
												end
											else
												local tStage = list[i] - list[i-1][1]
												local tStagePrevious = list[i] - list[i-2][1]
												local t = list[i] - list[i-3]
												str = format("%s, %.1f/%.1f/%.1f", str, tStage/1000, tStagePrevious/1000, t/1000)
											end
										else
											local tStage = list[i] - list[i-1][1]
											local t = list[i] - list[i-2]
											str = format("%s, %.1f/%.1f", str, tStage/1000, t/1000)
										end
									else
										local t = list[i] - list[i-1]
										str = format("%s, %.1f", str, t/1000)
									end
								end
							end
						end
						currentLog.TIMERS.EMOTES[#currentLog.TIMERS.EMOTES+1] = str
					end
				end
				table.sort(currentLog.TIMERS.EMOTES)
			end
		end
		if collectPlayerAuras then
			if not currentLog.TIMERS then currentLog.TIMERS = {} end
			currentLog.TIMERS.PLAYER_AURAS = {}
			for id,tbl in next, collectPlayerAuras do
				local n = format("%d-%s", id, (GetSpellInfo(id)))
				currentLog.TIMERS.PLAYER_AURAS[n] = {}
				for event in next, tbl do
					currentLog.TIMERS.PLAYER_AURAS[n][#currentLog.TIMERS.PLAYER_AURAS[n]+1] = event
				end
			end
		end
		for id, str in next, hiddenUnitAuraCollector do
			if not hiddenAuraPermList[id] then
				if not currentLog.TIMERS then currentLog.TIMERS = {} end
				if not currentLog.TIMERS.HIDDEN_AURAS then currentLog.TIMERS.HIDDEN_AURAS = {} end
				currentLog.TIMERS.HIDDEN_AURAS[#currentLog.TIMERS.HIDDEN_AURAS+1] = str
			end
		end
		for id, str in next, playerSpellCollector do
			if not currentLog.TIMERS then currentLog.TIMERS = {} end
			if not currentLog.TIMERS.PLAYER_SPELLS then currentLog.TIMERS.PLAYER_SPELLS = {} end
			currentLog.TIMERS.PLAYER_SPELLS[#currentLog.TIMERS.PLAYER_SPELLS+1] = str
		end

		--Clear Log Path
		currentLog = nil
		logging = nil
		compareSuccess = nil
		compareUnitSuccess = nil
		compareEmotes = nil
		compareStart = nil
		compareAuraApplied = nil
		compareStartTime = nil
		collectPlayerAuras = nil
		logStartTime = nil
		collectNameplates = nil
		hiddenUnitAuraCollector = nil
		playerSpellCollector = nil

		return logName
	end
end

function Transcriptor:ClearAll()
	if not logging then
		TranscriptDB = {}
		print(L["All transcripts cleared."])
	else
		print(L["You can't clear your transcripts while logging an encounter."])
	end
end

_G.Transcriptor = Transcriptor
