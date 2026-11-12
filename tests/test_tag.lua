-- Run from the addon folder: lua5.1 tests\test_tag.lua
package.path = "./?.lua;" .. package.path
local RPV = dofile("Tag.lua")

local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
	end
end

local info = { race = "Orc", faction = "Horde", sex = "male", chat = "SAY", name = "Grom", persona = "old; [veteran]=gruff|x", style = "medium" }

check("full tag", RPV.BuildTag(info),
	"[[RPV race=Orc; faction=Horde; sex=male; chat=SAY; name=Grom; persona=old veteran gruff x; style=medium]] ")
check("short tag", RPV.BuildTag(info, true), "[[RPV race=Orc; faction=Horde; sex=male; chat=SAY]] ")
check("no persona", RPV.BuildTag({ race = "Dwarf", faction = "Alliance", sex = "female", chat = "PARTY" }),
	"[[RPV race=Dwarf; faction=Alliance; sex=female; chat=PARTY]] ")

check("voice fields", RPV.BuildTag({ race = "Dwarf", faction = "Alliance", sex = "male", chat = "SAY",
	style = "strong", tone = "cheerful", native = "none", length = "shorter", lang = "english", phrases = "By my beard!, Stone", avoid = "lass" }),
	"[[RPV race=Dwarf; faction=Alliance; sex=male; chat=SAY; style=strong; tone=cheerful; native=none; length=shorter; lang=english; phrases=By my beard!, Stone; avoid=lass]] ")
check("channel officer", RPV.ChannelKey("OFFICER"), "GUILD")
check("channel instance", RPV.ChannelKey("INSTANCE_CHAT"), "RAID")
check("channel say", RPV.ChannelKey("SAY"), "SAY")

check("race token", RPV.RaceName("Scourge", "Undead"), "Forsaken")
check("race night elf", RPV.RaceName("NightElf", "Elfe de la nuit"), "Night Elf")
check("race unknown", RPV.RaceName("Vulpera", "Vulpéra"), "Vulpéra")

check("can tag", RPV.CanTag("hello there"), true)
check("empty", RPV.CanTag("   "), false)
check("slash", RPV.CanTag("/dance"), false)
check("already tagged", RPV.CanTag(RPV.BuildTag(info) .. "hi"), false)

local line = "hello, friend"
check("strip", RPV.StripTag(RPV.BuildTag(info) .. line), line)
check("strip untagged", RPV.StripTag(line), line)

check("clean length", RPV.Clean("one two three four", 9), "one two")

if failures > 0 then
	print(failures .. " failed")
	os.exit(1)
end
print("all tag tests passed")
