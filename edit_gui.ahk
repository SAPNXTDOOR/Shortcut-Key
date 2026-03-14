#Requires AutoHotkey v2.0
#SingleInstance Force

configFile := A_ScriptDir "\config.txt"
targetKey := "NumpadMult"

recording := false
recorded := ""
ignoreNextClick := false

types := ["Launch App","Open URL","Macro","Change Output Device"]
pressTypes := ["Single", "Double", "Hold"]

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

audioDevices := GetAudioOutputDevices()

myGui := Gui("-Resize -MaximizeBox -MinimizeBox","Edit Shortcut")

myGui.AddText("xm","Press Type")
pressTypeDDL := myGui.AddDropDownList("w200 Choose1", pressTypes)
pressTypeDDL.OnEvent("Change", LoadExistingConfig)

myGui.AddText("xm","Type")
typeDDL := myGui.AddDropDownList("w200", types)
typeDDL.OnEvent("Change", ToggleControls)

myGui.AddText("xm","Value")
valueEdit := myGui.AddEdit("w260")
valueAudioDDL := myGui.AddDropDownList("xp yp w260 Hidden", audioDevices)

actionBtn := myGui.AddButton("x+m yp w120 Center Hidden","Action")
actionBtn.OnEvent("Click", ActionButton)

saveBtn := myGui.AddButton("xm w100", "Save")
saveBtn.OnEvent("Click", SaveConfig)
clearBtn := myGui.AddButton("x+m w100", "Clear")
clearBtn.OnEvent("Click", ClearFields)

WinSetStyle("-0x10000", myGui.Hwnd)
myGui.Show("Hide") 
myGui.GetClientPos(,, &guiWidth)
totalButtonsWidth := 210 
startX := (guiWidth - totalButtonsWidth) / 2
saveBtn.Move(startX)
clearBtn.Move(startX + 110)

LoadExistingConfig()
myGui.Show()

ToggleControls(*)
{
    global typeDDL, actionBtn, valueEdit, valueAudioDDL, recording
    type := typeDDL.Text

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
    global configFile, targetKey, typeDDL, valueEdit, valueAudioDDL, pressTypeDDL, audioDevices

    typeDDL.Choose(0)
    valueEdit.Text := ""
    valueAudioDDL.Choose(0)

    if !FileExist(configFile)
        return

    selectedPress := pressTypeDDL.Text

    Loop Read configFile
    {
        line := Trim(A_LoopReadLine)
        if (line = "" || SubStr(line,1,1) = ";")
            continue

        parts := StrSplit(line, "|")

        if (parts.Length >= 4 && parts[1] = targetKey && parts[2] = selectedPress)
        {
            typeCode := parts[3]
            val := parts[4]

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
                
                valueEdit.Text := val
            }
            break
        }
    }
    ToggleControls()
}

SaveConfig(*)
{
    global typeDDL, valueEdit, valueAudioDDL, configFile, targetKey, pressTypeDDL

    selectedPress := pressTypeDDL.Text
    typeText := typeDDL.Text
    
    if (typeText = "Change Output Device") {
        type := "audio"
        value := Trim(RegExReplace(valueAudioDDL.Text, "\s*\([^)]*\)"))
    } else {
        value := valueEdit.Text
        if (typeText = "Launch App") 
            type := "app"
        else if (typeText = "Open URL") 
            type := "url"
        else if (typeText = "Macro") 
            type := "macro"
        else 
            type := ""
    }

    newContent := ""
    isDeleting := (type = "" || value = "")

    if FileExist(configFile) {
        Loop Read configFile {
            line := Trim(A_LoopReadLine)
            if (line = "")
                continue
            parts := StrSplit(line, "|")
            if (parts.Length < 4 || parts[1] != targetKey || parts[2] != selectedPress)
                newContent .= line "`n"
        }
    }

    if (!isDeleting)
        newContent .= targetKey "|" selectedPress "|" type "|" value "`n"

    FileDelete(configFile)
    FileAppend(newContent, configFile)
    
    msg := isDeleting ? selectedPress " Shortcut Cleared." : "Shortcut Updated"
    MsgBox(msg, "Shortcut Manager")
}

ClearFields(*)
{
    global typeDDL, valueEdit, valueAudioDDL
    typeDDL.Choose(0)
    valueEdit.Value := ""
    valueAudioDDL.Choose(0)
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
        valueEdit.Text := file
}

ToggleRecording(*)
{
    global recording, recorded, valueEdit, actionBtn
    if (!recording)
    {
        recording := true
        recorded := ""
        valueEdit.Text := ""
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
    valueEdit.Text := recorded
}

OpenAudioDevices(*)
{
    path := A_ScriptDir "\audio\SoundVolumeView.exe"
    if FileExist(path)
        Run(path)
    else
        MsgBox("SoundVolumeView not found", "Error", "Iconx")
}

PasteOrClear(*)
{
    global valueEdit
    if (valueEdit.Text = "")
        valueEdit.Text := A_Clipboard
    else
        valueEdit.Text := ""
    UpdatePasteButton()
}

UpdatePasteButton()
{
    global actionBtn, valueEdit
    if (valueEdit.Text = "")
        actionBtn.Text := "Paste"
    else
        actionBtn.Text := "Clear"
}