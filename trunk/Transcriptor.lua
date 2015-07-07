
local Transcriptor = {}
local revision = tonumber(("$Revision$"):sub(12, -3))

local logName = nil
local currentLog = nil
local logStartTime = nil
local logging = nil
local compareSuccess = nil
local compareStart = nil
local compareStartTime = nil
local inEncounter = false
local tinsert = table.insert
local format = string.format
local tostringall = tostringall
local type = type
local date = date
local debugprofilestop = debugprofilestop
local C_Scenario = C_Scenario
local wowVersion, buildRevision, _, buildTOC = GetBuildInfo() -- Note that both returns here are strings, not numbers.

-- GLOBALS: TranscriptDB BigWigsLoader DBM CLOSE SlashCmdList SLASH_TRANSCRIPTOR1 SLASH_TRANSCRIPTOR2 SLASH_TRANSCRIPTOR3

local origPrint = print
local function print(msg)
	return origPrint("|cffffff00" .. msg .. "|r")
end
local origUnitName = UnitName
local function UnitName(name)
	local n = origUnitName(name)
	return n or "??"
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

Transcriptor.GetSpells = function()
	local tbl = {}
	local _, _, offset, numSpells = GetSpellTabInfo(GetNumSpellTabs())
	for i = 1, offset + numSpells do
		local spellType, id = GetSpellBookItemInfo(i, "spell")
		if spellType == "SPELL" and not tbl[id] then
			tbl[id] = GetSpellBookItemName(i, "spell")
		end
	end
	TranscriptDB.spellList = tbl
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
	-- These spells are taken using the spell book dump function Transcriptor.GetSpells()
	-- Last updated on WoW 6.2.0 LIVE
	local badPlayerSpellList = {
		-- DRUID
		[102401] = "Wild Charge",
		[22842] = "Frenzied Regeneration",
		[1079] = "Rip",
		[119467] = "Battle Pet Training",
		[90265] = "Master Riding",
		[774] = "Rejuvenation",
		[6795] = "Growl",
		[131231] = "Path of the Scarlet Blade",
		[106839] = "Skull Bash",
		[113043] = "Omen of Clarity",
		[165374] = "Naturalist",
		[2908] = "Soothe",
		[48500] = "Living Seed",
		[131232] = "Path of the Necromancer",
		[157283] = "Enhanced Tooth and Claw",
		[2782] = "Remove Corruption",
		[5215] = "Prowl",
		[783] = "Travel Form",
		[175682] = "Typhoon",
		[16864] = "Omen of Clarity",
		[68978] = "Flayer",
		[175683] = "Mighty Bash",
		[157284] = "Empowered Berserk",
		[157286] = "Enhanced Faerie Fire",
		[33745] = "Lacerate",
		[6807] = "Maul",
		[18562] = "Swiftmend",
		[2912] = "Starfire",
		[5221] = "Shred",
		[115913] = "Wisdom of the Four Winds",
		[90267] = "Flight Master's License",
		[768] = "Cat Form",
		[79742] = "Languages",
		[8936] = "Regrowth",
		[165962] = "Flight Form",
		[88423] = "Nature's Cure",
		[106952] = "Berserk",
		[145205] = "Wild Mushroom",
		[169605] = "Dragoon",
		[102342] = "Ironbark",
		[145518] = "Genesis",
		[158477] = "Soul of the Forest",
		[165372] = "Sharpened Claws",
		[131204] = "Path of the Jade Serpent",
		[80313] = "Pulverize",
		[125439] = "Revive Battle Pets",
		[48438] = "Wild Growth",
		[17007] = "Leader of the Pack",
		[5217] = "Tiger's Fury",
		[106785] = "Swipe",
		[83950] = "The Quick and the Dead",
		[131205] = "Path of the Stout Brew",
		[5487] = "Bear Form",
		[78674] = "Starsurge",
		[68996] = "Two Forms",
		[132158] = "Nature's Swiftness",
		[33917] = "Mangle",
		[54197] = "Cold Weather Flying",
		[93399] = "Shooting Stars",
		[76275] = "Armor Skills",
		[87840] = "Running Wild",
		[106898] = "Stampeding Roar",
		[179333] = "Nature's Bounty",
		[770] = "Faerie Fire",
		[165386] = "Lunar Guidance",
		[5176] = "Wrath",
		[33786] = "Cyclone",
		[1850] = "Dash",
		[78633] = "Mount Up",
		[127663] = "Astral Communion",
		[79577] = "Eclipse",
		[33605] = "Astral Showers",
		[18960] = "Teleport: Moonglade",
		[52610] = "Savage Roar",
		[48505] = "Starfall",
		[20484] = "Rebirth",
		[16914] = "Hurricane",
		[83958] = "Mobile Banking",
		[76300] = "Weapon Skills",
		[112071] = "Celestial Alignment",
		[102351] = "Cenarion Ward",
		[83944] = "Hasty Hearth",
		[339] = "Entangling Roots",
		[5185] = "Healing Touch",
		[131225] = "Path of the Setting Sun",
		[135288] = "Tooth and Claw",
		[157292] = "Empowered Bear Form",
		[165387] = "Survival of the Fittest",
		[158298] = "Resolve",
		[50769] = "Revive",
		[159286] = "Primal Fury",
		[740] = "Tranquility",
		[33763] = "Lifebloom",
		[106832] = "Thrash",
		[88747] = "Wild Mushroom",
		[8921] = "Moonfire",
		[61336] = "Survival Instincts",
		[1822] = "Rake",
		[124974] = "Nature's Vigil",
		[68975] = "Viciousness",
		[131206] = "Path of the Shado-Pan",
		[131222] = "Path of the Mogu King",
		[83968] = "Mass Resurrection",
		[161691] = "Garrison Ability",
		[22812] = "Barkskin",
		[78675] = "Solar Beam",
		[16974] = "Predatory Swiftness",
		[1126] = "Mark of the Wild",
		[131228] = "Path of the Black Ox",
		[22568] = "Ferocious Bite",
		[22570] = "Maim",
		[24858] = "Moonkin Form",
		[159232] = "Ursa Major",
		[83951] = "Guild Mail",
		[62606] = "Savage Defense",
		[68976] = "Aberration",
		[131229] = "Path of the Scarlet Mitre",
		[68992] = "Darkflight",
		[6603] = "Auto Attack",

		-- WARRIOR
		[3411] = "Intervene",
		[118038] = "Die by the Sword",
		[57755] = "Heroic Throw",
		[85288] = "Raging Blow",
		[119467] = "Battle Pet Training",
		[6603] = "Auto Attack",
		[114030] = "Vigilance",
		[1715] = "Hamstring",
		[167188] = "Inspiring Presence",
		[6544] = "Heroic Leap",
		[1160] = "Demoralizing Shout",
		[159362] = "Blood Craze",
		[6673] = "Battle Shout",
		[20598] = "The Human Spirit",
		[59752] = "Every Man for Himself",
		[469] = "Commanding Shout",
		[23920] = "Spell Reflection",
		[23922] = "Shield Slam",
		[20243] = "Devastate",
		[165365] = "Weapon Mastery",
		[871] = "Shield Wall",
		[115913] = "Wisdom of the Four Winds",
		[90267] = "Flight Master's License",
		[1719] = "Recklessness",
		[34428] = "Victory Rush",
		[112048] = "Shield Barrier",
		[18499] = "Berserker Rage",
		[176051] = "Improved Recklessness",
		[125439] = "Revive Battle Pets",
		[83950] = "The Quick and the Dead",
		[83958] = "Mobile Banking",
		[114192] = "Mocking Banner",
		[355] = "Taunt",
		[54197] = "Cold Weather Flying",
		[29838] = "Second Wind",
		[6572] = "Revenge",
		[156321] = "Shield Charge",
		[83951] = "Guild Mail",
		[23881] = "Bloodthirst",
		[12323] = "Piercing Howl",
		[12328] = "Sweeping Strikes",
		[103827] = "Double Time",
		[5308] = "Execute",
		[12712] = "Seasoned Soldier",
		[20599] = "Diplomacy",
		[5246] = "Intimidating Shout",
		[83944] = "Hasty Hearth",
		[83968] = "Mass Resurrection",
		[12975] = "Last Stand",
		[97462] = "Rallying Cry",
		[165393] = "Shield Mastery",
		[158298] = "Resolve",
		[115768] = "Deep Wounds",
		[175708] = "Storm Bolt",
		[79738] = "Languages",
		[2565] = "Shield Block",
		[100] = "Charge",
		[13046] = "Enrage",
		[161691] = "Garrison Ability",
		[165383] = "Cruelty",
		[1680] = "Whirlwind",
		[100130] = "Wild Strike",
		[76290] = "Weapon Skills",
		[167105] = "Colossus Smash",
		[174926] = "Shield Barrier",
		[78633] = "Mount Up",
		[78] = "Mortal Strike",
		[6552] = "Pummel",
		[90265] = "Master Riding",
		[175710] = "Bloodbath",
		[23588] = "Crazed Berserker",
		[2457] = "Battle Stance",
		[6343] = "Thunder Clap",
		[163201] = "Execute",
		[76268] = "Armor Skills",
		[29725] = "Sudden Death",
		[772] = "Rend",
		[71] = "Defensive Stance",

		-- PRIEST
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
	}
	local badPlayerFilteredEvents = {
		["SPELL_CAST_SUCCESS"] = true,
		["SPELL_AURA_APPLIED"] = true,
		["SPELL_AURA_APPLIED_DOSE"] = true,
		["SPELL_AURA_REFRESH"] = true,
		["SPELL_AURA_REMOVED"] = true,
		["SPELL_AURA_REMOVED_DOSE"] = true,
		["SPELL_CAST_START"] = true,
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
	local playerOrPet = 13568 -- COMBATLOG_OBJECT_CONTROL_PLAYER + COMBATLOG_OBJECT_TYPE_PLAYER + COMBATLOG_OBJECT_TYPE_PET + COMBATLOG_OBJECT_TYPE_GUARDIAN
	local band = bit.band
	-- Note some things we are trying to avoid filtering:
	-- BRF/Kagraz - Player damage with no source "SPELL_DAMAGE##nil#Player-GUID#PLAYER#154938#Molten Torrent#"
	-- HFC/Socrethar - Player cast on vehicle ""
	-- HFC/Zakuun - Player cast on player ""
	function sh.COMBAT_LOG_EVENT_UNFILTERED(timeStamp, event, caster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, _, extraSpellId, amount)
		if badEvents[event] or (sourceName and badPlayerEvents[event] and band(sourceFlags, playerOrPet) ~= 0) or (sourceName and badPlayerFilteredEvents[event] and badPlayerSpellList[spellId] and band(sourceFlags, playerOrPet) ~= 0) then
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
		line = strjoin("#", tostringall(event, ...))
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

		return
	else
		tinsert(currentLog.total, format("<%.2f %s> [%s] %s", t, time, event, line))
	end
	if type(currentLog[event]) ~= "table" then currentLog[event] = {} end
	tinsert(currentLog[event], format("<%.2f %s> %s", t, time, line))
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
	TranscriptDB.spellList = nil -- Cleanup

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

local logNameFormat = "[%s]@[%s] - %d/%d/%s/%s/%s@%s (r%d) (%s.%s)"
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
		logName = format(logNameFormat, date("%Y-%m-%d"), date("%H:%M:%S"), GetCurrentMapAreaID(), select(8, GetInstanceInfo()), GetZoneText() or "?", GetRealZoneText() or "?", GetSubZoneText() or "none", diff, revision or 1, tostring(wowVersion), tostring(buildRevision))

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
			for i, event in pairs(dbmEvents) do
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
		logName = nil
		currentLog = nil
		logging = nil
		compareSuccess = nil
		compareStart = nil
		compareStartTime = nil
		logStartTime = nil
	end
end

function Transcriptor:ClearAll()
	if not logging then
		local t2 = {}
		for k,v in pairs(TranscriptDB.ignoredEvents) do
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
