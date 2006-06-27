local dewdrop = DewdropLib:GetInstance("1.0")
local tablet = TabletLib:GetInstance("1.0")

local icon_on = "Interface\\AddOns\\Transcriptor\\icon_on.tga"
local icon_off = "Interface\\AddOns\\Transcriptor\\icon_off.tga"

local logging

TSMenuFu = FuBarPlugin:new({
	name          = "Transcriptor",
	description   = "Easy Control of Transcriptor",
	version       = "0.1a",
	releaseDate   = "06-26-2006",
	aceCompatible = 103,
	fuCompatible  = "1.2",
	author        = "Kyahx",
	email 		  = "Kyahx.Pots@gmail.com",
	category      = "interface",
	cmd           = AceChatCmd:new({}, {}),

	hasIcon = icon_off,
	cannotHideText = false,
	cannotDetachTooltip = true,
	hasNoColor = true,
})


function TSMenuFu:MenuSettings(level, value)
	if level == 1 then
		dewdrop:AddLine(
			'text', "Events",
			'hasArrow', true,
			'value', "events"
		)
		dewdrop:AddLine(
			'text', "Clear Transcript Database",
			'func', function() Transcriptor:ClearLogs() end,
			'closeWhenClicked', true
		)
	elseif level == 2 then
		if value == "events" then
			if logging then
				dewdrop:AddLine(
					'text', "You can't modify events while logging an encounter."
				)
			else
				for event,status in TranscriptDB.events do
					local event = event
					local status = status
					dewdrop:AddLine(
						'text', event,
						'checked', status == 1,
						'func', function()
							if status == 1 then
								TranscriptDB.events[event] = 0
							else
								TranscriptDB.events[event] = 1
							end
						end
					)
				end
			end
		end
	end
end

function TSMenuFu:UpdateTooltip()
	tablet:SetHint("Click to start or stop transcribeing an encounter.")
end

function TSMenuFu:OnClick()
	if not logging then
		Transcriptor:StartLog()
		logging = true
		self:SetIcon(icon_on)
	else
		Transcriptor:StopLog()
		logging = nil
		self:SetIcon(icon_off)
	end
end

TSMenuFu:RegisterForLoad()
