-- Key bindings set from RP Voice's own windows (Bindings.xml holds the actions).
-- Logic only; the keycap is built in Options.lua. Saved with the game's key bindings.

local K = {}
RPVoiceKeys = K

BINDING_HEADER_RPVOICE = "RP Voice"
BINDING_CATEGORY_RPVOICE = "RP Voice"
BINDING_NAME_RPVOICE_TOGGLE = "Open window"

-- Bindings offered, in the order shown.
K.ACTIONS = {
	{ action = "RPVOICE_TOGGLE", label = "Open window" },
}

K.MODIFIERS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
	LALT = true, RALT = true, LMETA = true, RMETA = true,
}

-- Never bound: the chat's keys, plain clicks, and the helper's own keys.
local NEVER = {
	ENTER = true, BACKSPACE = true, BUTTON1 = true, BUTTON2 = true,
	["SHIFT-ENTER"] = true, ["CTRL-ENTER"] = true,
	["CTRL-SHIFT-F10"] = true, ["CTRL-SHIFT-F11"] = true, ["CTRL-SHIFT-F12"] = true,
}

function K.Refused(combo)
	return NEVER[combo] == true
end

-- The key pressed with its held modifiers, as the bindings write it.
function K.Combo(key)
	local mods = ""
	if IsAltKeyDown() then mods = mods .. "ALT-" end
	if IsControlKeyDown() then mods = mods .. "CTRL-" end
	if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
	if IsMetaKeyDown and IsMetaKeyDown() then mods = mods .. "META-" end
	return mods .. key
end

local BUTTONS = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3" }
function K.Button(button)
	return BUTTONS[button] or button:upper()
end

local function Shown(key)
	return GetBindingText and GetBindingText(key) or key
end

-- The key bound to action, as shown, or nil.
function K.Bound(action)
	local key = GetBindingKey and GetBindingKey(action)
	return key and Shown(key) or nil
end

-- Binds key to action, in place of the action's old keys and of what had key.
-- Returns ok, message (what the key did before, or why it was refused).
function K.Bind(action, key)
	if InCombatLockdown() then return false, "Not in combat" end
	if K.Refused(key) then return false, "Kept for chat" end
	local before = GetBindingAction(key)
	for _, old in ipairs({ GetBindingKey(action) }) do SetBinding(old) end
	SetBinding(key, action)
	SaveBindings(GetCurrentBindingSet())
	if before and before ~= "" and before ~= action then
		return true, "Was " .. (_G["BINDING_NAME_" .. before] or before)
	end
	return true, ""
end

function K.Clear(action)
	if InCombatLockdown() then return false, "Not in combat" end
	for _, old in ipairs({ GetBindingKey(action) }) do SetBinding(old) end
	SaveBindings(GetCurrentBindingSet())
	return true, ""
end

return K
