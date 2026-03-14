#Requires AutoHotkey v2.0
#SingleInstance Force

global configFile := A_ScriptDir "\config.txt"
global settingsFile := A_ScriptDir "\settings.ini"
global macros := Map()
macros.CaseSense := false 

global holdDelay := "0.3"   
global doubleDelay := "0.2" 

global targetKey := "NumpadMult"
global recording := false
global recorded := ""
global ignoreNextClick := false
global types := ["Launch App","Open URL","Macro","Change Output Device"]
global pressTypes := ["Single", "Double", "Hold"]

global runAsAdminVal := IniRead(settingsFile, "Settings", "RunAsAdmin", "0")
global runAtStartupVal := IniRead(settingsFile, "Settings", "RunAtStartup", "0")

if (runAsAdminVal == "1" && !A_IsAdmin) {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp()
    } catch {
        IniWrite("0", settingsFile, "Settings", "RunAsAdmin")
        runAsAdminVal := "0"
    }
}

A_IconTip := "Shortcut Key"

A_TrayMenu.Delete() 
A_TrayMenu.Add("Edit shortcut", ShowEditGui)
A_TrayMenu.Add("Settings", ShowSettingsGui)
A_TrayMenu.Add("Refresh", RefreshScript)
A_TrayMenu.Add("Exit", CloseScript)

OnMessage(0x0404, TrayIconDoubleClick)
TrayIconDoubleClick(wParam, lParam, msg, hwnd) {
    if (lParam = 0x0203) 
        ShowEditGui()
}

if !FileExist(configFile)
{
    FileAppend("", configFile) 
}

Loop Read configFile
{
    line := Trim(A_LoopReadLine)

    if (line = "" || SubStr(line,1,1) = ";")
        continue

    parts := StrSplit(line, "|")

    if (StrLower(Trim(parts[1])) = "delay")
    {
        if (parts.Length >= 3)
        {
            delayType := StrLower(Trim(parts[2]))
            try 
            {
                ms := Integer(Trim(parts[3]))
                sec := ms / 1000 
                
                if (delayType = "hold")
                    global holdDelay := String(sec)
                else if (delayType = "double")
                    global doubleDelay := String(sec)
            }
        }
        continue
    }

    if (parts.Length < 4)
        continue

    key := Trim(parts[1])
    triggerType := StrLower(Trim(parts[2]))
    actionType := StrLower(Trim(parts[3]))
    value := Trim(parts[4])

    if !macros.Has(key)
    {
        innerMap := Map()
        innerMap.CaseSense := false 
        macros[key] := innerMap
        try Hotkey(key, HandleMacro)
    }

    macros[key][triggerType] := {actionType: actionType, value: value}
}

global audioDevices := GetAudioOutputDevices()
global myGui := Gui("-Resize -MaximizeBox -MinimizeBox", "Edit Shortcut")

; Uniform layout: Column 1 is w260, Column 2 is w120
myGui.AddText("xm w260", "Press Type:")
global delayText := myGui.AddText("x+m yp w120", "Delay (ms):")

global pressTypeDDL := myGui.AddDropDownList("xm y+2 w260 Choose1", pressTypes)
pressTypeDDL.OnEvent("Change", LoadExistingConfig)

global delayEdit := myGui.AddEdit("x+m yp w120 Number")

; Manually hide them AFTER creation
delayText.Visible := false
delayEdit.Visible := false

myGui.AddText("xm", "Action Type:")
global typeDDL := myGui.AddDropDownList("w260", types)
typeDDL.OnEvent("Change", ToggleControls)

myGui.AddText("xm", "Value:")
global valueEdit := myGui.AddEdit("w260")
global valueAudioDDL := myGui.AddDropDownList("xp yp w260", audioDevices)
valueAudioDDL.Visible := false

global actionBtn := myGui.AddButton("x+m yp w120 Center", "Action")
actionBtn.OnEvent("Click", ActionButton)
actionBtn.Visible := false

global saveBtn := myGui.AddButton("xm w100", "Save")
saveBtn.OnEvent("Click", SaveConfig)
global clearBtn := myGui.AddButton("x+m w100", "Clear")
clearBtn.OnEvent("Click", ClearFields)

WinSetStyle("-0x10000", myGui.Hwnd)
myGui.Show("Hide") 
myGui.GetClientPos(,, &guiWidth)
totalButtonsWidth := 210 
startX := (guiWidth - totalButtonsWidth) / 2
saveBtn.Move(startX)
clearBtn.Move(startX + 110)

global settingsGui := Gui("-Resize -MaximizeBox -MinimizeBox", "Settings")

global chkStartup := settingsGui.AddCheckbox("xm y+10 vChkStartup Checked" runAtStartupVal, "Run at Startup")
global chkAdmin := settingsGui.AddCheckbox("xm y+10 vChkAdmin Checked" runAsAdminVal, "Run as Administrator")

global applySettingsBtn := settingsGui.AddButton("y+15 w120", "Apply Settings")
applySettingsBtn.OnEvent("Click", ApplySettings)

settingsGui.Show("Hide")
settingsGui.GetClientPos(,, &setGuiWidth)
btnX := (setGuiWidth - 120) / 2
applySettingsBtn.Move(btnX)


ShowEditGui(*)
{
    ; Check config for the first saved action for this key to select it by default
    foundPress := "Single" 
    if FileExist(configFile) {
        Loop Read configFile {
            line := Trim(A_LoopReadLine)
            if (line = "" || SubStr(line,1,1) = ";")
                continue
            parts := StrSplit(line, "|")
            if (parts.Length >= 4 && parts[1] = targetKey) {
                sp := StrLower(Trim(parts[2]))
                if (sp = "single")
                    foundPress := "Single"
                else if (sp = "double")
                    foundPress := "Double"
                else if (sp = "hold")
                    foundPress := "Hold"
                break 
            }
        }
    }
    
    pressTypeDDL.Choose(foundPress)
    LoadExistingConfig()
    myGui.Show()
}

ShowSettingsGui(*)
{
    chkStartup.Value := IniRead(settingsFile, "Settings", "RunAtStartup", "0")
    chkAdmin.Value := IniRead(settingsFile, "Settings", "RunAsAdmin", "0")
    settingsGui.Show()
}

RefreshScript(*)
{
    Reload()
}

CloseScript(*)
{
    ExitApp()
}

ApplySettings(*)
{
    global chkStartup, chkAdmin, settingsFile
    
    valStartup := chkStartup.Value
    valAdmin := chkAdmin.Value
    
    IniWrite(valStartup, settingsFile, "Settings", "RunAtStartup")
    IniWrite(valAdmin, settingsFile, "Settings", "RunAsAdmin")
    
    shortcutPath := A_Startup "\ShortcutManager.lnk"
    if (valStartup = 1) {
        FileCreateShortcut(A_ScriptFullPath, shortcutPath)
    } else {
        if FileExist(shortcutPath)
            FileDelete(shortcutPath)
    }
    
    if (valAdmin = 1 && !A_IsAdmin) {
        try {
            Run('*RunAs "' A_ScriptFullPath '"')
            ExitApp()
        } catch {
            chkAdmin.Value := 0
            IniWrite("0", settingsFile, "Settings", "RunAsAdmin")
            MsgBox("Administrator privileges were denied. Settings reverted.", "Settings", "Iconx")
        }
    } else if (valAdmin = 0 && A_IsAdmin) {
        Run('explorer.exe "' A_ScriptFullPath '"')
        ExitApp()
    } else {
        MsgBox("Settings saved and applied successfully.", "Settings", "Iconi")
        settingsGui.Hide()
    }
}

HandleMacro(thisHotkey)
{
    global holdDelay, doubleDelay, macros
    
    bareKey := RegExReplace(thisHotkey, "^[~*$!^+#]+")
    
    waitHold := "T" . holdDelay
    waitDouble := "D T" . doubleDelay
    
    if !KeyWait(bareKey, waitHold) 
    {
        ExecuteAction(thisHotkey, "hold")
        KeyWait(bareKey) 
        return
    }
    
    if !KeyWait(bareKey, waitDouble) 
    {
        ExecuteAction(thisHotkey, "single")
        return
    }
    
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
        
        Run('"' exe '" /SetDefault "' macro.value '" all', , "Hide")
    }
}

GetAudioOutputDevices() {
    devices := []
    try {
        IMMDeviceEnumerator := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        ComCall(3, IMMDeviceEnumerator, "UInt", 0, "UInt", 1, "Ptr*", &pCollection:=0)
        ComCall(3, pCollection, "UInt*", &count:=0)
        
        Loop count {
            ComCall(4, pCollection, "UInt", A_Index-1, "Ptr*", &pDevice:=0)
            ComCall(4, pDevice, "UInt", 0, "Ptr*", &pProps:=0)
            
            PKEY := Buffer(20, 0)
            DllCall("ole32\CLSIDFromString", "Str", "{A45C254E-DF1C-4EFD-8020-67D146A850E0}", "Ptr", PKEY)
            NumPut("UInt", 14, PKEY, 16)
            
            propVar := Buffer(24, 0)
            ComCall(5, pProps, "Ptr", PKEY, "Ptr", propVar)
            
            if (NumGet(propVar, 0, "UShort") == 31) {
                pStr := NumGet(propVar, 8, "Ptr")
                fullName := StrGet(pStr, "UTF-16")
                
                devices.Push(Trim(fullName))
                
                DllCall("ole32\CoTaskMemFree", "Ptr", pStr)
            }
            
            ObjRelease(pProps)
            ObjRelease(pDevice)
        }
        ObjRelease(pCollection)
    }
    return devices.Length ? devices : ["Speakers"]
}

ToggleControls(*)
{
    global typeDDL, actionBtn, valueEdit, valueAudioDDL, recording, pressTypeDDL, delayText, delayEdit
    type := typeDDL.Text
    pType := pressTypeDDL.Text

    if (pType = "Double" || pType = "Hold") {
        delayText.Visible := true
        delayEdit.Visible := true
    } else {
        delayText.Visible := false
        delayEdit.Visible := false
    }

    if (type = "Change Output Device") {
        valueEdit.Visible := false
        valueAudioDDL.Visible := true
    } else {
        valueEdit.Visible := true
        valueAudioDDL.Visible := false
    }

    if (type = "Launch App") {
        actionBtn.Visible := true
        actionBtn.Text := "Browse"
    } else if (type = "Macro") {
        actionBtn.Visible := true
        actionBtn.Text := recording ? "Stop" : "Record"
    } else if (type = "Change Output Device") {
        actionBtn.Visible := true
        actionBtn.Text := "Devices"
    } else if (type = "Open URL") {
        actionBtn.Visible := true
        UpdatePasteButton()
    } else {
        actionBtn.Visible := false
    }
}

LoadExistingConfig(*)
{
    global configFile, targetKey, typeDDL, valueEdit, valueAudioDDL, pressTypeDDL, audioDevices, delayEdit
    global holdDelay, doubleDelay 

    typeDDL.Choose(0)
    valueEdit.Value := ""
    valueAudioDDL.Choose(0)
    delayEdit.Value := ""

    selectedPress := pressTypeDDL.Text

    ; Always fill the delay box with the current global delay so it is never blank
    if (StrLower(selectedPress) = "hold")
        delayEdit.Value := String(Integer(Number(holdDelay) * 1000))
    else if (StrLower(selectedPress) = "double")
        delayEdit.Value := String(Integer(Number(doubleDelay) * 1000))

    if !FileExist(configFile) {
        ToggleControls()
        return
    }

    Loop Read configFile
    {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line,1,1) = ";")
            continue

        parts := StrSplit(line, "|")

        ; Fill in the action info for the selected press type
        if (parts.Length >= 4 && parts[1] = targetKey && StrLower(parts[2]) = StrLower(selectedPress))
        {
            typeCode := StrLower(Trim(parts[3]))
            val := Trim(parts[4])

            if (typeCode = "audio") {
                typeDDL.Text := "Change Output Device"
                for index, devName in audioDevices {
                    if (Trim(RegExReplace(devName, "\s*\([^)]*\)")) = val) {
                        valueAudioDDL.Choose(index)
                        break
                    }
                }
            } else {
                if (typeCode = "app") 
                    typeDDL.Text := "Launch App"
                else if (typeCode = "url")
                    typeDDL.Text := "Open URL"
                else if (typeCode = "macro")
                    typeDDL.Text := "Macro"
                
                valueEdit.Value := val
            }
            break
        }
    }
    
    ToggleControls()
}

SaveConfig(*)
{
    global typeDDL, valueEdit, valueAudioDDL, configFile, targetKey, pressTypeDDL, delayEdit
    global holdDelay, doubleDelay

    selectedPress := pressTypeDDL.Text
    typeText := typeDDL.Text
    delayVal := delayEdit.Value
    
    if (typeText = "Change Output Device") {
        type := "audio"
        value := Trim(RegExReplace(valueAudioDDL.Text, "\s*\([^)]*\)"))
    } else {
        value := valueEdit.Value
        if (typeText = "Launch App") 
            type := "app"
        else if (typeText = "Open URL") 
            type := "url"
        else if (typeText = "Macro") 
            type := "macro"
        else 
            type := ""
    }

    isDeleting := (type = "" || value = "")

    ; Update global memory delays if changed by user
    if (StrLower(selectedPress) = "hold" && delayVal != "") {
        holdDelay := String(Number(delayVal) / 1000)
    } else if (StrLower(selectedPress) = "double" && delayVal != "") {
        doubleDelay := String(Number(delayVal) / 1000)
    }

    ; Format the global delay lines perfectly
    delayHoldLine := "delay|hold|" . String(Integer(Number(holdDelay) * 1000))
    delayDoubleLine := "delay|double|" . String(Integer(Number(doubleDelay) * 1000))

    newContent := delayHoldLine "`n" delayDoubleLine "`n"

    if FileExist(configFile) {
        Loop Read configFile {
            line := Trim(A_LoopReadLine)
            if (line = "")
                continue
            parts := StrSplit(line, "|")
            
            ; Skip existing delay lines because we put the fresh ones at the top
            if (StrLower(Trim(parts[1])) = "delay")
                continue
                
            ; Skip the shortcut we are modifying/deleting
            if (parts.Length >= 4 && parts[1] = targetKey && StrLower(parts[2]) = StrLower(selectedPress))
                continue
                
            newContent .= line "`n"
        }
    }

    if (!isDeleting) {
        newContent .= targetKey "|" selectedPress "|" type "|" value "`n"
    }

    FileDelete(configFile)
    FileAppend(newContent, configFile)
    
    msg := isDeleting ? selectedPress " Shortcut Cleared." : "Shortcut Updated"
    Reload()
    MsgBox(msg, "Shortcut Manager")
}

ClearFields(*)
{
    global typeDDL, valueEdit, valueAudioDDL, delayEdit
    typeDDL.Choose(0)
    valueEdit.Value := ""
    valueAudioDDL.Choose(0)
    delayEdit.Value := ""
    ToggleControls()
}

ActionButton(*)
{
    global typeDDL
    type := typeDDL.Text
    if (type = "Launch App")
        BrowseApp()
    else if (type = "Macro")
        ToggleRecording()
    else if (type = "Change Output Device")
        OpenAudioDevices()
    else if (type = "Open URL")
        PasteOrClear()
}

BrowseApp(*)
{
    global valueEdit
    file := FileSelect(1,, "Select Application", "Programs (*.exe)")
    if (file != "")
        valueEdit.Value := file
}

ToggleRecording(*)
{
    global recording, recorded, valueEdit, actionBtn
    if (!recording)
    {
        recording := true
        recorded := ""
        valueEdit.Value := ""
        actionBtn.Text := "Stop"
        InstallKeyHooks()
    }
    else
    {
        RemoveKeyHooks()
        recording := false
        actionBtn.Text := "Record"
    }
}

InstallKeyHooks()
{
    Loop 254
    {
        key := GetKeyName("vk" Format("{:02X}", A_Index))
        if (key != "")
            try Hotkey("*~" key, RecordKey, "On")
    }
}

RemoveKeyHooks()
{
    Loop 254
    {
        key := GetKeyName("vk" Format("{:02X}", A_Index))
        if (key != "")
            try Hotkey("*~" key, RecordKey, "Off")
    }
}

RecordKey(ThisHotkey)
{
    global recorded, valueEdit, actionBtn
    if InStr(ThisHotkey, "LButton")
    {
        MouseGetPos ,, &win, &ctrl
        if (ctrl = actionBtn.Hwnd)
            return
    }
    key := SubStr(ThisHotkey,3)
    mods := ""
    if GetKeyState("Ctrl")
        mods .= "^"
    if GetKeyState("Alt")
        mods .= "!"
    if GetKeyState("Shift")
        mods .= "+"
    if (GetKeyState("LWin") || GetKeyState("RWin"))
        mods .= "#"
    if RegExMatch(key,"^[A-Z0-9]$")
        recorded .= mods . StrLower(key)
    else
        recorded .= mods . "{" key "}"
    valueEdit.Value := recorded
}

OpenAudioDevices(*)
{
    path := A_ScriptDir "\audio\SoundVolumeView.exe"
    
    if FileExist(path) {
        Run('"' path '"', A_ScriptDir "\audio")
    } else {
        MsgBox("SoundVolumeView.exe could not be found!`n`nExpected Location:`n" path, "File Missing", "IconX")
    }
}

PasteOrClear(*)
{
    global valueEdit
    if (valueEdit.Value = "")
        valueEdit.Value := A_Clipboard
    else
        valueEdit.Value := ""
    UpdatePasteButton()
}

UpdatePasteButton()
{
    global actionBtn, valueEdit
    if (valueEdit.Value = "")
        actionBtn.Text := "Paste"
    else
        actionBtn.Text := "Clear"
}