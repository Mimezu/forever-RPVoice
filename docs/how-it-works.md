# How RP Voice works

WoW addons cannot reach the network, so RP Voice has two parts.

- **The addon** knows who you are playing. When the helper asks, it puts a short tag in front of your chat line, for example `[[RPV race=Orc; faction=Horde; sex=male; chat=SAY]]`. It puts your line back as soon as the tag has been copied.
- **The helper** (`helper\RPVoice.ahk`, AutoHotkey v2) runs on Windows. It sends the tagged line to BridgeControl (`http://127.0.0.1:18080`) and pastes the answer back into the chat box. Its hotkeys only work while WoW Forever (`_forever_\Wow.exe`) is the active window.

## Shift+Enter, step by step

1. The helper presses Ctrl+Shift+F12. The addon adds the tag and selects the line.
2. The helper presses Ctrl+C.
3. The helper presses Ctrl+Shift+F11. The addon restores the line, selected.
4. The helper asks BridgeControl, then presses Ctrl+Shift+F11 again and pastes the answer.

You always press Enter yourself.

## Hold Ctrl+Enter to talk

1. The helper records the microphone while you hold the keys.
2. On release, BridgeControl transcribes it (`/v1/audio/transcriptions`, about half a second).
3. The helper presses Ctrl+Shift+F10: the addon opens the chat box, or selects its text.
4. The transcript is pasted in, then rewritten as with Shift+Enter.

## Rewrite rules

- Each line gets a word budget based on what you typed and the style. If an answer runs long, the helper asks once more and keeps the shorter one.
- No added sentences, battle cries or poetry.
- Your jokes stay jokes. `insert joke here` or `{a joke about X}` lets the character write that part.
- Language English: the line is translated into English, then rewritten.
- `/emote` lines become actions and `/yell` lines become shouts. Party and guild lines stay practical.

## Helper settings

The top of `helper\RPVoice.ahk` sets the hotkeys, the model (`gpt-6-luna`), fast mode, reasoning effort (`medium`), the BridgeControl addresses and the timeout.
