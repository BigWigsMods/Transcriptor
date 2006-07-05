local dewdrop = DewdropLib:GetInstance("1.0")
local tablet = TabletLib:GetInstance("1.0")

local icon_on = "Interface\\AddOns\\Transcriptor\\icon_on.tga"
local icon_off = "Interface\\AddOns\\Transcriptor\\icon_off.tga"

local statustext = "Transcriptor - |cff696969Idle|r"

TSMenuFu = FuBarPlugin:new({
	name          = "TranscriptorFu",
	description   = "Easy Control of Transcriptor",
	version       = "0.1a",
	releaseDate   = "06-26-2006",
	aceCompatible = 103,
	fuCompatible  = "1.2",
	author        = "Kyahx",
	email 		  = "Kyahx.Pots@gmail.com",
	category      = "interface",
	db            = AceDatabase:new("TSMenuFuDB"),
    cmd           = AceChatCmdClass:new({}, {}),

	hasIcon = icon_off,
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
		dewdrop:AddLine()
		dewdrop:AddLine(
			'text', "Insert Bookmark",
			'func', function() Transcriptor:InsNote("!! Bookmark !!") end,
			'closeWhenClicked', true
		)
	elseif level == 2 then
		if value == "events" then
			if Transcriptor.logging then
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
	local status = tablet:AddCategory()
	status:AddLine(
	    'text', statustext,
		'func', function() self:OnClick() end,
		'justify', "CENTER"
	)
end

function TSMenuFu:UpdateText()
	if Transcriptor.logging then
		statustext = "Transcriptor - |cffFF0000Recording|r"
		self:SetIcon(icon_on)
	else
		statustext = "Transcriptor - |cff696969Idle|r"
		self:SetIcon(icon_off)
	end
	self:SetText(statustext)
end

function TSMenuFu:OnClick()
	if not Transcriptor.logging then
		Transcriptor:StartLog()
	else
		Transcriptor:StopLog()
	end
end

TSMenuFu:RegisterForLoad()
