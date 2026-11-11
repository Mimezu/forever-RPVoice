# RP Voice

Rewrites the line you are typing in WoW Forever chat into your character's roleplay voice, from your race, faction and sex, using ChatGPT through BridgeControl.

Example (male Orc of the Horde): `hey, want to group for the mine?` becomes `Lok'tar! You want to group for the mine, eh?`

## How it works

WoW addons cannot reach the network, so there are two parts:

- **The addon** (`RPVoice`) knows who you are playing. When the helper asks, it puts a short tag in front of your chat line, for example `[[RPV race=Orc; faction=Horde; sex=male; chat=SAY]]`, and puts your line back right after it has been copied.
- **The helper** (`helper\RPVoice.ahk`, AutoHotkey v2) runs on Windows. It sends the tagged line to BridgeControl (`http://127.0.0.1:18080`) and pastes the answer back into the chat box.

You always press Enter yourself. Nothing is sent for you.

## Use

1. Make sure BridgeControl is running.
2. Start `helper\RPVoice.ahk` (double-click). A tray icon appears.
3. In WoW, open a chat box, type your line, press **Ctrl+Shift+R**.
4. After a moment the rewritten line replaces yours. Edit it or press Enter.

The helper only reacts while WoW is the active window. It uses Ctrl+Shift+F12 and Ctrl+Shift+F11 to talk to the addon, so leave those keys unbound in WoW.

## In-game settings (per character)

- `/rpv`: status and commands
- `/rpv on` / `/rpv off`
- `/rpv name <name>`: the name the AI is told (default: your character's name), `clear` to reset
- `/rpv persona <text>`: e.g. `gruff old veteran who distrusts mages`
- `/rpv style light | medium | strong`: how far the rewrite goes
- `/rpv test`: shows the tag the helper will see

`/emote` lines are rewritten as actions, `/yell` as shouts, party and guild lines are kept practical.

## Helper settings

At the top of `helper\RPVoice.ahk`: the hotkey, the model (`gpt-5.6-luna` by default), the BridgeControl address and the timeout.

Test without the game:

```
AutoHotkey64.exe helper\RPVoice.ahk --test "[[RPV race=Dwarf; faction=Alliance; sex=female; chat=SAY]] good morning"
```

## Tests

```
lua5.1 tests\test_tag.lua
```
