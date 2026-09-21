# Lorewalking Helper

Lorewalking Helper is an app for helping with the LOA Lorewalking quest. 

## Requirements

- Windows 10 or 11
- A World of Warcraft account
- PowerShell 5.1+
- Optional: Raspberry Pi Pico for hardware input (Recommended)

## Installation

1. Download or copy the full project folder to a location on your PC.
2. Right click the zip file and unblock files if needed
3. Extract the zip 
4. Launch the GUI via the included shortcut  

Notes: If the app detects your World of Warcraft install, it will use it automatically. If it does not detect it, set the WoW install path manually in the settings menu

The app will check the addon folder and will copy the addon into your WoW `Interface\AddOns` folder when needed.

## Addon setup

Before starting:
1. Launch WoW
2. Configure settings in the app menu
3. Set the in-game keybinds to match the ones configured in the app's settings.
4. Move the Addon window into the bottom left/middle/right to match the same as you set in the settings. 

In-game commands:
use `/lw` to see in-game addon commands.
**Primary Keybind** is required, the others are optional but must match the keybinds set in the app settings.

## Settings
Most are self-explanatory and have app tool-tips if you hover over a setting.
- Make sure keybinds set in the addon are the same ones you set in the settings menu.
- Auto stop and stop timer
- Auto logout and auto sleep
- WoW install path ('AUTO') usually works, but if not, can browse to your wow folder.
- Raspberry Pi Pico and COM port
- Quest XP modifier (%) (For calculating x rates)
- Primary keybind
- Failsafe keybind
- Logout keybind
- Discord webhook notifications
- Addon screen location
- Window focus behavior

The settings are stored in:
- `config/LorewalkingHelperSettings.json`


## Usage  

1. Make sure addon is enabled, configured and placed correctly in-game
2. Launch the app via the shortcut, configure settings if needed
3. Click Start

## Notes

- Raspberry Pi method is recommended
- For faster load screens, set graphics to 1, disable all other addons except LorewalkingHelper, can also resize the WoW window, just make sure addon screen is legible.
- If your WoW install path is not detected automatically, set it manually.
- If notifications are enabled, make sure your Discord webhook URL is valid.
- The helper is designed to work with the matching addon included in the app. These files will be copied over automatically into your addon folder.
