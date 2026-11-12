# How RP Voice works

WoW addons cannot reach the network, so RP Voice has two parts.

- **The addon** knows who you are playing. When the helper asks, it puts a short tag in front of your chat line, for example `[[RPV race=Orc; faction=Horde; sex=male; chat=SAY]]`. It puts your line back as soon as the tag has been copied.
- **The helper** (`helper\RPVoice.ahk`, AutoHotkey v2) runs on Windows. It sends the tagged line to BridgeControl (`http://127.0.0.1:18080`) and pastes the answer back into the chat box.

## The hotkey, step by step

1. The helper presses Ctrl+Shift+F12. The addon adds the tag and selects the line.
2. The helper presses Ctrl+C.
3. The helper presses Ctrl+Shift+F11. The addon restores the line, selected.
4. The helper asks BridgeControl, then presses Ctrl+Shift+F11 again and pastes the answer.

You always press Enter yourself.

## Rewrite rules

- Each line gets a word budget based on what you typed and the style. If an answer runs long, the helper asks once more and keeps the shorter one.
- No added sentences, battle cries or poetry.
- Your jokes stay jokes. `insert joke here` or `{a joke about X}` lets the character write that part.
- `/emote` lines become actions and `/yell` lines become shouts. Party and guild lines stay practical.

## Helper settings

The top of `helper\RPVoice.ahk` sets the hotkey, the model (`gpt-5.6-luna`), the BridgeControl address and the timeout.
