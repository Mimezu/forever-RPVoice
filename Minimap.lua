-- Minimap button: click opens the window, drag moves it around the minimap edge.
-- Shown by default; RPVoiceDB.minimap (account-wide) keeps hide and angle.

local M = {}
RPVoiceMinimap = M

local DEFAULT_ANGLE = 200
local ICON = "Interface\\Icons\\INV_Misc_Note_02"

function M.DB()
	RPVoiceDB = RPVoiceDB or {}
	local mm = RPVoiceDB.minimap
	if type(mm) ~= "table" then mm = {}; RPVoiceDB.minimap = mm end
	if type(mm.angle) ~= "number" then mm.angle = DEFAULT_ANGLE end
	mm.hide = mm.hide == true
	return mm
end

-- Offset from the minimap centre for an angle in degrees.
function M.Offset(angle, radius)
	local r = math.rad(angle)
	return math.cos(r) * radius, math.sin(r) * radius
end

-- Angle in degrees (0-360) of a point relative to the minimap centre.
function M.AngleOf(dx, dy)
	local a = math.deg(math.atan2(dy, dx))
	if a < 0 then a = a + 360 end
	return a
end

local button

local function Place()
	if not button then return end
	local radius = (Minimap:GetWidth() / 2) + 5
	local x, y = M.Offset(M.DB().angle, radius)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	M.DB().angle = M.AngleOf(cx / scale - mx, cy / scale - my)
	Place()
end

local function Build()
	button = CreateFrame("Button", "RPVoiceMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function()
		if RPVoiceOptions_Toggle then RPVoiceOptions_Toggle() end
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("RP Voice", 1, 0.82, 0)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function M.Refresh()
	if not Minimap then return end
	if M.DB().hide then
		if button then button:Hide() end
		return
	end
	if not button then Build() end
	Place()
	button:Show()
end

function M.IsShown()
	return not M.DB().hide
end

function M.SetShown(show)
	M.DB().hide = not show
	M.Refresh()
end

if CreateFrame then
	local loader = CreateFrame("Frame")
	loader:RegisterEvent("PLAYER_LOGIN")
	loader:SetScript("OnEvent", function() M.Refresh() end)
end

return M
