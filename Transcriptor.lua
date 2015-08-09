
local Transcriptor = {}
local revision = tonumber(("$Revision$"):sub(12, -3))

local badPlayerSpellList
local playerSpellBlacklist
local badSourcelessPlayerSpellList

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
					if id and not ignoreList[id] and not badPlayerSpellList[id] and not playerSpellBlacklist[id] and not total[id] and #aurasSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
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
					if id and not ignoreList[id] and not badPlayerSpellList[id] and not playerSpellBlacklist[id] and not total[id] and #castsSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
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
					if id and not ignoreList[id] and not badPlayerSpellList[id] and not playerSpellBlacklist[id] and not total[id] and #summonSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
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
		text = ""
		for i = 1, #totalSorted do
			local id = totalSorted[i]
			local name = GetSpellInfo(id)
			text = format("%s[%d] = true, -- %s\n", text, id, name)
		end
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
	badPlayerSpellList = {
		-- AURAs
		-- Example command for pulling all player->player buffs from a transcript:
		-- sed -r -e '/SPELL_AURA.*?#(Player|Pet)-.*#(Player|Pet)-.*#BUFF/!d' \
		--        -e 's/.*?\[CLEU\] .*#([0-9]+)#([^#]+)#.*", --.*/[\1] = "\2",/' \
		--     Transcriptor.lua | sort | uniq > output.txt
		-- Don't add spells without checking them first!

		-- Debuffs
		[104232] = "Rain of Fire",
		[105771] = "Charge",
		[108685] = "Conflagrate",
		[113344] = "Bloodbath",
		[113942] = "Demonic Gateway",
		[114216] = "Angelic Bulwark",
		[115356] = "Windstrike",
		[115767] = "Deep Wounds",
		[115804] = "Mortal Wounds",
		[116888] = "Shroud of Purgatory",
		[118895] = "Dragon Roar",
		[119381] = "Leg Sweep",
		[120360] = "Barrage",
		[123981] = "Perdition",
		[124273] = "Heavy Stagger",
		[124274] = "Moderate Stagger",
		[124275] = "Light Stagger",
		[124280] = "Touch of Karma",
		[12654] = "Ignite",
		[127797] = "Ursol's Vortex",
		[128531] = "Blackout Kick",
		[129197] = "Insanity",
		[129250] = "Power Word: Solace",
		[130320] = "Rising Sun Kick",
		[130736] = "Soul Reaper",
		[132168] = "Shockwave",
		[132169] = "Storm Bolt",
		[135299] = "Ice Trap",
		[13812] = "Explosive Trap",
		[146739] = "Corruption",
		[147531] = "Bloodbath",
		[15407] = "Mind Flay",
		[155159] = "Necrotic Plague",
		[155166] = "Mark of Sindragosa",
		[156004] = "Defile",
		[156432] = "Draenic Channeled Mana Potion",
		[157335] = "Will of the Necropolis",
		[157680] = "Chi Explosion",
		[157736] = "Immolate",
		[157981] = "Blast Wave",
		[158831] = "Devouring Plague",
		[160029] = "Resurrecting",
		[164812] = "Moonfire",
		[164815] = "Sunfire",
		[17364] = "Stormstrike",
		[25771] = "Forbearance",
		[29341] = "Shadowburn",
		[30283] = "Shadowfury",
		[31661] = "Dragon's Breath",
		[36032] = "Arcane Charge",
		[41425] = "Hypothermia",
		[44457] = "Living Bomb",
		[45181] = "Cheated Death",
		[48743] = "Death Pact",
		[49560] = "Death Grip",
		[50613] = "Arcane Torrent",
		[51399] = "Death Grip",
		[55078] = "Blood Plague",
		[55095] = "Frost Fever",
		[57723] = "Exhaustion",
		[57724] = "Sated",
		[61391] = "Typhoon",
		[6788] = "Weakened Soul",
		[80354] = "Temporal Displacement",
		[80483] = "Arcane Torrent",
		[8050] = "Flame Shock",
		[8056] = "Frost Shock",
		[83853] = "Combustion",
		[87023] = "Cauterize",
		[87024] = "Cauterized",
		[95223] = "Recently Mass Resurrected",

		-- Buffs
		[100977] = "Harmony",
		[101185] = "Leyara's Locket",
		[102352] = "Cenarion Ward",
		[102543] = "Incarnation: King of the Jungle",
		[102560] = "Incarnation: Chosen of Elune",
		[104232] = "Rain of Fire",
		[105809] = "Holy Avenger",
		[106951] = "Berserk",
		[107574] = "Avatar",
		[108271] = "Astral Shift",
		[108281] = "Ancestral Guidance",
		[108294] = "Heart of the Wild",
		[108359] = "Dark Regeneration",
		[108366] = "Soul Leech",
		[108416] = "Sacrificial Pact",
		[108446] = "Soul Link",
		[108503] = "Grimoire of Sacrifice",
		[108839] = "Ice Floes",
		[109128] = "Charge",
		[110909] = "Alter Time",
		[110913] = "Dark Bargain",
		[110960] = "Greater Invisibility",
		[111264] = "Ice Ward",
		[111400] = "Burning Rush",
		[112833] = "Spectral Guise",
		[112942] = "Shadow Focus",
		[113862] = "Greater Invisibility",
		[114028] = "Mass Spell Reflection",
		[114051] = "Ascendance",
		[114214] = "Angelic Bulwark",
		[114232] = "Sanctified Wrath",
		[114250] = "Selfless Healer",
		[114255] = "Surge of Light",
		[114282] = "Treant Form",
		[114637] = "Bastion of Glory",
		[114695] = "Pursuit of Justice",
		[114851] = "Blood Charge",
		[114868] = "Soul Reaper",
		[114917] = "Stay of Execution",
		[114919] = "Arcing Light",
		[115000] = "Remorseless Winter",
		[115001] = "Remorseless Winter",
		[115189] = "Anticipation",
		[115191] = "Stealth",
		[115192] = "Subterfuge",
		[115288] = "Energizing Brew",
		[115307] = "Shuffle",
		[115547] = "Glyph of Avenging Wrath",
		[115654] = "Glyph of Denounce",
		[115668] = "Glyph of Templar's Verdict",
		[115867] = "Mana Tea",
		[116014] = "Rune of Power",
		[116740] = "Tigereye Brew",
		[116768] = "Combo Breaker: Blackout Kick",
		[116841] = "Tiger's Lust",
		[116847] = "Rushing Jade Wind",
		[116956] = "Grace of Air",
		[117050] = "Glaive Toss",
		[117679] = "Incarnation",
		[117828] = "Backdraft",
		[118291] = "Fire Elemental Totem",
		[118323] = "Earth Elemental Totem",
		[118340] = "Impending Victory",
		[118455] = "Beast Cleave",
		[118470] = "Unleashed Fury",
		[118472] = "Unleashed Fury",
		[118473] = "Unleashed Fury",
		[118522] = "Elemental Blast: Critical Strike",
		[118674] = "Vital Mists",
		[118779] = "Victory Rush",
		[118864] = "Combo Breaker: Tiger Palm",
		[118922] = "Posthaste",
		[119085] = "Momentum",
		[119415] = "Blink",
		[119611] = "Renewing Mist",
		[119899] = "Cauterize Master",
		[120273] = "Tiger Strikes",
		[120360] = "Barrage",
		[120587] = "Glyph of Mind Flay",
		[120954] = "Fortifying Brew",
		[121125] = "Death Note",
		[121153] = "Blindside",
		[121557] = "Angelic Feather",
		[122278] = "Dampen Harm",
		[122470] = "Touch of Karma",
		[122510] = "Ultimatum",
		[122783] = "Diffuse Magic",
		[12292] = "Bloodbath",
		[123254] = "Twist of Fate",
		[123262] = "Prayer of Mending",
		[123267] = "Divine Insight",
		[124081] = "Zen Sphere",
		[124430] = "Shadowy Insight",
		[125195] = "Tigereye Brew",
		[125359] = "Tiger Power",
		[125950] = "Soothing Mist",
		[126154] = "Lightwell Renew",
		[126373] = "Fearless Roar",
		[127722] = "Crane's Zeal",
		[12880] = "Enrage",
		[128939] = "Elusive Brew",
		[128997] = "Spirit Beast Blessing",
		[129914] = "Power Strikes",
		[131116] = "Raging Blow!",
		[132120] = "Enveloping Mist",
		[132402] = "Savage Defense",
		[132403] = "Shield of the Righteous",
		[132404] = "Shield Block",
		[132413] = "Shadow Bulwark",
		[132573] = "Insanity",
		[134563] = "Healing Elixirs",
		[135286] = "Tooth and Claw",
		[135700] = "Clearcasting",
		[137452] = "Displacer Beast",
		[137573] = "Burst of Speed",
		[137639] = "Storm, Earth, and Fire",
		[142912] = "Glyph of Lightning Shield",
		[144595] = "Divine Crusader",
		[145629] = "Anti-Magic Zone",
		[147065] = "Glyph of Inspired Hymns",
		[147364] = "Rapid Rolling",
		[147833] = "Intervene",
		[148899] = "Tenacious",
		[152151] = "Shadow Reflection",
		[152173] = "Serenity",
		[152255] = "Liquid Magma",
		[152277] = "Ravager",
		[152279] = "Breath of Sindragosa",
		[155362] = "Word of Mending",
		[155363] = "Mending",
		[155631] = "Clearcasting",
		[155777] = "Rejuvenation (Germination)",
		[155784] = "Primal Tenacity",
		[156132] = "World Shrinker",
		[156150] = "Flowing Thoughts",
		[156322] = "Eternal Flame",
		[156423] = "Draenic Agility Potion",
		[156426] = "Draenic Intellect Potion",
		[156428] = "Draenic Strength Potion",
		[156430] = "Draenic Armor Potion",
		[156436] = "Draenic Mana Potion",
		[156438] = "Healing Tonic",
		[156719] = "Venom Rush",
		[156910] = "Beacon of Faith",
		[157048] = "Final Verdict",
		[157146] = "Enhanced Leap of Faith",
		[157174] = "Elemental Fusion",
		[157228] = "Empowered Moonkin",
		[157384] = "Eye of the Storm",
		[157562] = "Crimson Poison",
		[157610] = "Improved Blink",
		[157633] = "Improved Scorch",
		[157644] = "Enhanced Pyrotechnics",
		[157698] = "Haunting Spirits",
		[157766] = "Enhanced Chain Lightning",
		[157913] = "Evanesce",
		[158108] = "Enhanced Vendetta",
		[158300] = "Resolve",
		[158792] = "Pulverize",
		[159233] = "Ursa Major",
		[159363] = "Blood Craze",
		[159407] = "Combo Breaker: Chi Explosion",
		[159430] = "Glyph of Runic Power",
		[159537] = "Glyph of Soothing Mist",
		[159756] = "Glyph of Rallying Cry",
		[160002] = "Enhanced Holy Shock",
		[160200] = "Lone Wolf: Ferocity of the Raptor",
		[160203] = "Lone Wolf: Haste of the Hyena",
		[160331] = "Blood Elf Illusion",
		[160373] = "Glyph of Celestial Alignment",
		[16166] = "Elemental Mastery",
		[16188] = "Ancestral Swiftness",
		[162557] = "Enhanced Unleash",
		[162915] = "Spirit of the Warlords",
		[162917] = "Strength of Steel",
		[162919] = "Nightmare Fire",
		[162997] = "Nightmarish Reins",
		[164047] = "Shadow of Death",
		[164545] = "Solar Empowerment",
		[164547] = "Lunar Empowerment",
		[164857] = "Survivalist",
		[165185] = "Bloodclaw Charm",
		[165442] = "Crusader's Fury",
		[165530] = "Deadly Aim",
		[165531] = "Haste",
		[165961] = "Travel Form",
		[166587] = "Deadly Calm",
		[166588] = "Rampage",
		[166603] = "Forceful Winds",
		[166780] = "Lawful Words",
		[166781] = "Light's Favor",
		[166868] = "Pyromaniac",
		[166869] = "Ice Shard",
		[166871] = "Arcane Affinity",
		[166872] = "Arcane Instability",
		[166916] = "Windflurry",
		[167187] = "Sanctity Aura",
		[167204] = "Feral Spirit",
		[167254] = "Mental Instinct",
		[167695] = "Clear Thoughts",
		[167732] = "Mistweaving",
		[16870] = "Clearcasting",
		[168811] = "Sniper Training",
		[168980] = "Lock and Load",
		[169686] = "Unyielding Strikes",
		[169688] = "Shield Mastery",
		[170000] = "Chaotic Infusion",
		[170202] = "Frozen Runeblade",
		[170808] = "Protection of Chi-Ji",
		[171049] = "Rune Tap",
		[171743] = "Lunar Peak",
		[171744] = "Solar Peak",
		[172359] = "Empowered Archangel",
		[173183] = "Elemental Blast: Haste",
		[173184] = "Elemental Blast: Mastery",
		[173185] = "Elemental Blast: Multistrike",
		[173187] = "Elemental Blast: Spirit",
		[173260] = "Shieldtronic Shield",
		[174544] = "Savage Roar",
		[175439] = "Stout Augmentation",
		[175456] = "Hyper Augmentation",
		[175457] = "Focus Augmentation",
		[176873] = "Turnbuckle Terror",
		[176874] = "Convulsive Shadows",
		[176878] = "Lub-Dub",
		[176978] = "Immaculate Living Mushroom",
		[176984] = "Blackheart Enforcer's Medallion",
		[177035] = "Meaty Dragonspine Trophy",
		[177038] = "Balanced Fate",
		[177040] = "Tectus' Heartbeat",
		[177042] = "Screaming Spirits",
		[177046] = "Howling Soul",
		[177051] = "Instability",
		[177053] = "Gazing Eye",
		[177056] = "Blast Furnace",
		[177060] = "Squeak Squeak",
		[177063] = "Elemental Shield",
		[177067] = "Detonation",
		[177070] = "Detonating",
		[177081] = "Molten Metal",
		[177083] = "Pouring Slag",
		[177086] = "Sanitizing",
		[177087] = "Cleansing Steam",
		[177096] = "Forgemaster's Vigor",
		[177099] = "Hammer Blows",
		[177102] = "Battering",
		[177159] = "Archmage's Incandescence",
		[177160] = "Archmage's Incandescence",
		[177161] = "Archmage's Incandescence",
		[177172] = "Archmage's Greater Incandescence",
		[177175] = "Archmage's Greater Incandescence",
		[177176] = "Archmage's Greater Incandescence",
		[177189] = "Sword Technique",
		[177668] = "Steady Focus",
		[179334] = "Nature's Bounty",
		[179338] = "Searing Insanity",
		[180612] = "Recently Death Striked",
		[182057] = "Surge of Dominance",
		[183924] = "Sign of the Dark Star",
		[183926] = "Countenance of Tyranny",
		[183929] = "Sudden Intuition",
		[183931] = "Anzu's Flight",
		[183941] = "Hungering Blows",
		[184293] = "Spirit Shift",
		[184671] = "Shadowfel Infusion",
		[184770] = "Tyrant's Immortality",
		[184989] = "Starfall",
		[185002] = "Sunfall",
		[185158] = "Extend Life",
		[185562] = "Darkmoon Firewater",
		[185576] = "Beacon's Tribute",
		[185577] = "Undying Salvation",
		[185647] = "Wings of Liberty",
		[185676] = "Avenger's Reprieve",
		[185875] = "Riptide",
		[186286] = "Adrenaline Rush",
		[186367] = "Prayer's Reprise",
		[186478] = "Reparation",
		[187146] = "Tome of Secrets",
		[187174] = "Jewel of Hellfire",
		[187616] = "Nithramus",
		[187617] = "Sanctus",
		[187618] = "Etheralus",
		[187619] = "Thorasus",
		[187620] = "Maalus",
		[187805] = "Etheralus",
		[187806] = "Maalus",
		[187807] = "Etheralus",
		[187808] = "Sanctus",
		[187893] = "Obliteration",
		[187894] = "Frozen Wake",
		[187981] = "Crazed Monstrosity",
		[188086] = "Faerie Blessing",
		[188202] = "Rapid Fire",
		[188550] = "Lifebloom",
		[188700] = "Deathly Shadows",
		[188779] = "Premonition",
		[189063] = "Lightning Vortex",
		[189078] = "Gathering Vortex",
		[190027] = "Surge of Dominance",
		[19615] = "Frenzy",
		[20572] = "Blood Fury",
		[20925] = "Sacred Shield",
		[24450] = "Prowl",
		[24604] = "Furious Howl",
		[24907] = "Moonkin Aura",
		[24932] = "Leader of the Pack",
		[26297] = "Berserking",
		[2645] = "Ghost Wolf",
		[27827] = "Spirit of Redemption",
		[2825] = "Bloodlust",
		[30823] = "Shamanistic Rage",
		[31616] = "Nature's Guardian",
		[31665] = "Master of Subtlety",
		[31884] = "Avenging Wrath",
		[32182] = "Heroism",
		[32216] = "Victorious",
		[324] = "Lightning Shield",
		[32612] = "Invisibility",
		[32752] = "Summoning Disorientation",
		[33702] = "Blood Fury",
		[33891] = "Incarnation: Tree of Life",
		[34720] = "Thrill of the Hunt",
		[35079] = "Misdirection",
		[36554] = "Shadowstep",
		[41635] = "Prayer of Mending",
		[44544] = "Fingers of Frost",
		[45182] = "Cheating Death",
		[45242] = "Focused Will",
		[46916] = "Bloodsurge",
		[46924] = "Bladestorm",
		[47753] = "Divine Aegis",
		[48107] = "Heating Up",
		[48108] = "Pyroblast!",
		[48504] = "Living Seed",
		[50227] = "Sword and Board",
		[50334] = "Berserk",
		[50421] = "Scent of Blood",
		[51460] = "Runic Corruption",
		[51755] = "Camouflage",
		[52437] = "Sudden Death",
		[53257] = "Cobra Strikes",
		[53365] = "Unholy Strength",
		[53390] = "Tidal Waves",
		[53817] = "Maelstrom Weapon",
		[54149] = "Infusion of Light",
		[546] = "Water Walking",
		[54957] = "Glyph of Flash of Light",
		[55342] = "Mirror Image",
		[55694] = "Enraged Regeneration",
		[57761] = "Brain Freeze",
		[58875] = "Spirit Walk",
		[58984] = "Shadowmeld",
		[59547] = "Gift of the Naaru",
		[59578] = "Exorcism!",
		[59628] = "Tricks of the Trade",
		[59889] = "Borrowed Time",
		[60233] = "Agility",
		[60478] = "Summon Doomguard",
		[61648] = "Aspect of the Beast",
		[61684] = "Dash",
		[6262] = "Healthstone",
		[63735] = "Serendipity",
		[64844] = "Divine Hymn",
		[65081] = "Body and Soul",
		[65116] = "Stoneform",
		[65148] = "Sacred Shield",
		[69369] = "Predatory Swiftness",
		[73681] = "Unleash Wind",
		[73683] = "Unleash Flame",
		[74001] = "Combat Readiness",
		[74002] = "Combat Insight",
		[77489] = "Echo of Light",
		[77535] = "Blood Shield",
		[77616] = "Dark Simulacrum",
		[77761] = "Stampeding Roar",
		[77762] = "Lava Surge",
		[79683] = "Arcane Missiles!",
		[80240] = "Havoc",
		[81141] = "Crimson Scourge",
		[81256] = "Dancing Rune Weapon",
		[81340] = "Sudden Doom",
		[81661] = "Evangelism",
		[81782] = "Power Word: Barrier",
		[8190] = "Magma Totem",
		[8222] = "Yaaarrrr",
		[82626] = "Grounded Plasma Shield",
		[82921] = "Bombardment",
		[84745] = "Shallow Insight",
		[84746] = "Moderate Insight",
		[84747] = "Deep Insight",
		[85416] = "Grand Crusader",
		[85499] = "Speed of Light",
		[85739] = "Meat Cleaver",
		[86211] = "Soul Swap",
		[86273] = "Illuminated Healing",
		[86663] = "Rude Interruption",
		[87160] = "Surge of Darkness",
		[87173] = "Long Arm of the Law",
		[88684] = "Holy Word: Serenity",
		[88819] = "Daybreak",
		[90174] = "Divine Purpose",
		[90328] = "Spirit Walk",
		[91342] = "Shadow Infusion",
		[93400] = "Shooting Stars",
		[93435] = "Roar of Courage",
		[93622] = "Mangle!",
		[94632] = "Illusion",
		[94686] = "Supplication",
		[96206] = "Glyph of Rejuvenation",
		[96243] = "Invisibility",
		[96312] = "Kalytha's Haunted Locket",
		[97463] = "Rallying Cry",
		[98444] = "Vrykul Drinking Horn",

		-- Spells not from the spell book (talents and misc stuff)
		[101568] = "Dark Succor",
		[102280] = "Displacer Beast",
		[102793] = "Ursol's Vortex",
		[103840] = "Impending Victory",
		[105593] = "Fist of Justice",
		[105809] = "Holy Avenger",
		[106830] = "Thrash",
		[106996] = "Astral Storm",
		[107570] = "Storm Bolt",
		[108199] = "Gorefiend's Grasp",
		[108200] = "Remorseless Winter",
		[108270] = "Stone Bulwark Totem",
		[108273] = "Windwalk Totem",
		[108285] = "Call of the Elements",
		[108359] = "Dark Regeneration",
		[108446] = "Soul Link",
		[108557] = "Jab",
		[108686] = "Immolate",
		[108839] = "Ice Floes",
		[108853] = "Inferno Blast",
		[108978] = "Alter Time",
		[109248] = "Binding Shot",
		[109304] = "Exhilaration",
		[110744] = "Divine Star",
		[110959] = "Greater Invisibility",
		[111264] = "Ice Ward",
		[112833] = "Spectral Guise",
		[112927] = "Summon Terrorguard",
		[113724] = "Ring of Frost",
		[114028] = "Mass Spell Reflection",
		[114074] = "Lava Beam",
		[114089] = "Windlash",
		[114093] = "Windlash Off-Hand",
		[114157] = "Execution Sentence",
		[114158] = "Light's Hammer",
		[114163] = "Eternal Flame",
		[114165] = "Holy Prism",
		[114654] = "Incinerate",
		[114790] = "Seed of Corruption",
		[114923] = "Nether Tempest",
		[115098] = "Chi Wave",
		[115284] = "Clone Magic",
		[115399] = "Chi Brew",
		[115693] = "Jab",
		[115746] = "Felbolt",
		[115778] = "Tongue Lash",
		[115989] = "Unholy Blight",
		[117014] = "Elemental Blast",
		[117405] = "Binding Shot",
		[117418] = "Fists of Fury",
		[118000] = "Dragon Roar",
		[118297] = "Immolate",
		[119031] = "Gift of the Serpent",
		[119392] = "Charging Ox Wave",
		[11958] = "Cold Snap",
		[119899] = "Cauterize Master",
		[119905] = "Cauterize Master",
		[119911] = "Optical Blast",
		[120361] = "Barrage",
		[120517] = "Halo",
		[120644] = "Halo",
		[121135] = "Cascade",
		[121283] = "Chi Sphere",
		[121536] = "Angelic Feather",
		[121783] = "Emancipate",
		[122032] = "Exorcism",
		[12294] = "Mortal Strike",
		[123259] = "Prayer of Mending",
		[123273] = "Surging Mist",
		[123687] = "Charging Ox Wave",
		[123693] = "Plague Leech",
		[123761] = "Mana Tea",
		[123904] = "Invoke Xuen, the White Tiger",
		[123986] = "Chi Burst",
		[124081] = "Zen Sphere",
		[124503] = "Gift of the Ox",
		[124506] = "Gift of the Ox",
		[124916] = "Chaos Wave",
		[125355] = "Healing Sphere",
		[126393] = "Eternal Guardian",
		[127140] = "Alter Time",
		[127632] = "Cascade",
		[129176] = "Shadow Word: Death",
		[129597] = "Arcane Torrent",
		[130654] = "Chi Burst",
		[131894] = "A Murder of Crows",
		[132409] = "Spell Lock",
		[132603] = "Shadowfiend",
		[132604] = "Mindbender",
		[133] = "Fireball",
		[135029] = "Water Jet",
		[135920] = "Gift of the Serpent",
		[137619] = "Marked for Death",
		[13810] = "Ice Trap",
		[139546] = "Combo Point",
		[145629] = "Anti-Magic Zone",
		[147193] = "Shadowy Apparition",
		[147349] = "Wild Mushroom",
		[147489] = "Expel Harm",
		[148135] = "Chi Burst",
		[152087] = "Prismatic Crystal",
		[152118] = "Clarity of Will",
		[152151] = "Shadow Reflection",
		[152174] = "Chi Explosion",
		[152245] = "Focusing Shot",
		[152256] = "Storm Elemental Totem",
		[152280] = "Defile",
		[153595] = "Comet Storm",
		[153626] = "Arcane Orb",
		[153640] = "Arcane Orb",
		[155145] = "Arcane Torrent",
		[155245] = "Clarity of Purpose",
		[155521] = "Auspicious Spirits",
		[155592] = "Sunfall",
		[155625] = "Moonfire",
		[157701] = "Chaos Bolt",
		[157708] = "Kill Shot",
		[157750] = "Summon Water Elemental",
		[157897] = "Summon Terrorguard",
		[157900] = "Grimoire: Doomguard",
		[157980] = "Supernova",
		[157982] = "Tranquility",
		[157997] = "Ice Nova",
		[158392] = "Hammer of Wrath",
		[159556] = "Consecration",
		[160067] = "Web Spray",
		[163212] = "Healing Sphere",
		[163485] = "Focusing Shot",
		[164862] = "Flap",
		[16511] = "Hemorrhage",
		[16827] = "Claw",
		[16953] = "Primal Fury",
		[16979] = "Wild Charge",
		[171138] = "Shadow Lock",
		[171140] = "Shadow Lock",
		[17253] = "Bite",
		[175821] = "Pure Rage",
		[176289] = "Siegebreaker",
		[177592] = "Whisper of Spirits",
		[178173] = "Gift of the Ox",
		[178207] = "Drums of Fury",
		[179337] = "Searing Insanity",
		[182387] = "Earthquake",
		[184270] = "Burning Mirror",
		[185187] = "Eviscerate",
		[187611] = "Nithramus",
		[187612] = "Etheralus",
		[187613] = "Sanctus",
		[187614] = "Thorasus",
		[187615] = "Maalus",
		[188046] = "Fey Missile",
		[188550] = "Lifebloom",
		[189429] = "Dire Beast",
		[19386] = "Wyvern Sting",
		[20925] = "Sacred Shield",
		[21169] = "Reincarnation",
		[27576] = "Mutilate Off-Hand",
		[31707] = "Waterbolt",
		[32182] = "Heroism",
		[33697] = "Blood Fury",
		[3606] = "Searing Bolt",
		[36554] = "Shadowstep",
		[42208] = "Blizzard",
		[45529] = "Blood Tap",
		[46968] = "Shockwave",
		[47666] = "Penance",
		[47750] = "Penance",
		[49376] = "Wild Charge",
		[49821] = "Mind Sear",
		[50334] = "Berserk",
		[50622] = "Bladestorm",
		[51052] = "Anti-Magic Zone",
		[51124] = "Killing Machine",
		[51963] = "Gargoyle Strike",
		[52174] = "Heroic Leap",
		[58984] = "Shadowmeld",
		[59052] = "Freezing Fog",
		[59547] = "Gift of the Naaru",
		[60192] = "Freezing Trap",
		[63619] = "Shadowcrawl",
		[69070] = "Rocket Jump",
		[69179] = "Arcane Torrent",
		[7268] = "Arcane Missiles",
		[74001] = "Combat Readiness",
		[77758] = "Thrash",
		[77761] = "Stampeding Roar",
		[82939] = "Explosive Trap",
		[82941] = "Ice Trap",
		[85384] = "Raging Blow Off-Hand",
		[85692] = "Doom Bolt",
		[86213] = "Soul Swap Exhale",
		[88263] = "Hammer of the Righteous",
		[88685] = "Holy Word: Sanctuary",
		[90361] = "Spirit Mend",
		[93402] = "Sunfire",
		[96103] = "Raging Blow",
		[98057] = "Grand Crusader",

		-- SPELL_SUMMON
		[112869] = "Summon Observer",
		[112926] = "Summon Terrorguard",
		[113724] = "Ring of Frost",
		[116011] = "Rune of Power",
		[117663] = "Fire Elemental Totem",
		[117753] = "Earth Elemental",
		[121818] = "Stampede",
		[123040] = "Mindbender",
		[123904] = "Invoke Xuen, the White Tiger",
		[126135] = "Lightwell",
		[132603] = "Shadowfiend",
		[132604] = "Mindbender",
		[138121] = "Storm, Earth, and Fire",
		[138122] = "Storm, Earth, and Fire",
		[138123] = "Storm, Earth, and Fire",
		[152087] = "Prismatic Crystal",
		[152151] = "Shadow Reflection",
		[152277] = "Ravager",
		[157299] = "Storm Elemental Totem",
		[157319] = "Storm Elemental Totem",
		[166862] = "Inner Demon",
		[169018] = "Defile",
		[184271] = "Burning Mirror",
		[184272] = "Burning Mirror",
		[184273] = "Burning Mirror",
		[184274] = "Burning Mirror",
		[188083] = "Fey Moonwing",
		[2894] = "Fire Elemental Totem",
		[3599] = "Searing Totem",
		[42651] = "Army of the Dead",
		[49028] = "Dancing Rune Weapon",
		[51485] = "Earthgrab Totem",
		[51533] = "Feral Spirit",
		[52150] = "Raise Dead",
		[58831] = "Mirror Image",
		[58833] = "Mirror Image",
		[58834] = "Mirror Image",
	}
	playerSpellBlacklist = {
		[10] = true, -- Blizzard
		[17] = true, -- Power Word: Shield
		[53] = true, -- Backstab
		[66] = true, -- Invisibility
		[71] = true, -- Defensive Stance
		[78] = true, -- Heroic Strike
		[100] = true, -- Charge
		[116] = true, -- Frostbolt
		[120] = true, -- Cone of Cold
		[122] = true, -- Frost Nova
		[136] = true, -- Mend Pet
		[139] = true, -- Renew
		[172] = true, -- Corruption
		[348] = true, -- Immolate
		[355] = true, -- Taunt
		[370] = true, -- Purge
		[403] = true, -- Lightning Bolt
		[408] = true, -- Kidney Shot
		[421] = true, -- Chain Lightning
		[469] = true, -- Commanding Shout
		[475] = true, -- Remove Curse
		[498] = true, -- Divine Protection
		[527] = true, -- Purify
		[528] = true, -- Dispel Magic
		[585] = true, -- Smite
		[586] = true, -- Fade
		[589] = true, -- Shadow Word: Pain
		[596] = true, -- Prayer of Healing
		[603] = true, -- Doom
		[633] = true, -- Lay on Hands
		[642] = true, -- Divine Shield
		[686] = true, -- Shadow Bolt
		[689] = true, -- Drain Life
		[691] = true, -- Summon Felhunter
		[697] = true, -- Summon Voidwalker
		[703] = true, -- Garrote
		[724] = true, -- Lightwell
		[740] = true, -- Tranquility
		[768] = true, -- Cat Form
		[770] = true, -- Faerie Fire
		[772] = true, -- Rend
		[774] = true, -- Rejuvenation
		[853] = true, -- Hammer of Justice
		[871] = true, -- Shield Wall
		[879] = true, -- Exorcism
		[883] = true, -- Call Pet 1
		[974] = true, -- Earth Shield
		[980] = true, -- Agony
		[1022] = true, -- Hand of Protection
		[1044] = true, -- Hand of Freedom
		[1064] = true, -- Chain Heal
		[1079] = true, -- Rip
		[1122] = true, -- Summon Infernal
		[1126] = true, -- Mark of the Wild
		[1160] = true, -- Demoralizing Shout
		[1329] = true, -- Mutilate
		[1459] = true, -- Arcane Brilliance
		[1706] = true, -- Levitate
		[1715] = true, -- Hamstring
		[1719] = true, -- Recklessness
		[1752] = true, -- Sinister Strike
		[1766] = true, -- Kick
		[1776] = true, -- Gouge
		[1784] = true, -- Stealth
		[1822] = true, -- Rake
		[1833] = true, -- Cheap Shot
		[1850] = true, -- Dash
		[1943] = true, -- Rupture
		[1953] = true, -- Blink
		[1966] = true, -- Feint
		[2060] = true, -- Heal
		[2061] = true, -- Flash Heal
		[2062] = true, -- Earth Elemental Totem
		[2098] = true, -- Eviscerate
		[2120] = true, -- Flamestrike
		[2139] = true, -- Counterspell
		[2457] = true, -- Battle Stance
		[2484] = true, -- Earthbind Totem
		[2649] = true, -- Growl
		[2782] = true, -- Remove Corruption
		[2812] = true, -- Denounce
		[2818] = true, -- Deadly Poison
		[2823] = true, -- Deadly Poison
		[2908] = true, -- Soothe
		[2912] = true, -- Starfire
		[2944] = true, -- Devouring Plague
		[2948] = true, -- Scorch
		[2983] = true, -- Sprint
		[3044] = true, -- Arcane Shot
		[3045] = true, -- Rapid Fire
		[3110] = true, -- Firebolt
		[3355] = true, -- Freezing Trap
		[3408] = true, -- Crippling Poison
		[3409] = true, -- Crippling Poison
		[3411] = true, -- Intervene
		[3674] = true, -- Black Arrow
		[4987] = true, -- Cleanse
		[5019] = true, -- Shoot
		[5116] = true, -- Concussive Shot
		[5118] = true, -- Aspect of the Cheetah
		[5171] = true, -- Slice and Dice
		[5176] = true, -- Wrath
		[5185] = true, -- Healing Touch
		[5211] = true, -- Mighty Bash
		[5215] = true, -- Prowl
		[5217] = true, -- Tiger's Fury
		[5221] = true, -- Shred
		[5225] = true, -- Track Humanoids
		[5246] = true, -- Intimidating Shout
		[5277] = true, -- Evasion
		[5308] = true, -- Execute
		[5394] = true, -- Healing Stream Totem
		[5487] = true, -- Bear Form
		[5782] = true, -- Fear
		[6343] = true, -- Thunder Clap
		[6346] = true, -- Fear Ward
		[6353] = true, -- Soul Fire
		[6552] = true, -- Pummel
		[6572] = true, -- Revenge
		[6673] = true, -- Battle Shout
		[6789] = true, -- Mortal Coil
		[6795] = true, -- Growl
		[6807] = true, -- Maul
		[6940] = true, -- Hand of Sacrifice
		[7001] = true, -- Lightwell Renew
		[7321] = true, -- Chilled
		[7870] = true, -- Lesser Invisibility
		[8004] = true, -- Healing Surge
		[8042] = true, -- Earth Shock
		[8092] = true, -- Mind Blast
		[8143] = true, -- Tremor Totem
		[8177] = true, -- Grounding Totem
		[8212] = true, -- Giant Growth
		[8676] = true, -- Ambush
		[8680] = true, -- Wound Poison
		[8921] = true, -- Moonfire
		[8936] = true, -- Regrowth
		[10060] = true, -- Power Infusion
		[10326] = true, -- Turn Evil
		[11129] = true, -- Combustion
		[11366] = true, -- Pyroblast
		[11426] = true, -- Ice Barrier
		[12042] = true, -- Arcane Power
		[12043] = true, -- Presence of Mind
		[12051] = true, -- Evocation
		[12323] = true, -- Piercing Howl
		[12328] = true, -- Sweeping Strikes
		[12472] = true, -- Icy Veins
		[12975] = true, -- Last Stand
		[13159] = true, -- Aspect of the Pack
		[13750] = true, -- Adrenaline Rush
		[13819] = true, -- Summon Warhorse
		[13877] = true, -- Blade Flurry
		[14183] = true, -- Premeditation
		[14914] = true, -- Holy Fire
		[15286] = true, -- Vampiric Embrace
		[15473] = true, -- Shadowform
		[15487] = true, -- Silence
		[15571] = true, -- Dazed
		[16591] = true, -- Noggenfogger Elixir
		[16593] = true, -- Noggenfogger Elixir
		[16595] = true, -- Noggenfogger Elixir
		[16739] = true, -- Orb of Deception
		[16914] = true, -- Hurricane
		[17735] = true, -- Suffering
		[17877] = true, -- Shadowburn
		[17962] = true, -- Conflagrate
		[18499] = true, -- Berserker Rage
		[18540] = true, -- Summon Doomguard
		[18562] = true, -- Swiftmend
		[19263] = true, -- Deterrence
		[19434] = true, -- Aimed Shot
		[19506] = true, -- Trueshot Aura
		[19574] = true, -- Bestial Wrath
		[19577] = true, -- Intimidation
		[19740] = true, -- Blessing of Might
		[19750] = true, -- Flash of Light
		[19801] = true, -- Tranquilizing Shot
		[20154] = true, -- Seal of Righteousness
		[20165] = true, -- Seal of Insight
		[20217] = true, -- Blessing of Kings
		[20243] = true, -- Devastate
		[20271] = true, -- Judgment
		[20473] = true, -- Holy Shock
		[20484] = true, -- Rebirth
		[20707] = true, -- Soulstone
		[20736] = true, -- Distracting Shot
		[21562] = true, -- Power Word: Fortitude
		[22568] = true, -- Ferocious Bite
		[22703] = true, -- Infernal Awakening
		[22812] = true, -- Barkskin
		[23161] = true, -- Dreadsteed
		[23214] = true, -- Summon Charger
		[23881] = true, -- Bloodthirst
		[23920] = true, -- Spell Reflection
		[23922] = true, -- Shield Slam
		[24275] = true, -- Hammer of Wrath
		[24394] = true, -- Intimidation
		[24858] = true, -- Moonkin Form
		[26679] = true, -- Deadly Throw
		[27243] = true, -- Seed of Corruption
		[28880] = true, -- Gift of the Naaru
		[29722] = true, -- Incinerate
		[30108] = true, -- Unstable Affliction
		[30151] = true, -- Pursuit
		[30213] = true, -- Legion Strike
		[30449] = true, -- Spellsteal
		[30451] = true, -- Arcane Blast
		[30455] = true, -- Ice Lance
		[31224] = true, -- Cloak of Shadows
		[31589] = true, -- Slow
		[31801] = true, -- Seal of Truth
		[31803] = true, -- Censure
		[31821] = true, -- Devotion Aura
		[31842] = true, -- Avenging Wrath
		[31850] = true, -- Ardent Defender
		[31935] = true, -- Avenger's Shield
		[32379] = true, -- Shadow Word: Death
		[32546] = true, -- Binding Heal
		[32645] = true, -- Envenom
		[33076] = true, -- Prayer of Mending
		[33206] = true, -- Pain Suppression
		[33649] = true, -- Rage of the Unraveller
		[33745] = true, -- Lacerate
		[33763] = true, -- Lifebloom
		[33831] = true, -- Force of Nature
		[33917] = true, -- Mangle
		[34026] = true, -- Kill Command
		[34428] = true, -- Victory Rush
		[34433] = true, -- Shadowfiend
		[34477] = true, -- Misdirection
		[34914] = true, -- Vampiric Touch
		[35395] = true, -- Crusader Strike
		[42292] = true, -- PvP Trinket
		[42650] = true, -- Army of the Dead
		[43265] = true, -- Death and Decay
		[44425] = true, -- Arcane Barrage
		[44572] = true, -- Deep Freeze
		[44614] = true, -- Frostfire Bolt
		[45334] = true, -- Immobilized
		[45438] = true, -- Ice Block
		[45462] = true, -- Plague Strike
		[45477] = true, -- Icy Touch
		[45524] = true, -- Chains of Ice
		[47476] = true, -- Strangulate
		[47528] = true, -- Mind Freeze
		[47541] = true, -- Death Coil
		[47585] = true, -- Dispersion
		[47788] = true, -- Guardian Spirit
		[47960] = true, -- Hand of Gul'dan
		[48018] = true, -- Demonic Circle: Summon
		[48020] = true, -- Demonic Circle: Teleport
		[48045] = true, -- Mind Sear
		[48181] = true, -- Haunt
		[48263] = true, -- Blood Presence
		[48265] = true, -- Unholy Presence
		[48266] = true, -- Frost Presence
		[48438] = true, -- Wild Growth
		[48707] = true, -- Anti-Magic Shell
		[48778] = true, -- Acherus Deathcharger
		[48792] = true, -- Icebound Fortitude
		[49020] = true, -- Obliterate
		[49039] = true, -- Lichborne
		[49143] = true, -- Frost Strike
		[49184] = true, -- Howling Blast
		[49206] = true, -- Summon Gargoyle
		[49222] = true, -- Bone Shield
		[49576] = true, -- Death Grip
		[49998] = true, -- Death Strike
		[50256] = true, -- Invigorating Roar
		[50259] = true, -- Dazed
		[50435] = true, -- Chilblains
		[50769] = true, -- Revive
		[51271] = true, -- Pillar of Frost
		[51490] = true, -- Thunderstorm
		[51505] = true, -- Lava Burst
		[51690] = true, -- Killing Spree
		[51713] = true, -- Shadow Dance
		[51714] = true, -- Razorice
		[52127] = true, -- Water Shield
		[52610] = true, -- Savage Roar
		[53148] = true, -- Charge
		[53209] = true, -- Chimaera Shot
		[53271] = true, -- Master's Call
		[53301] = true, -- Explosive Shot
		[53351] = true, -- Kill Shot
		[53480] = true, -- Roar of Sacrifice
		[53563] = true, -- Beacon of Light
		[53595] = true, -- Hammer of the Righteous
		[53600] = true, -- Shield of the Righteous
		[54114] = true, -- Heart of the Phoenix
		[54216] = true, -- Master's Call
		[54680] = true, -- Monstrous Bite
		[54861] = true, -- Nitro Boosts
		[55090] = true, -- Scourge Strike
		[55233] = true, -- Vampiric Blood
		[55711] = true, -- Weakened Heart
		[56222] = true, -- Dark Command
		[56641] = true, -- Steady Shot
		[57330] = true, -- Horn of Winter
		[57755] = true, -- Heroic Throw
		[57934] = true, -- Tricks of the Trade
		[57994] = true, -- Wind Shear
		[58180] = true, -- Infected Wounds
		[58501] = true, -- Iron Boot Flask
		[58604] = true, -- Double Bite
		[59542] = true, -- Gift of the Naaru
		[59543] = true, -- Gift of the Naaru
		[59544] = true, -- Gift of the Naaru
		[59545] = true, -- Gift of the Naaru
		[59548] = true, -- Gift of the Naaru
		[59752] = true, -- Every Man for Himself
		[60103] = true, -- Lava Lash
		[60229] = true, -- Strength
		[60234] = true, -- Intellect
		[61295] = true, -- Riptide
		[61316] = true, -- Dalaran Brilliance
		[61336] = true, -- Survival Instincts
		[61685] = true, -- Charge
		[61999] = true, -- Raise Ally
		[62124] = true, -- Reckoning
		[62305] = true, -- Master's Call
		[63058] = true, -- Glyph of Barkskin
		[63529] = true, -- Dazed - Avenger's Shield
		[63560] = true, -- Dark Transformation
		[63685] = true, -- Frozen Power
		[64044] = true, -- Psychic Horror
		[64695] = true, -- Earthgrab
		[64843] = true, -- Divine Hymn
		[66906] = true, -- Argent Charger
		[68992] = true, -- Darkflight
		[72968] = true, -- Precious's Ribbon
		[73325] = true, -- Leap of Faith
		[73326] = true, -- Tabard of the Lightbringer
		[73510] = true, -- Mind Spike
		[73651] = true, -- Recuperate
		[73685] = true, -- Unleash Life
		[74434] = true, -- Soulburn
		[75531] = true, -- Gnomeregan Pride
		[77130] = true, -- Purify Spirit
		[77472] = true, -- Healing Wave
		[77505] = true, -- Earthquake
		[77575] = true, -- Outbreak
		[77606] = true, -- Dark Simulacrum
		[77764] = true, -- Stampeding Roar
		[77767] = true, -- Cobra Shot
		[77769] = true, -- Trap Launcher
		[78674] = true, -- Starsurge
		[78675] = true, -- Solar Beam
		[79140] = true, -- Vendetta
		[79206] = true, -- Spiritwalker's Grace
		[80313] = true, -- Pulverize
		[80353] = true, -- Time Warp
		[80396] = true, -- Illusion
		[81206] = true, -- Chakra: Sanctuary
		[81208] = true, -- Chakra: Serenity
		[81292] = true, -- Glyph of Mind Spike
		[81700] = true, -- Archangel
		[82326] = true, -- Holy Light
		[82327] = true, -- Holy Radiance
		[82692] = true, -- Focus Fire
		[83243] = true, -- Call Pet 3
		[83244] = true, -- Call Pet 4
		[83245] = true, -- Call Pet 5
		[84617] = true, -- Revealing Strike
		[84714] = true, -- Frozen Orb
		[84721] = true, -- Frozen Orb
		[85256] = true, -- Templar's Verdict
		[85288] = true, -- Raging Blow
		[85673] = true, -- Word of Glory
		[85948] = true, -- Festering Strike
		[86121] = true, -- Soul Swap
		[86659] = true, -- Guardian of Ancient Kings
		[87194] = true, -- Glyph of Mind Blast
		[87840] = true, -- Running Wild
		[88085] = true, -- Mirror Image
		[88086] = true, -- Mirror Image
		[88087] = true, -- Mirror Image
		[88088] = true, -- Mirror Image
		[88089] = true, -- Mirror Image
		[88090] = true, -- Mirror Image
		[88423] = true, -- Nature's Cure
		[88747] = true, -- Wild Mushroom
		[89751] = true, -- Felstorm
		[89766] = true, -- Axe Toss
		[90309] = true, -- Terrifying Roar
		[90628] = true, -- Guild Battle Standard
		[91021] = true, -- Find Weakness
		[91760] = true, -- Endure the Transformation
		[91797] = true, -- Monstrous Blow
		[91800] = true, -- Gnaw
		[91807] = true, -- Shambling Rush
		[96231] = true, -- Rebuke
		[96268] = true, -- Death's Advance
		[96294] = true, -- Chains of Ice
		[98008] = true, -- Spirit Link Totem
		[100130] = true, -- Wild Strike
		[100780] = true, -- Jab
		[100784] = true, -- Blackout Kick
		[100787] = true, -- Tiger Palm
		[101546] = true, -- Spinning Crane Kick
		[102342] = true, -- Ironbark
		[102351] = true, -- Cenarion Ward
		[102558] = true, -- Incarnation: Son of Ursoc
		[102693] = true, -- Force of Nature
		[103103] = true, -- Drain Soul
		[103958] = true, -- Metamorphosis
		[103964] = true, -- Touch of Chaos
		[104027] = true, -- Soul Fire
		[104317] = true, -- Wild Imp
		[104773] = true, -- Unending Resolve
		[105174] = true, -- Hand of Gul'dan
		[105681] = true, -- Mantid Elixir
		[105691] = true, -- Flask of the Warm Sun
		[106839] = true, -- Skull Bash
		[106898] = true, -- Stampeding Roar
		[107428] = true, -- Rising Sun Kick
		[108196] = true, -- Death Siphon
		[108211] = true, -- Leeching Poison
		[108269] = true, -- Capacitor Totem
		[108280] = true, -- Healing Tide Totem
		[108287] = true, -- Totemic Projection
		[108291] = true, -- Heart of the Wild
		[108292] = true, -- Heart of the Wild
		[108293] = true, -- Heart of the Wild
		[108508] = true, -- Mannoroth's Fury
		[108683] = true, -- Fire and Brimstone
		[108843] = true, -- Blazing Speed
		[109773] = true, -- Dark Intent
		[110300] = true, -- Burden of Guilt
		[111240] = true, -- Dispatch
		[111685] = true, -- Summon Infernal
		[111758] = true, -- Levitate
		[111759] = true, -- Levitate
		[112048] = true, -- Shield Barrier
		[112071] = true, -- Celestial Alignment
		[112870] = true, -- Summon Wrathguard
		[112922] = true, -- Summon Abyssal
		[112947] = true, -- Nerve Strike
		[112948] = true, -- Frost Bomb
		[113656] = true, -- Fists of Fury
		[113742] = true, -- Swiftblade's Cunning
		[113858] = true, -- Dark Soul: Instability
		[113860] = true, -- Dark Soul: Misery
		[113861] = true, -- Dark Soul: Knowledge
		[114030] = true, -- Vigilance
		[114050] = true, -- Ascendance
		[114052] = true, -- Ascendance
		[114108] = true, -- Soul of the Forest
		[114192] = true, -- Mocking Banner
		[114198] = true, -- Mocking Banner
		[114239] = true, -- Phantasm
		[114635] = true, -- Ember Tap
		[114866] = true, -- Soul Reaper
		[114916] = true, -- Execution Sentence
		[114925] = true, -- Demonic Calling
		[115018] = true, -- Desecrated Ground
		[115069] = true, -- Stance of the Sturdy Ox
		[115070] = true, -- Stance of the Wise Serpent
		[115080] = true, -- Touch of Death
		[115151] = true, -- Renewing Mist
		[115175] = true, -- Soothing Mist
		[115176] = true, -- Zen Meditation
		[115196] = true, -- Debilitating Poison
		[115236] = true, -- Void Shield
		[115268] = true, -- Mesmerize
		[115294] = true, -- Mana Tea
		[115295] = true, -- Guard
		[115308] = true, -- Elusive Brew
		[115313] = true, -- Summon Jade Serpent Statue
		[115317] = true, -- Raging Wind
		[115450] = true, -- Detox
		[115522] = true, -- Glyph of Word of Glory
		[115546] = true, -- Provoke
		[115625] = true, -- Mortal Cleave
		[115687] = true, -- Jab
		[115698] = true, -- Jab
		[115748] = true, -- Bladedance
		[115760] = true, -- Glyph of Ice Block
		[115921] = true, -- Legacy of the Emperor
		[116095] = true, -- Disable
		[116189] = true, -- Provoke
		[116330] = true, -- Dizzying Haze
		[116680] = true, -- Thunder Focus Tea
		[116694] = true, -- Surging Mist
		[116705] = true, -- Spear Hand Strike
		[116781] = true, -- Legacy of the White Tiger
		[116849] = true, -- Life Cocoon
		[116858] = true, -- Chaos Bolt
		[117952] = true, -- Crackling Jade Lightning
		[118009] = true, -- Desecrated Ground
		[118038] = true, -- Die by the Sword
		[118253] = true, -- Serpent Sting
		[119072] = true, -- Holy Wrath
		[120086] = true, -- Fists of Fury
		[120679] = true, -- Dire Beast
		[120761] = true, -- Glaive Toss
		[121253] = true, -- Keg Smash
		[121414] = true, -- Glaive Toss
		[122233] = true, -- Crimson Tempest
		[122355] = true, -- Molten Core
		[122998] = true, -- Arcane Language
		[124036] = true, -- Anglers Fishing Raft
		[124218] = true, -- Well Fed
		[124682] = true, -- Enveloping Mist
		[124974] = true, -- Nature's Vigil
		[126533] = true, -- Indomitable
		[126554] = true, -- Agile
		[126582] = true, -- Unwavering Might
		[126665] = true, -- Bloody Healing
		[126679] = true, -- Call of Victory
		[127230] = true, -- Visions of Insanity
		[127663] = true, -- Astral Communion
		[128432] = true, -- Cackling Howl
		[130735] = true, -- Soul Reaper
		[132158] = true, -- Nature's Swiftness
		[132411] = true, -- Singe Magic
		[133278] = true, -- Glyph of Heroic Leap
		[133630] = true, -- Exquisite Proficiency
		[135601] = true, -- Tooth and Claw
		[136494] = true, -- Word of Glory
		[137562] = true, -- Nimble Brew
		[137587] = true, -- Kil'jaeden's Cunning
		[138703] = true, -- Acceleration
		[139133] = true, -- Mastermind
		[140074] = true, -- Molten Core
		[145152] = true, -- Bloodtalons
		[145162] = true, -- Dream of Cenarius
		[145205] = true, -- Wild Mushroom
		[146046] = true, -- Expanded Mind
		[146184] = true, -- Wrath of the Darkspear
		[146202] = true, -- Wrath
		[147362] = true, -- Counter Shot
		[147405] = true, -- Elixir of Wandering Spirits
		[147407] = true, -- Elixir of Wandering Spirits
		[152116] = true, -- Saving Grace
		[152150] = true, -- Death from Above
		[152262] = true, -- Seraphim
		[154436] = true, -- Stance of the Spirited Crane
		[154796] = true, -- Touch of Elune - Day
		[154797] = true, -- Touch of Elune - Night
		[154953] = true, -- Internal Bleeding
		[155158] = true, -- Meteor Burn
		[155274] = true, -- Saving Grace
		[155522] = true, -- Power of the Grave
		[155722] = true, -- Rake
		[156064] = true, -- Greater Draenic Agility Flask
		[156070] = true, -- Draenic Intellect Flask
		[156079] = true, -- Greater Draenic Intellect Flask
		[156080] = true, -- Greater Draenic Strength Flask
		[156291] = true, -- Gladiator Stance
		[156321] = true, -- Shield Charge
		[156779] = true, -- Neural Silencer
		[156989] = true, -- Liadrin's Righteousness
		[156990] = true, -- Maraad's Truth
		[157153] = true, -- Cloudburst Totem
		[157584] = true, -- Instant Poison
		[157676] = true, -- Chi Explosion
		[157695] = true, -- Demonbolt
		[158486] = true, -- Safari Hat
		[159238] = true, -- Shattered Bleed
		[159546] = true, -- Glyph of Zen Focus
		[159988] = true, -- Bark of the Wild
		[160039] = true, -- Keen Senses
		[160198] = true, -- Lone Wolf: Grace of the Cat
		[160199] = true, -- Lone Wolf: Fortitude of the Bear
		[160205] = true, -- Lone Wolf: Wisdom of the Serpent
		[160206] = true, -- Lone Wolf: Power of the Primates
		[160715] = true, -- Chains of Ice
		[160724] = true, -- Well Fed
		[160726] = true, -- Well Fed
		[160793] = true, -- Well Fed
		[160832] = true, -- Well Fed
		[160889] = true, -- Well Fed
		[160897] = true, -- Well Fed
		[160900] = true, -- Well Fed
		[161414] = true, -- Blingtron 5000
		[161676] = true, -- Call to Arms
		[161678] = true, -- Call to Arms
		[161679] = true, -- Call to Arms
		[161767] = true, -- Guardian Orb
		[161930] = true, -- Call to Arms
		[161931] = true, -- Call to Arms
		[162075] = true, -- Artillery Strike
		[162359] = true, -- Genesis
		[162536] = true, -- Incendiary Ammo
		[162537] = true, -- Poisoned Ammo
		[162539] = true, -- Frozen Ammo
		[162543] = true, -- Poisoned Ammo
		[162546] = true, -- Frozen Ammo
		[162913] = true, -- Visions of the Future
		[163201] = true, -- Execute
		[163505] = true, -- Rake
		[164221] = true, -- Champion's Honor
		[164223] = true, -- Y'kish's Y'llusion
		[164415] = true, -- Champion's Honor
		[164417] = true, -- Jonaa's Justice
		[164991] = true, -- Entangling Energy
		[165462] = true, -- Unleash Flame
		[165485] = true, -- Mastery
		[165540] = true, -- Critical Strike
		[165638] = true, -- Vicious Strike
		[165640] = true, -- Vicious Strike
		[165699] = true, -- Bloodletting
		[165822] = true, -- Haste
		[165824] = true, -- Mastery
		[165830] = true, -- Critical Strike
		[165832] = true, -- Multistrike
		[165833] = true, -- Versatility
		[165889] = true, -- Righteous Determination
		[165903] = true, -- Vindicator's Fury
		[166057] = true, -- Biting Cold
		[166361] = true, -- Pride
		[166592] = true, -- Vindicator's Armor Polish Kit
		[166638] = true, -- Gushing Wound
		[166831] = true, -- Blazing Contempt
		[166928] = true, -- Blood Pact
		[167105] = true, -- Colossus Smash
		[167135] = true, -- Bestial Wrath
		[167165] = true, -- Heavy Shot
		[167188] = true, -- Inspiring Presence
		[167205] = true, -- Focus of the Elements
		[167362] = true, -- Tiny Iron Star
		[167608] = true, -- Mechashredder Custom Ride
		[167703] = true, -- Harmony of the Elements
		[168407] = true, -- Robo-Rooster
		[168655] = true, -- Sticky Grenade
		[168657] = true, -- Bubble Wand
		[169667] = true, -- Shield Charge
		[170108] = true, -- Smuggling Run!
		[170176] = true, -- Anguish
		[170364] = true, -- Dire Beast
		[170397] = true, -- Rapid Adaptation
		[170856] = true, -- Nature's Grasp
		[170996] = true, -- Debilitate
		[171023] = true, -- Blaze Magic
		[171103] = true, -- Black Fire
		[171114] = true, -- Strength of the Pack
		[171130] = true, -- Penance
		[171745] = true, -- Claws of Shirvallah
		[171982] = true, -- Demonic Synergy
		[172425] = true, -- Well-Rested
		[172518] = true, -- Pitch Tent
		[172968] = true, -- Lone Wolf: Quickness of the Dragonhawk
		[173266] = true, -- Mecha-Blast Rocket
		[173488] = true, -- Pride
		[173519] = true, -- Lingering Spirit
		[173958] = true, -- Pirate Costume
		[173959] = true, -- Pirate Costume
		[173983] = true, -- Nagrand Wolf Guardian
		[174018] = true, -- Pale Vision Potion
		[174708] = true, -- Avatar of Terokk
		[174926] = true, -- Shield Barrier
		[175733] = true, -- Paladin Protector
		[175753] = true, -- Mr. Pinchies
		[175790] = true, -- Draenic Swiftness Potion
		[176151] = true, -- Whispers of Insanity
		[176310] = true, -- Lilian's Warning Sign
		[176569] = true, -- Sargerei Disguise
		[176588] = true, -- Guardian of the Forge
		[176594] = true, -- Touch of the Naaru
		[176644] = true, -- Solace of the Forge
		[176875] = true, -- Void Shards
		[176876] = true, -- Vision of the Cyclops
		[176881] = true, -- Turbulent Emblem
		[176882] = true, -- Turbulent Focusing Crystal
		[176974] = true, -- Mote of the Mountain
		[176980] = true, -- Heart of the Fury
		[176982] = true, -- Stoneheart Idol
		[177103] = true, -- Cracks!
		[177130] = true, -- Talon Sweep
		[177131] = true, -- Dark Winds
		[177135] = true, -- Zephyr
		[177137] = true, -- Zephyr
		[177142] = true, -- Zephyr Wind
		[177193] = true, -- Sha'tari Defender
		[177214] = true, -- Path of Flame
		[177494] = true, -- Dark Winds
		[177594] = true, -- Sudden Clarity
		[177597] = true, -- "Lucky" Flip
		[177969] = true, -- Primal Mending
		[178119] = true, -- Accelerated Learning
		[178776] = true, -- Rune of Power
		[178857] = true, -- Contender
		[178858] = true, -- Contender
		[179141] = true, -- Brute Strength
		[179144] = true, -- Wall of Steel
		[180745] = true, -- Well Fed
		[180746] = true, -- Well Fed
		[180747] = true, -- Well Fed
		[180748] = true, -- Well Fed
		[180749] = true, -- Well Fed
		[180750] = true, -- Well Fed
		[181201] = true, -- Gladiator's Distinction
		[182059] = true, -- Surge of Conquest
		[182062] = true, -- Surge of Victory
		[182067] = true, -- Surge of Dominance
		[182068] = true, -- Surge of Conquest
		[182069] = true, -- Surge of Victory
		[182073] = true, -- Rapid Adaptation
		[182226] = true, -- Bladebone Hook
		[183170] = true, -- Netherblade Oil
		[184073] = true, -- Mark of Doom
		[184256] = true, -- Fel Burn
		[185229] = true, -- Flamelicked
		[187748] = true, -- Brazier of Awakening
		[188117] = true, -- Tyrande Whisperwind
		[188217] = true, -- Jaina Proudmoore
		[188280] = true, -- Sylvanas Windrunner
		[188289] = true, -- Prince Arthas Menethil
		[188534] = true, -- Well Fed
		[189325] = true, -- King of the Jungle
		[189363] = true, -- Burning Blade
		[190026] = true, -- Surge of Conquest
		[190632] = true, -- Trailblazer
		[190639] = true, -- Hand of the Prophet Standard
		[190640] = true, -- Saberstalkers Standard
		[190641] = true, -- Order of the Awakened Standard
		[190653] = true, -- Ceremonial Karabor Guise
	}
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
		   (sourceName and badPlayerFilteredEvents[event] and (badPlayerSpellList[spellId] or playerSpellBlacklist[spellId]) and band(sourceFlags, playerOrPet) ~= 0) or
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
