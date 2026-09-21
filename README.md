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
1. Launch WoW.
2. Configure settings in the app menu
4. Set the in-game keybinds to match the ones configured in the app's settings.

In-game commands:
use `/lw` to see in-game addon commands.
**Primary Keybind** is required, the others are optional but must match the keybinds set in the app settings.

## Settings
Most are self-explanatory:
- Make sure keybinds set in the addon are the same ones you set in the settings menu.
- Auto stop and stop timer
- Auto logout and auto sleep
- WoW install path ('AUTO') usually works, but if not, can browse to your wow folder.
- Use Raspberry Pi Pico and COM port
- Quest XP modifier (%)
- Primary keybind
- Failsafe keybind
- Logout key
- Discord webhook notifications
- Addon screen location
- Window focus behavior

The settings are stored in:
- `config/LorewalkingHelperSettings.json`

## Notes

- If you use a Raspberry Pi Pico, set `Use Raspberry Pi Pico for input` and fill in the correct COM port.
- If your WoW install path is not detected automatically, set it manually.
- If notifications are enabled, make sure your Discord webhook URL is valid.
- The helper is designed to work with the matching addon files included in the app These files will be copied over automatically into your addon folder.
