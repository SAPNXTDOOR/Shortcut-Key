# AHK Shortcut Manager

A lightweight, portable **AutoHotkey v2** application that transforms a single key on a  keyboard into a powerful multi-action macro button.


---

# ✨ Features

### 🧠 Hardware State

Reliably detects:

* **Single Press**
* **Double Press**
* **Long Hold**

All from **one physical key**.

### ⚡ Custom Configurable Actions

#### 🚀 Launch App

Open any executable, file, or document.

#### 🌐 Open URL

Launch websites instantly in your default browser.

#### ⌨️ Macro Recording

Record and replay complex keyboard combinations including:

* `Ctrl`
* `Shift`
* `Alt`
* `Win`

#### 🔊 Change Output Device

Instantly switch Windows audio output devices using NirSoft's **SoundVolumeView**.

### 🖥 Dynamic GUI

A built-in graphical interface accessible from the **System Tray** to:

* Edit shortcuts
* Configure press types
* Adjust timing delays
* Toggle admin/startup settings

---

# 🚀 Installation & Setup

To modify the script and use it on any key on your keyboard, follow these steps.

---

# Prerequisites

Install the following tools:

* **AutoHotkey v2**
  https://www.autohotkey.com/

---

# Step !: Configure the Target Key

Open **`final.ahk`** and locate this line near the top:

```ahk
global targetKey := "NumpadMult"
```

Replace `"NumpadMult"` with the name of the key of your choice.

You can find all AutoHotkey key names here: https://www.autohotkey.com/docs/v2/KeyList.htm

---
```

Directory structure example:

```
ShortcutManager
 ├── ShortcutManager.exe
 ├── config.txt
 ├── settings.ini
 └── audio
     └── SoundVolumeView.exe
```

---

# Step 4: Compile to Portable `.exe`

To run the app on **any PC without installing AutoHotkey**:

1. Open **Start Menu**
2. Launch **AutoHotkey Dash**
3. Click **Compile**

Then:

1. Select your file:

```
final.ahk
```

2. Choose the correct base file:

```
AutoHotkey64.exe
```

3. Click **Convert**

This will generate a standalone executable.

---

# Cleanup

Once compiled, you can delete:

```
*.ahk
```


Directory structure:

```
ShortcutManager
 ├── ShortcutManager.exe
 ├── config.txt
 ├── settings.ini
 └── audio
     └── SoundVolumeView.exe
```


# 🖱 Usage

1. Run the compiled:

```
ShortcutKey.exe
```

2. Locate the **green "H" icon** in the Windows system tray.

3. Open the GUI:

* Double click the tray icon
  or
* Right click → **Edit Shortcut**

4. Choose your **Press Type**

```
Single
Double
Hold
```

5. Select the **Action Type**

Examples:

```
Launch App
Open URL
Macro
Change Output Device
```

6. Enter the action value and click **Save**.

---

# 📦 Example Config

```
NumpadMult|single|app|notepad.exe
NumpadMult|double|url|https://google.com
NumpadMult|hold|audio|Headphones
```

---

# 💡 Use Cases

* Dedicated **streaming macro button**
* **Audio device switching**
* **Video editing shortcuts**
* **Accessibility tools**

---

# 🛠 Built With

* **AutoHotkey v2**
* **SoundVolumeView (NirSoft)**

