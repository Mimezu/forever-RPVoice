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

A_IconTip := "RP Voice: Ctrl+Shift+R in WoW chat"
HotIfWinActive(WOW_WINDOW)
Hotkey(HOTKEY_KEYS, RewriteChatLine)
HotIfWinActive()
TrayTip("Ctrl+Shift+R while typing in WoW chat.", "RP Voice is ready", "Mute")
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
            Notify("No RP Voice tag. Is a chat box open with a line typed, and the RPVoice addon on?")
            return
        }

        Notify("RP Voice: rewriting...", 0)
        result := RewriteTagged(tagged)

        if !WinActive(WOW_WINDOW) {
            Notify("WoW is no longer the active window, nothing pasted.")
            return
        }
        A_Clipboard := result
        if !ClipWait(1)
            throw Error("could not use the clipboard")
        Send("^+{F11}")     ; make sure the whole line is selected again
        Sleep(60)
        Send("^v")
        Sleep(150)
        ToolTip()
    } catch as e {
        Notify("RP Voice: " e.Message)
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
        throw Error("tag is not closed")
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

BuildMessages(parsed) {
    f := parsed.fields
    race := Field(f, "race", "adventurer")
    faction := Field(f, "faction", "")
    sex := Field(f, "sex", "")
    name := Field(f, "name", "")
    persona := Field(f, "persona", "")
    style := Field(f, "style", "medium")
    chat := StrUpper(Field(f, "chat", "SAY"))

    system := "You rewrite World of Warcraft chat lines into in-character roleplay speech. "
        . "Reply with the rewritten line only: no quotes around it, no explanation, no speaker name in front. "
        . "Keep the meaning, who is addressed, numbers, names and anything in [brackets] exactly. "
        . "Keep any text from |c or |H up to |r unchanged. "
        . "Do not guess the gender of the people addressed; the speaker's sex only describes the speaker. "
        . "Answer in the language of the line. "
        . "One line, at most 200 characters. Plain punctuation: no curly quotes, no long dashes (accented letters are fine). "
        . "Give the speaker the speech habits, greetings and turns of phrase of their race and faction in the Warcraft setting. "
        . "Native words (Orcish, Thalassian, Darnassian, Zandali and so on) only sparingly so other players still understand, "
        . "and never phrases that belong to another race."

    if (style = "light")
        system .= " Light touch: keep the player's own wording and add only a little flavour, like a greeting or a word of accent."
    else if (style = "strong")
        system .= " Full roleplay: vivid in-character speech with a strong voice and lore flavour; it may be a little longer."
    else
        system .= " Rephrase it the way this character would say it, with a clear voice and accent, about the same length."

    if (chat = "EMOTE")
        system .= " This is an /emote: write a third-person action without the character's name (the game adds it), for example: grins and raises a tankard."
    else if (chat = "YELL")
        system .= " The line is shouted."
    else if (chat = "WHISPER" || chat = "BN_WHISPER")
        system .= " It is a private whisper."
    else if (chat = "PARTY" || chat = "RAID" || chat = "GUILD" || chat = "OFFICER" || chat = "INSTANCE_CHAT")
        system .= " It is said to the character's group or guild; keep it practical and clear."

    who := (name != "" ? name ", " : "") . Trim(sex " " race) . (faction != "" && faction != "Neutral" ? " of the " faction : "")
    user := "Speaker: " who "."
    if (persona != "")
        user .= "`nPersona: " persona
    user .= "`nChat: " chat "`nLine: " parsed.line

    return [Map("role", "system", "content", system), Map("role", "user", "content", user)]
}

RewriteTagged(tagged) {
    parsed := ParseTagged(tagged)
    if (parsed.line = "")
        throw Error("the line is empty")
    msgs := BuildMessages(parsed)
    body := '{"model":' JsonString(MODEL) ',"stream":false,"messages":['
    for i, m in msgs
        body .= (i > 1 ? "," : "") '{"role":' JsonString(m["role"]) ',"content":' JsonString(m["content"]) '}'
    body .= "]}"

    reply := PostJson(API_URL, body)
    if !RegExMatch(reply, 's)"content"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
        if RegExMatch(reply, 's)"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &err)
            throw Error("BridgeControl: " JsonUnescape(err[1]))
        throw Error("BridgeControl gave no answer")
    }
    return CleanForWow(JsonUnescape(m[1]))
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
        throw Error("BridgeControl is not answering on " url)
    text := BytesToUtf8(req.ResponseBody)
    if (req.Status != 200) {
        if RegExMatch(text, 's)"message"\s*:\s*"((?:[^"\\]|\\.)*)"', &err)
            throw Error("BridgeControl " req.Status ": " JsonUnescape(err[1]))
        throw Error("BridgeControl answered " req.Status)
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
        throw Error("BridgeControl gave an empty answer")
    return s
}
