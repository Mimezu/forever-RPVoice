-- RP Voice: hands your chat line to the RPVoice helper with a tag saying who speaks.
--
-- Addons cannot reach BridgeControl (no network in the game). The helper on Windows
-- does that part. Its hotkey works like this, while you are typing in a chat box:
--   1. helper presses Ctrl+Shift+F12  -> this addon puts the tag in front and selects the line
--   2. helper presses Ctrl+C          -> copies tag + line
--   3. helper presses Ctrl+Shift+F11  -> this addon puts your line back as it was, selected
--   4. helper asks BridgeControl, then re-presses Ctrl+Shift+F11 and pastes the answer
-- You still press Enter yourself.

local RPV = RPVoiceTag

local TAG_KEY = "F12"
local UNTAG_KEY = "F11"
local TAG_TIMEOUT = 2 -- seconds; a tag still there after this is removed

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffd8a35aRP Voice:|r " .. msg)
end

local function Warn(msg)
	if UIErrorsFrame then
		UIErrorsFrame:AddMessage(msg, 1, 0.3, 0.3)
	else
		Print(msg)
	end
end

local function OneOf(list, value)
	for _, v in ipairs(list) do
		if v == value then return value end
	end
	return list[1]
end

local function CharDB()
	RPVoiceCharDB = RPVoiceCharDB or {}
	local db = RPVoiceCharDB
	if db.enabled == nil then db.enabled = true end
	db.style = RPV.STYLES[db.style or ""] and db.style or "medium"
	db.tone = OneOf(RPV.TONES, db.tone)
	db.native = OneOf(RPV.NATIVE, db.native)
	db.length = OneOf(RPV.LENGTHS, db.length)
	-- db.race: nil = the character's real race, otherwise a name from RPV.RACE_LIST
	if db.race and OneOf(RPV.RACE_LIST, db.race) ~= db.race then db.race = nil end
	db.channels = db.channels or {}
	for _, ch in ipairs(RPV.CHANNELS) do
		if db.channels[ch.key] == nil then db.channels[ch.key] = true end
	end
	return db
end

local function SpeakerInfo(editBox)
	local db = CharDB()
	local raceLocalized, raceFile = UnitRace("player")
	local faction = UnitFactionGroup("player")
	local chat = editBox and editBox:GetAttribute("chatType") or "SAY"
	return {
		race = db.race or RPV.RaceName(raceFile, raceLocalized),
		faction = faction or "Neutral",
		sex = RPV.SEX_NAMES[UnitSex("player")] or "unknown",
		chat = chat,
		name = (db.name and db.name ~= "") and db.name or UnitName("player"),
		persona = db.persona,
		style = db.style,
		tone = db.tone,
		native = db.native,
		length = db.length,
		phrases = db.phrases,
		avoid = db.avoid,
	}
end

-- The chat box only shows 255 bytes. Lift that while the tag is in, put it back after.
local LIMITS = {
	{ "GetVisibleTextByteLimit", "SetVisibleTextByteLimit" },
	{ "GetMaxBytes", "SetMaxBytes" },
	{ "GetMaxLetters", "SetMaxLetters" },
}

local function LiftLimits(editBox)
	local saved = {}
	for _, pair in ipairs(LIMITS) do
		local get, set = editBox[pair[1]], editBox[pair[2]]
		if get and set then
			local ok, value = pcall(get, editBox)
			if ok and value and value > 0 then
				saved[pair[2]] = value
				pcall(set, editBox, 0)
			end
		end
	end
	return saved
end

local function RestoreLimits(editBox, saved)
	for setter, value in pairs(saved or {}) do
		pcall(editBox[setter], editBox, value)
	end
end

local function Untag(editBox)
	if editBox.rpvOriginal then
		local original = editBox.rpvOriginal
		editBox.rpvOriginal = nil
		editBox:SetText(original)
		RestoreLimits(editBox, editBox.rpvLimits)
		editBox.rpvLimits = nil
	elseif RPV.HasTag(editBox:GetText()) then
		editBox:SetText(RPV.StripTag(editBox:GetText()))
	end
	editBox:HighlightText()
end

local function Tag(editBox)
	local db = CharDB()
	if not db.enabled then
		Warn("RP Voice is off (/rpv on).")
		return
	end
	if editBox.rpvOriginal then
		Untag(editBox)
	end
	local original = editBox:GetText()
	if not RPV.CanTag(original) then
		Warn("RP Voice: type a line first (slash commands are skipped).")
		return
	end

	local info = SpeakerInfo(editBox)
	local channel = RPV.ChannelKey(info.chat)
	if db.channels[channel] == false then
		Warn("RP Voice is off for this chat (" .. channel:lower() .. "). Change it in /rpv.")
		return
	end
	editBox.rpvLimits = LiftLimits(editBox)
	editBox.rpvOriginal = original

	local tagged = RPV.BuildTag(info) .. original
	editBox:SetText(tagged)
	if editBox:GetText() ~= tagged then
		tagged = RPV.BuildTag(info, true) .. original
		editBox:SetText(tagged)
	end
	if editBox:GetText() ~= tagged then
		Untag(editBox)
		Warn("RP Voice: this line is too long to rewrite.")
		return
	end
	editBox:HighlightText()

	C_Timer.After(TAG_TIMEOUT, function()
		if editBox.rpvOriginal and RPV.HasTag(editBox:GetText()) then
			Untag(editBox)
		end
	end)
end

local function OnKeyDown(editBox, key)
	if not (IsControlKeyDown() and IsShiftKeyDown()) then return end
	if key == TAG_KEY then
		Tag(editBox)
	elseif key == UNTAG_KEY then
		Untag(editBox)
	end
end

local hooked = {}

local function HookEditBox(editBox)
	if editBox and not hooked[editBox] then
		hooked[editBox] = true
		editBox:HookScript("OnKeyDown", OnKeyDown)
	end
end

local function HookAll()
	local frames = CHAT_FRAMES
	if frames then
		for _, frameName in ipairs(frames) do
			HookEditBox(_G[frameName .. "EditBox"])
		end
	end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		HookEditBox(_G["ChatFrame" .. i .. "EditBox"])
	end
end

local function ShowStatus()
	local db = CharDB()
	local info = SpeakerInfo(nil)
	Print(string.format("%s. Speaking as %s, %s %s of the %s. Style: %s.",
		db.enabled and "|cff80ff80on|r" or "|cffff8080off|r",
		info.name, info.sex, info.race, info.faction, db.style))
	Print("Persona: " .. ((db.persona and db.persona ~= "") and db.persona or "(none)"))
	Print("/rpv opens the settings window. Also: /rpv on | off | name <name or clear> | persona <text or clear> | style light/medium/strong | test")
end

SLASH_RPVOICE1 = "/rpv"
SLASH_RPVOICE2 = "/rpvoice"
SlashCmdList.RPVOICE = function(msg)
	local db = CharDB()
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "on" or cmd == "off" then
		db.enabled = (cmd == "on")
		Print(db.enabled and "on." or "off.")
	elseif cmd == "name" then
		db.name = (rest:lower() ~= "clear") and RPV.Clean(rest, 40) or nil
		Print("name: " .. (db.name or UnitName("player")))
	elseif cmd == "persona" then
		db.persona = (rest:lower() ~= "clear" and rest ~= "") and RPV.Clean(rest, 200) or nil
		Print("persona: " .. (db.persona or "(none)"))
	elseif cmd == "style" then
		local style = rest:lower()
		if RPV.STYLES[style] then
			db.style = style
			Print("style: " .. style)
		else
			Print("style must be light, medium or strong.")
		end
	elseif cmd == "test" then
		Print("tag the helper will see: " .. RPV.BuildTag(SpeakerInfo(nil)))
	elseif cmd == "help" or cmd == "status" then
		ShowStatus()
	elseif RPVoiceOptions_Toggle then
		RPVoiceOptions_Toggle()
	else
		ShowStatus()
	end
end

-- Shared with Options.lua
RPVoiceCore = {
	CharDB = CharDB,
	SpeakerInfo = SpeakerInfo,
	Print = Print,
}

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	CharDB()
	HookAll()
	if FCF_OpenTemporaryWindow then
		hooksecurefunc("FCF_OpenTemporaryWindow", HookAll)
	end
end)
