local tbl
do
	local _
	_, tbl = ...
end

tbl.specialEvents = {
	["UNIT_SPELLCAST_SUCCEEDED"] = {
		--[[ Tomb of Sargeras ]]--
		[239423] = { -- Dread Shark
			[115767] = function() -- Mistress Sassz'ine
				tbl.data[1] = (tbl.data[1] or 1) + 1

				local stage = tbl.data[1]
				local _, _, diff = GetInstanceInfo()
				if diff == 16 then -- Mythic
					if stage == 3 then
						return "Stage 2"
					elseif stage == 5 then
						return "Stage 3"
					end
				else
					return "Stage ".. stage
				end
			end,
		},
		[235268] = { -- Lunar Ghost
			[118523] = "Stage 2", -- Huntress Kasparian (Sisters of the Moon)
			[118374] = "Stage 3", -- Captain Yathae Moonstrike (Sisters of the Moon)
		},
		[239978] = { -- Soul Pallor
			[118460] = "Stage 2", -- Engine of Souls (The Desolate Host)
		},

		-- [[ Antorus, the Burning Throne ]] --
		[248995] = { -- Jet Packs
			[124158] = "Intermission 1", -- Imonar
		},
		[248194] = { -- Jet Packs
			[124158] = "Intermission 2", -- Imonar
		},

		-- [[ Uldir ]] --
		[269051] = { -- Cleansing Purge
			[136429] = "Room 1", -- Room 1 (MOTHER)
			[137022] = "Room 2", -- Room 2 (MOTHER)
			[137023] = "Room 3", -- Room 3 (MOTHER)
		},
		[279749] = { -- Stage 2 Start
			[134546] = "Stage 2", -- Mythrax
		},
		[279748] = { -- Stage 2 End
			[134546] = "Stage 1", -- Mythrax
		},

		-- [[ Battle of Dazar'Alor ]]--
		[287165] = { -- King Rastakhan P1 -> P2 Conversation
			[145616] = "Stage 2", -- King Rastakhan
		},
		[290801] = { -- King Rastakhan P2 -> P3 Conversation [DO NOT TRANSLATE]
			[145616] = "Stage 3", -- King Rastakhan
		},
		[290852] = { -- King Rastakhan P3 -> P4 Conversation [DO NOT TRANSLATE]
			[145616] = "Stage 4", -- King Rastakhan
		},
		[287282] = { -- Intermission 1 Start
			[146409] = "Intermission 1", -- Lady Jaina Proudmoore
		},

		-- [[ The Eternal Palace ]] --
		[301428] = { -- Intermission Start
			[150653] = "Intermission",  -- Blackwater Behemoth
		},
		[298689] = { -- Intermission Start
			[152128] = "Intermission",  -- Orgozoa
		},
		[297121] = { -- Intermission Over
			[152364] = "Intermission Over",  -- Radiance of Azshara
		},
		[295361] = { -- Cancel All Phases (Encounter Reset)  (Stage 4 start)
			[150859] = "Stage 4",  -- Za'qul
		},

		-- [[ Castle Nathria ]] --
		[331844] = { -- Focus Anima: Desires
			[165521] = "Desires Focused" -- Lady Inerva Darkvein
		},
		[331870] = { -- Focus Anima: Bottles
			[165521] = "Bottles Focused" -- Lady Inerva Darkvein
		},
		[331872] = { -- Focus Anima: Sins
			[165521] = "Sins Focused" -- Lady Inerva Darkvein
		},
		[331873] = { -- Focus Anima: Desires
			[165521] = "Adds Focused" -- Lady Inerva Darkvein
		},

		-- [[ Sanctum Of Domination ]] --
		[350745] = { -- Maw Power (Set to 00)  [DNT]
			[175726] = "Stage 2" -- Skyja
		},
	},
	["UNIT_SPELLCAST_INTERRUPTED"] = {
		-- [[ Battle of Dazar'Alor ]]--
		[288696] = { -- Stage 2 start
			[146256] = "Stage 2", -- Laminaria (Blockade)
		},

		-- [[ The Eternal Palace ]] --
		[292083] = { -- Cavitation
			[150653] = "Intermission Over",  -- Blackwater Behemoth
		},
		[298548] = { -- Massive Incubator // Stage 2 start
			[152128] = "Stage 2",  -- Orgozoa
		},
	},
	["SPELL_AURA_APPLIED"] = {
		--[[ Tomb of Sargeras ]]--
		[244834] = { -- Nether Gale
			[117269] = "Intermission 1", -- Kil'jaeden
		},

		-- [[ Antorus, the Burning Throne ]] --
		[246897] = { -- Haywire
			[122773] = "Decimator Haywire", -- Decimator (Worldbreaker)
		},
		[246965] = { -- Haywire
			[122778] = "Annihilator Haywire", -- Annihilator (Worldbreaker)
		},
		[246516] = { -- Apocalypse Protocol
			[122578] = "Construction Stage", -- Kin'garoth
		},
		[244894] = { -- Corrupt Aegis
			[121975] = function() -- Aggramar
				return "Intermission ".. (tbl.data[1] or 1)
			end,
		},

		-- [[ Uldir ]] --
		[271965] = { -- Powered Down
			[137119] = "Intermission", -- Taloc
		},
		[270443] = { -- Corrupting Bite
			[132998] = "Stage 2", -- G'huun
		},

		-- [[ The Eternal Palace ]] --
		[296650] = { -- Hardened Carapace Removed
			[152236] = "Stage 1", -- Priscilla Ashvane
		},

		-- [[ Castle Nathria ]] --
		[323402] = { -- Reflection of Guilt
			[165759] = "Shade Up", -- Kael'thas Sunstrider
		},
		[329636] = { -- Hardened Stone Form
			[168112] = "Intermission" -- General Kaal
		},
		[329808] = { -- Hardened Stone Form
			[168113] = "Intermission" -- General Grashaal
		},

		-- [[ Sanctum Of Domination ]] --
		[348805] = { -- Stygian Darkshield
			[175725] = function() -- Eye of the Jailer
				tbl.data[1] = 2 -- Stage 2
				return "Stage 2"
			end,
		},
		[352385] = { -- Energizing Link
			[176583] = function() -- Energy Core
				local t = GetTime()
				if t - (tbl.data[1] or 0) > 5 then
					tbl.data[1] = t
					return "Link Active"
				end
			end,
		},
		[357739] = { -- Realign Fate
			[175730] = "Stage 2", -- Fatescribe Roh-Kalo
		},
		[350857] = { -- Banshee Shroud
			[175732] = function() -- Sylvanas Windrunner
				if not tbl.data[1] then -- We only want to trigger this once
					tbl.data[1] = true
					return "Intermission"
				end
			end,
		},
		[352051] = { -- Necrotic Surge
			[175559] = function() -- Kel'Thuzad
				if not tbl.data[1] then
					local power = UnitPower("boss1")
					return ("Stage 1 (%s)"):format(power or "?")
				end
			end,
		},
		[348146] = { -- Banshee Form
			[175732] = function() -- Sylvanas Windrunner
				if not tbl.data[2] then -- We only want to trigger this once
					tbl.data[2] = true
					return "Stage 2"
				end
			end,
		},

		-- [[ Sepulcher of the First Ones ]] --
		[363139] = { -- Decipher Relic
			[183501] = "Intermission" -- Artificer Xy'mox
		},
		[365216] = { -- Domination's Grasp
			[181954] = "Intermission" -- Anduin Wrynn
		},
	},
	["SPELL_AURA_APPLIED_DOSE"] = {
		-- [[ Sanctum Of Domination ]] --
		[352051] = { -- Necrotic Surge
			[175559] = function() -- Kel'Thuzad
				if not tbl.data[1] then
					local power = UnitPower("boss1")
					return ("Stage 1 (%s)"):format(power or "?")
				end
			end,
		},
	},
	["SPELL_AURA_REMOVED"] = {
		--[[ Tomb of Sargeras ]]--
		[234891] = { -- Wrath of the Creators
			[118289] = "Wrath Over", -- Maiden of Vigilance
		},
		[244834] = { -- Nether Gale
			[117269] = "Stage 2", -- Kil'jaeden
		},
		[241983] = { -- Deceiver's Veil
			[117269] = "Stage 3", -- Kil'jaeden
		},

		-- [[ Antorus, the Burning Throne ]] --
		[248233] = { -- Conflagration
			[124158] = "Stage 2", -- Imonar
		},
		[250135] = { -- Conflagration
			[124158] = "Stage 3", -- Imonar
		},
		[246516] = { -- Apocalypse Protocol
			[122578] = "Deployment Stage", -- Kin'garoth
		},
		[244894] = { -- Corrupt Aegis
			[121975] = function() -- Aggramar
				tbl.data[1] = (tbl.data[1] or 1) + 1
				return "Stage ".. tbl.data[1]
			end,
		},

		-- [[ Uldir ]] --
		[271965] = { -- Powered Down
			[137119] = "Stage 2", -- Taloc
		},
		[265217] = { -- Liquefy
			[134442] = "Intermission Over", -- Vectis
		},

		-- [[ Battle of Dazar'Alor ]]--
		[288199] = { -- Howling Winds
			[146409] = "Stage 2", -- Lady Jaina Proudmoore
		},
		[290001] = { -- Arcane Barrage
			[146409] = "Stage 3", -- Lady Jaina Proudmoore
		},

		-- [[ The Eternal Palace ]] --
		[296650] = { -- Hardened Carapace Removed
			[152236] = "Stage 2", -- Priscilla Ashvane
		},

		-- [[ Ny'alotha, the Waking City ]] --
		[306995] = { -- Smoke and Mirrors
			[156818] = "Stage 1", -- Wrathion
		},

		-- [[ Castle Nathria ]] --
		[328921] = { -- Bloodgorge
			[164406] = "Stage 1", -- Shriekwing
		},
		[323402] = { -- Reflection of Guilt
			[165759] = "Shade Killed", -- Kael'thas Sunstrider
		},
		[331314] = { -- Destructive Impact
			[164407] = "Impact Removed", -- Sludgefist
		},
		[329636] = { -- Hardened Stone Form
			[168112] = "Stage 2" -- General Kaal
		},
		[329808] = { -- Hardened Stone Form
			[168113] = "Stage 3" -- General Grashaal
		},

		-- [[ Sanctum Of Domination ]] --
		[348805] = { -- Stygian Darkshield
			[175725] = function() -- Eye of the Jailer
				if tbl.data[1] == 2 then -- Only if still in stage 2
					tbl.data[1] = 1
					return "Stage 1"
				end
			end,
		},
		[357739] = { -- Realign Fate
			[175730] = function() -- Fatescribe Roh-Kalo
				tbl.data[1] = (tbl.data[1] or 1) + 1
				if tbl.data[1] > 3 then -- Stage 3 after 3x Realign Fate
					return "Stage 3"
				else
					return "Stage 1"
				end
			end,
		},
		[355525] = { -- Forge Weapon
			[176523] = function() -- Painsmith Raznal
				return "Intermission "..tbl.data[1].." Over"
			end,
		},

		-- [[ Sepulcher of the First Ones ]] --
		[360879] = { -- Ancient Defenses
			[180773] = "Stage 2", -- Vigilant Guardian
		},
		[361651] = { -- Siphoned Barrier
			[181224] = "Barrier Removed", -- Dausegne
		},
		[363139] = { -- Decipher Relic
			[183501] = function() -- Artificer Xy'mox
				tbl.data[1] = (tbl.data[1] or 1) + 1
				return "Stage "..tbl.data[1]
			end,
		},
		[363130] = { -- Synthesize
			[182169] = "Synthesize Over", -- Lihuvim
		},
		[360115] = { -- Reclaim
			[180906] = "Reclaim", -- Halondrus
		},
		[365216] = { -- Domination's Grasp
			[181954] = function() -- Anduin Wrynn
				tbl.data[1] = (tbl.data[1] or 1) + 1
				return "Stage " .. tbl.data[1]
			end
		},
		[360516] = { -- Infiltration
			[181398] = "Infiltration Over" -- Malganis
		},
	},
	["SPELL_CAST_START"] = {
		--[[ Tomb of Sargeras ]]--
		[232174] = { -- Frosty Discharge
			[116407] = "Discharge", -- Harjatan the Bludger
		},
		[241983] = { -- Deceiver's Veil
			[117269] = "Intermission 2", -- Kil'jaeden
		},

		-- [[ Antorus, the Burning Throne ]] --
		[245227] = { -- Assume Command
			[122367] = "Svirax Leaving", -- Admiral Svirax (High Command)
			[122369] = "Ishkar Leaving", -- Chief Engineer Ishkar (High Command)
			[122333] = "Erodus Leaving", -- General Erodus (High Command)
		},
		[255648] = { -- Golganneth's Wrath
			[126268] = "Stage 2", -- Golganneth (Argus the Unmaker)
		},
		[257645] = { -- Temporal Blast
			[125885] = "Stage 3", -- Aman'Thul (Argus the Unmaker)
		},
		[256542] = { -- Reap Soul
			[124828] = "Stage 4", -- Argus the Unmaker
		},

		-- [[ Uldir ]] --
		[265217] = { -- Liquefy
			[134442] = "Intermission", -- Vectis
		},

		-- [[ Battle of Dazar'Alor ]]--
		[287751] = { -- Evasive Maneuvers!
			[144796] = "Stage 2", -- High Tinker Mekkatorque
		},
		[287797] = { -- Crash Down
			[144796] = "Stage 3", -- High Tinker Mekkatorque
		},
		[288719] = { -- Flash Freeze
			[146409] = "Intermission 2", -- Lady Jaina Proudmoore
		},

		[295916] = { -- Ancient Tempest
			[152364] = "Intermission",  -- Radiance of Azshara
		},
		[296257] = { -- OpeningFearRealm
			[150859] = "Stage 2",  -- Za'qul
		},
		[304733] = { -- DeliriumsDescent
			[150859] = "Stage 3",  -- Za'qul
		},

		-- [[ Ny'alotha, the Waking City ]] --
		[306735] = { -- Burning Cataclysm
			[156818] = "Cataclysm", -- Wrathion
		},
		[306995] = { -- Smoke and Mirrors
			[156818] = "Stage 2", -- Wrathion
		},

		-- [[ Sanctum Of Domination ]] --
		[347679] = { -- Hungering Mist
			[175611] = "Mists" -- The Tarragrue
		},
		[348974] = { -- Immediate Extermination
			[175725] = function() -- Eye of the Jailer
				tbl.data[1] = 3
				return "Stage 3"
			end,
		},
		[351066] = { -- Shatter
			[175729] = "Shatter (Helm)", -- Remnant of Ner'zhul
		},
		[351067] = { -- Shatter
			[175729] = "Shatter (Gauntlet)", -- Remnant of Ner'zhul
		},
		[351073] = { -- Shatter
			[175729] = "Shatter (Rattlecage)", -- Remnant of Ner'zhul
		},
		[355525] = { -- Forge Weapon
			[176523] = function() -- Painsmith Raznal
				tbl.data[1] = (tbl.data[1] or 0) + 1
				return "Intermission "..tbl.data[1]
			end,
		},
		[352293] = { -- Vengeful Destruction
			[175559] = "Stage 2", -- Kel'Thuzad
		},
		[357102] = { -- Raid Portal: Oribos
			[176533] = "Stage 2 End", -- Lady Jaina Proudmoore // Sylvanas Windrunner Encounter
		},

		-- [[ Sepulcher of the First Ones ]] --
		[361630] = { -- Teleport
			[181224] = "Teleport" -- Dausegne
		},
		[359770] = { -- Unending Hunger
			[181395] = "Burrow", -- Skolex
		},
		[363130] = { -- Synthesize
			[182169] = "Synthesize", -- Lihuvim
		},
		[359236] = { -- Relocation Form
			[180906] = "Stage 2", -- Halondrus
		},
		[359235] = { -- Reclamation Form
			[180906] = "Stage 1", -- Halondrus
		},
		[361300] = { -- Reconstruction
			[181549] = function() -- Prototype of War // They all cast it, we only have to track 1 boss
				tbl.data[1] = (tbl.data[1] or 1) + 1
				return "Stage "..tbl.data[1]
			end,
		},
		[360300] = { -- Swarm of Decay // Unto Darkness
			[181398] = "Unto Darkness", -- Mal'Ganis
		},
		[360717] = { -- Infiltration of Dread
			[181398] = "Infiltration", -- Mal'Ganis
		},
		[363533] = { -- Massive Bang
			[182777] = "Massive Bang", -- Rygelon
		},
		[364114] = { -- Shatter Sphere
			[182777] = "Shatter Sphere", -- Rygelon
		},
	},
	["SPELL_CAST_SUCCESS"] = {
		--[[ Tomb of Sargeras ]]--
		[235597] = { -- Annihilation
			[116939] = "Stage 2", -- Fallen Avatar
		},

		-- [[ Uldir ]] --
		[274168] = { -- Locus of Corruption
			[138967] = "Stage 2", -- Zul
		},
		[276839] = { -- Collapse
			[132998] = "Stage 3", -- G'huun
		},

		-- [[ Ny'alotha, the Waking City ]] --
		[307453] = { -- The Void Unleashed
			[157354] = "Stage 3" -- Vexiona
		},

		-- [[ Castle Nathria ]] --
		[343995] = { -- Bloodgorge
			[164406] = "Intermission", -- Shriekwing
		},
		[181089] = { -- Encounter Event
			[166644] = "Encounter Event", -- Artificer Xy'mox
		},
		[347376] = { -- Dance Area Trigger (Danse Macabre trigger)
			[168870] = "Danse Macabre Begin" -- Dance Controller
		},
		[329697] = { -- Begin the Chorus
			[167406] = "Stage 2" -- Denathrius
		},
		[326005] = { -- Indignation
			[167406] = "Stage 3" -- Denathrius
		},

		-- [[ Sanctum of Domination ]] --
		[349985] = { -- Encore of Torment
			[175727] = "Dance" -- Soulrender Dormazain
		},

		-- [[ Sepulcher of the First Ones ]] --
		[367711] = { -- Decipher Relic
			[183501] = function() -- Artificer Xy'mox
				tbl.data[1] = (tbl.data[1] or 1) + 1
				return "Stage "..tbl.data[1]
			end,
		},
		[357729] = { -- Blasphemy
			[178072] = function() -- Anduin Wrynn // Sylvanas Windrunner Encounter
				if not tbl.data[3] then -- We only want to trigger this once
					tbl.data[3] = true
					return "Stage 3"
				end
			end,
		},
	},
	["UNIT_DIED"] = {
		--[[ Antorus, the Burning Throne ]]--
		[122773] = "Decimator Killed", -- Decimator (Worldbreaker)
		[122778] = "Annihilator Killed", -- Annihilator (Worldbreaker)

		-- [[ Castle Nathria ]] --
		[165067] = "Margore Killed", -- Margore (Huntsman Altimor)
		[169457] = "Bargast Killed", -- Bargast (Huntsman Altimor)
		[169458] = "Hecutis Killed", -- Hecutis (Huntsman Altimor)
		[166969] = "Baroness Frieda Killed", -- Baroness Frieda (The Council of Blood)
		[166970] = "Lord Stavros Killed", -- Lord Stavros (The Council of Blood)
		[166971] = "Castellan Niklaus Killed", -- Castellan Niklaus (The Council of Blood)

		-- [[ Sanctum of Domination ]] --
		[176929] = function() -- Remnant of Kel'Thuzad
			tbl.data[1] = true
			local power = UnitPower("boss1")
			return ("Stage 3 (%s)"):format(power or "?")
		end,
	},
}
