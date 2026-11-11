-- RP Voice settings window. Opens with /rpv.
-- Look follows the suite's Legacy windows (ForeverNames layout B): leather, bronze cards,
-- gold accents, segmented choices and steppers instead of dropdowns.

local RPV = RPVoiceTag
local S = RPVoiceSkin
local Core = RPVoiceCore

local W, H = 660, 536
local GOLD = { 1, 0.82, 0 }
local NOTE = { 0.80, 0.77, 0.70 }
local DIM = { 0.62, 0.60, 0.55 }
local BRONZE = { 0.68, 0.50, 0.26 }
local ROW = 28
local PAD = 14
local LABEL_W = 96

local frame
local refreshers = {}

local function Refresh()
	for _, fn in ipairs(refreshers) do fn() end
end

local function OnRefresh(fn)
	refreshers[#refreshers + 1] = fn
end

local function Capitalize(s)
	return (s:gsub("^%l", string.upper))
end

local function Tooltip(widget, title, text)
	widget:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, GOLD[1], GOLD[2], GOLD[3])
		if text then GameTooltip:AddLine(text, NOTE[1], NOTE[2], NOTE[3], true) end
		GameTooltip:Show()
	end)
	widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------

local function Line(parent, alpha)
	local t = parent:CreateTexture(nil, "BORDER")
	t:SetColorTexture(BRONZE[1], BRONZE[2], BRONZE[3], alpha)
	return t
end

-- A section card: soft leather wash, thin bronze edges, gold title.
local function Card(parent, title, x, y, w, h)
	local card = CreateFrame("Frame", nil, parent)
	card:SetPoint("TOPLEFT", x, y)
	card:SetSize(w, h)
	local fill = card:CreateTexture(nil, "BACKGROUND", nil, 1)
	fill:SetAllPoints()
	fill:SetColorTexture(0.25, 0.17, 0.085, 0.16)
	local top = Line(card, 0.55); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
	local bottom = Line(card, 0.3); bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
	local left = Line(card, 0.3); left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
	local right = Line(card, 0.3); right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)
	local heading = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	heading:SetPoint("TOPLEFT", PAD, -11)
	heading:SetText(title)
	card.nextY = -34
	return card
end

-- Next row inside a card, with a white label on the left. Returns the row frame.
local function Row(card, label, height)
	height = height or ROW
	local row = CreateFrame("Frame", nil, card)
	row:SetPoint("TOPLEFT", PAD, card.nextY)
	row:SetPoint("RIGHT", card, "RIGHT", -PAD, 0)
	row:SetHeight(height)
	card.nextY = card.nextY - height - 4
	if label then
		local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		text:SetPoint("TOPLEFT", 0, -6)
		text:SetWidth(LABEL_W)
		text:SetJustifyH("LEFT")
		text:SetText(label)
		row.label = text
	end
	return row
end

-- Text input on a dark inset with a bronze edge; saves as you type.
local function Input(parent, opts)
	local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	box:SetBackdropColor(0, 0, 0, 0.38)
	box:SetBackdropBorderColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.55)
	box:SetFontObject(opts.multi and "GameFontHighlightSmall" or "GameFontHighlight")
	box:SetAutoFocus(false)
	box:SetTextInsets(7, 7, opts.multi and 6 or 0, opts.multi and 6 or 0)
	box:SetMaxLetters(opts.max or 60)
	if opts.multi then
		box:SetMultiLine(true)
		box:SetSpacing(2)
	end

	local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", 8, opts.multi and -7 or -1)
	hint:SetPoint("RIGHT", -8, 0)
	if not opts.multi then hint:SetPoint("BOTTOM", 0, 0) end
	hint:SetJustifyH("LEFT")
	hint:SetJustifyV(opts.multi and "TOP" or "MIDDLE")

	local counter
	if opts.counter then
		counter = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		counter:SetPoint("BOTTOMRIGHT", -6, 5)
	end

	local function UpdateHint()
		local text = box:GetText()
		hint:SetText(opts.hint and opts.hint() or "")
		hint:SetShown(text == "" and not box:HasFocus())
		if counter then counter:SetText(#text .. "/" .. (opts.max or 60)) end
	end

	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnEnterPressed", box.ClearFocus)
	box:SetScript("OnEditFocusGained", function()
		box:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
		UpdateHint()
	end)
	box:SetScript("OnEditFocusLost", function()
		box:SetBackdropBorderColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.55)
		-- tidy what was typed (no line breaks or tag characters)
		local clean = RPV.Clean(box:GetText(), opts.max or 60)
		if clean ~= box:GetText() then box:SetText(clean) end
		UpdateHint()
	end)
	box:SetScript("OnTextChanged", function(_, userInput)
		if userInput then
			local value = RPV.Clean(box:GetText(), opts.max or 60)
			opts.set(value ~= "" and value or nil)
			Refresh()
		end
		UpdateHint()
	end)
	box:SetScript("OnMouseDown", function() box:SetFocus() end)

	OnRefresh(function()
		if not box:HasFocus() then
			box:SetText(opts.get() or "")
			box:SetCursorPosition(0)
		end
		UpdateHint()
	end)
	return box
end

-- A plate-backed button cell (segment, stepper arrow, footer button).
local function Cell(parent, w, h)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.art = S.Plate(b, "common-button-list-collapseExpand")
	b:HookScript("OnSizeChanged", function() b.art:Update() end)
	local hover = b:CreateTexture(nil, "HIGHLIGHT")
	hover:SetPoint("TOPLEFT", 3, -3); hover:SetPoint("BOTTOMRIGHT", -3, 3)
	hover:SetColorTexture(1, 0.72, 0.2, 0.12)
	b.wash = b:CreateTexture(nil, "ARTWORK")
	b.wash:SetPoint("TOPLEFT", 3, -3); b.wash:SetPoint("BOTTOMRIGHT", -3, 3)
	b.wash:SetColorTexture(1, 0.72, 0.2, 0.22)
	b.wash:Hide()
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.text:SetPoint("CENTER")
	b:HookScript("OnMouseDown", function() b.art:Tint({ 0.7, 0.7, 0.7, 1 }) end)
	b:HookScript("OnMouseUp", function() b.art:Tint({ 1, 1, 1, 1 }) end)
	return b
end

-- Segmented choice: [Light|Medium|Strong]. Selected cell is gold with a warm wash.
local function Segmented(row, values, get, set, tips)
	local width = row:GetWidth() > 0 and row:GetWidth() or 260
	local holder = CreateFrame("Frame", nil, row)
	holder:SetPoint("TOPLEFT", LABEL_W + 6, -2)
	holder:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	holder:SetHeight(22)
	local cells = {}
	for i, value in ipairs(values) do
		local c = Cell(holder, 10, 22)
		c.text:SetText(Capitalize(value))
		c:SetScript("OnClick", function()
			set(value)
			PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115)
			Refresh()
		end)
		if tips and tips[value] then Tooltip(c, Capitalize(value), tips[value]) end
		cells[i] = c
	end
	local function Layout()
		local w = holder:GetWidth()
		if w <= 0 then return end
		local cw = w / #cells
		for i, c in ipairs(cells) do
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", (i - 1) * cw, 0)
			c:SetSize(cw + (i < #cells and 1 or 0), 22)
		end
	end
	holder:SetScript("OnSizeChanged", Layout)
	Layout()
	OnRefresh(function()
		local current = get()
		for i, c in ipairs(cells) do
			local on = values[i] == current
			c.wash:SetShown(on)
			c.text:SetTextColor(on and GOLD[1] or 0.82, on and GOLD[2] or 0.82, on and GOLD[3] or 0.82)
		end
	end)
	return holder
end

-- Stepper: [<][ value ][>] cycling through a list. labelOf(value) gives the shown text.
local function Stepper(row, values, labelOf, get, set)
	local holder = CreateFrame("Frame", nil, row)
	holder:SetPoint("TOPLEFT", LABEL_W + 6, -2)
	holder:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	holder:SetHeight(22)
	local prev = Cell(holder, 24, 22)
	prev:SetPoint("LEFT")
	prev.text:SetText("<")
	local nextB = Cell(holder, 24, 22)
	nextB:SetPoint("RIGHT")
	nextB.text:SetText(">")
	local mid = Cell(holder, 10, 22)
	mid:SetPoint("LEFT", prev, "RIGHT", -1, 0)
	mid:SetPoint("RIGHT", nextB, "LEFT", 1, 0)
	mid.text:SetFontObject("GameFontHighlight")

	local function IndexOf(v)
		for i, x in ipairs(values) do if x == v then return i end end
		return 1
	end
	local function Step(delta)
		local i = IndexOf(get()) + delta
		if i < 1 then i = #values elseif i > #values then i = 1 end
		set(values[i])
		PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115)
		Refresh()
	end
	prev:SetScript("OnClick", function() Step(-1) end)
	nextB:SetScript("OnClick", function() Step(1) end)
	mid:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mid:SetScript("OnClick", function(_, button) Step(button == "RightButton" and -1 or 1) end)
	mid:EnableMouseWheel(true)
	mid:SetScript("OnMouseWheel", function(_, d) Step(d > 0 and -1 or 1) end)
	OnRefresh(function() mid.text:SetText(labelOf(get())) end)
	return holder
end

local function Check(parent, label, get, set)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	local text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
	text:SetText(label)
	if cb.Text then cb.Text:SetText("") end
	cb:SetHitRectInsets(0, -(text:GetStringWidth() + 6), 0, 0)
	cb:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		Refresh()
	end)
	OnRefresh(function() cb:SetChecked(get()) end)
	cb.label = text
	return cb
end

local function Button(parent, label, w, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 24)
	b:SetText(label)
	S.Button(b)
	b:SetScript("OnClick", onClick)
	return b
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local function DB() return Core.CharDB() end

local function Describe()
	local info = Core.SpeakerInfo(nil)
	local db = DB()
	local who = string.format("|cffffd100%s|r, %s %s of the %s", info.name, info.sex, info.race, info.faction)
	local voice = Capitalize(db.style)
	if db.tone ~= "natural" then voice = voice .. ", " .. db.tone end
	return who, voice
end

local function Build()
	frame = CreateFrame("Frame", "RPVoiceOptions", UIParent, "BackdropTemplate")
	frame:SetSize(W, H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:Hide()
	table.insert(UISpecialFrames, "RPVoiceOptions")

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetText("RP Voice")
	S.Frame(frame, title)

	if FrameGambitAPI and FrameGambitAPI.RegisterCinematicWindow then
		pcall(FrameGambitAPI.RegisterCinematicWindow, frame)
	end

	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 26, -42)
	content:SetPoint("BOTTOMRIGHT", -22, 50)
	local CW = W - 48
	local COL = math.floor((CW - 10) / 2)

	-- Header: who you are speaking as, and the master switch
	local who = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	who:SetPoint("TOPLEFT", 2, -4)
	who:SetJustifyH("LEFT")
	local voiceLine = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	voiceLine:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -3)
	voiceLine:SetTextColor(NOTE[1], NOTE[2], NOTE[3])
	OnRefresh(function()
		local w, v = Describe()
		who:SetText("Speaking as " .. w)
		voiceLine:SetText("Voice: " .. v .. "   |cff9a9488Rewrite: type in chat, then Ctrl+Shift+R|r")
	end)
	local enabled = Check(content, "Enabled", function() return DB().enabled end, function(v) DB().enabled = v end)
	enabled:SetPoint("TOPRIGHT", -enabled.label:GetStringWidth() - 6, -2)
	Tooltip(enabled, "Enabled", "When off, the helper's hotkey leaves your chat line alone.")
	local rule = Line(content, 0.45)
	rule:SetPoint("TOPLEFT", 0, -40); rule:SetPoint("TOPRIGHT", 0, -40); rule:SetHeight(1)

	local top = -50

	-- Character -------------------------------------------------------------
	local char = Card(content, "Character", 0, top, COL, 186)
	local nameRow = Row(char, "Name")
	local nameBox = Input(nameRow, {
		max = 40,
		hint = function() return UnitName("player") .. " (your character)" end,
		get = function() return DB().name end,
		set = function(v) DB().name = v end,
	})
	nameBox:SetPoint("TOPLEFT", LABEL_W + 6, -2); nameBox:SetPoint("RIGHT"); nameBox:SetHeight(22)
	Tooltip(nameBox, "Name", "The name the storyteller is told. Leave empty to use your character's name.")

	local raceValues = { "auto" }
	for _, r in ipairs(RPV.RACE_LIST) do raceValues[#raceValues + 1] = r end
	local raceRow = Row(char, "Race")
	Stepper(raceRow, raceValues, function(v)
		if v == "auto" then
			local loc, file = UnitRace("player")
			return "Own race (" .. RPV.RaceName(file, loc) .. ")"
		end
		return v
	end, function() return DB().race or "auto" end, function(v) DB().race = (v ~= "auto") and v or nil end)
	Tooltip(raceRow, "Race", "Normally your character's own race. Pick another to speak like one (a raised-by-dwarves human, say).")

	local personaRow = Row(char, "Persona", 82)
	personaRow.label:SetPoint("TOPLEFT", 0, -6)
	local persona = Input(personaRow, {
		multi = true, max = 200, counter = true,
		hint = function() return "Who is this character? e.g. gruff old veteran who distrusts mages" end,
		get = function() return DB().persona end,
		set = function(v) DB().persona = v end,
	})
	persona:SetPoint("TOPLEFT", LABEL_W + 6, -2); persona:SetPoint("RIGHT"); persona:SetHeight(80)

	-- Voice -----------------------------------------------------------------
	local voice = Card(content, "Voice", 0, top - 196, COL, 166)
	Segmented(Row(voice, "Rewrite"), RPV.STYLE_LIST, function() return DB().style end, function(v) DB().style = v end, {
		light = "Your own words, with a touch of accent.",
		medium = "Rephrased the way your character talks.",
		strong = "Full roleplay flourish.",
	})
	Stepper(Row(voice, "Tone"), RPV.TONES, Capitalize, function() return DB().tone end, function(v) DB().tone = v end)
	Segmented(Row(voice, "Native words"), { "none", "few", "many" }, function() return DB().native end, function(v) DB().native = v end, {
		none = "No Orcish, Thalassian, Darnassian... only English phrasing.",
		few = "A word here and there that others still understand.",
		many = "More of the race's own language.",
	})
	Segmented(Row(voice, "Length"), { "shorter", "same", "longer" }, function() return DB().length end, function(v) DB().length = v end)

	-- Personal touches ------------------------------------------------------
	local x2 = COL + 10
	local touches = Card(content, "Personal touches", x2, top, COL, 186)
	local function Stacked(card, label, note, key, hint)
		local row = Row(card, nil, 62)
		local l = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		l:SetPoint("TOPLEFT", 0, -2)
		l:SetText(label)
		local box = Input(row, {
			max = 150,
			hint = function() return hint end,
			get = function() return DB()[key] end,
			set = function(v) DB()[key] = v end,
		})
		box:SetPoint("TOPLEFT", 0, -20); box:SetPoint("RIGHT"); box:SetHeight(22)
		local n = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		n:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 1, -4)
		n:SetTextColor(NOTE[1], NOTE[2], NOTE[3])
		n:SetText(note)
	end
	Stacked(touches, "Favourite expressions", "Used now and then, not every line. Separate with commas.", "phrases", "By my beard!, Light preserve us")
	Stacked(touches, "Never say", "Words or expressions to keep out.", "avoid", "mon, lass")

	-- Channels --------------------------------------------------------------
	local chans = Card(content, "Rewrite in", x2, top - 196, COL, 166)
	local note = chans:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	note:SetPoint("TOPRIGHT", -PAD, -12)
	note:SetTextColor(DIM[1], DIM[2], DIM[3])
	note:SetText("Off: the hotkey skips that chat")
	local colW = math.floor((COL - 2 * PAD) / 2)
	for i, ch in ipairs(RPV.CHANNELS) do
		local cb = Check(chans, ch.label,
			function() return DB().channels[ch.key] ~= false end,
			function(v) DB().channels[ch.key] = v end)
		local col = (i - 1) % 2
		local line = math.floor((i - 1) / 2)
		cb:SetPoint("TOPLEFT", PAD - 4 + col * colW, -32 - line * 28)
	end

	-- Footer ----------------------------------------------------------------
	local preview = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	preview:SetPoint("BOTTOMLEFT", 30, 24)
	preview:SetPoint("RIGHT", frame, "RIGHT", -230, 0)
	preview:SetJustifyH("LEFT")
	preview:SetTextColor(DIM[1], DIM[2], DIM[3])
	preview:SetText("Settings are saved per character. The helper (RPVoice.ahk) and BridgeControl must be running.")
	preview:SetWordWrap(true)

	local close = Button(frame, CLOSE or "Close", 90, function() frame:Hide() end)
	close:SetPoint("BOTTOMRIGHT", -30, 20)
	local tagBtn = Button(frame, "Show tag", 90, function()
		Core.Print("the helper will see: " .. RPV.BuildTag(Core.SpeakerInfo(nil)))
	end)
	tagBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
	Tooltip(tagBtn, "Show tag", "Prints, in chat, exactly what the helper sends along with your line.")

	frame:SetScript("OnShow", function()
		local uiW, uiH = UIParent:GetSize()
		local scale = math.min(1, (uiW - 40) / (W + 60), (uiH - 40) / H)
		frame:SetScale(math.max(0.4, scale))
		Refresh()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
	end)
	frame:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
	end)
end

function RPVoiceOptions_Toggle()
	if not frame then Build() end
	frame:SetShown(not frame:IsShown())
end

-- Entry in the game's AddOns settings list: a short page with a button to the window.
local function RegisterInSettings()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 16, -16)
	heading:SetText("RP Voice")
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
	text:SetText("Your character's roleplay voice for chat. Settings are in their own window (/rpv).")
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(180, 26)
	open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
	open:SetText("Open RP Voice settings")
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		if not frame then Build() end
		frame:Show()
	end)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "RP Voice")
	Settings.RegisterAddOnCategory(category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	pcall(RegisterInSettings)
end)
