-- RPVoice tag building. Pure Lua (no WoW API) so tests can load it with lua5.1.
--
-- The helper (helper\RPVoice.ahk) copies the chat line with this tag in front,
-- so it knows who is speaking. Format, all on one line:
--   [[RPV race=Orc; faction=Horde; sex=male; chat=SAY; name=Grom; persona=...; style=medium]] text
-- Values never contain ; [ ] = | or line breaks.

local RPV = {}

RPV.TAG_OPEN = "[[RPV "
RPV.TAG_CLOSE = "]] "

-- WoW race file tokens -> the name a roleplayer would use.
RPV.RACE_NAMES = {
	Human = "Human",
	Dwarf = "Dwarf",
	NightElf = "Night Elf",
	Gnome = "Gnome",
	Orc = "Orc",
	Scourge = "Forsaken",
	Undead = "Forsaken",
	Tauren = "Tauren",
	Troll = "Troll",
	BloodElf = "Blood Elf",
	Draenei = "Draenei",
	Goblin = "Goblin",
	Worgen = "Worgen",
	Pandaren = "Pandaren",
}

RPV.SEX_NAMES = { [2] = "male", [3] = "female" }

RPV.STYLES = { light = true, medium = true, strong = true }

-- Choices offered in the settings window. First entry is the default.
RPV.STYLE_LIST = { "light", "medium", "strong" }
RPV.TONES = { "natural", "friendly", "gruff", "noble", "sly", "scholarly", "cheerful", "grim", "pious", "wild" }
RPV.NATIVE = { "few", "none", "many" }       -- how many words in the race's own language
RPV.LENGTHS = { "same", "shorter", "longer" }
RPV.RACE_LIST = { "Human", "Dwarf", "Night Elf", "Gnome", "Orc", "Forsaken", "Tauren", "Troll" }

-- Chat types the player can switch on or off, in display order.
RPV.CHANNELS = {
	{ key = "SAY", label = "Say" },
	{ key = "YELL", label = "Yell" },
	{ key = "EMOTE", label = "Emote" },
	{ key = "PARTY", label = "Party" },
	{ key = "RAID", label = "Raid" },
	{ key = "GUILD", label = "Guild" },
	{ key = "WHISPER", label = "Whisper" },
	{ key = "CHANNEL", label = "Channels" },
}

-- Which channel switch a chat type falls under.
function RPV.ChannelKey(chatType)
	chatType = chatType or "SAY"
	if chatType == "RAID_WARNING" or chatType == "INSTANCE_CHAT" then return "RAID" end
	if chatType == "OFFICER" then return "GUILD" end
	if chatType == "BN_WHISPER" then return "WHISPER" end
	return chatType
end

function RPV.Clean(value, maxLen)
	if value == nil then return "" end
	value = tostring(value)
	value = value:gsub("[%c;%[%]=|]", " ")
	value = value:gsub("%s+", " ")
	value = value:gsub("^ ", ""):gsub(" $", "")
	if maxLen and #value > maxLen then
		value = value:sub(1, maxLen):gsub(" [^ ]*$", "")
	end
	return value
end

function RPV.RaceName(raceFile, raceLocalized)
	return RPV.RACE_NAMES[raceFile or ""] or RPV.Clean(raceLocalized or raceFile or "Adventurer")
end

-- info: { race, faction, sex, chat, name, persona, style, tone, native, length, phrases, avoid }
-- short = true leaves out name and persona (used when the box will not take a long line).
function RPV.BuildTag(info, short)
	local parts = {
		"race=" .. RPV.Clean(info.race, 30),
		"faction=" .. RPV.Clean(info.faction, 20),
		"sex=" .. RPV.Clean(info.sex, 10),
		"chat=" .. RPV.Clean(info.chat, 20),
	}
	if not short then
		if info.name and info.name ~= "" then
			parts[#parts + 1] = "name=" .. RPV.Clean(info.name, 40)
		end
		if info.persona and info.persona ~= "" then
			parts[#parts + 1] = "persona=" .. RPV.Clean(info.persona, 200)
		end
		local optional = {
			{ "style", 10 }, { "tone", 20 }, { "native", 10 }, { "length", 10 },
			{ "phrases", 150 }, { "avoid", 150 },
		}
		for _, field in ipairs(optional) do
			local key, maxLen = field[1], field[2]
			local value = RPV.Clean(info[key], maxLen)
			if value ~= "" then
				parts[#parts + 1] = key .. "=" .. value
			end
		end
	end
	return RPV.TAG_OPEN .. table.concat(parts, "; ") .. RPV.TAG_CLOSE
end

-- Lines the helper should not touch: empty, or a slash command not yet parsed.
function RPV.CanTag(text)
	if type(text) ~= "string" then return false end
	if not text:find("%S") then return false end
	if text:find("^%s*/") then return false end
	if RPV.HasTag(text) then return false end
	return true
end

function RPV.HasTag(text)
	return type(text) == "string" and text:sub(1, #RPV.TAG_OPEN) == RPV.TAG_OPEN
end

-- Removes a tag left at the front of a line (safety net before sending).
function RPV.StripTag(text)
	if not RPV.HasTag(text) then return text end
	local closeAt = text:find(RPV.TAG_CLOSE, 1, true)
	if not closeAt then return text end
	return text:sub(closeAt + #RPV.TAG_CLOSE)
end

RPVoiceTag = RPV
return RPV
