; RP Voice helper (AutoHotkey v2)
; Rewrites the line you are typing in WoW chat into your character's roleplay voice,
; using BridgeControl's local ChatGPT server. Needs the RPVoice addon in the game.
;
; Use, in WoW Forever only:
;   Shift+Enter        rewrite the line you typed in the chat box
;   hold Ctrl+Enter    talk; on release your words are typed into chat and rewritten
; Read the result, then press Enter.
; Nothing is ever sent for you.
;
; Test without the game:  AutoHotkey64.exe RPVoice.ahk --test "[[RPV race=Orc; faction=Horde; sex=male; chat=SAY]] hi all"

#Requires AutoHotkey v2.0
#SingleInstance Off   ; --test runs must not close the tray helper (see below)

; ---- settings ---------------------------------------------------------------
global API_URL     := "http://127.0.0.1:18080/v1/chat/completions"
global MODEL       := "gpt-6-luna"
global FAST        := true     ; BridgeControl fast mode (service_tier priority)
global EFFORT      := "medium" ; reasoning effort (none, low, medium, high)
global TIMEOUT_SEC := 30
global REWRITE_KEY := "+Enter"        ; Shift+Enter: rewrite the chat line
global TALK_KEY    := "^Enter"        ; hold Ctrl+Enter: speech to chat, then rewrite
global STT_URL     := "http://127.0.0.1:18080/v1/audio/transcriptions"
global WOW_EXE     := "Wow.exe"
global WOW_FOLDER  := "\_forever_\"   ; only the WoW Forever client
global MAX_BYTES   := 255              ; WoW chat line limit
; ----------------------------------------------------------------------------

global TAG_OPEN := "[[RPV "
global TAG_CLOSE := "]] "

if (A_Args.Length >= 2 && A_Args[1] = "--stt") {
    try {
        FileAppend(Transcribe(A_Args[2]) "`n", "*", "UTF-8")
        ExitApp(0)
    } catch as e {
        FileAppend("ERROR: " e.Message "`n", "**", "UTF-8")
        ExitApp(1)
    }
}
if (A_Args.Length >= 2 && A_Args[1] = "--test") {
    try {
        FileAppend(RewriteTagged(A_Args[2]) "`n", "*", "UTF-8")
        ExitApp(0)
    } catch as e {
        FileAppend("ERROR: " e.Message "`n", "**", "UTF-8")
        ExitApp(1)
    }
}

; Tray mode: one copy only. Close any other tray copy of this script.
DetectHiddenWindows(true)
for hwnd in WinGetList(A_ScriptFullPath " ahk_class AutoHotkey")
    if (WinGetPID(hwnd) != DllCall("GetCurrentProcessId"))
        try ProcessClose(WinGetPID(hwnd))
DetectHiddenWindows(false)

A_IconTip := "RP Voice · Shift+Enter · hold Ctrl+Enter"
HotIf((*) => IsForever())
Hotkey("$" REWRITE_KEY, (*) => RewriteChatLine())
Hotkey("$" TALK_KEY, TalkToChat)
HotIf()
TrayTip("Shift+Enter: rewrite`nHold Ctrl+Enter: talk", "RP Voice ready", "Mute")
return

; ---- the hotkey ---------------------------------------------------------------

IsForever() {
    try return WinActive("ahk_exe " WOW_EXE) && InStr(WinGetProcessPath("A"), WOW_FOLDER)
    return false
}

RewriteChatLine() {
    static busy := false
    if busy
        return
    busy := true
    saved := ClipboardAll()
    try {
        KeyWait("Enter")
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

        if !IsForever() {
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

; ---- hold Ctrl+Enter: speech to chat ----------------------------------------------

TalkToChat(*) {
    static busy := false
    if busy
        return
    busy := true
    wav := A_Temp "\rpvoice_talk.wav"
    try {
        Mci("close rpv")
        Mci("open new type waveaudio alias rpv", true)
        Mci("set rpv bitspersample 16 channels 1 samplespersec 16000 bytespersec 32000 alignment 2")
        Mci("record rpv", true)
        start := A_TickCount
        Notify("Listening…", 0)
        KeyWait("Enter")
        Sleep(200)                       ; keep the last word
        Mci("stop rpv")
        held := A_TickCount - start
        Mci('save rpv "' wav '"', true)
        Mci("close rpv")
        if (held < 500) {
            Notify("Hold Ctrl+Enter while talking")
            return
        }
        Notify("Listening done, writing…", 0)
        text := Transcribe(wav)
        if (text = "") {
            Notify("Heard nothing")
            return
        }
        if !IsForever() {
            Notify("WoW not active, not pasted")
            return
        }
        KeyWait("Ctrl")
        PasteIntoChat(text)
        RewriteChatLine()
    } catch as e {
        Notify(e.Message)
    } finally {
        try Mci("close rpv")
        try FileDelete(wav)
        busy := false
    }
}

Mci(cmd, check := false) {
    err := DllCall("winmm\mciSendStringW", "Str", cmd, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt")
    if (err && check) {
        buf := Buffer(512, 0)
        DllCall("winmm\mciGetErrorStringW", "UInt", err, "Ptr", buf, "UInt", 256)
        throw Error("Microphone: " StrGet(buf))
    }
    return err
}

; The addon opens the chat box (or selects its text) on Ctrl+Shift+F10; paste over it.
PasteIntoChat(text) {
    saved := ClipboardAll()
    try {
        Send("^+{F10}")
        Sleep(150)
        A_Clipboard := text
        if !ClipWait(1)
            throw Error("Clipboard failed")
        Send("^v")
        Sleep(150)
    } finally {
        A_Clipboard := saved
    }
}

Transcribe(wavPath) {
    data := FileRead(wavPath, "RAW")
    boundary := "----RPVoice" A_TickCount
    head := "--" boundary "`r`nContent-Disposition: form-data; name=`"file`"; filename=`"talk.wav`"`r`nContent-Type: audio/wav`r`n`r`n"
    tail := "`r`n--" boundary "--`r`n"
    hLen := StrPut(head, "UTF-8") - 1, tLen := StrPut(tail, "UTF-8") - 1
    body := Buffer(hLen + data.Size + tLen)
    StrPut(head, body, "UTF-8")
    DllCall("RtlMoveMemory", "Ptr", body.Ptr + hLen, "Ptr", data, "Ptr", data.Size)
    StrPut(tail, body.Ptr + hLen + data.Size, tLen, "UTF-8")
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.SetTimeouts(2000, 2000, TIMEOUT_SEC * 1000, TIMEOUT_SEC * 1000)
    req.Open("POST", STT_URL, false)
    req.SetRequestHeader("Content-Type", "multipart/form-data; boundary=" boundary)
    req.SetRequestHeader("User-Agent", "RPVoice")
    try
        req.Send(BufToSafeArray(body, body.Size))
    catch
        throw Error("BridgeControl not running")
    reply := BytesToUtf8(req.ResponseBody)
    if (req.Status != 200)
        throw Error("Speech error " req.Status)
    if !RegExMatch(reply, 's)"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
        return ""
    return Trim(CleanForWow(JsonUnescape(m[1]) " "))
}

BufToSafeArray(buf, len) {
    arr := ComObjArray(0x11, len)
    pData := 0
    DllCall("oleaut32\SafeArrayAccessData", "Ptr", ComObjValue(arr), "Ptr*", &pData)
    DllCall("RtlMoveMemory", "Ptr", pData, "Ptr", buf, "Ptr", len)
    DllCall("oleaut32\SafeArrayUnaccessData", "Ptr", ComObjValue(arr))
    return arr
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
        budget := Round(words * 1.6) + 4
    else
        budget := Round(words * 1.3) + 3
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

; How each race talks, and one line ('anyone want to group?') at the three levels.
; Only the speaker's own entry goes in the prompt.
RaceVoice(race) {
    static voices := Map(
        "orc", ["blunt, clipped and proud, with scorn for weakness. Orcish words, rarely: Lok'tar (battle cry), Zug zug (ok, will do), Throm-ka (a greeting, never thanks).",
            "Group? Who fights with me?", "Who fights with me? Need a group.", "Who has the stomach to fight beside me?",
            "Wait for healer mana.", "Hold. Healer needs mana.", "Hold. Healer drinks first, then we crush them."],
        "troll", ["laid-back island accent: mon, da, dat, den, 'be' for is/are, dropped endings; easy and sly; the loa and voodoo.",
            "Anyone wanna group, mon?", "Who be wantin' to group up, mon?", "Who be comin' wit' me, mon? Da loa say we go together.",
            "Wait for da healer's mana.", "Hold up, mon, da healer be drinkin'.", "Easy now, mon. Healer be sippin', den we go."],
        "dwarf", ["hearty Scots-ish accent: aye, ye, yer, o', me for my, dropped g's, wee, lads for a group; ale, stone and the forge.",
            "Anyone want to group up, lads?", "Any o' ye fancy groupin' up?", "Who's comin' wi' me, then? Grab yer axes, lads.",
            "Wait fer the healer's mana.", "Hold yer horses, the healer needs a drink.", "Easy, lads. Healer's havin' a drink, an' so should we."],
        "gnome", ["quick, chirpy and clever; talks fast, loves numbers, gadgets and clever plans.",
            "Anyone up for a teeny group run?", "Anyone want to group? Five heads beat one.", "Group wanted. Five heads, one plan, minimal explosions.",
            "Wait for the healer's mana, please.", "Quick pause, healer mana's in the red.", "Hold it, team. Healer's mana gauge reads empty, refuel first."],
        "human", ["a Stormwind soldier, courteous but brisk: hold, steady, right then, if you please; the Light now and then.",
            "Anyone care to form a group?", "Well met. Anyone care to group up?", "Any able sword arms looking for a group? I'd welcome the company.",
            "Hold for the healer's mana.", "Hold, everyone. Let the healer drink.", "Hold the line, all. Healer drinks first, then we advance."],
        "night elf", ["calm, graceful and formal even in quick messages; no slang, no contractions; Elune, the moon, the grove, the wild. Ishnu-alah means hello or goodbye.",
            "Would anyone like to group?", "Would anyone care to join me? I seek companions.", "Elune guide us. Who will walk the road with me tonight?",
            "Please wait for the healer's mana.", "Patience. Let the healer restore their strength.", "Be still a moment. The healer must restore their strength before we go on."],
        "forsaken", ["dry, cold and sardonic, never warm or theatrical; flat understatement about death and rot.",
            "Anyone want to group, living or otherwise?", "Anyone want to group? I promise to rot quietly.", "Who'll group with a corpse? I'm better company than I smell.",
            "Wait for the healer's mana. Some of us need it.", "Wait. The healer needs mana. The living tire so easily.", "Patience. Let the healer drink. The living are so fragile."],
        "tauren", ["slow, calm, earthy and kind; short plain words; the Earth Mother, the winds, the hunt.",
            "Anyone wish to walk with me?", "Who would walk with me? Many hooves, one path.", "The Earth Mother says none should hunt alone. Who will join me?",
            "Wait for the healer's mana, the herd rests.", "Rest a moment. The healer must drink.", "Be still. Let the healer drink, the hunt can wait."],
        "blood elf", ["proud, refined and faintly disdainful; elegant words. Native: Bal'a dash.",
            "Anyone competent want to group?", "Looking for a group. Competent ones only.", "I require a group. Do try to keep up.",
            "Do wait for the healer's mana.", "Wait. The healer needs mana, obviously.", "Must I say it? Wait for the healer's mana."],
        "draenei", ["formal and kind, slightly foreign word order; the Light and the Naaru.",
            "Is someone wanting to group?", "Is someone wishing to group with me?", "The Light brings us together. Who will join me?",
            "Please, wait for healer mana.", "Wait, please, the healer is needing mana.", "Patience. The healer is needing the Light's strength again."],
        "goblin", ["fast-talking and money-minded; deals, profit, explosives.",
            "Anyone want to group? Quick, time's money.", "Group up, pal? Loot split fair. Mostly.", "Five slots, zero patience. Who's in, pal? Time is money.",
            "Wait for the healer's mana, pal.", "Hold up, healer's runnin' on empty.", "Hold it, pal. No mana, no heals, no profit."],
        "worgen", ["Gilnean: proper, old-fashioned, a little gruff.",
            "Anyone fancy a group?", "I say, would anyone care to group?", "Right then, who's up for a spot of hunting, old chap?",
            "Do wait for the healer's mana.", "Steady on, the healer needs a drink.", "Steady on, chaps. Let the healer have a proper drink first."],
        "pandaren", ["gentle and cheerful; food, brew and little proverbs.",
            "Anyone want to share the road?", "Who would share the road? Many hands, light work.", "A road shared is a meal shared. Who joins me?",
            "Wait for the healer's mana, the tea is steeping.", "Wait a moment. Even a teapot must be refilled.", "Patience. A healer is like a teapot: empty pours nothing."]
    )
    key := StrLower(race)
    return voices.Has(key) ? voices[key]
        : ["talks the way a " race " of Azeroth would.", "", "", "", "", "", ""]
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
    english := (Field(f, "lang", "same") = "english")
    v := RaceVoice(race)

    system := "Rewrite a World of Warcraft player's chat line the way their character would type it. Reply with the new line only: no label, no quotes, no asterisks."
        . "`n`nThe character is a " race ": " v[1]

    if (style = "light")
        system .= "`nLevel: light. Keep the player's words with one touch of the voice (an accent spelling or a typical word). It must show who the character is; tidying spelling or adding 'then' or 'all' does not count."
    else if (style = "strong")
        system .= "`nLevel: strong. Rebuild the sentence itself in the character's voice and attitude, bolder than medium. Then you may add one short aside about the same subject (a grumble, a boast or a little joke) that makes sense on its own. The aside is never the only change. No stock blessings, no strings of race words."
    else
        system .= "`nLevel: medium. Reword it so a reader could name the race, with the voice inside the sentence. No aside."

    if (v[2] != "")
        system .= "`n`nThis race at each level:"
            . "`n'anyone want to group?' -> light: " v[2] " | medium: " v[3] " | strong: " v[4]
            . "`n'wait for healer mana' -> light: " v[5] " | medium: " v[6] " | strong: " v[7]
            . "`nMatch the " style " level. Do not reuse these lines."

    system .= "`n`nRules:"
        . "`n- Same meaning. No new facts, offers or plans. Keep names, numbers, [links] and |c...|r codes."
        . "`n- Game chat, not literature: short and casual. No poetry, no semicolons, no '!' the player did not type."
        . "`n- Never add a word that names or describes the listeners (their class or race, or 'corpse', 'soldier', 'warrior', 'friend'); only a race's group word like 'lads' or 'mon'. Never invent words."
        . "`n- Use a word of the race's language only with the meaning given above, at most one per line."
        . "`n- At most " budget " words."
        . "`n- 'insert joke here' or something in {braces} asks you to write that part: one short real joke with a punchline, about the topic itself, in voice. Self-mockery works well. Not a demand, an insult or a meme."
        . "`n- Do not guess the gender of the people addressed."
        . (english
            ? "`n- Answer in English: translate the line first if needed, then give it the voice at the chosen level. Plain ASCII punctuation."
            : "`n- Answer in the language of the line. No curly quotes or long dashes.")

    if (native = "none")
        system .= "`n- No words from the race's own language."
    else if (native = "many")
        system .= "`n- A word of the race's own language is welcome when it fits."
    else
        system .= "`n- A word of the race's own language only rarely, where it means something."
    if (style != "light")
        system .= "`n- Work the voice into the sentence. Never just stick a native word, 'mon', 'aye' or 'friends' onto an otherwise unchanged line."
    if (tone != "natural")
        system .= "`n- Mood: " tone "."
    if (phrases != "")
        system .= "`n- Favourite expressions, now and then: " phrases "."
    if (avoid != "")
        system .= "`n- Never use: " avoid "."

    if (chat = "EMOTE")
        system .= "`n- This is an /emote: a third-person action, no name, starting lower case. Show the character in the action itself (a gesture typical of them), not in adverbs."
    else if (chat = "YELL")
        system .= "`n- The line is shouted."
    else if (chat = "PARTY" || chat = "RAID" || chat = "RAID_WARNING" || chat = "GUILD" || chat = "OFFICER" || chat = "INSTANCE_CHAT")
        system .= "`n- Said to their group or guild: still in voice, but any instruction stays clear."

    who := (name != "" ? name ", " : "") . Trim(sex " " race) . (faction != "" && faction != "Neutral" ? " of the " faction : "")
    user := "Speaker: " who "."
    if (persona != "")
        user .= "`nPersona: " persona
    user .= "`nChat: " chat "`nLine: " parsed.line

    return [Map("role", "system", "content", system), Map("role", "user", "content", user)]
}

Ask(msgs) {
    body := '{"model":' JsonString(MODEL) ',"stream":false'
    if FAST
        body .= ',"service_tier":"priority"'
    if (EFFORT != "")
        body .= ',"reasoning_effort":' JsonString(EFFORT)
    body .= ',"messages":['
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
        msgs.Push(Map("role", "user", "content", "Too long. Same voice, fewer words: at most " budget " words."))
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
    return BufToSafeArray(buf, len)
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
    ; drop a "SAY:" / "Line:" label and *asterisks* around an emote
    s := RegExReplace(s, "i)^(SAY|YELL|EMOTE|PARTY|RAID|GUILD|WHISPER|CHANNEL|Line|light|medium|strong)\s*:\s*", "")
    if (StrLen(s) >= 2 && SubStr(s, 1, 1) = "*" && SubStr(s, -1) = "*")
        s := Trim(SubStr(s, 2, StrLen(s) - 2))
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
