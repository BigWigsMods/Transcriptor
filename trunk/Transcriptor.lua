
local Transcriptor = {}
local revision = tonumber(("$Revision$"):sub(12, -3))

local badPlayerSpellList
local playerSpellBlacklist

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
	for i = 1, 2 do
		frame[i] = CreateFrame("Frame", nil, UIParent)
		frame[i]:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = {left = 1, right = 1, top = 1, bottom = 1}}
		)
		frame[i]:SetBackdropColor(0,0,0,1)
		frame[i]:SetWidth(650)
		frame[i]:SetHeight(900)
		frame[i]:Hide()
		frame[i]:SetFrameStrata("DIALOG")

		local scrollArea = CreateFrame("ScrollFrame", "TranscriptorDevScrollArea"..i, frame[i], "UIPanelScrollFrameTemplate")
		scrollArea:SetPoint("TOPLEFT", frame[i], "TOPLEFT", 8, -5)
		scrollArea:SetPoint("BOTTOMRIGHT", frame[i], "BOTTOMRIGHT", -30, 5)

		editBox[i] = CreateFrame("EditBox", nil, frame[i])
		editBox[i]:SetMultiLine(true)
		editBox[i]:SetMaxLetters(99999)
		editBox[i]:EnableMouse(true)
		editBox[i]:SetAutoFocus(false)
		editBox[i]:SetFontObject(ChatFontNormal)
		editBox[i]:SetWidth(620)
		editBox[i]:SetHeight(895)
		editBox[i]:SetScript("OnEscapePressed", function(f) f:GetParent():GetParent():Hide() f:SetText("") end)
		if i == 1 then
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
			[181488] = true, -- Vision of Death (Kilrogg Deadeye)
			[182008] = true, -- Latent Energy
			[183963] = true, -- Light of the Naaru (Archimonde)
			[184450] = true, -- Mark of the Necromancer (Hellfire High Council)
			[185014] = true, -- Focused Chaos (Archimonde)
			[185656] = true, -- Shadowfel Annihilation
			[186123] = true, -- Wrought Chaos (Archimonde)
			[187344] = true, -- Phantasmal Cremation (Shadow-Lord Iskar)
			[187668] = true, -- Mark of Kazzak (Supreme Lord Kazzak)
			[189030] = true, -- Befouled
			[189031] = true, -- Befouled
			[189032] = true, -- Befouled
			[190466] = true, -- Incomplete Binding (Socrethar the Eternal)
		}
		for logName, logTbl in next, TranscriptDB do
			if type(logTbl) == "table" and logTbl.total then
				for i=1, #logTbl.total do
					local text = logTbl.total[i]

					-- AURA
					local name, tarName, id, spellName = text:match("SPELL_AURA_[^#]+#P[le][at][^#]+#([^#]+)#[^#]+#([^#]+)#(%d+)#([^#]+)#")
					id = tonumber(id)
					if id and not ignoreList[id] and not badPlayerSpellList[id] and not playerSpellBlacklist[id] and not total[id] and #aurasSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						if name == tarName then
							auraTbl[id] = "|cFF81BEF7".. name:gsub("%-.+", "*") .." >> ".. tarName:gsub("%-.+", "*") .."|r"
						else
							auraTbl[id] = "|cFF3ADF00".. name:gsub("%-.+", "*") .." >> ".. tarName:gsub("%-.+", "*") .."|r"
						end
						total[id] = true
						aurasSorted[#aurasSorted+1] = id
					end

					-- CAST
					name, tarName, id, spellName = text:match("SPELL_CAST_[^#]+#P[le][at][^#]+#([^#]+)#[^#]+#([^#]+)#(%d+)#([^#]+)#")
					id = tonumber(id)
					if id and not ignoreList[id] and not badPlayerSpellList[id] and not playerSpellBlacklist[id] and not total[id] and #castsSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						if name == tarName then
							castTbl[id] = "|cFF81BEF7".. name:gsub("%-.+", "*") .." >> ".. tarName:gsub("%-.+", "*") .."|r"
						else
							castTbl[id] = "|cFF3ADF00".. name:gsub("%-.+", "*") .." >> ".. tarName:gsub("%-.+", "*") .."|r"
						end
						total[id] = true
						castsSorted[#castsSorted+1] = id
					end

					-- SUMMON
					name, tarName, id, spellName = text:match("SPELL_SUMMON#P[le][at][^#]+#([^#]+)#[^#]+#([^#]+)#(%d+)#([^#]+)#")
					id = tonumber(id)
					if id and not ignoreList[id] and not badPlayerSpellList[id] and not playerSpellBlacklist[id] and not total[id] and #summonSorted < 15 then -- Check total to avoid duplicates and lock to a max of 15 for sanity
						if name == tarName then
							summonTbl[id] = "|cFF81BEF7".. name:gsub("%-.+", "*") .." >> ".. tarName:gsub("%-.+", "*") .."|r"
						else
							summonTbl[id] = "|cFF3ADF00".. name:gsub("%-.+", "*") .." >> ".. tarName:gsub("%-.+", "*") .."|r"
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
		frame[1]:SetPoint("RIGHT", UIParent, "CENTER")
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
		frame[2]:SetPoint("LEFT", UIParent, "CENTER")
		frame[2]:Show()
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
	-- XXX spellbook is being removed
	badPlayerSpellList = {
		-- PRIEST, updated 6.2.0 LIVE
		[81700] = "Archangel",
		[6346] = "Fear Ward",
		[81208] = "Chakra: Serenity",
		[76279] = "Armor Skills",
		[119467] = "Battle Pet Training",
		[6603] = "Auto Attack",
		[108942] = "Phantasm",
		[528] = "Dispel Magic",
		[165362] = "Divine Providence",
		[5019] = "Shoot",
		[20711] = "Spirit of Redemption",
		[81209] = "Chakra: Chastise",
		[47540] = "Penance",
		[20598] = "The Human Spirit",
		[73510] = "Mind Spike",
		[59752] = "Every Man for Himself",
		[81662] = "Evangelism",
		[9484] = "Shackle Undead",
		[585] = "Mind Flay",
		[2944] = "Devouring Plague",
		[115913] = "Wisdom of the Four Winds",
		[90267] = "Flight Master's License",
		[62618] = "Power Word: Barrier",
		[175701] = "Void Tendrils",
		[586] = "Fade",
		[45243] = "Focused Will",
		[15473] = "Shadowform",
		[2006] = "Resurrection",
		[175702] = "Halo",
		[132157] = "Holy Nova",
		[33206] = "Pain Suppression",
		[34861] = "Circle of Healing",
		[83950] = "The Quick and the Dead",
		[83958] = "Mobile Banking",
		[2061] = "Flash Heal",
		[8092] = "Mind Blast",
		[54197] = "Cold Weather Flying",
		[1706] = "Levitate",
		[17] = "Power Word: Shield",
		[2096] = "Mind Vision",
		[83951] = "Guild Mail",
		[165370] = "Mastermind",
		[78633] = "Mount Up",
		[34433] = "Mindbender",
		[596] = "Prayer of Healing",
		[64044] = "Psychic Horror",
		[20599] = "Diplomacy",
		[33076] = "Prayer of Mending",
		[83944] = "Hasty Hearth",
		[83968] = "Mass Resurrection",
		[49868] = "Mind Quickening",
		[63733] = "Serendipity",
		[589] = "Shadow Word: Pain",
		[139] = "Renew",
		[126135] = "Lightwell",
		[10060] = "Power Infusion",
		[88625] = "Holy Word: Chastise",
		[47788] = "Guardian Spirit",
		[76301] = "Weapon Skills",
		[79738] = "Languages",
		[64843] = "Divine Hymn",
		[81206] = "Chakra: Sanctuary",
		[32546] = "Binding Heal",
		[161691] = "Garrison Ability",
		[19236] = "Desperate Prayer",
		[47515] = "Divine Aegis",
		[81749] = "Atonement",
		[73325] = "Leap of Faith",
		[15487] = "Silence",
		[47585] = "Dispersion",
		[125439] = "Revive Battle Pets",
		[2060] = "Heal",
		[14914] = "Holy Fire",
		[78203] = "Shadowy Apparitions",
		[15286] = "Vampiric Embrace",
		[90265] = "Master Riding",
		[527] = "Purify",
		[34914] = "Vampiric Touch",
		[21562] = "Power Word: Fortitude",
		[165376] = "Enlightenment",
		[32379] = "Shadow Word: Death",
		[32375] = "Mass Dispel",
		[48045] = "Mind Sear",

		-- ROGUE, updated 6.2.0 LIVE
		[31224] = "Cloak of Shadows",
		[31230] = "Cheat Death",
		[119467] = "Battle Pet Training",
		[6603] = "Auto Attack",
		[79748] = "Languages",
		[32645] = "Envenom",
		[822] = "Arcane Resistance",
		[57934] = "Tricks of the Trade",
		[51723] = "Fan of Knives",
		[84654] = "Bandit's Guile",
		[5277] = "Evasion",
		[138106] = "Cloak and Dagger",
		[14183] = "Premeditation",
		[14185] = "Preparation",
		[76273] = "Armor Skills",
		[76297] = "Weapon Skills",
		[35551] = "Combat Potency",
		[58423] = "Relentless Strikes",
		[79147] = "Sanguinary Vein",
		[53] = "Backstab",
		[125439] = "Revive Battle Pets",
		[34091] = "Artisan Riding",
		[31209] = "Fleet Footed",
		[1943] = "Rupture",
		[83950] = "The Quick and the Dead",
		[83958] = "Mobile Banking",
		[2823] = "Deadly Poison",
		[84617] = "Revealing Strike",
		[5171] = "Slice and Dice",
		[2094] = "Blind",
		[121733] = "Throw",
		[114018] = "Shroud of Concealment",
		[111240] = "Dispatch",
		[5938] = "Shiv",
		[83951] = "Guild Mail",
		[108216] = "Dirty Tricks",
		[51701] = "Honor Among Thieves",
		[51713] = "Shadow Dance",
		[2098] = "Eviscerate",
		[6770] = "Sap",
		[14161] = "Ruthlessness",
		[1804] = "Pick Lock",
		[83944] = "Hasty Hearth",
		[108209] = "Shadow Focus",
		[1725] = "Distract",
		[83968] = "Mass Resurrection",
		[1833] = "Cheap Shot",
		[13877] = "Blade Flurry",
		[13750] = "Adrenaline Rush",
		[14190] = "Seal Fate",
		[165390] = "Master Poisoner",
		[1329] = "Mutilate",
		[113742] = "Swiftblade's Cunning",
		[79140] = "Vendetta",
		[76577] = "Smoke Bomb",
		[54197] = "Cold Weather Flying",
		[25046] = "Arcane Torrent",
		[1766] = "Kick",
		[51690] = "Killing Spree",
		[108210] = "Nerve Strike",
		[161691] = "Garrison Ability",
		[408] = "Kidney Shot",
		[154742] = "Arcane Acuity",
		[921] = "Pick Pocket",
		[78633] = "Mount Up",
		[8676] = "Ambush",
		[1752] = "Hemorrhage",
		[1966] = "Feint",
		[8679] = "Wound Poison",
		[3408] = "Crippling Poison",
		[2983] = "Sprint",
		[1776] = "Gouge",
		[703] = "Garrote",
		[73651] = "Recuperate",
		[121411] = "Crimson Tempest",
		[28877] = "Arcane Affinity",
		[1856] = "Vanish",
		[1784] = "Stealth",
		[31220] = "Sinister Calling",
		[90267] = "Flight Master's License",

		-- DEATH KNIGHT, updated 6.2.0 LIVE
		[43265] = "Death and Decay",
		[47476] = "Strangulate",
		[119467] = "Battle Pet Training",
		[6603] = "Auto Attack",
		[49143] = "Frost Strike",
		[49020] = "Obliterate",
		[48266] = "Frost Presence",
		[165394] = "Runic Strikes",
		[158298] = "Resolve",
		[111673] = "Control Undead",
		[47528] = "Mind Freeze",
		[49572] = "Shadow Infusion",
		[49576] = "Death Grip",
		[85948] = "Festering Strike",
		[34090] = "Expert Riding",
		[45524] = "Chains of Ice",
		[48707] = "Anti-Magic Shell",
		[47568] = "Empower Rune Weapon",
		[51128] = "Killing Machine",
		[155522] = "Power of the Grave",
		[51271] = "Pillar of Frost",
		[46584] = "Raise Dead",
		[90267] = "Flight Master's License",
		[77575] = "Outbreak",
		[114556] = "Purgatory",
		[45477] = "Icy Touch",
		[61999] = "Raise Ally",
		[51462] = "Runic Corruption",
		[114866] = "Soul Reaper",
		[49184] = "Howling Blast",
		[47541] = "Death Coil",
		[125439] = "Revive Battle Pets",
		[81164] = "Will of the Necropolis",
		[20549] = "War Stomp",
		[20551] = "Nature Resistance",
		[49998] = "Death Strike",
		[55090] = "Scourge Strike",
		[3714] = "Path of Frost",
		[55610] = "Unholy Aura",
		[55233] = "Vampiric Blood",
		[45462] = "Plague Strike",
		[49530] = "Sudden Doom",
		[161497] = "Plaguebearer",
		[130735] = "Soul Reaper",
		[76292] = "Weapon Skills",
		[63560] = "Dark Transformation",
		[53428] = "Runeforging",
		[81333] = "Might of the Frozen Wastes",
		[178819] = "Dark Succor",
		[50887] = "Icy Talons",
		[50029] = "Veteran of the Third War",
		[79746] = "Languages",
		[154743] = "Brawn",
		[48265] = "Unholy Presence",
		[161691] = "Garrison Ability",
		[48792] = "Icebound Fortitude",
		[56222] = "Dark Command",
		[76282] = "Armor Skills",
		[81136] = "Crimson Scourge",
		[77606] = "Dark Simulacrum",
		[42650] = "Army of the Dead",
		[50842] = "Blood Boil",
		[48263] = "Blood Presence",
		[175678] = "Death Pact",
		[49028] = "Dancing Rune Weapon",
		[57330] = "Horn of Winter",
		[49206] = "Summon Gargoyle",
		[48982] = "Rune Tap",
		[96268] = "Death's Advance",
		[51986] = "On a Pale Horse",
		[49222] = "Bone Shield",
		[20550] = "Endurance",
		[20552] = "Cultivation",
		[50977] = "Death Gate",

		-- WARLOCK, updated 6.2.0 LIVE
		[710] = "Banish",
		[120451] = "Flames of Xoroth",
		[980] = "Agony",
		[126] = "Eye of Kilrogg",
		[119467] = "Battle Pet Training",
		[6603] = "Auto Attack",
		[80240] = "Havoc",
		[18540] = "Summon Doomguard",
		[79748] = "Languages",
		[29722] = "Incinerate",
		[20707] = "Soulstone",
		[48020] = "Demonic Circle: Teleport",
		[822] = "Arcane Resistance",
		[5782] = "Fear",
		[103958] = "Metamorphosis",
		[28730] = "Arcane Torrent",
		[172] = "Corruption",
		[688] = "Summon Imp",
		[712] = "Summon Succubus",
		[29893] = "Create Soulwell",
		[114635] = "Ember Tap",
		[119898] = "Command Demon",
		[116858] = "Chaos Bolt",
		[689] = "Drain Life",
		[697] = "Summon Voidwalker",
		[122351] = "Molten Core",
		[109151] = "Demonic Leap",
		[113858] = "Dark Soul: Instability",
		[165367] = "Eradication",
		[125439] = "Revive Battle Pets",
		[108683] = "Fire and Brimstone",
		[103103] = "Drain Soul",
		[101976] = "Soul Harvest",
		[5740] = "Rain of Fire",
		[111771] = "Demonic Gateway",
		[698] = "Ritual of Summoning",
		[76299] = "Weapon Skills",
		[74434] = "Soulburn",
		[48018] = "Demonic Circle: Summon",
		[30108] = "Unstable Affliction",
		[29858] = "Soulshatter",
		[1454] = "Life Tap",
		[755] = "Health Funnel",
		[6201] = "Create Healthstone",
		[166928] = "Blood Pact",
		[109773] = "Dark Intent",
		[76277] = "Armor Skills",
		[17962] = "Conflagrate",
		[104773] = "Unending Resolve",
		[161691] = "Garrison Ability",
		[165363] = "Devastation",
		[117896] = "Backdraft",
		[113860] = "Dark Soul: Misery",
		[6353] = "Soul Fire",
		[348] = "Immolate",
		[28877] = "Arcane Affinity",
		[27243] = "Seed of Corruption",
		[48181] = "Haunt",
		[5019] = "Shoot",
		[5697] = "Unending Breath",
		[1098] = "Enslave Demon",
		[17877] = "Shadowburn",
		[691] = "Summon Felhunter",
		[86121] = "Soul Swap",
		[686] = "Shadow Bolt",
		[1122] = "Summon Infernal",
		[154742] = "Arcane Acuity",

		-- MONK, updated 6.2.0 LIVE
		[109132] = "Roll",
		[119467] = "Battle Pet Training",
		[6603] = "Auto Attack",
		[115546] = "Provoke",
		[115308] = "Elusive Brew",
		[120277] = "Way of the Monk",
		[115078] = "Paralysis",
		[158298] = "Resolve",
		[165379] = "Ferment",
		[117952] = "Crackling Jade Lightning",
		[116849] = "Life Cocoon",
		[115460] = "Detonate Chi",
		[100784] = "Blackout Kick",
		[115151] = "Renewing Mist",
		[115921] = "Legacy of the Emperor",
		[115294] = "Mana Tea",
		[115175] = "Soothing Mist",
		[115310] = "Revival",
		[154555] = "Focus and Harmony",
		[115072] = "Expel Harm",
		[107079] = "Quaking Palm",
		[124502] = "Gift of the Ox",
		[125439] = "Revive Battle Pets",
		[115295] = "Guard",
		[115176] = "Zen Meditation",
		[83950] = "The Quick and the Dead",
		[107072] = "Epicurean",
		[126892] = "Zen Pilgrimage",
		[101643] = "Transcendence",
		[119582] = "Purifying Brew",
		[103985] = "Stance of the Fierce Tiger",
		[83951] = "Guild Mail",
		[107073] = "Gourmand",
		[78633] = "Mount Up",
		[143368] = "Languages",
		[116781] = "Legacy of the White Tiger",
		[100787] = "Tiger Palm",
		[116670] = "Uplift",
		[116694] = "Surging Mist",
		[115178] = "Resuscitate",
		[83944] = "Hasty Hearth",
		[107074] = "Inner Peace",
		[83968] = "Mass Resurrection",
		[100780] = "Jab",
		[165397] = "Jade Mists",
		[101546] = "Spinning Crane Kick",
		[115313] = "Summon Jade Serpent Statue",
		[115070] = "Stance of the Wise Serpent",
		[119996] = "Transcendence: Transfer",
		[154436] = "Stance of the Spirited Crane",
		[115203] = "Fortifying Brew",
		[116705] = "Spear Hand Strike",
		[106904] = "Armor Skills",
		[161691] = "Garrison Ability",
		[120272] = "Tiger Strikes",
		[107428] = "Rising Sun Kick",
		[115181] = "Breath of Fire",
		[115080] = "Touch of Death",
		[137562] = "Nimble Brew",
		[121253] = "Keg Smash",
		[116680] = "Thunder Focus Tea",
		[124682] = "Enveloping Mist",
		[83958] = "Mobile Banking",
		[113656] = "Fists of Fury",
		[115315] = "Summon Black Ox Statue",
		[115450] = "Detox",
		[107076] = "Bouncy",
		[106902] = "Weapon Skills",
		[115180] = "Dizzying Haze",
		[115069] = "Stance of the Sturdy Ox",

		-- SHAMAN, updated 6.2.0 LIVE
		[5394] = "Healing Stream Totem",
		[1064] = "Chain Heal",
		[16196] = "Resurgence",
		[8004] = "Healing Surge",
		[421] = "Chain Lightning",
		[73899] = "Stormstrike",
		[166221] = "Enhanced Weapons",
		[20608] = "Reincarnation",
		[51886] = "Cleanse Spirit",
		[58875] = "Spirit Walk",
		[73685] = "Unleash Life",
		[57994] = "Wind Shear",
		[77130] = "Purify Spirit",
		[974] = "Earth Shield",
		[108269] = "Capacitor Totem",
		[370] = "Purge",
		[36936] = "Totemic Recall",
		[77472] = "Healing Wave",
		[546] = "Water Walking",
		[107079] = "Quaking Palm",
		[165462] = "Unleash Flame",
		[51490] = "Thunderstorm",
		[51514] = "Hex",
		[2062] = "Earth Elemental Totem",
		[54197] = "Cold Weather Flying",
		[108271] = "Astral Shift",
		[108287] = "Totemic Projection",
		[2008] = "Ancestral Spirit",
		[403] = "Lightning Bolt",
		[556] = "Astral Recall",
		[51564] = "Tidal Waves",
		[55453] = "Telluric Currents",
		[165391] = "Purification",
		[6196] = "Far Sight",
		[2825] = "Bloodlust",
		[108280] = "Healing Tide Totem",
		[98008] = "Spirit Link Totem",
		[8050] = "Flame Shock",
		[114052] = "Ascendance",
		[324] = "Lightning Shield",
		[116956] = "Grace of Air",
		[2894] = "Fire Elemental Totem",
		[107074] = "Inner Peace",
		[83968] = "Mass Resurrection",
		[77756] = "Lava Surge",
		[88766] = "Fulmination",
		[1535] = "Fire Nova",
		[165399] = "Elemental Overload",
		[51505] = "Lava Burst",
		[16282] = "Flurry",
		[108281] = "Ancestral Guidance",
		[79206] = "Spiritwalker's Grace",
		[2484] = "Earthbind Totem",
		[8042] = "Earth Shock",
		[114050] = "Ascendance",
		[63374] = "Frozen Power",
		[8177] = "Grounding Totem",
		[161691] = "Garrison Ability",
		[51530] = "Maelstrom Weapon",
		[16166] = "Elemental Mastery",
		[2645] = "Ghost Wolf",
		[83944] = "Hasty Hearth",
		[73920] = "Healing Rain",
		[61882] = "Earthquake",
		[73680] = "Unleash Elements",
		[78633] = "Mount Up",
		[3599] = "Searing Totem",
		[30823] = "Shamanistic Rage",
		[8056] = "Frost Shock",
		[52127] = "Water Shield",
		[51533] = "Feral Spirit",
		[60103] = "Lava Lash",
		[8143] = "Tremor Totem",
		[8190] = "Magma Totem",
		[61295] = "Riptide",

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
		[71] = true, -- Defensive Stance
		[78] = true, -- Heroic Strike
		[100] = true, -- Charge
		[116] = true, -- Frostbolt
		[355] = true, -- Taunt
		[475] = true, -- Remove Curse
		[498] = true, -- Divine Protection
		[633] = true, -- Lay on Hands
		[642] = true, -- Divine Shield
		[724] = true, -- Lightwell
		[740] = true, -- Tranquility
		[768] = true, -- Cat Form
		[770] = true, -- Faerie Fire
		[772] = true, -- Rend
		[774] = true, -- Rejuvenation
		[879] = true, -- Exorcism
		[1022] = true, -- Hand of Protection
		[1044] = true, -- Hand of Freedom
		[1126] = true, -- Mark of the Wild
		[1160] = true, -- Demoralizing Shout
		[1715] = true, -- Hamstring
		[1719] = true, -- Recklessness
		[1850] = true, -- Dash
		[1953] = true, -- Blink
		[2139] = true, -- Counterspell
		[2457] = true, -- Battle Stance
		[2812] = true, -- Denounce
		[2818] = true, -- Deadly Poison
		[2912] = true, -- Starfire
		[3044] = true, -- Arcane Shot
		[3045] = true, -- Rapid Fire
		[3409] = true, -- Crippling Poison
		[3411] = true, -- Intervene
		[4987] = true, -- Cleanse
		[5118] = true, -- Aspect of the Cheetah
		[5176] = true, -- Wrath
		[5185] = true, -- Healing Touch
		[5211] = true, -- Mighty Bash
		[5308] = true, -- Execute
		[5487] = true, -- Bear Form
		[6343] = true, -- Thunder Clap
		[6552] = true, -- Pummel
		[6572] = true, -- Revenge
		[6673] = true, -- Battle Shout
		[6789] = true, -- Mortal Coil
		[6795] = true, -- Growl
		[6807] = true, -- Maul
		[6940] = true, -- Hand of Sacrifice
		[7001] = true, -- Lightwell Renew
		[7321] = true, -- Chilled
		[8921] = true, -- Moonfire
		[8936] = true, -- Regrowth
		[10326] = true, -- Turn Evil
		[11426] = true, -- Ice Barrier
		[12042] = true, -- Arcane Power
		[12043] = true, -- Presence of Mind
		[12051] = true, -- Evocation
		[12323] = true, -- Piercing Howl
		[12328] = true, -- Sweeping Strikes
		[12472] = true, -- Icy Veins
		[15571] = true, -- Dazed
		[16591] = true, -- Noggenfogger Elixir
		[16593] = true, -- Noggenfogger Elixir
		[16739] = true, -- Orb of Deception
		[16914] = true, -- Hurricane
		[17735] = true, -- Suffering
		[18499] = true, -- Berserker Rage
		[18562] = true, -- Swiftmend
		[19263] = true, -- Deterrence
		[19434] = true, -- Aimed Shot
		[19506] = true, -- Trueshot Aura
		[19574] = true, -- Bestial Wrath
		[19740] = true, -- Blessing of Might
		[19750] = true, -- Flash of Light
		[20154] = true, -- Seal of Righteousness
		[20165] = true, -- Seal of Insight
		[20217] = true, -- Blessing of Kings
		[20243] = true, -- Devastate
		[20271] = true, -- Judgment
		[20473] = true, -- Holy Shock
		[20484] = true, -- Rebirth
		[22812] = true, -- Barkskin
		[23881] = true, -- Bloodthirst
		[23920] = true, -- Spell Reflection
		[23922] = true, -- Shield Slam
		[24275] = true, -- Hammer of Wrath
		[24858] = true, -- Moonkin Form
		[30449] = true, -- Spellsteal
		[30451] = true, -- Arcane Blast
		[30455] = true, -- Ice Lance
		[31589] = true, -- Slow
		[31801] = true, -- Seal of Truth
		[31803] = true, -- Censure
		[31821] = true, -- Devotion Aura
		[31842] = true, -- Avenging Wrath
		[31850] = true, -- Ardent Defender
		[31935] = true, -- Avenger's Shield
		[33649] = true, -- Rage of the Unraveller
		[33745] = true, -- Lacerate
		[33763] = true, -- Lifebloom
		[33917] = true, -- Mangle
		[34026] = true, -- Kill Command
		[34428] = true, -- Victory Rush
		[34477] = true, -- Misdirection
		[35395] = true, -- Crusader Strike
		[44425] = true, -- Arcane Barrage
		[44572] = true, -- Deep Freeze
		[44614] = true, -- Frostfire Bolt
		[45438] = true, -- Ice Block
		[48438] = true, -- Wild Growth
		[50435] = true, -- Chilblains
		[51714] = true, -- Razorice
		[53209] = true, -- Chimaera Shot
		[53301] = true, -- Explosive Shot
		[53351] = true, -- Kill Shot
		[53563] = true, -- Beacon of Light
		[53595] = true, -- Hammer of the Righteous
		[53600] = true, -- Shield of the Righteous
		[54861] = true, -- Nitro Boosts
		[56641] = true, -- Steady Shot
		[57755] = true, -- Heroic Throw
		[58180] = true, -- Infected Wounds
		[59543] = true, -- Gift of the Naaru
		[59544] = true, -- Gift of the Naaru
		[59545] = true, -- Gift of the Naaru
		[59548] = true, -- Gift of the Naaru
		[60229] = true, -- Strength
		[60234] = true, -- Intellect
		[61316] = true, -- Dalaran Brilliance
		[61336] = true, -- Survival Instincts
		[62124] = true, -- Reckoning
		[63058] = true, -- Glyph of Barkskin
		[63685] = true, -- Frozen Power
		[64695] = true, -- Earthgrab
		[68992] = true, -- Darkflight
		[73326] = true, -- Tabard of the Lightbringer
		[75531] = true, -- Gnomeregan Pride
		[77505] = true, -- Earthquake
		[77764] = true, -- Stampeding Roar
		[77767] = true, -- Cobra Shot
		[78674] = true, -- Starsurge
		[80313] = true, -- Pulverize
		[80353] = true, -- Time Warp
		[80396] = true, -- Illusion
		[82326] = true, -- Holy Light
		[82327] = true, -- Holy Radiance
		[82692] = true, -- Focus Fire
		[84714] = true, -- Frozen Orb
		[84721] = true, -- Frozen Orb
		[85256] = true, -- Templar's Verdict
		[85288] = true, -- Raging Blow
		[85673] = true, -- Word of Glory
		[86659] = true, -- Guardian of Ancient Kings
		[88086] = true, -- Mirror Image
		[88088] = true, -- Mirror Image
		[88090] = true, -- Mirror Image
		[88423] = true, -- Nature's Cure
		[90628] = true, -- Guild Battle Standard
		[91797] = true, -- Monstrous Blow
		[91807] = true, -- Shambling Rush
		[96231] = true, -- Rebuke
		[96294] = true, -- Chains of Ice
		[100130] = true, -- Wild Strike
		[102342] = true, -- Ironbark
		[102351] = true, -- Cenarion Ward
		[102558] = true, -- Incarnation: Son of Ursoc
		[105681] = true, -- Mantid Elixir
		[106839] = true, -- Skull Bash
		[106898] = true, -- Stampeding Roar
		[108508] = true, -- Mannoroth's Fury
		[108843] = true, -- Blazing Speed
		[111685] = true, -- Summon Infernal
		[111759] = true, -- Levitate
		[112048] = true, -- Shield Barrier
		[112071] = true, -- Celestial Alignment
		[114030] = true, -- Vigilance
		[114108] = true, -- Soul of the Forest
		[114916] = true, -- Execution Sentence
		[115196] = true, -- Debilitating Poison
		[115236] = true, -- Void Shield
		[115317] = true, -- Raging Wind
		[115687] = true, -- Jab
		[115698] = true, -- Jab
		[116095] = true, -- Disable
		[118038] = true, -- Die by the Sword
		[118253] = true, -- Serpent Sting
		[119072] = true, -- Holy Wrath
		[120679] = true, -- Dire Beast
		[122233] = true, -- Crimson Tempest
		[122998] = true, -- Arcane Language
		[124974] = true, -- Nature's Vigil
		[126554] = true, -- Agile
		[126582] = true, -- Unwavering Might
		[126665] = true, -- Bloody Healing
		[127230] = true, -- Visions of Insanity
		[132158] = true, -- Nature's Swiftness
		[133630] = true, -- Exquisite Proficiency
		[135601] = true, -- Tooth and Claw
		[136494] = true, -- Word of Glory
		[137587] = true, -- Kil'jaeden's Cunning
		[145152] = true, -- Bloodtalons
		[145162] = true, -- Dream of Cenarius
		[147362] = true, -- Counter Shot
		[152116] = true, -- Saving Grace
		[152150] = true, -- Death from Above
		[155158] = true, -- Meteor Burn
		[155274] = true, -- Saving Grace
		[155722] = true, -- Rake
		[156064] = true, -- Greater Draenic Agility Flask
		[156079] = true, -- Greater Draenic Intellect Flask
		[156080] = true, -- Greater Draenic Strength Flask
		[156989] = true, -- Liadrin's Righteousness
		[156990] = true, -- Maraad's Truth
		[157584] = true, -- Instant Poison
		[158486] = true, -- Safari Hat
		[159238] = true, -- Shattered Bleed
		[160715] = true, -- Chains of Ice
		[161767] = true, -- Guardian Orb
		[162075] = true, -- Artillery Strike
		[162543] = true, -- Poisoned Ammo
		[162913] = true, -- Visions of the Future
		[163201] = true, -- Execute
		[165485] = true, -- Mastery
		[165822] = true, -- Haste
		[165824] = true, -- Mastery
		[165830] = true, -- Critical Strike
		[165832] = true, -- Multistrike
		[165833] = true, -- Versatility
		[165889] = true, -- Righteous Determination
		[166361] = true, -- Pride
		[166592] = true, -- Vindicator's Armor Polish Kit
		[166831] = true, -- Blazing Contempt
		[167105] = true, -- Colossus Smash
		[167188] = true, -- Inspiring Presence
		[169667] = true, -- Shield Charge
		[170176] = true, -- Anguish
		[170996] = true, -- Debilitate
		[171130] = true, -- Penance
		[171745] = true, -- Claws of Shirvallah
		[172968] = true, -- Lone Wolf: Quickness of the Dragonhawk
		[173983] = true, -- Nagrand Wolf Guardian
		[174926] = true, -- Shield Barrier
		[175790] = true, -- Draenic Swiftness Potion
		[176151] = true, -- Whispers of Insanity
		[176569] = true, -- Sargerei Disguise
		[176594] = true, -- Touch of the Naaru
		[176875] = true, -- Void Shards
		[176876] = true, -- Vision of the Cyclops
		[176974] = true, -- Mote of the Mountain
		[176980] = true, -- Heart of the Fury
		[177103] = true, -- Cracks!
		[177193] = true, -- Sha'tari Defender
		[177594] = true, -- Sudden Clarity
		[178776] = true, -- Rune of Power
		[178857] = true, -- Contender
		[178858] = true, -- Contender
		[179141] = true, -- Brute Strength
		[180745] = true, -- Well Fed
		[180747] = true, -- Well Fed
		[180748] = true, -- Well Fed
		[180749] = true, -- Well Fed
		[180750] = true, -- Well Fed
		[182059] = true, -- Surge of Conquest
		[182062] = true, -- Surge of Victory
		[182067] = true, -- Surge of Dominance
		[182073] = true, -- Rapid Adaptation
		[182226] = true, -- Bladebone Hook
		[184073] = true, -- Mark of Doom
		[184256] = true, -- Fel Burn
		[185229] = true, -- Flamelicked
		[188117] = true, -- Tyrande Whisperwind
		[188217] = true, -- Jaina Proudmoore
		[188280] = true, -- Sylvanas Windrunner
		[188289] = true, -- Prince Arthas Menethil
		[189325] = true, -- King of the Jungle
		[189363] = true, -- Burning Blade
		[190632] = true, -- Trailblazer
		[190639] = true, -- Hand of the Prophet Standard
		[190640] = true, -- Saberstalkers Standard
		[190653] = true, -- Ceremonial Karabor Guise
	}
	local badSourcelessPlayerSpellList = {
		[145629] = "Anti-Magic Zone",
		[156055] = "Oglethorpe's Missile Splitter",
		[156060] = "Megawatt Filament",
		[159234] = "Mark of the Thunderlord",
		[159675] = "Mark of Warsong",
		[159678] = "Mark of Shadowmoon",
		[159679] = "Mark of Blackrock",
		[173288] = "Hemet's Heartseeker",
		[173322] = "Mark of Bleeding Hollow",
		[81782] = "Power Word: Barrier",
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
		   (destName and badPlayerFilteredEvents[event] and badSourcelessPlayerSpellList[spellId] and band(destFlags, playerOrPet) ~= 0)
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
