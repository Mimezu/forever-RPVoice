# RP Voice

Rewrites the chat line you are typing in your character's roleplay voice, using ChatGPT through BridgeControl.

## Install

1. Put the `RPVoice` folder in `_forever_\Interface\AddOns\`.
2. Install AutoHotkey v2.
3. Run BridgeControl.

## Use

1. Double-click `helper\RPVoice.ahk`.
2. In WoW, type a line in chat.
3. Press Ctrl+Shift+R.
4. Check the new line, then press Enter.

- Nothing is ever sent for you.
- `{a joke about gnomes}` or `insert joke here` lets the character write that part.
- Language: English translates any line first (/rpv, Voice).
- Leave Ctrl+Shift+F11 and Ctrl+Shift+F12 unbound in WoW.

| Command | |
|---|---|
| `/rpv` | Settings |
| `/rpv on`, `/rpv off` | On or off |
| `/rpv test` | Show the tag |
| `/rpv help` | Status |

## Data

Settings are saved per character, in `WTF\Account\<account>\<realm>\<character>\SavedVariables\RPVoice.lua`.

## Test

```
lua5.1 tests\test_tag.lua
AutoHotkey64.exe helper\RPVoice.ahk --test "[[RPV race=Dwarf; faction=Alliance; sex=male; chat=SAY]] good morning"
```

## More

[How it works](docs/how-it-works.md)
