# RP Voice

Rewrites your chat line, typed or spoken, in your character's roleplay voice, using BridgeControl.

## Install

1. Put the `RPVoice` folder in `_forever_\Interface\AddOns\`.
2. Install AutoHotkey v2.
3. Run BridgeControl.

## Use

1. Double-click `helper\RPVoice.ahk` (or let it start with Windows).
2. In WoW Forever, type a line in chat and press Shift+Enter.
3. Or hold Ctrl+Enter, talk, release.
4. Check the new line, then press Enter.

- Nothing is ever sent for you.
- `{a joke about gnomes}` or `insert joke here` lets the character write that part.
- Language: English translates any line first (/rpv, Voice).
- Leave Ctrl+Shift+F10, F11 and F12 unbound in WoW.
- Window key and minimap icon: /rpv, Keys.

| Command | |
|---|---|
| `/rpv` | Settings |
| `/rpv on`, `/rpv off` | On or off |
| `/rpv test` | Show the tag |
| `/rpv help` | Status |

## Data

Settings are saved per character, in `WTF\Account\<account>\<realm>\<character>\SavedVariables\RPVoice.lua`; the minimap icon account-wide.

## Test

```
lua5.1 tests\test_tag.lua
AutoHotkey64.exe helper\RPVoice.ahk --test "[[RPV race=Dwarf; faction=Alliance; sex=male; chat=SAY]] good morning"
```

## More

[How it works](docs/how-it-works.md)
