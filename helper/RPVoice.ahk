; RP Voice helper (AutoHotkey v2)
; Rewrites the line you are typing in WoW chat into your character's roleplay voice,
; using BridgeControl's local ChatGPT server. Needs the RPVoice addon in the game.
;
; Use: type a line in a chat box, press Ctrl+Shift+R, wait a moment, read it, press Enter.
; Nothing is ever sent for you.
;
; Test without the game:  AutoHotkey64.exe RPVoice.ahk --test "[[RPV race=Orc; faction=Horde; sex=male; chat=SAY]] hi all"

#Requires AutoHotkey v2.0
#SingleInstance Force

; ---- settings ---------------------------------------------------------------
global API_URL     := "http://127.0.0.1:18080/v1/chat/completions"
global MODEL       := "gpt-5.6-luna"
global TIMEOUT_SEC := 30
global HOTKEY_KEYS := "^+r"            ; Ctrl+Shift+R
global WOW_WINDOW  := "ahk_exe Wow.exe"
global MAX_BYTES   := 255              ; WoW chat line limit
; ----------------------------------------------------------------------------

global TAG_OPEN := "[[RPV "
global TAG_CLOSE := "]] "

if (A_Args.Length >= 2 && A_Args[1] = "--test") {
    try {
        FileAppend(RewriteTagged(A_Args[2]) "`n", "*", "UTF-8")
        ExitApp(0)
    } catch as e {
        FileAppend("ERROR: " e.Message "`n", "**", "UTF-8")
        ExitApp(1)
    }
}

A_IconTip := "RP Voice · Ctrl+Shift+R"
HotIfWinActive(WOW_WINDOW)
Hotkey(HOTKEY_KEYS, RewriteChatLine)
HotIfWinActive()
TrayTip("Ctrl+Shift+R in chat", "RP Voice ready", "Mute")
return

; ---- the hotkey ---------------------------------------------------------------

RewriteChatLine(*) {
    static busy := false
    if busy
        return
    busy := true
    saved := ClipboardAll()
    try {
        KeyWait("r")
        KeyWait("Ctrl")
        KeyWait("Shift")

        ; 1-3: addon tags + selects, we copy, addon restores the line (selected)
        A_Clipboard := ""
        Send("^+{F12}")
        Sleep(80)
        Send("^c")
        got := ClipWait(1)
        Send("^+{F11}")
        tagged := got ? A_Clipboard : ""
        if (SubStr(tagged, 1, StrLen(TAG_OPEN)) != TAG_OPEN) {
            Notify("No line to rewrite")
            return
        }

        Notify("Rewriting…", 0)
        result := RewriteTagged(tagged)

        if !WinActive(WOW_WINDOW) {
            Notify("WoW not active, not pasted")
            return
        }
        A_Clipboard := result
        if !ClipWait(1)
            throw Error("Clipboard failed")
        Send("^+{F11}")     ; make sure the whole line is selected again
        Sleep(60)
        Send("^v")
        Sleep(150)
        ToolTip()
    } catch as e {
        Notify(e.Message)
    } finally {
        A_Clipboard := saved
        busy := false
    }
}

Notify(msg, ms := 4000) {
    ToolTip(msg)
    if ms
        SetTimer(() => ToolTip(), -ms)
}

; ---- building the request -------------------------------------------------------

ParseTagged(tagged) {
    closeAt := InStr(tagged, TAG_CLOSE)
    if !closeAt
        throw Error("Bad tag")
    fields := Map()
    fields.CaseSense := false
    header := SubStr(tagged, StrLen(TAG_OPEN) + 1, closeAt - StrLen(TAG_OPEN) - 1)
    for part in StrSplit(header, ";") {
        eq := InStr(part, "=")
        if eq
            fields[Trim(SubStr(part, 1, eq - 1))] := Trim(SubStr(part, eq + 1))
    }
    line := Trim(SubStr(tagged, closeAt + StrLen(TAG_CLOSE)), " `t`r`n")
    return {fields: fields, line: line}
}

Field(fields, key, default := "") {
    return (fields.Has(key) && fields[key] != "") ? fields[key] : default
}

WordCount(s) {
    RegExReplace(Trim(s), "\S+", "", &n)
    return n
}

; The player asks the AI to fill something in: "insert joke here" or {a joke about gnomes}.
HasRequest(line) {
    return RegExMatch(line, "i)insert.{1,40}?here") || RegExMatch(line, "\{[^{}]+\}")
}

; How many words the rewrite may use, from what the player typed.
; Voice should come from word choice, not from more words.
WordBudget(fields, line) {
    words := Max(1, WordCount(line))
    style := Field(fields, "style", "medium")
    length := Field(fields, "length", "same")
    if (style = "light")
        budget := words + 2
    else if (style = "strong")
        budget := Round(words * 1.4) + 3
    else
        budget := Round(words * 1.2) + 2
    if (length = "shorter")
        budget := Max(2, Min(budget, words))
    else if (length = "longer")
        budget := Round(budget * 1.3) + 1
    if HasRequest(line)
        budget += 15
    if (StrUpper(Field(fields, "chat", "SAY")) = "EMOTE")
        budget += 2
    return Max(3, budget)
}

BuildMessages(parsed, budget) {
    f := parsed.fields
    race := Field(f, "race", "adventurer")
    faction := Field(f, "faction", "")
    sex := Field(f, "sex", "")
    name := Field(f, "name", "")
    persona := Field(f, "persona", "")
    style := Field(f, "style", "medium")
    chat := StrUpper(Field(f, "chat", "SAY"))
    tone := Field(f, "tone", "natural")
    native := Field(f, "native", "few")
    phrases := Field(f, "phrases", "")
    avoid := Field(f, "avoid", "")

    system := "You turn a World of Warcraft player's chat line into what their character would say. "
        . "It must read like a real roleplayer typing quickly in game chat, not like a writer. "
        . "Reply with the line only: no quotes, no explanation, no speaker name. "
        . "`n`nRules:"
        . "`n- Say only what the player said. Add no new ideas, details, jokes, offers or second sentences of your own."
        . "`n- If the player made a joke, keep it a joke: you may sharpen it in the character's voice, but keep it quick."
        . "`n- If the player left a request for you, like 'insert joke here' or something in {curly braces} such as {a joke about gnomes}, "
        . "replace it with what they asked for, written by the character: short, in their voice, fitting the moment. Never leave the request words or braces in."
        . "`n- At most " budget " words. Never pad."
        . "`n- The voice comes from word choice and a little accent, not from extra words."
        . "`n- Do not open or close with a battle cry, a blessing, a god or an oath unless the player did."
        . "`n- No poetic images, no grand words, no 'indeed', no 'mayhap'. Plain, natural speech."
        . "`n- Keep the player's energy: do not add '!' if they did not use one. Short lines stay short; 'ok' stays a word or two."
        . "`n- Keep the meaning, who is addressed, numbers, names and anything in [brackets] exactly. Keep text from |c or |H to |r unchanged."
        . "`n- Do not guess the gender of the people addressed; the speaker's sex only describes the speaker."
        . "`n- Answer in the language of the line. Plain punctuation: no curly quotes, no long dashes."
        . "`n- Only phrases that fit this race and faction in the Warcraft setting, never another race's."
        . "`n- How races talk: orcs blunt, short clipped sentences, honour and strength; trolls drop little words, 'mon', 'da' for 'the'; "
        . "dwarves 'aye', 'ye', 'o'', hearty; gnomes quick, clever, a bit technical; humans plain and courteous; "
        . "night elves calm and formal; Forsaken dry, cold, a little dark; tauren slow, calm, earthy. "
        . "Words like 'lads', 'mon' or 'aye' belong only to the races that use them."

    if (native = "none")
        system .= "`n- No words from the race's own language."
    else if (native = "many")
        system .= "`n- A word from the race's own language (Orcish, Thalassian, Darnassian, Zandali...) is welcome, still at most one."
    else
        system .= "`n- A word from the race's own language only rarely; usually none."

    if (style = "light")
        system .= "`n- Light: keep the player's own words. One small touch at most (an accent word or an address like 'friend'); sometimes none."
    else if (style = "strong")
        system .= "`n- Strong: rewrite the whole line in the character's own voice. Change the wording freely (accent, grammar, their kind of words), keep only the content. It must not read like the original with a word swapped. Still short, no extra content."
    else
        system .= "`n- Medium: reword it so it clearly sounds like this character (accent, word choice, the way they build a sentence). One or two touches, not more."

    if (tone != "natural")
        system .= "`n- Tone of voice: " tone "."
    if (phrases != "")
        system .= "`n- Favourite expressions: " phrases ". Use one only rarely, when it fits naturally; most lines have none."
    if (avoid != "")
        system .= "`n- Never use: " avoid "."

    if (chat = "EMOTE")
        system .= "`n- This is an /emote: a short third-person action without the character's name (the game adds it)."
    else if (chat = "YELL")
        system .= "`n- The line is shouted."
    else if (chat = "WHISPER" || chat = "BN_WHISPER")
        system .= "`n- A private whisper."
    else if (chat = "PARTY" || chat = "RAID" || chat = "RAID_WARNING" || chat = "GUILD" || chat = "OFFICER" || chat = "INSTANCE_CHAT")
        system .= "`n- Said to their group or guild: practical and clear first."

    system .= "`n`nExamples of the right size and feel (other speakers, other lines):"
        . "`nLight, Dwarf, 'need a heal' -> Need a heal here, friend."
        . "`nMedium, Dwarf, 'need a heal' -> Could use a heal o'er here."
        . "`nStrong, Dwarf, 'need a heal' -> Get some healin' o'er here, I'm bleedin'."
        . "`nMedium, Orc, 'anyone want to group for the mine?' -> Who fights with me in the mine?"
        . "`nStrong, Troll, 'brb 5 min, need food' -> Back in five, mon. Gotta eat."
        . "`nStrong, Orc, 'thanks for the help' -> You fought well. I owe you."
        . "`nStrong, Forsaken, 'anyone want to group?' -> Who would walk with me, then?"
        . "`nMedium, Night elf, 'where is the auction house?' -> Where might I find the auction house?"
        . "`nMedium, Human, 'ok' -> Very well."

    who := (name != "" ? name ", " : "") . Trim(sex " " race) . (faction != "" && faction != "Neutral" ? " of the " faction : "")
    user := "Speaker: " who "."
    if (persona != "")
        user .= "`nPersona: " persona
    user .= "`nChat: " chat "`nLine: " parsed.line

    return [Map("role", "system", "content", system), Map("role", "user", "content", user)]
}

Ask(msgs) {
    body := '{"model":' JsonString(MODEL) ',"stream":false,"messages":['
    for i, m in msgs
        body .= (i > 1 ? "," : "") '{"role":' JsonString(m["role"]) ',"content":' JsonString(m["content"]) '}'
    body .= "]}"
    reply := PostJson(API_URL, body)
    if !RegExMatch(reply, 's)"content"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
        if RegExMatch(reply, 's)"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &err)
            throw Error("BridgeControl: " JsonUnescape(err[1]))
        throw Error("No answer")
    }
    return CleanForWow(JsonUnescape(m[1]))
}

RewriteTagged(tagged) {
    parsed := ParseTagged(tagged)
    if (parsed.line = "")
        throw Error("Empty line")
    budget := WordBudget(parsed.fields, parsed.line)
    msgs := BuildMessages(parsed, budget)
    result := Ask(msgs)
    ; too long: ask once more, firmly, and keep the shorter answer
    if (WordCount(result) > budget + 1) {
        msgs.Push(Map("role", "assistant", "content", result))
        msgs.Push(Map("role", "user", "content", "Too long and too much. Same meaning, plain, at most " budget " words."))
        try {
            second := Ask(msgs)
            if (WordCount(second) < WordCount(result))
                result := second
        }
    }
    return result
}


; ---- HTTP + JSON ----------------------------------------------------------------

PostJson(url, body) {
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(2000, 2000, TIMEOUT_SEC * 1000, TIMEOUT_SEC * 1000)
    req.Open("POST", url, false)
    req.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
    req.SetRequestHeader("User-Agent", "RPVoice")
    try
        req.Send(Utf8Bytes(body))
    catch
        throw Error("BridgeControl not running")
    text := BytesToUtf8(req.ResponseBody)
    if (req.Status != 200) {
        if RegExMatch(text, 's)"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &err)
            throw Error("BridgeControl " req.Status ": " JsonUnescape(err[1]))
        throw Error("BridgeControl error " req.Status)
    }
    return text
}

Utf8Bytes(s) {
    len := StrPut(s, "UTF-8") - 1
    buf := Buffer(len + 1)
    StrPut(s, buf, "UTF-8")
    arr := ComObjArray(0x11, len)
    Loop len
        arr[A_Index - 1] := NumGet(buf, A_Index - 1, "UChar")
    return arr
}

BytesToUtf8(arr) {
    n := arr.MaxIndex() + 1
    if (n <= 0)
        return ""
    buf := Buffer(n)
    Loop n
        NumPut("UChar", arr[A_Index - 1], buf, A_Index - 1)
    return StrGet(buf, n, "UTF-8")
}

JsonString(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    out := ""
    Loop Parse s {
        c := Ord(A_LoopField)
        out .= (c < 0x20) ? Format("\u{:04x}", c) : A_LoopField
    }
    return '"' out '"'
}

JsonUnescape(s) {
    out := ""
    i := 1
    n := StrLen(s)
    while (i <= n) {
        ch := SubStr(s, i, 1)
        if (ch != "\") {
            out .= ch
            i += 1
            continue
        }
        nx := SubStr(s, i + 1, 1)
        switch nx, true {
            case "n": out .= "`n"
            case "r": out .= "`r"
            case "t": out .= "`t"
            case "b", "f": out .= ""
            case "u":
                out .= Chr(Integer("0x" SubStr(s, i + 2, 4)))
                i += 4
            default: out .= nx
        }
        i += 2
    }
    return out
}

; ---- make the answer safe for a WoW chat line ---------------------------------------------

CleanForWow(s) {
    s := RegExReplace(s, "[\r\n\t]+", " ")
    s := StrReplace(s, Chr(0x2018), "'"), s := StrReplace(s, Chr(0x2019), "'")
    s := StrReplace(s, Chr(0x201C), '"'), s := StrReplace(s, Chr(0x201D), '"')
    s := StrReplace(s, Chr(0x2014), " - "), s := StrReplace(s, Chr(0x2013), "-")
    s := StrReplace(s, Chr(0x2026), "...")
    s := RegExReplace(s, " {2,}", " ")
    s := Trim(s)
    ; drop quotes wrapped around the whole answer
    if (StrLen(s) >= 2 && ((SubStr(s, 1, 1) = '"' && SubStr(s, -1) = '"') || (SubStr(s, 1, 1) = "'" && SubStr(s, -1) = "'")))
        s := Trim(SubStr(s, 2, StrLen(s) - 2))
    ; fit WoW's 255-byte line, cutting at a word
    while (StrPut(s, "UTF-8") - 1 > MAX_BYTES) {
        cut := InStr(s, " ", , -1)
        s := cut > 1 ? RTrim(SubStr(s, 1, cut - 1), " ,;:-") : SubStr(s, 1, StrLen(s) - 1)
    }
    if (s = "")
        throw Error("Empty answer")
    return s
}
