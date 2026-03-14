#Requires AutoHotkey v2.0
#SingleInstance Force

configFile := A_ScriptDir "\config.txt"
global macros := Map()
macros.CaseSense := false ; Makes the main Map case-insensitive to prevent matching errors

; Set default delays in seconds just in case they aren't in config.txt
global holdDelay := "0.3"   ; 300ms default
global doubleDelay := "0.2" ; 200ms default

if !FileExist(configFile)
{
    MsgBox("config.txt not found")
    ExitApp
}

Loop Read configFile
{
    line := Trim(A_LoopReadLine)

    if (line = "" || SubStr(line,1,1) = ";")
        continue

    parts := StrSplit(line, "|")

    ; -- NEW: Check for delay settings --
    ; Format: delay | hold/double | milliseconds
    if (StrLower(Trim(parts[1])) = "delay")
    {
        if (parts.Length >= 3)
        {
            delayType := StrLower(Trim(parts[2]))
            try 
            {
                ms := Integer(Trim(parts[3]))
                sec := ms / 1000 ; Convert ms to seconds for KeyWait
                
                if (delayType = "hold")
                    global holdDelay := String(sec)
                else if (delayType = "double")
                    global doubleDelay := String(sec)
            }
        }
        continue
    }

    ; -- Existing Macro Parsing --
    ; Expect 4 parts: Key | TriggerType | ActionType | Value
    if (parts.Length < 4)
        continue

    key := Trim(parts[1])
    triggerType := StrLower(Trim(parts[2]))
    actionType := StrLower(Trim(parts[3]))
    value := Trim(parts[4])

    if !macros.Has(key)
    {
        innerMap := Map()
        innerMap.CaseSense := false ; Makes trigger types case-insensitive
        macros[key] := innerMap
        try Hotkey(key, HandleMacro)
    }

    macros[key][triggerType] := {actionType: actionType, value: value}
}

HandleMacro(thisHotkey)
{
    ; Access the global delay variables mapped from config.txt
    global holdDelay, doubleDelay
    
    bareKey := RegExReplace(thisHotkey, "^[~*$!^+#]+")
    
    ; Safely concatenate strings using the dot operator
    waitHold := "T" . holdDelay
    waitDouble := "D T" . doubleDelay
    
    ; 1. Wait for the key to be released using the dynamic hold delay
    if !KeyWait(bareKey, waitHold) 
    {
        ExecuteAction(thisHotkey, "hold")
        KeyWait(bareKey) ; Wait for physical release
        return
    }
    
    ; 2. Key released quickly. Wait for a second press using dynamic double delay
    if !KeyWait(bareKey, waitDouble) 
    {
        ExecuteAction(thisHotkey, "single")
        return
    }
    
    ; 3. Second press occurred within the time limit
    ExecuteAction(thisHotkey, "double")
    KeyWait(bareKey)
}

ExecuteAction(key, triggerType)
{
    global macros
    
    if !macros.Has(key) || !macros[key].Has(triggerType)
        return 
        
    macro := macros[key][triggerType]

    if (macro.actionType = "app" || macro.actionType = "url")
    {
        Run(macro.value)
    }
    else if (macro.actionType = "macro")
    {
        Send(macro.value)
    }
    else if (macro.actionType = "audio")
    {
        exe := A_ScriptDir "\audio\SoundVolumeView.exe"
        
        if !FileExist(exe)
        {
            MsgBox("Could not find: " exe "`n`nPlease ensure SoundVolumeView.exe is in the 'audio' folder next to this script.", "Error", "IconX")
            return
        }
        
        ; Run the executable directly. 'all' changes default for both standard and comms.
        Run('"' exe '" /SetDefault "' macro.value '" all', , "Hide")
    }
}