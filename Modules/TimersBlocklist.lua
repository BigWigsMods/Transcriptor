local addonTbl
do
	local _
	_, addonTbl = ...
end

--[[ Block certain spells from appearing in the TIMERS list
	[spellId] = { -- Spell name
		[npcId] = true, -- NPC name (reason)
	}
]]
addonTbl.TIMERS_BLOCKLIST = {
	[181113] = { -- Encounter Spawn
		[189233] = true, -- Caustic Spiderling (Small Adds on Sennarth, The Cold Breath)
	},

	-- [[ Vault of the Incarnates ]] --
	-- Eranog
	[370597] = { -- Kill Order
		[187638] = true, -- Flaming Tarasek (Small Adds)
	},
	[370342] = { -- Eruption
		[187593] = true, -- Collapsing Flame (Small Adds)
	},
	[373327] = { -- Destruction
		[187593] = true, -- Collapsing Flame (Small Adds)
	},

	-- Sennarth, The Cold Breath
	[374327] = { -- Caustic Blood
		[189233] = true, -- Caustic Spiderling (Small Adds)
	},
	[372045] = { -- Caustic Eruption
		[189233] = true, -- Caustic Spiderling (Small Adds)
	},

	-- Dathea, Ascended
	[384273] = { -- Storm Bolt
		[194647] = true, -- Thunder Caller (Small adds)
	},
	[388988] = { -- Crosswinds
		[191856] = true, -- Raging Tempest (Tornadoes Moving Individual)
	},

	-- Broodkeeper Diurna
	[388949] = { -- Frozen Shroud
		[196679] = true, -- Frozen Shroud (Units on each player after cast from boss)
	},
	[380483] = { -- Empowered Greatstaff's Wrath
		[193109] = true, -- Empowered Greatstaff of the Broodkeeper (Buffs/Debuffs on Each different staff)
	},
	[379413] = { -- Empowered Greatstaff's Wrath
		[193106] = true, -- Empowered Greatstaff of the Broodkeeper (Buffs/Debuffs on Each different staff)
	},
	[390711] = { -- Empowered Greatstaff's Wrath
		[193106] = true, -- Empowered Greatstaff of the Broodkeeper (Buffs/Debuffs on Each different staff)
	},
	[380176] = { -- Empowered Greatstaff of the Broodkeeper
		[193106] = true, -- Empowered Greatstaff of the Broodkeeper (Buffs/Debuffs on Each different staff)
	},
	[375842] = { -- Greatstaff of the Broodkeeper
		[191436] = true, -- Greatstaff of the Broodkeeper (Buffs/Debuffs on Each different staff)
	},
	[375882] = { -- Greatstaff's Wrath
		[191436] = true, -- Greatstaff of the Broodkeeper (Buffs/Debuffs on Each different staff)
	},
	[390710] = { -- Greatstaff's Wrath
		[191436] = true, -- Greatstaff of the Broodkeeper (Buffs/Debuffs on Each different staff)
	},
	[375889] = { -- Greatstaff's Wrath
		[191448] = true, -- Greatstaff of the Broodkeeper (Buffs/Debuffs on Each different staff)
	},
	[375716] = { -- Ice Barrage
		[191206] = true, -- Primalist Mage (Small Adds Broodkeeper)
	},
	[385547] = { -- Ascension
		[194990] = true, -- Stormseeker Acolyte (Small Adds Raszageth)
	},
	[385553] = { -- Storm Bolt
		[194990] = true, -- Stormseeker Acolyte (Small Adds Raszageth)
	},
	[388631] = { -- Volatile
		[194999] = true, -- Volatile Spark (Small Adds Raszageth)
	},
	[388635] = { -- Burst
		[194999] = true, -- Volatile Spark (Small Adds Raszageth)
	},
	[400259] = { -- -ClearAllDebuffs-
		[194999] = true, -- Volatile Spark (Small Adds Raszageth)
	},
	[388638] = { -- Volatile Current
		[194999] = true, -- Volatile Spark (Small Adds Raszageth)
	},
	[385559] = { -- Windforce Strikes
		[194991] = true, -- Oathsworn Vanguard (Small Adds Raszageth)
	}
}
