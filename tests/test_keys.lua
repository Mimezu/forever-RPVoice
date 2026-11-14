-- Run from the addon folder: lua5.1 tests\test_keys.lua
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, tostring(got), tostring(want)))
	end
end

-- Minimal binding stubs
local binds, saved, combat = {}, 0, false
local mods = {}
function IsAltKeyDown() return mods.alt end
function IsControlKeyDown() return mods.ctrl end
function IsShiftKeyDown() return mods.shift end
function InCombatLockdown() return combat end
function GetBindingText(k) return k end
function GetBindingAction(k) return binds[k] or "" end
function GetBindingKey(action)
	local out = {}
	for k, a in pairs(binds) do if a == action then out[#out + 1] = k end end
	table.sort(out)
	return unpack(out)
end
function SetBinding(k, a) binds[k] = a end
function SaveBindings() saved = saved + 1 end
function GetCurrentBindingSet() return 1 end

local K = dofile("Keys.lua")

check("binding name", BINDING_NAME_RPVOICE_TOGGLE, "Open window")
check("action listed", K.ACTIONS[1].action, "RPVOICE_TOGGLE")

mods = { ctrl = true, shift = true }
check("combo", K.Combo("P"), "CTRL-SHIFT-P")
mods = {}
check("combo plain", K.Combo("F5"), "F5")
check("button", K.Button("MiddleButton"), "BUTTON3")
check("button4", K.Button("Button4"), "BUTTON4")

check("refuse enter", K.Refused("ENTER"), true)
check("refuse helper", K.Refused("CTRL-SHIFT-F12"), true)
check("refuse shift-enter", K.Refused("SHIFT-ENTER"), true)
check("allow", K.Refused("CTRL-R"), false)

check("unbound", K.Bound("RPVOICE_TOGGLE"), nil)
local ok, msg = K.Bind("RPVOICE_TOGGLE", "CTRL-R")
check("bind ok", ok, true)
check("bind msg", msg, "")
check("bound", K.Bound("RPVOICE_TOGGLE"), "CTRL-R")
check("saved", saved, 1)

BINDING_NAME_TOGGLEBAG = "Open bag"
binds["B"] = "TOGGLEBAG"
ok, msg = K.Bind("RPVOICE_TOGGLE", "B")
check("replace msg", msg, "Was Open bag")
check("old key freed", binds["CTRL-R"], nil)
check("moved", binds["B"], "RPVOICE_TOGGLE")

check("refused bind", select(2, K.Bind("RPVOICE_TOGGLE", "CTRL-SHIFT-F11")), "Kept for chat")
check("kept after refuse", binds["B"], "RPVOICE_TOGGLE")

combat = true
check("combat", select(2, K.Bind("RPVOICE_TOGGLE", "N")), "Not in combat")
combat = false

K.Clear("RPVOICE_TOGGLE")
check("cleared", K.Bound("RPVOICE_TOGGLE"), nil)

-- Minimap maths and saved settings
local M = dofile("Minimap.lua")
local db = M.DB()
check("shown by default", M.IsShown(), true)
check("default angle", db.angle, 200)
RPVoiceDB.minimap.hide = nil
check("hide normalised", M.DB().hide, false)
local x, y = M.Offset(0, 80)
check("offset x", math.floor(x + 0.5), 80)
check("offset y", math.floor(y + 0.5), 0)
check("angle up", math.floor(M.AngleOf(0, 10) + 0.5), 90)
check("angle down", math.floor(M.AngleOf(0, -10) + 0.5), 270)
M.SetShown(false)
check("hidden", RPVoiceDB.minimap.hide, true)
M.SetShown(true)
check("shown", M.IsShown(), true)

if failures == 0 then print("OK keys") else print(failures .. " failed"); os.exit(1) end
