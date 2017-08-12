local n, tbl = ...
tbl.specialEvents = {
	-- Tomb of Sargeras
	["UNIT_SPELLCAST_SUCCEEDED"] = {
		[235268] = { -- Lunar Ghost
			[118523] = "Stage 2", -- Huntress Kasparian (Sisters of the Moon)
			[118374] = "Stage 3", -- Captain Yathae Moonstrike (Sisters of the Moon)
		},
		[239978] = { -- Soul Pallor
			[118460] = "Stage 2", -- Engine of Souls (The Desolate Host)
		},
	},
	["SPELL_AURA_APPLIED"] = {
		[244834] = { -- Nether Gale
			[117269] = "Intermission 1", -- Kil'jaeden
		},
	},
	["SPELL_AURA_REMOVED"] = {
		[244834] = { -- Nether Gale
			[117269] = "Stage 2", -- Kil'jaeden
		},
	},
	["SPELL_CAST_START"] = {
		[232174] = { -- Frosty Discharge
			[116407] = "Discharge", -- Harjatan the Bludger
		},
		[241983] = { -- Deceiver's Veil
			[117269] = "Intermission 2", -- Kil'jaeden
		},
	},
	["SPELL_AURA_REMOVED"] = {
		[234891] = { -- Wrath of the Creators
			[118289] = "Wrath Over", -- Maiden of Vigilance
		},
		[241983] = { -- Deceiver's Veil
			[117269] = "Stage 3", -- Kil'jaeden
		},
	},
}
