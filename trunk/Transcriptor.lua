
local Transcriptor = {}
local revision = tonumber(("$Revision$"):sub(12, -3))

local playerSpellBlacklist
local badSourcelessPlayerSpellList

do
	local n, tbl = ...
	playerSpellBlacklist = tbl.blacklist
end

local logName = nil
local currentLog = nil
local logStartTime = nil
local logging = nil
local compareSuccess = nil
local compareStart = nil
local compareStartTime = nil
local inEncounter = false
local wowVersion, buildRevision, _, buildTOC = GetBuildInfo() -- Note that both returns here are strings, not numbers.

local tinsert = table.insert
local format, strjoin = string.format, string.join
local tostring, tostringall = tostring, tostringall
local type, select, next = type, select, next
local date = date
local debugprofilestop = debugprofilestop
local print = print

local C_Scenario = C_Scenario
local RegisterAddonMessagePrefix = RegisterAddonMessagePrefix
local IsEncounterInProgress, IsAltKeyDown, EJ_GetEncounterInfo, EJ_GetSectionInfo = IsEncounterInProgress, IsAltKeyDown, EJ_GetEncounterInfo, EJ_GetSectionInfo
local UnitInRaid, UnitInParty, UnitIsFriend, UnitCastingInfo, UnitChannelInfo = UnitInRaid, UnitInParty, UnitIsFriend, UnitCastingInfo, UnitChannelInfo
local UnitCanAttack, UnitExists, UnitIsVisible, UnitGUID, UnitClassification = UnitCanAttack, UnitExists, UnitIsVisible, UnitGUID, UnitClassification
local UnitName, UnitPower, UnitPowerMax, UnitPowerType, UnitHealth, UnitHealthMax = UnitName, UnitPower, UnitPowerMax, UnitPowerType, UnitHealth, UnitHealthMax
local UnitLevel, UnitCreatureType, GetNumWorldStateUI, GetWorldStateUIInfo = UnitLevel, UnitCreatureType, GetNumWorldStateUI, GetWorldStateUIInfo
local GetInstanceInfo, GetCurrentMapAreaID, GetCurrentMapDungeonLevel, GetMapNameByID = GetInstanceInfo, GetCurrentMapAreaID, GetCurrentMapDungeonLevel, GetMapNameByID
local GetZoneText, GetRealZoneText, GetSubZoneText, SetMapToCurrentZone, GetSpellInfo = GetZoneText, GetRealZoneText, GetSubZoneText, SetMapToCurrentZone, GetSpellInfo
local GetSpellTabInfo, GetNumSpellTabs, GetSpellBookItemInfo, GetSpellBookItemName = GetSpellTabInfo, GetNumSpellTabs, GetSpellBookItemInfo, GetSpellBookItemName

-- GLOBALS: TranscriptDB BigWigsLoader DBM CLOSE SlashCmdList SLASH_TRANSCRIPTOR1 SLASH_TRANSCRIPTOR2 SLASH_TRANSCRIPTOR3 EasyMenu CloseDropDownMenus
-- GLOBALS: GetMapID GetBossID GetSectionID

do
	local origPrint = print
	function print(msg)
		return origPrint(format("|cffffff00%s|r", msg))
	end

	local origUnitName = UnitName
	function UnitName(name)
		return origUnitName(name) or "??"
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

do
	-- Create UI spell display, copied from BasicChatMods
	local frame, editBox = {}, {}
	for i = 1, 4 do
		frame[i] = CreateFrame("Frame", nil, UIParent)
		frame[i]:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = {left = 1, right = 1, top = 1, bottom = 1}}
		)
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
				if link and link:find("spell", nil, true) then
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
		if InCombatLockdown() or UnitAffectingCombat("player") then return end

		local total, totalSorted = {}, {}
		local auraTbl, castTbl, summonTbl = {}, {}, {}
		local aurasSorted, castsSorted, summonSorted = {}, {}, {}
		local ignoreList = {
			[39565] = true, -- Stand State (Iron Cannoneer in Frostfire Ridge, some kind of long lasting debuff)
			[180247] = true, -- Gather Felfire Munitions (Hellfire Assault)
			[180410] = true, -- Heart Seeker (Kilrogg Deadeye)
			[180413] = true, -- Heart Seeker (Kilrogg Deadeye)
			[181102] = true, -- Mark Eruption (Mannoroth)
			[181488] = true, -- Vision of Death (Kilrogg Deadeye)
			[182008] = true, -- Latent Energy (Fel Lord Zakuun)
			[182038] = true, -- Shattered Defenses (Socrethar the Eternal)
			[182218] = true, -- Felblaze Residue (Socrethar the Eternal)
			[183963] = true, -- Light of the Naaru (Archimonde)
			[184450] = true, -- Mark of the Necromancer (Dia Darkwhisper - Hellfire High Council)
			[185014] = true, -- Focused Chaos (Archimonde)
			[185656] = true, -- Shadowfel Annihilation
			[186123] = true, -- Wrought Chaos (Archimonde)
			[187344] = true, -- Phantasmal Cremation (Shadow-Lord Iskar)
			[187668] = true, -- Mark of Kazzak (Supreme Lord Kazzak)
			[189030] = true, -- Befouled (Fel Lord Zakuun)
			[189031] = true, -- Befouled (Fel Lord Zakuun)
			[189032] = true, -- Befouled (Fel Lord Zakuun)
			[189559] = true, -- Carrion Swarm (Korvos, Hellfire Citadel trash)
			[189565] = true, -- Torpor (Korvos, Hellfire Citadel trash)
			[190466] = true, -- Incomplete Binding (Socrethar the Eternal)
		}
		for logName, logTbl in next, TranscriptDB do
			if type(logTbl) == "table" and logTbl.total then
				for i=1, #logTbl.total do
					local text = logTbl.total[i]

					-- AURA
					local name, destGUID, tarName, id, spellName = text:match("SPELL_AURA_[^#]+#P[le][at][^#]+#([^#]+)#([^#]+)#([^#]+)#(%d+)#([^#]+)#")
					id = tonumber(id)
					local trim = destGUID and destGUID:find("^P[le][at]")
					if id and not ignoreList[id] and not playerSpellBlacklist[id] and not total[id] and #aurasSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						if name == tarName then
							auraTbl[id] = "|cFF81BEF7".. name:gsub("%-.+", "*") .." >> ".. (trim and tarName:gsub("%-.+", "*") or tarName) .."|r"
						else
							auraTbl[id] = "|cFF3ADF00".. name:gsub("%-.+", "*") .." >> ".. (trim and tarName:gsub("%-.+", "*") or tarName) .."|r"
						end
						total[id] = true
						aurasSorted[#aurasSorted+1] = id
					end

					-- CAST
					name, destGUID, tarName, id, spellName = text:match("SPELL_CAST_[^#]+#P[le][at][^#]+#([^#]+)#([^#]+)#([^#]+)#(%d+)#([^#]+)#")
					id = tonumber(id)
					local trim = destGUID and destGUID:find("^P[le][at]")
					if id and not ignoreList[id] and not playerSpellBlacklist[id] and not total[id] and #castsSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						if name == tarName then
							castTbl[id] = "|cFF81BEF7".. name:gsub("%-.+", "*") .." >> ".. (trim and tarName:gsub("%-.+", "*") or tarName) .."|r"
						else
							castTbl[id] = "|cFF3ADF00".. name:gsub("%-.+", "*") .." >> ".. (trim and tarName:gsub("%-.+", "*") or tarName) .."|r"
						end
						total[id] = true
						castsSorted[#castsSorted+1] = id
					end

					-- SUMMON
					name, destGUID, tarName, id, spellName = text:match("SPELL_SUMMON#P[le][at][^#]+#([^#]+)#([^#]+)#([^#]+)#(%d+)#([^#]+)#")
					id = tonumber(id)
					local trim = destGUID and destGUID:find("^P[le][at]")
					if id and not ignoreList[id] and not playerSpellBlacklist[id] and not total[id] and #summonSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						if name == tarName then
							summonTbl[id] = "|cFF81BEF7".. name:gsub("%-.+", "*") .." >> ".. (trim and tarName:gsub("%-.+", "*") or tarName) .."|r"
						else
							summonTbl[id] = "|cFF3ADF00".. name:gsub("%-.+", "*") .." >> ".. (trim and tarName:gsub("%-.+", "*") or tarName) .."|r"
						end
						total[id] = true
						summonSorted[#summonSorted+1] = id
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
		editBox[1]:SetText(text)
		frame[1]:ClearAllPoints()
		frame[1]:SetPoint("BOTTOMRIGHT", UIParent, "CENTER")
		frame[1]:Show()

		for k, v in next, playerSpellBlacklist do
			total[k] = true
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
			[179202] = true, -- Eye of Anzu (Shadow-Lord Iskar)
			[179908] = true, -- Shared Fate (Gorefiend)
			[180079] = true, -- Felfire Munitions (Hellfire Assault)
			[180164] = true, -- Touch of Harm (Tyrant Velhari)
			[180270] = true, -- Shadow Globule (Kormrok)
			[180575] = true, -- Fel Flames (Kilrogg Deadeye)
			[181295] = true, -- Digest (Gorefiend)
			[181653] = true, -- Fel Crystals (Fel Lord Zakuun)
			[182159] = true, -- Fel Corruption (Kilrogg Deadeye)
			[182171] = true, -- Blood of Mannoroth (Mannoroth)
			[182600] = true, -- Fel Fire (Shadow-Lord Iskar)
			[182879] = true, -- Doomfire Fixate (Archimonde)
			[183586] = true, -- Doomfire (Archimonde)
			[184396] = true, -- Fel Corruption (Kilrogg Deadeye)
			[184398] = true, -- Fel Corruption (Kilrogg Deadeye)
			[184652] = true, -- Reap (Dia Darkwhisper - Hellfire High Council)
			[185065] = true, -- Mark of the Necromancer (Dia Darkwhisper - Hellfire High Council)
			[185066] = true, -- Mark of the Necromancer (Dia Darkwhisper - Hellfire High Council)
			[185239] = true, -- Radiance of Anzu (Shadow-Lord Iskar)
			[185242] = true, -- Blitz (Iron Reaver)
			[186046] = true, -- Solar Chakram (Shadow-Lord Iskar)
			[186770] = true, -- Pool of Souls (Gorefiend)
			[186952] = true, -- Nether Banish (Archimonde)
			[187255] = true, -- Nether Storm (Archimonde)
			[188520] = true, -- Fel Sludge (Supreme Lord Kazzak, pools close by)
			[188852] = true, -- Blood Splatter (Kilrogg Deadeye)
			[189891] = true, -- Nether Tear (Archimonde)
			[190341] = true, -- Nether Corruption (Archimonde)
		}
		for logName, logTbl in next, TranscriptDB do
			if type(logTbl) == "table" and logTbl.total then
				for i=1, #logTbl.total do
					local text = logTbl.total[i]

					-- AURA
					local name, destGUID, tarName, id, spellName = text:match("SPELL_AURA_[AR][^#]+##([^#]+)#(P[le][at][^#]+)#([^#]+)#(%d+)#([^#]+)#") -- For sourceless we use SPELL_AURA_[AR] to filter _BROKEN which usually originates from NPCs
					id = tonumber(id)
					if name == "nil" and id and not ignoreList[id] and not badSourcelessPlayerSpellList[id] and not total[id] and #aurasSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						auraTbl[id] = tarName:gsub("%-.+", "*")
						total[id] = true
						aurasSorted[#aurasSorted+1] = id
					end

					-- CAST
					name, destGUID, tarName, id, spellName = text:match("SPELL_CAST_[^#]+##([^#]+)#(P[le][at][^#]+)#([^#]+)#(%d+)#([^#]+)#")
					id = tonumber(id)
					if name == "nil" and id and not ignoreList[id] and not badSourcelessPlayerSpellList[id] and not total[id] and #castsSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						castTbl[id] = tarName:gsub("%-.+", "*")
						total[id] = true
						castsSorted[#castsSorted+1] = id
					end

					-- SUMMON
					name, destGUID, tarName, id, spellName = text:match("SPELL_SUMMON##([^#]+)#(P[le][at][^#]+)#([^#]+)#(%d+)#([^#]+)#")
					id = tonumber(id)
					if name == "nil" and id and not ignoreList[id] and not badSourcelessPlayerSpellList[id] and not total[id] and #summonSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						summonTbl[id] = tarName:gsub("%-.+", "*")
						total[id] = true
						summonSorted[#summonSorted+1] = id
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
		L["Beginning Transcript: "] = "기록 시작됨: "
		L["Ending Transcript: "] = "기록 종료: "
		L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."] = "UI 재시작 후에 WoW\\WTF\\Account\\<아이디>\\SavedVariables\\Transcriptor.lua 에 기록이 저장됩니다."
		L["All transcripts cleared."] = "모든 기록 초기화 완료"
		L["You can't clear your transcripts while logging an encounter."] = "전투 기록중엔 기록을 초기화 할 수 없습니다."
		L["|cffFF0000Recording|r: "] = "|cffFF0000기록중|r: "
		L["|cff696969Idle|r"] = "|cff696969무시|r"
		L["|cffeda55fClick|r to start or stop transcribing. |cffeda55fRight-Click|r to configure events. |cffeda55fAlt-Middle Click|r to clear all stored transcripts."] = "|cffeda55f클릭|r 전투 기록 시작/정지. |cffeda55f우-클릭|r 이벤트 설정. |cffeda55f알트-중앙 클릭|r 기록된 자료 삭제."
		L["|cffFF0000Recording|r"] = "|cffFF0000기록중|r"
		--L["|cFFFFD200Transcriptor|r - Disabled Events"] = "|cFFFFD200Transcriptor|r - Disabled Events"
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

local sh = {}
function sh.UPDATE_WORLD_STATES()
	local ret
	for i = 1, GetNumWorldStateUI() do
		local m = strjoin("#", tostringall(GetWorldStateUIInfo(i)))
		if m then
			if not ret then
				ret = format("[%d] %s", i, m)
			else
				ret = format("%s [%d] %s", ret, i, m)
			end
		end
	end
	return ret
end
sh.WORLD_STATE_UI_TIMER_UPDATE = sh.UPDATE_WORLD_STATES

do
	badSourcelessPlayerSpellList = {
		[81782] = true, -- Power Word: Barrier
		[145629] = true, -- Anti-Magic Zone
		[156055] = true, -- Oglethorpe's Missile Splitter
		[156060] = true, -- Megawatt Filament
		[157384] = true, -- Eye of the Storm
		[159234] = true, -- Mark of the Thunderlord
		[159675] = true, -- Mark of Warsong
		[159676] = true, -- Mark of the Frostwolf
		[159678] = true, -- Mark of Shadowmoon
		[159679] = true, -- Mark of Blackrock
		[173288] = true, -- Hemet's Heartseeker
		[173322] = true, -- Mark of Bleeding Hollow
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
		["SPELL_AURA_BROKEN_SPELL"] = true,
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
	local playerOrPet = 13312 -- COMBATLOG_OBJECT_TYPE_PLAYER + COMBATLOG_OBJECT_TYPE_PET + COMBATLOG_OBJECT_TYPE_GUARDIAN
	local band = bit.band
	-- Note some things we are trying to avoid filtering:
	-- BRF/Kagraz - Player damage with no source "SPELL_DAMAGE##nil#Player-GUID#PLAYER#154938#Molten Torrent#"
	-- HFC/Socrethar - Player cast on friendly vehicle "SPELL_CAST_SUCCESS#Player-GUID#PLAYER#Vehicle-0-3151-1448-8853-90296-00001D943C#Soulbound Construct#190466#Incomplete Binding"
	-- HFC/Zakuun - Player boss debuff cast on self "SPELL_AURA_APPLIED#Player-GUID#PLAYER#Player-GUID#PLAYER#189030#Befouled#DEBUFF#"
	function sh.COMBAT_LOG_EVENT_UNFILTERED(timeStamp, event, caster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, _, extraSpellId, amount)
		if badEvents[event] or
		   (sourceName and badPlayerEvents[event] and band(sourceFlags, playerOrPet) ~= 0) or
		   (sourceName and badPlayerFilteredEvents[event] and playerSpellBlacklist[spellId] and band(sourceFlags, playerOrPet) ~= 0) or
		   (not sourceName and destName and badPlayerFilteredEvents[event] and badSourcelessPlayerSpellList[spellId] and band(destFlags, playerOrPet) ~= 0)
		then
			return
		else
			if event == "SPELL_CAST_SUCCESS" and (not sourceName or band(sourceFlags, playerOrPet) == 0) then
				if not compareSuccess then compareSuccess = {} end
				if not compareSuccess[spellId] then compareSuccess[spellId] = {} end
				compareSuccess[spellId][#compareSuccess[spellId]+1] = debugprofilestop()
			end
			if event == "SPELL_CAST_START" and (not sourceName or band(sourceFlags, playerOrPet) == 0) then
				if not compareStart then compareStart = {} end
				if not compareStart[spellId] then compareStart[spellId] = {} end
				compareStart[spellId][#compareStart[spellId]+1] = debugprofilestop()
			end
			return strjoin("#", tostringall(event, sourceGUID, sourceName, destGUID, destName, spellId, spellName, extraSpellId, amount))
		end
	end
end

function sh.PLAYER_REGEN_DISABLED() return " ++ > Regen Disabled : Entering combat! ++ > " end
function sh.PLAYER_REGEN_ENABLED() return " -- < Regen Enabled : Leaving combat! -- < " end
function sh.UNIT_SPELLCAST_STOP(unit, ...)
	if ((unit == "target" or unit == "focus") and not UnitInRaid(unit) and not UnitInParty(unit)) or unit:find("boss", nil, true) or unit:find("arena", nil, true) then
		return format("%s(%s) [[%s]]", UnitName(unit), UnitName(unit.."target"), strjoin(":", tostringall(unit, ...)))
	end
end
sh.UNIT_SPELLCAST_CHANNEL_STOP = sh.UNIT_SPELLCAST_STOP
sh.UNIT_SPELLCAST_INTERRUPTED = sh.UNIT_SPELLCAST_STOP
sh.UNIT_SPELLCAST_SUCCEEDED = sh.UNIT_SPELLCAST_STOP
function sh.UNIT_SPELLCAST_START(unit, ...)
	if ((unit == "target" or unit == "focus") and not UnitInRaid(unit) and not UnitInParty(unit)) or unit:find("boss", nil, true) or unit:find("arena", nil, true) then
		local _, _, _, icon, startTime, endTime = UnitCastingInfo(unit)
		local time = ((endTime or 0) - (startTime or 0)) / 1000
		icon = icon and icon:gsub(".*\\([^\\]+)$", "%1") or "no icon"
		return format("%s(%s) - %s - %ssec [[%s]]", UnitName(unit), UnitName(unit.."target"), icon, time, strjoin(":", tostringall(unit, ...)))
	end
end
function sh.UNIT_SPELLCAST_CHANNEL_START(unit, ...)
	if ((unit == "target" or unit == "focus") and not UnitInRaid(unit) and not UnitInParty(unit)) or unit:find("boss", nil, true) or unit:find("arena", nil, true) then
		local _, _, _, icon, startTime, endTime = UnitChannelInfo(unit)
		local time = ((endTime or 0) - (startTime or 0)) / 1000
		icon = icon and icon:gsub(".*\\([^\\]+)$", "%1") or "no icon"
		return format("%s(%s) - %s - %ssec [[%s]]", UnitName(unit), UnitName(unit.."target"), icon, time, strjoin(":", tostringall(unit, ...)))
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
	return strjoin("#", tostringall(unit, UnitCanAttack("player", unit), UnitExists(unit), UnitIsVisible(unit), UnitName(unit), UnitGUID(unit), UnitClassification(unit), UnitHealth(unit)))
end

do
	local allowedPowerUnits = {
		boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
		arena1 = true, arena2 = true, arena3 = true, arena4 = true, arena5 = true,
		arenapet1 = true, arenapet2 = true, arenapet3 = true, arenapet4 = true, arenapet5 = true
	}
	function sh.UNIT_POWER(unit, typeName)
		if not allowedPowerUnits[unit] then return end
		local typeIndex = UnitPowerType(unit)
		local mainPower = UnitPower(unit)
		local maxPower = UnitPowerMax(unit)
		local alternatePower = UnitPower(unit, 10)
		local alternatePowerMax = UnitPowerMax(unit, 10)
		return strjoin("#", unit, UnitName(unit), typeName, typeIndex, mainPower, maxPower, alternatePower, alternatePowerMax)
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
	SetMapToCurrentZone()
	local areaId = GetCurrentMapAreaID() or 0
	local areaLevel = GetCurrentMapDungeonLevel() or 0
	local id = ("%d:%d"):format(areaId, areaLevel)
	return strjoin("#", "Fake ID:", id, "Real Args:", tostringall(...))
end

function sh.CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if prefix == "Transcriptor" then
		return strjoin("#", "RAID_BOSS_WHISPER_SYNC", msg, sender)
	end
end

function sh.ENCOUNTER_START(...)
	compareStartTime = debugprofilestop()
	return strjoin("#", "ENCOUNTER_START", ...)
end

local function eventHandler(self, event, ...)
	if TranscriptDB.ignoredEvents[event] then return end
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
		tinsert(currentLog.total, format("<%.2f %s> [CLEU] %s", t, time, line))

		-- Throw this in here rather than polling it.
		if not inEncounter and IsEncounterInProgress() then
			inEncounter = true
			tinsert(currentLog.total, format("<%.2f %s> [IsEncounterInProgress()] true", t, time))
			if type(currentLog["IsEncounterInProgress()"]) ~= "table" then currentLog["IsEncounterInProgress()"] = {} end
			tinsert(currentLog["IsEncounterInProgress()"], format("<%.2f %s> true", t, time))
		elseif inEncounter and not IsEncounterInProgress() then
			inEncounter = false
			tinsert(currentLog.total, format("<%.2f %s> [IsEncounterInProgress()] false", t, time))
			if type(currentLog["IsEncounterInProgress()"]) ~= "table" then currentLog["IsEncounterInProgress()"] = {} end
			tinsert(currentLog["IsEncounterInProgress()"], format("<%.2f %s> false", t, time))
		end
	else
		local text = format("<%.2f %s> [%s] %s", t, time, event, line)
		tinsert(currentLog.total, text)
		if type(currentLog[event]) ~= "table" then currentLog[event] = {} end
		tinsert(currentLog[event], text)
	end
end
eventFrame:SetScript("OnEvent", eventHandler)

local wowEvents = {
	-- Raids
	"CHAT_MSG_ADDON",
	"COMBAT_LOG_EVENT_UNFILTERED",
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
	"INSTANCE_ENCOUNTER_ENGAGE_UNIT",
	"UNIT_TARGETABLE_CHANGED",
	"ENCOUNTER_START",
	"ENCOUNTER_END",
	"BOSS_KILL",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
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
local bwEvents = {
	"BigWigs_Message",
	"BigWigs_StartBar",
	--"BigWigs_Debug",
}
local dbmEvents = {
	"DBM_Announce",
	"DBM_TimerStart",
	"DBM_TimerStop",
}

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
			func = function() TranscriptDB.ignoredEvents[v] = not TranscriptDB.ignoredEvents[v] end,
			checked = function() return TranscriptDB.ignoredEvents[v] end,
			isNotRadio = true,
			keepShownOnClick = 1,
		})
		tinsert(Transcriptor.events, v)
	end
end

local init = CreateFrame("Frame")
init:SetScript("OnEvent", function(self, event, addon)
	TranscriptDB = TranscriptDB or {}
	if not TranscriptDB.ignoredEvents then TranscriptDB.ignoredEvents = {} end
	TranscriptDB.spellList = nil -- Cleanup XXX temp
	TranscriptDB.spellBookList = nil -- Cleanup XXX temp
	TranscriptDB.logAuraList = nil -- Cleanup XXX temp

	tinsert(menu, { text = L["|cFFFFD200Transcriptor|r - Disabled Events"], fontObject = "GameTooltipHeader", notCheckable = 1 })
	insertMenuItems(wowEvents)
	if BigWigsLoader then insertMenuItems(bwEvents) end
	if DBM then insertMenuItems(dbmEvents) end
	tinsert(menu, { text = CLOSE, func = function() CloseDropDownMenus() end, notCheckable = 1 })

	RegisterAddonMessagePrefix("Transcriptor")

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

local logNameFormat = "[%s]@[%s] - %d/%d/%s/%s/%s@%s" .. format(" (r%d) (%s.%s)", revision or 1, wowVersion, buildRevision)
function Transcriptor:StartLog(silent)
	if logging then
		print(L["You are already logging an encounter."])
	else
		ldb.text = L["|cffFF0000Recording|r"]
		ldb.icon = "Interface\\AddOns\\Transcriptor\\icon_on"

		compareStartTime = debugprofilestop()
		logStartTime = compareStartTime / 1000
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
		elseif diff == 7 then
			diff = "LFR25M"
		elseif diff == 8 then
			diff = "CM5M"
		elseif diff == 14 then
			diff = "Normal"
		elseif diff == 15 then
			diff = "Heroic"
		elseif diff == 16 then
			diff = "Mythic"
		elseif diff == 17 then
			diff = "LFR"
		elseif diff == 18 then
			diff = "Event40M"
		elseif diff == 19 then
			diff = "Event5M"
		elseif diff == 23 then
			diff = "Mythic5M"
		elseif diff == 24 then
			diff = "TW5M"
		else
			diff = tostring(diff)
		end
		SetMapToCurrentZone() -- Update map ID
		logName = format(logNameFormat, date("%Y-%m-%d"), date("%H:%M:%S"), GetCurrentMapAreaID(), select(8, GetInstanceInfo()), GetZoneText() or "?", GetRealZoneText() or "?", GetSubZoneText() or "none", diff)

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
					BigWigsLoader.RegisterMessage(eventFrame, event, BWEventHandler)
				end
			end
		end
		if DBM then
			for i, event in next, dbmEvents do
				if not TranscriptDB.ignoredEvents[event] then
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
			for i, event in next, dbmEvents do
				DBM:UnregisterCallback(event)
			end
		end
		--Notify Stop
		if not silent then
			print(L["Ending Transcript: "]..logName)
			print(L["Logs will probably be saved to WoW\\WTF\\Account\\<name>\\SavedVariables\\Transcriptor.lua once you relog or reload the user interface."])
		end

		if compareSuccess or compareStart then
			currentLog.TIMERS = {}
			if compareSuccess then
				currentLog.TIMERS.SPELL_CAST_SUCCESS = {}
				for id,tbl in next, compareSuccess do
					local n = format("%d-%s", id, (GetSpellInfo(id)))
					local str
					for i = 1, #tbl do
						if not str then
							local t = tbl[i] - compareStartTime
							str = format("pull:%.1f", t/1000)
						else
							local t = tbl[i] - tbl[i-1]
							str = format("%s, %.1f", str, t/1000)
						end
					end
					currentLog.TIMERS.SPELL_CAST_SUCCESS[n] = str
				end
			end
			if compareStart then
				currentLog.TIMERS.SPELL_CAST_START = {}
				for id,tbl in next, compareStart do
					local n = format("%d-%s", id, (GetSpellInfo(id)))
					local str
					for i = 1, #tbl do
						if not str then
							local t = tbl[i] - compareStartTime
							str = format("pull:%.1f", t/1000)
						else
							local t = tbl[i] - tbl[i-1]
							str = format("%s, %.1f", str, t/1000)
						end
					end
					currentLog.TIMERS.SPELL_CAST_START[n] = str
				end
			end
		end

		--Clear Log Path
		currentLog = nil
		logging = nil
		compareSuccess = nil
		compareStart = nil
		compareStartTime = nil
		logStartTime = nil

		return logName
	end
end

function Transcriptor:ClearAll()
	if not logging then
		local t2 = {}
		for k, v in next, TranscriptDB.ignoredEvents do
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
