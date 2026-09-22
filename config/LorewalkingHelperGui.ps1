####################################################
###            Lorewalking Helper Gui            ###
####################################################
# Requirements:                                    #
#   - World of Warcraft Account                    #
#   - Windows 10/11                                #
# Info:                                            #
#   - https://github.com/Glacerr/LoreWalkingHelper #
####################################################

# This script is designed to be called together with the LorewalkingHelper.ps1 script.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Dark "midnight" theme colors, defined up top since Show-Popup (used for early startup errors) needs them
$bgDark     = "#1E1E2E"
$panelDark  = "#17171C"
$borderDark = "#2A2A30"
$textLight  = "#E6E6E6"
$accent     = "#F5A623"
$stopColor  = "#3A3A3E"

if (-not ("LorewalkingWindowChrome" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class LorewalkingWindowChrome
{
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int valueSize);
}
"@
}

function Enable-DarkTitleBar {
    param([System.Windows.Window]$Window)

    $Window.Add_SourceInitialized({
        $darkMode = 1
        $windowHandle = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        [void][LorewalkingWindowChrome]::DwmSetWindowAttribute($windowHandle, 20, [ref]$darkMode, 4)
    }.GetNewClosure())
}

# Themed replacement for [System.Windows.MessageBox]::Show(), styled to match the main window.
# Self-contained (no dependency on controls/images defined later in the script) so it can also be
# used for early startup errors, eg: before $window or $logoImage exist yet.
function Show-Popup {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Title = "Lorewalking Helper",
        [ValidateSet('Info', 'Warning', 'Error')][string]$Icon = 'Info'
    )

    $popup = New-Object System.Windows.Window
    $popup.Title                = "Lorewalking Helper"
    $popup.SizeToContent         = "WidthAndHeight"
    $popup.MaxWidth              = 480
    $popup.ResizeMode            = "NoResize"
    $popup.Background            = $bgDark
    $popup.Foreground            = $textLight
    $popup.FontFamily            = "Segoe UI"
    $popup.FontSize              = 13
    if ($window) { $popup.Owner = $window }
    $popup.WindowStartupLocation = if ($popup.Owner) { "CenterOwner" } else { "CenterScreen" }
    if ($logoImage) { $popup.Icon = $logoImage }
    Enable-DarkTitleBar -Window $popup

    $popupRoot = New-Object System.Windows.Controls.StackPanel
    $popupRoot.Margin = New-Object System.Windows.Thickness(20)
    $popup.Content = $popupRoot

    $iconGlyphs = @{ Info = [char]0xE946; Warning = [char]0xE7BA; Error = [char]0xEA39 }
    $iconColors = @{ Info = $accent; Warning = $accent; Error = "#E05555" }

    $headingText = New-Object System.Windows.Controls.TextBlock
    $headingText.Text = $Title
    $headingText.FontWeight = "Bold"
    $headingText.FontSize = 15
    $headingText.Foreground = $accent
    $headingText.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
    [void]$popupRoot.Children.Add($headingText)

    $messageRow = New-Object System.Windows.Controls.StackPanel
    $messageRow.Orientation = "Horizontal"
    $messageRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 20)

    $iconText = New-Object System.Windows.Controls.TextBlock
    $iconText.Text = $iconGlyphs[$Icon]
    $iconText.FontFamily = "Segoe MDL2 Assets"
    $iconText.FontSize = 28
    $iconText.Foreground = $iconColors[$Icon]
    $iconText.VerticalAlignment = "Center"
    $iconText.Margin = New-Object System.Windows.Thickness(0, 0, 14, 0)
    [void]$messageRow.Children.Add($iconText)

    $messageText = New-Object System.Windows.Controls.TextBlock
    $messageText.Text = $Message
    $messageText.Foreground = $textLight
    $messageText.TextWrapping = "Wrap"
    $messageText.MaxWidth = 380
    $messageText.VerticalAlignment = "Center"
    [void]$messageRow.Children.Add($messageText)

    [void]$popupRoot.Children.Add($messageRow)

    $okBtn = New-Object System.Windows.Controls.Button
    $okBtn.Content             = "OK"
    $okBtn.Width               = 90
    $okBtn.Height              = 32
    $okBtn.Background          = $accent
    $okBtn.Foreground          = "#000000"
    $okBtn.FontWeight          = "Bold"
    $okBtn.Cursor              = [System.Windows.Input.Cursors]::Hand
    $okBtn.HorizontalAlignment = "Right"
    $okBtn.IsDefault           = $true
    [void]$popupRoot.Children.Add($okBtn)
    $okBtn.Add_Click({ $popup.Close() }.GetNewClosure())

    [void]$popup.ShowDialog()
}

# Var's and paths
Try {
    $scriptRoot = if ($PSScriptRoot) {
        $PSScriptRoot
    } elseif ($MyInvocation.MyCommand.Path) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        # Fallback to current working directory
        $psEditor.GetEditorContext().CurrentFile.Path | Split-Path -Parent
    }
} Catch {
    Show-Popup -Message "Could not determine script root. Run this script from the same directory as LorewalkingHelper.ps1." -Title "Error" -Icon "Error"
    return
}

$settingsFile          = Join-Path $scriptRoot "LorewalkingHelperSettings.json"
$loreWalkingScriptFile = Join-Path $scriptRoot "LorewalkingHelper.ps1"
$addonPath             = Join-Path $scriptRoot "Addon" "LorewalkingHelper"

# Default values
function Get-DefaultSettings {
    return @{
        AutoStop             = $True
        AutoStopTime         = 300
        AutoLogout           = $False
        AutoSleep            = $False
        LoadingTime          = 10

        UseWindowFocus       = $False
        UsePi                = $False
        PicoComPort          = "AUTO"
        WowInstallPath       = "AUTO"

        PrimaryKeybind       = "F12"
        FailsafeKeybind      = "F11"
        Logout               = "F10"
        EnableFailsafe       = $False

        EnableNotifications  = $False
        DiscordWebhook       = "Your Discord Webhook Here"
        OnStart              = $True
        OnStop               = $True
        OnError              = $True
        OnLevelUp            = $True

        WindowTitle          = 'World of Warcraft'
        AddonScreenLocation  = "BOTTOMLEFT"
        UseMyOwnCoordinates  = $False
        TopLeftX             = 0
        TopLeftY             = 0
        BottomRightX         = 0
        BottomRightY         = 0
    }
}

# Load settings from the file, filling in any missing keys (eg: new settings, or no file yet) with defaults
function Import-Settings {
    $merged = Get-DefaultSettings
    if (Test-Path $settingsFile) {
        try {
            $loaded = Get-Content $settingsFile -Raw | ConvertFrom-Json
            foreach ($prop in $loaded.PSObject.Properties) {
                $merged[$prop.Name] = $prop.Value
            }
        } catch {
            Show-Popup -Message "Error loading settings: $_" -Title "Error" -Icon "Error"
        }
    }
    return $merged
}

# Save settings to file
function Export-Settings {
    param (
        [hashtable]$settings
    )
    try {
        $json = $settings | ConvertTo-Json -Depth 3
        Set-Content -Path $settingsFile -Value $json -ErrorAction Stop
        #Show-Popup -Message "Settings Saved"
    } catch {
        Show-Popup -Message "Error saving settings: $_" -Title "Error" -Icon "Error"
    }
}

# Install LorewalkerHelper addon
function Install-Addon {
    #check/get install path
    $goodToInstall = $False
    $wowInstallPath = $settings.WowInstallPath
    if ($wowInstallPath -eq "AUTO") {
        $wowInstallPath = 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft'
    }
    if (Test-Path $wowInstallPath) {
        if ($wowInstallPath -eq 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft') {
            $actualInstallPath = (Get-ItemProperty $wowInstallPath -ErrorAction SilentlyContinue).installPath
            if ($null -ne $actualInstallPath) {
                $goodToInstall = $True
            } else {
                Show-Popup -Message "Wow Install path not detected!`nManually set the path in the $lorewalkingScriptFile file and try running this again." -Title "Path Not Found" -Icon "Warning"
            }
        } else {
            $actualInstallPath = Join-Path $wowInstallPath "_retail_"
            $goodToInstall = $True
        }
    } else {
        Show-Popup -Message "Wow Install path not detected!`nManually set the path in the $lorewalkingScriptFile file and try running this again." -Title "Path Not Found" -Icon "Warning"
    }

    if ($goodToInstall -eq $True) {
        if (Test-Path $addonPath) {
            # copy local addon files to wow addon path if they need updating
            $existingAddonLuaHash = Get-FileHash -Algorithm MD5 -Path "$actualInstallPath\Interface\AddOns\LorewalkingHelper\LorewalkingHelper.lua"
            $existingAddonTocHash = Get-FileHash -Algorithm MD5 -Path "$actualInstallPath\Interface\AddOns\LorewalkingHelper\LorewalkingHelper.toc"
            $addonLuaHash = Get-FileHash -Algorithm MD5 -Path "$addonPath\LorewalkingHelper.lua"
            $addonTocHash = Get-FileHash -Algorithm MD5 -Path "$addonPath\LorewalkingHelper.toc"
            if ($addonLuaHash.Hash -eq $existingAddonLuaHash.Hash -and $addonTocHash.Hash -eq $existingAddonTocHash.Hash) {
                return
            } else {
                Copy-Item -Path $addonPath -Destination "$actualInstallPath\Interface\AddOns" -Recurse -Force
                Show-Popup -Message "Perform a /reload if you already have WoW running." -Title "Addon files updated!" -Icon "Info"
            }
        } else {
            Show-Popup -Message "Check that you downloaded all files for this app." -Title "Addon files not found!" -Icon "Error"
        }
    }
}

# Main window
# x,y or <-->, v^

# built-in logo
# To convert use in pwsh 5.1: [Convert]::ToBase64String((Get-Content -Path .\image.png -Encoding Byte))
$LiLiLogo = @'
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
'@

$gitHubIconBase64Img = @'
iVBORw0KGgoAAAANSUhEUgAAASYAAAEgCAYAAAAZnd7HAAAACXBIWXMAACE4AAAhOAFFljFgAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAABfkSURBVHgB7d39ddTIEgXwa877f00EK0cARLAiAkwEjCPARLDjCIAIGCLARGARgU0EbiLAG8G8LquE5fF8SDMtqbvr/s7R2o/HnrNja+5UV3/oCETecrks/Jdjf7W//qXfH7f+rNH82TZuzfd3ev1qfe+ar0dHR3cg845
AZmj4vEQdMC/0a3PFQoLpRr/+RB1act0wtOxgMGXIB5BUMiUeAqj5PnVNaMn1A3WFdQPKDoMpAz6IpAoqkVcIdbUaVhUrq/QxmBLkg6hEPSR7o1939XqsaYLqO+ohoAMlhcGUAB2azfz1D+qKiEHUj4RU5a/vPqQqUPQYTJHSqqgJohIUigzzLlFXUxz2RYrBFJFWGM1gq080pSakLhlS8WAwTUyn8N+BYRSDBerh3iVoUgymCbR6RtK8LkGxcah7Up+5HGEaDKYR6VBNwmgGNr
BTIcH0GRzqjYrBNDCtjk5RD9dKUKqapvkFlx8Mj8E0EA2k9/46B6uj3FSoA6oCDYLBFJg2syWQZmAg5c6hDqgFKCgGUyC6LaQJJLLFgQEVFIPpQBpIH8H+ETGggnkG2osM2fz1xX97DYYS1Qp/ffH3xa2/ZqC9sWLqSZva/6JuahNt48AKai8Mpo44y0YHcP464yxedwymDnwoyTok6SMVINrfAlwH1QmDaQs2tmkgcx9OF6CN2PxeQ4Zt/pJAYmObhjBng3w7VkwrdD+bzLYVI
BreAhzePcFgUtrclkA6BdG4HDh79wiDCX+a2xJKnG2jKVWoZ+8cjDPdY9Je0jf/rVwMJZpa6a9rf0+aXyNntmJiL4kit4Dh3pO5iqk143YFhhLFa+avK6szd6YqJj2SRIZtL0GUDnPrnswEkw8lOUHyE9hLojQ5f722MrQzMZTTodsCDCVKVwFDQ7usKyYO3ShT2Q/tsg0m3ecmoVSAKD/yYIQPuQ7tsgwmH0pyPMknEOXNIdO+U3Y9Jh9KcogbQ4ksKFAvyMxuG1U2waTrk2TB
5BxEdsiEzjf9QM5GFkM5NrmJ7mXTFE8+mDSUuIqbqLbw4XSGxCUdTJx5I1rrBnVT/A6JSjaYNJSkUuKiSaKnJJzepjpjl2Qw6ckAPKqEaDuHRJcTJDcrp3veWCkR7Vag3sZSIDFJVUwaSgsQUR8OiVVOyQQTQ4noIA4JhVMSwcRQIgrCIZFwij6YdPbtGkQUgkMC4RR187u1JICIwiiQQEM82oqJK7qJBhX1IswoKyaGEtHgml0TUYoumBhKRKMp9USO6MRYMXHvG9F4ZjEemRJ
VMOlDA3h0CdG45rE9/Tea5rem9hxENBVphleIQBTBpEeDRtuIIzJCZuhexbDGafJg0ma3LKDkplyi6TnU4TTpMoJJe0ytGTiGElEcCn9NPlM3dfNbmt0FiCgmp1PP1E02lGOzmyh6kzXDJwkmPYGSe+CI4jZZM3z0oZz2laJcbUpEj0jvd5L36hQ9JnmhBYgoBaUufB7VqMGkfaUSRJSSc22/jGa0HpMO4W6RLhlvu9ZXUejXY/2eyx5su8Pj+6RZC1ToV9luleo94jDi+qYxg0
lCqUC6zvwvZbHtL/jXKDfdy9b1Atz7lys5z+iHfpXL7XrTZrDD4dK/xrcYwSjBlMHSALnpTrAHrRRLvd6AVVWqJHS++quSa9/Kwd8Pv5H2PfDBv/ZPGNjgwZTBEE4Eex68jtVn/noHil0TRpeh1vP437+8qd8jXaMsIRgjmFIfwongC8102CelvVSTBSgmlb8uhlhcmMkaPqkYX2NAgwZTJqu79x7GdaU3K2csp9VUR1Id32BAGQznxM6e6yEGC6ZMhnDiu/8FnGIEDKhJSCB99
tensWac/O9ZKqYSaZOf1clQP7Mh1zHlsuWkwkhk6KAlslwONLQF6n7JfORjPn4ifVLxDbbRd5CKyX8izJDPtpPJNjLqzzGGHlR7TY5b82ebHOPxkKVY+TqVCgP1kLrI7GDEQd4fwYMpw6ecPJ/y0Cz9ec4xzCxeEy7SU/mFxwtI778f8rXra2vCq9DrbzwsVg29Bkxey8UY093bZNTmEIP0YIcIJqmUZsjDjf+hv0IEtHqSPUv7Nk0d6krhp35/k8Iz7PVpzAUeFqw23/cl4fs2
ltfsX9cS+ZCwnyOgoMGU2SeBGHxatI8e1ahUBhVaK5OnPio1pNYK+9Jf/2D3Vo/P/vWfIyKZLKNpDNoIP5j/YV8v8zJpyb+O/286lv+ulf/O3/668pdstgw9/EmCvG59/VcrP5uoAqmx5r8zdUF7yv9DIMt6qJHbmyK6TwD9VJI3oHyVKuESmVVE+9C1R3JJaMvPpUTd/xh0TdIBfiEvM/9z/xqqER4smDDg1OGEHCIVekyfEw3pS8Qtxw8SyYAKAQRZx6TVUoH8OBANI8dgkkP
lSgQQaoFljtUS0ZAc8hQkCw4OpmW9H65AnhyIqI9SR1AHOSiYlvX09QxERA8OrpoOrZhkNXKBTKWwAJGS5ZCv4tCqae9gYrVERFscVDUdUjGdggecEdF6B1VNhwRTyseDEtHw9t54vlcwZbxuiWgsBfK397qmfSsmE+uWtI9GRPvbKyt6BxOrJaIg9j2+JjV7VU37VEx87BDR4awEk+hdNfUKpuXDwxutKEA0DEvBVOqJD531rZis7YkrQDSMv2FLr3OxOgeT0QWVlj7VaFzW7q
33faqmPhVTCXsKEA3D2kmjzeF9nfQJJotHmxQgCkwrB4vVeOdF2Z2CSaf7CtjzAkThmTyXHXUTvOjyF7tWTFaXCBR9ZxOIOrAaTGLW5S91DaYSdlm+iWgYlivxTsO5ncHEld4MJgrO8j113GUleJeK6Q1ss/76KSDtsVj/sDvd9Re2PolX+yu/Qc+tP7eNwtARSNCHQyZo55N7d1VMO5PNiBmIwmAFXi+V2Fo17gom/hDrs5kXIArjDHz6jtg6079xKMdh3D0pNV/xoQQUkn9vS
bVwBdtbnrYO57ZVTCXogqFEofl76sZ/uYBtW4dz24LJ+jBu4W+gTyAagN5bFWzb2MPeNpS7hd31S85fr1kt0ZB06cA17A7p7vx77Pm6/2NtxWR4b1yDQzganN5jlod0GxdbbhrKWV4m4PwNswDRCDikW99n2hRMlvfyvAbRuCxXTWt72U+CSZcJlLBpwSEcjc3fc5X/8hU2rT0PfF3FVMIu61O4NB05E9vqtqcnwzkG0wNWSzQZXWj4GTY96WmvC6Z/YBOrJZqaNMItVk1PetqP
gknHehaPZGC1RJPTqslir+lJn2m1YrJ6TozVxiPFZwGbHmXPajCVsMfprAjR5HQfXQV7tgaTxf4Se0sUG4v3ZNn+H4/2yvlxnhxzYm3fzgn7SxQbg+/FR/vm/lRMekaMtVD6zlCiSFnrex63nznXHsoVsOcSRHGyeG/+6TO1g6mEPQwmipJOyFhb01Q237SDydrG3e988glFztpwrmi+sTyUY7VEsbN2j/4pju5n5Yw+eICzcRQ1fV/KSbKWJqXun+HYVEzWVnzfMJQodtpquIE
thfyjCSZrywSs/bIpXT9gy32RZLVisvbLpnRVsKWQfzTBZG1GjhUTpcLavfq3/MPiUO5ON0oSRU/7TA52mB3KMZQoNZbu2fsiyWLF9BNEafkFOwr5x7P2xjkjHIjSYqrKl0ySiqmALRzKUWocbLkPJmtrmLg/jlLjYIvJismBKCEGdykcm6uYeKIAJcrSfXtsrWJyIEqTpWD6W4LpL9jBaolSZeretTaUYzBRqizdu8UzEBFFxuKsHBHFjRUTEcWHwURE0eFQjohic2ytYrK2/Y
YoRQwmokQUMITBRJQGW1vHlh4MOfJAlBhr71Nzs3IGD8ajxFm8Zy0uFyhAlJYCxjCYiOJXwBiLwWTt4Z6UPnP3rASTgy0FiNJi7YG0zmLFZO2XTOkrYIzJHpOf5eB6JkqC3qsFjJFgsnh4WgmiNJSwxzGYiOJWwiAJJkuPH26wz0SpsHiv/mf1PKaSfSaKnd6jJez5bXG5QKMEUdxK2PTLao9JlCCK2xvYdGc5mN6BKG6nsOnO8lDu2I/hSxBFyN+bEkpW+6DOcjAJq59IFD+rw
zhxd6Sd/9+wSYaxJ0dHR3xCL0VDz1+6hV3Pn+mb0uobU0J5BqK4lLDrTjKpWcfkYJflkpni9C/supF/NMH0E3aVbIJTLLTpXcCu/+QfTTBZ77FY/oSiuLyHbY8qphvYxqqJJqf3YAnbnPyDwfSAVRNNjffgSjA5EKsmmoz2lkrQfZH05+GP/gcj6yYK2Fb5qcrXIBoZ33/3ZKnAc/mmfewJh3OsmmgC/p6bgaEk/mRQO5gsHhi3zhee1URj0VXe7C3V/ixbYsX0VOGvcxCNQ0Kp
AImq+abdYypge3/OKtlD50A0EB3CfQE1Xvn33OPmt/A/KNnMy2FM7cb/kF6BaABaCFyB1VLjT+NbrJ75zeHcg5f+5vkIomFwCPfYo+xZDSbLe+bWOecsHYXm7ynZdjIDtT3KntVgqkCrvmjZTXQwvZc+gVZV7f/BYNqtABuUFECrr0RPbR7K6aFx7DM9VbLfRIfQtXHfwL7SOjerM+DrHnj5A7SO9Ju4EI72JR9sL0HrPCmG1gVTBdpk7sOJj32iXvQDbQba5PvqHxyt/oHxhxN
09dqXnhWIdtBQmoO2Odk5lNM+UwXa5pu/4ViW01YMpU5u1u2weLbhL7PPtJ1UlVcMJ9qEodTZ2qzZFEwVaJcmnNhzokf8PSHLS+agLi7X/eHRpr/NfXO9fPDlKBfNGddaElCCuni0P67t2ZZ/6Suoq49cSmCbLp68BkOpj40to23BdAnqQ5YSfOQhc/bofkoJpQLUx8aM2TaUkzeYnM/EN1o/DvVyAgfKHpvcB3muqwCe2Fgx6b/wHdRX4a9rPQSMMiVDN3/Jvrc5aB/VplAS24
ZyYgHah1SZXzi0y5M+aon9pMNs7WEfbfs/OZwLwvnrjCvF06cNblkKUIIOtfXo6q0Vk5ZanJ07TIF6vRPPdUqYHu7GKimM77t6sLuGcoKzc2HMUAfUDJQMmXHzlwSSrFPjyCGMnZlyhA642DI4Bw7voqZLAGTGrQSF5Px9f7LrL3WpmMRnUEgFOLyLks62SR9JZtxKUGhVl7/UtWLiUSjDWvjrgmufpsMKaTSdjgzqFExC12yUiI9DfQKeNOr/0z/7C3VVIoGa0gkAFeqAqkCjY
CCNqtMwTvQJJlm78Q3Ta86LktnCrYu0hA6VSn+98dcp0uD8dYH69TlQUDoCkFm2c7B3Oibpqy66/MXOwSQiaIJLr2u+K4w20ZCa+yulo0oW/vrKKuowGkYz1B9QJWgKJ10/aPsG0xx12Ts2CaK3od6ciQaUg1aKDKlu9PcsVTLDaHoLf9+edf3LfYNpqib4K/+igj9WStcUpfioZglqWQsix0ZwuKf0/pSeYjNsL0CxOOlzn/YKJuF/+QuMW2nIKtHBekOZbDO40Us2XbshQjxG
rf7hC/2a0kSHJfLh+brPv7BPMJUY92miMks1x8D865KVve+Rh+bBpXL9ar7ftzc3NT1bvdBLQqj532xcp6Fz07vRO5jEyEsHPvsXdY4RTNhDG0uFuleXVEC1Hq1dgFLTeYlAW9eV36suMJ53Yz2NRCuzMV/bmKRqSi6UhPQm9ObmDoT07PV+2iuYdFaowjikXL/W7RslBpZpOMmar9epDuUaWjnn+sGRI9d3CNfYaygnJug1tTU9lGaRpUNgGfWcZHnBDBkxMOTOxdnowSQi2qa
ywAB7zSLehtNVdqHUYDhFb6/eUuPQYCoxXdW0yqEOpwUC0XUxqT79QmbhXiFjmc2k5ubskPfiQcEkIqwqZMtKsD6ENt7lNaY0NS3D3OR7Sl1kUNXm6KBqSew7K9cWWzNy7m/WYMsLdLFiSg1XM6GkZJuDA8Xk4PfLwRWTiPRTK+g2Fv8a5WSFwVagB+Jg8Jl2kbUUrDu4WhIhKiYRY0XxLfCjk2L/ZHYw+qBNXb7yFRSDIFkQJJj0xrhEXArU5+0EoUOjzrujR+bAp//K79rK8D
VWe69bWhWqYhIfEN+N8T7kmdoawLFVhw4MpeaDgyvDpxXsgztYMOkbI7YbQ4ZyQde66MrwWIYNDgylNlk+wKppGoujgOeEBWl+NyJe9/M85CyVvk5ptk55zIYDQ+kJnZH9CBrbSch7MeRQrimnPyA+QU8n0Nf5FtM1w5slAQ60agFWTWO7CH0vBq2YGhEuH5Ab9ST02p6JjuOQSYYzQ+uUeuN2lVEFWR6wKmjF1CJNsJjeOM1B9EHpp4SczBdsvdQO8smU5NElI/sEGssgk0GDB
FOkjfA3GICeFSR70oacrXOoh25z0E4a3BVoaIuQe1PbBhnKNXxJLY3wKRvEqzo9BXRfugJZzg8vEM5Bj6yySh808QU0FIcB+5xDDeUasTXCB+07SOjpeDvEKvEK9S/+nKG0F+nF8ec2nIujASdfBq2YRIRHUwxaNbXp04vl+ge7q6jm8Dt50smCYXQ4njwwmN5PPelrjGCKYc1P2+A/1HVazzwrVv6v+0Di1H94XNM0CIcRlqoMHkxCzzS6RjxGq5poOrqc4xYU0tlQDe+2oXtM
9/T4kZj6TVzjYoB+qnNIHM5ijFASowST8C9Iek0V4lCO8cQVikIFCsFhxA3sowWTimnhJasmG36AQjgbsw86ajDpC3uLOJQhj+ClaDnQoS7G7smO0vxeFdESgkH20FE82AA/2CRP25kkmEREa0wuZf8ZKFv+XluC9uEw0SkWY/eY2mI5Q/tUF0JSvhxoH2dHE62vmyyYIus3fQl5BC9Fh0P1/kbvK7VNWTHFtL5JVmV/A+XKgfpYTH2SxaTBJHR9UwxHpLz0VRO3L+TpP1BXDhE
UC5MHk5Ad9Ijj8U/nXEJAhjlE8hTnKIJJxdIM/+jD6R0oJw60y/059rFsJo8mmDSlZde/w/QWDCcy5oP2fKMQU8XUPkM7hlkUhhNZcTHW5tyuogomEWE4cU8d5exi6hm4daILJhHZMSlzztZRpj7HGEoiymASWloGexb6gWS27paLMCkjlzobHqVog0loOI12BswOhb9uObSjDMiIJJYP/bWiDiahpWYs4STmWj3NQJSe5vHyUW/TiT6YRIThVKDeX8eAopQkEUoiiWASEYaTKP
AQUB+H7kHJk1ZkZbocGcOjgamnZEJJJBNMItJwEoW/pJEoAXWtIXWqj2w6iDxhpgkj1AeeyQxhCaLukgol8T8kRsLJv0kd4n3880u97mc8/H+r3BTNwyx/6fduw79boD7p4AUenkF3cLiRacmFkkgumITM1vk3vPygJZxif+M2D/osQTSur/5K8hHzSQ3l2vwPW04jiGVvHVFsvvr3yCzFUBLJBpPQFeIMJ6LHZJvJDAlLOphEa2+dAxFFufetr+SDSWg4ySNmYjhsjmgKMmQ7y
yGURBbBJGQsrY9hinE5AdGQHOqZtwUykU0wNfQTI5aTCYiG1iwHiOaQtxCyCyahDzg4AftOlDdZDjDJAymHlmUwiVZTnH0nytGHlJcD7JJtMAkJJ/adKDMOdZX0CRnLOpga2nfikgJKXYU6lCpkzkQwCf1lSjh9BVF6ZOiWZT9pHTPBJHRoNwNn7SgdDgaGbqtMBVODs3aUiM/+emVh6LbKZDAJrZ4knNgYp9g0T8VN8mSAEMwGU0Mb46yeKBayvOVET88wy3wwiVb1JL0nk59Q
NDmHukp6a7VKamMwtWjvSTYDc+aOxtT0krgYWDGYVrRm7mRhpgPRcCrUM25me0mbMJg2kE+v1vDOgSgcCaFmXVIFeoLBtIMO77gwk0KRYduJtXVJfTGYOmgN76SCiiWgWPp35zC9CnUgcdjWAYOph5WAqjCdu9zO3xmYw3Qq1H0kM9tJaGLyNFx9Ku7YOHvTw7J+gvHv5biulnxaMk1pWQfUYjmeEtSL/5l9Wo7jir8fioq/IYvl8AF1DeptWX94DOlqyUCimC0fAup2GZYMRwr
QXpbDVE1XSwYSpcbftDN/XS8PJ6H0EnSQgL+Lub9ifzw90XbLhz7UPk3YW4ZSGMu6Ef5tuZ8rf50zkCg7+saYLbvN5vGTeSD6O7jt+DuQIWAJGs0RaDLLul9U+kuqoRf6x7L47hfq9S8VF+MNSwPnFA8/f+H89dNfN9wyQkRERERERNTJ/wFvpgex5tgiLAAAAABJRU5ErkJggg==
'@

# decode base64 images
function DecodeBase64Image {
    param ([Parameter(Mandatory=$true)][String]$ImageBase64)
    $ObjBitmapImage = New-Object System.Windows.Media.Imaging.BitmapImage #Provides a specialized BitmapSource that is optimized for loading images using Extensible Application Markup Language (XAML).
    $ObjBitmapImage.BeginInit() #Signals the start of the BitmapImage initialization.
    $ObjBitmapImage.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($ImageBase64) #Creates a stream whose backing store is memory.
    $ObjBitmapImage.EndInit() #Signals the end of the BitmapImage initialization.
    $ObjBitmapImage.Freeze() #Makes the current object unmodifiable and sets its IsFrozen property to true.
    $ObjBitmapImage
}

#images - used directly as WPF ImageSource, no System.Drawing conversion needed
$logoImage = DecodeBase64Image -ImageBase64 $LiLiLogo
$gitImage  = DecodeBase64Image -ImageBase64 $gitHubIconBase64Img


# Load existing settings
$settings = Import-Settings
# Install latest Addon
Install-Addon

#region Embedded console / runner
# LorewalkingHelper.ps1 emits one JSON line per event to stdout instead of default ps1 console
# text; this queue buffers those lines so the DispatcherTimer can safely apply them on the UI thread.
# The app still runs as a hidden Windows PowerShell (powershell.exe) process rather than an
# in-process runspace, because its Windows OCR/WinRT calls only resolve reliably under Windows
# PowerShell (Desktop/.NET Framework) - they fail when hosted inside PowerShell 7/pwsh (.NET Core).
$script:LogQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$script:proc     = $null
$script:stdoutReader = $null
$script:stderrReader = $null
$script:lastLineOpen = $false

function Get-Brush {
    param([string]$Name)
    try { return (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Name) }
    catch { return [System.Windows.Media.Brushes]::Gainsboro }
}

# Appends a colored line to the log, trimming old lines once the log gets too long.
# -NoNewline keeps appending to the same line (eg: a countdown); a leading `r overwrites
# the still-open line in place (simulates a terminal carriage return, eg: a progress message).
function Add-LogLine {
    param(
        [string]$Text = "",
        [string]$Color = "White",
        [switch]$NoNewline
    )
    $overwrite = $Text.StartsWith("`r")
    if ($overwrite) { $Text = $Text.Substring(1) }

    $run = New-Object System.Windows.Documents.Run($Text)
    $run.Foreground = Get-Brush $Color

    $continuing = $script:lastLineOpen -and $logBox.Document.Blocks.Count -gt 0
    if ($continuing -and $overwrite) {
        $logBox.Document.Blocks.LastBlock.Inlines.Clear()
        $logBox.Document.Blocks.LastBlock.Inlines.Add($run)
    } elseif ($continuing) {
        $logBox.Document.Blocks.LastBlock.Inlines.Add($run)
    } else {
        $para = New-Object System.Windows.Documents.Paragraph($run)
        $para.Margin = New-Object System.Windows.Thickness(0)
        $logBox.Document.Blocks.Add($para)
        while ($logBox.Document.Blocks.Count -gt 40) {
            $logBox.Document.Blocks.Remove($logBox.Document.Blocks.FirstBlock)
        }
    }
    $script:lastLineOpen = $NoNewline.IsPresent
    $logBox.ScrollToEnd()
}

# Clears all lines from the log/console
function Clear-Console {
    $logBox.Document.Blocks.Clear()
    $script:lastLineOpen = $false
}

# Updates the activity label + progress bar from a {type:'progress'} event
function Update-Progress {
    param($Evt)
    if ($Evt.done) {
        $progressBar.Value = 0
        $activityText.Text = ""
        return
    }
    $total     = [double]$Evt.totalSeconds
    $remaining = [double]$Evt.secondsRemaining
    $progressBar.Value = if ($total -gt 0) { (($total - $remaining) / $total) * 100 } else { 0 }
    $activityText.Text = "$($Evt.activity):  $([int]$remaining)s"
}

# Drains queued output from the app process and applies it to the UI. Runs on the UI thread via the timer.
function Update-Console {
    $raw   = $null
    $count = 0
    while ($count -lt 500 -and $script:LogQueue.TryDequeue([ref]$raw)) {
        $count++
        if ($raw.StartsWith('__ERR__')) { Add-LogLine -Text $raw.Substring(7) -Color 'Red'; continue }
        try {
            $evt = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Add-LogLine -Text $raw -Color 'White'
            continue
        }
        switch ($evt.type) {
            'log'      { Add-LogLine -Text $evt.text -Color $evt.color -NoNewline:([bool]$evt.noNewline) }
            'progress' { Update-Progress -Evt $evt }
            'clear'    { Clear-Console }
            'stats'    { Update-Stats -Evt $evt }
            default    { Add-LogLine -Text $raw -Color 'White' }
        }
    }

    # The app process has exited once both reader runspaces have hit EOF and there's nothing left queued
    if ($script:proc -and $script:proc.HasExited -and $script:LogQueue.IsEmpty -and
        (-not $script:stdoutReader -or $script:stdoutReader.AsyncResult.IsCompleted) -and
        (-not $script:stderrReader -or $script:stderrReader.AsyncResult.IsCompleted)) {
        Complete-AppRun
    }
}

# Reads a stream line-by-line on a dedicated background runspace, enqueueing each line the moment
# it's read. This guarantees strict in-order delivery - unlike Register-ObjectEvent +
# BeginOutputReadLine, whose events are dispatched via .NET's ThreadPool and PowerShell's own event
# queue, which don't guarantee lines are processed in the exact order the process wrote them.
function Start-StreamReader {
    param(
        [System.IO.StreamReader]$Reader,
        [string]$Prefix
    )
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('Reader', $Reader)
    $rs.SessionStateProxy.SetVariable('Queue', $script:LogQueue)
    $rs.SessionStateProxy.SetVariable('Prefix', $Prefix)

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        while ($null -ne ($line = $Reader.ReadLine())) {
            if ($Prefix) { $Queue.Enqueue("$Prefix$line") } else { $Queue.Enqueue($line) }
        }
    })

    [PSCustomObject]@{
        PS          = $ps
        Runspace    = $rs
        AsyncResult = $ps.BeginInvoke()
    }
}

# Stops and disposes the stdout/stderr reader runspaces
function Stop-StreamReaders {
    foreach ($reader in @($script:stdoutReader, $script:stderrReader)) {
        if (-not $reader) { continue }
        try { $reader.PS.Stop() } catch {}
        try { $reader.PS.Dispose() } catch {}
        try { $reader.Runspace.Close() } catch {}
        try { $reader.Runspace.Dispose() } catch {}
    }
    $script:stdoutReader = $null
    $script:stderrReader = $null
}

# Wraps a value as a quoted CLI argument, stripping embedded quotes so the arg list can't be broken out of
function ConvertTo-CliArg {
    param($Value)
    '"' + (("$Value") -replace '"', '') + '"'
}

# Runs LorewalkingHelper.ps1 as a hidden Windows PowerShell process, capturing its structured output into the GUI
function Start-App {
    if ($script:proc -and -not $script:proc.HasExited) { return }

    $logBox.Document.Blocks.Clear()
    $script:lastLineOpen = $false
    $progressBar.Value = 0
    $activityText.Text = ""
    $statusPanel.Visibility = [System.Windows.Visibility]::Visible
    Reset-Stats

    $autoStop     = $checkboxAutoStop.IsChecked -eq $true
    $autoStopTime = if ($Null -ne $textBoxAutoStopTime.Text -and $textBoxAutoStopTime.Text -match '^\d+$' ) {[int]$textBoxAutoStopTime.Text} else {300}
    $autoLogout   = $checkboxAutoLogout.IsChecked -eq $true
    $autoSleep    = $checkboxAutoSleep.IsChecked -eq $true
    $loadingTime  = if ($Null -ne $textBoxLoadingTime.Text -and $textBoxLoadingTime.Text -match '^\d+$' ) {[int]$textBoxLoadingTime.Text} else {10}

    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path $windowsPowerShell)) { $windowsPowerShell = 'powershell.exe' }

    $argList = @(
        '-NoProfile', '-NoLogo', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$loreWalkingScriptFile`"",
        '-autoStop', $autoStop,
        '-autoStopTime', $autoStopTime,
        '-autoLogout', $autoLogout,
        '-autoSleep', $autoSleep,
        '-loadingTime', $loadingTime,
        '-useWindowFocus', ($settings.UseWindowFocus -eq $true),
        '-usePi', ($settings.UsePi -eq $true),
        '-picoComPort', (ConvertTo-CliArg $settings.PicoComPort),
        '-wowInstallPath', (ConvertTo-CliArg $settings.WowInstallPath),
        '-PrimaryKeybind', (ConvertTo-CliArg $settings.PrimaryKeybind),
        '-FailsafeKeybind', (ConvertTo-CliArg $settings.FailsafeKeybind),
        '-logout', (ConvertTo-CliArg $settings.Logout),
        '-enableFailsafe', ($settings.EnableFailsafe -eq $true),
        '-enableNotifications', ($settings.EnableNotifications -eq $true),
        '-discordWebhook', (ConvertTo-CliArg $settings.DiscordWebhook),
        '-onStart', ($settings.OnStart -eq $true),
        '-onStop', ($settings.OnStop -eq $true),
        '-onError', ($settings.OnError -eq $true),
        '-onLevelUp', ($settings.OnLevelUp -eq $true),
        '-windowTitle', (ConvertTo-CliArg $settings.WindowTitle),
        '-AddonScreenLocation', (ConvertTo-CliArg $settings.AddonScreenLocation),
        '-useMyOwnCoordinates', ($settings.UseMyOwnCoordinates -eq $true),
        '-topLeftX', [int]$settings.TopLeftX,
        '-topLeftY', [int]$settings.TopLeftY,
        '-bottomRightX', [int]$settings.BottomRightX,
        '-bottomRightY', [int]$settings.BottomRightY
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $windowsPowerShell
    $psi.Arguments              = ($argList -join ' ')
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true

    $script:proc = New-Object System.Diagnostics.Process
    $script:proc.StartInfo = $psi

    [void]$script:proc.Start()
    $script:stdoutReader = Start-StreamReader -Reader $script:proc.StandardOutput
    $script:stderrReader = Start-StreamReader -Reader $script:proc.StandardError -Prefix '__ERR__'

    $startBtn.Content = "Stop"
    $startBtn.Background = $stopColor
    $startBtn.Foreground = $textLight
    $consoleTimer.Start()
    Start-ElapsedTimer
}

# Stops the currently running app, if any
function Stop-App {
    if (-not $script:proc -or $script:proc.HasExited) { return }
    $elapsed = (Get-Date) - $script:appStartTime
    $elapsedTime = "Session Time: " + $elapsed.ToString('hh\:mm\:ss')
    Add-LogLine -Text $elapsedTime -Color 'White'
    Add-LogLine -Text "Lorewalking Stopped" -Color 'Yellow'
    $startBtn.IsEnabled = $false
    $startBtn.Content = "Stopping..."
    Update-Progress -Evt @{ done = $true }
    Stop-ElapsedTimer
    try { $script:proc.Kill() } catch {}
}

# Cleans up the process once the app run finishes (naturally, via Stop-App, or on error)
function Complete-AppRun {
    Stop-StreamReaders
    if ($script:proc) {
        try { $script:proc.Dispose() } catch {}
    }
    $script:proc = $null
    $consoleTimer.Stop()
    Stop-ElapsedTimer
    $statusPanel.Visibility = [System.Windows.Visibility]::Hidden
    $startBtn.IsEnabled = $true
    $startBtn.Content = "Start"
    $startBtn.Background = $accent
    $startBtn.Foreground = "#000000"
}
#endregion Embedded console / runner

# Dark "midnight" theme WPF window (colors, chrome type, and Enable-DarkTitleBar are defined near the top of the script)

# Flat, rounded button look with basic hover/disabled feedback
$buttonTemplateXaml = @'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                  TargetType="Button">
    <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="4" BorderThickness="0">
        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="8,4"/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="border" Property="Opacity" Value="0.75"/>
        </Trigger>
        <Trigger Property="IsEnabled" Value="False">
            <Setter TargetName="border" Property="Opacity" Value="0.4"/>
        </Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
'@
$flatButtonTemplate = [System.Windows.Markup.XamlReader]::Parse($buttonTemplateXaml)

$locationComboTemplateXaml = @'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 TargetType="ComboBox">
    <Grid>
        <ToggleButton x:Name="ToggleButton"
                      Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="1"
                      Foreground="{TemplateBinding Foreground}"
                      IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                      Focusable="False"
                      ClickMode="Press">
            <ToggleButton.Template>
                <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="ToggleBorder"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}">
                        <ContentPresenter />
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="ToggleBorder" Property="Background" Value="#3A3A3E" />
                        </Trigger>
                        <Trigger Property="IsChecked" Value="True">
                            <Setter TargetName="ToggleBorder" Property="Background" Value="#3A3A3E" />
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </ToggleButton.Template>
            <Grid>
                <ContentPresenter Margin="8,2,28,2"
                                  VerticalAlignment="Center"
                                  Content="{TemplateBinding SelectionBoxItem}"
                                  ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                  ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" />
                <Path HorizontalAlignment="Right"
                      VerticalAlignment="Center"
                      Margin="0,0,9,0"
                      Fill="{TemplateBinding Foreground}"
                      Data="M 0 0 L 8 0 L 4 5 Z" />
            </Grid>
        </ToggleButton>
        <Popup x:Name="Popup"
               Placement="Bottom"
               AllowsTransparency="True"
               Focusable="False"
               IsOpen="{TemplateBinding IsDropDownOpen}">
            <Border MinWidth="{Binding ActualWidth, ElementName=ToggleButton}"
                    Background="#1E1E2E"
                    BorderBrush="#2A2A30"
                    BorderThickness="1">
                <ScrollViewer CanContentScroll="True">
                    <ItemsPresenter />
                </ScrollViewer>
            </Border>
        </Popup>
    </Grid>
</ControlTemplate>
'@
$locationComboTemplate = [System.Windows.Markup.XamlReader]::Parse($locationComboTemplateXaml)

$locationComboItemStyleXaml = @'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="ComboBoxItem">
    <Setter Property="Foreground" Value="#E6E6E6" />
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="ComboBoxItem">
                <Border x:Name="ItemBorder" Background="#1E1E2E" Padding="8,3">
                    <ContentPresenter />
                </Border>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="ItemBorder" Property="Background" Value="#3A3A3E" />
                    </Trigger>
                    <Trigger Property="IsSelected" Value="True">
                        <Setter TargetName="ItemBorder" Property="Background" Value="#F5A623" />
                        <Setter Property="Foreground" Value="#000000" />
                    </Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
'@
$locationComboItemStyle = [System.Windows.Markup.XamlReader]::Parse($locationComboItemStyleXaml)

function New-AccentButton {
    param([string]$Text, [string]$Background)
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content         = $Text
    $btn.FontSize        = 15
    $btn.Width           = 110
    $btn.Height          = 35
    $btn.Margin          = New-Object System.Windows.Thickness(0, 0, 10, 0)
    $btn.Background      = $Background
    $btn.Foreground      = "#000000"
    $btn.FontWeight      = "Bold"
    $btn.Cursor          = [System.Windows.Input.Cursors]::Hand
    $btn.Template        = $flatButtonTemplate
    $btn
}

function New-DarkCheckBox {
    param([string]$Text, [bool]$Checked, [string]$Tooltip)
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content    = $Text
    $cb.IsChecked  = $Checked
    $cb.Foreground = $textLight
    $cb.Margin     = New-Object System.Windows.Thickness(0, 0, 20, 8)
    $cb.VerticalContentAlignment = "Center"
    if ($Tooltip) { $cb.ToolTip = $Tooltip }
    $cb
}

function New-DarkTextBox {
    param([string]$Text, [int]$Width = 40, [int]$MaxLength = 3, [string]$Tooltip)
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Text            = $Text
    $tb.Width           = $Width
    $tb.Background      = $bgDark
    $tb.Foreground      = $textLight
    $tb.CaretBrush      = $textLight
    $tb.BorderBrush     = $borderDark
    $tb.TextAlignment   = "Center"
    $tb.MaxLength        = $MaxLength
    $tb.VerticalContentAlignment = "Center"
    if ($Tooltip) { $tb.ToolTip = $Tooltip }
    $tb
}

# Modal dialog for the settings
function Show-AdvancedSettingsDialog {
    $dlg = New-Object System.Windows.Window
    $dlg.Title                 = "Advanced Settings"
    $dlg.Width                 = 640
    $dlg.Height                = 800
    $dlg.MinWidth              = 480
    $dlg.MinHeight             = 550
    $dlg.WindowStartupLocation = "CenterOwner"
    $dlg.Owner                 = $window
    $dlg.Background            = $bgDark
    $dlg.Foreground            = $textLight
    $dlg.FontFamily            = "Segoe UI"
    $dlg.FontSize              = 13
    $dlg.Icon                  = $logoImage
    $dlg.ResizeMode            = "CanResizeWithGrip"
    Enable-DarkTitleBar -Window $dlg

    $dlgRoot = New-Object System.Windows.Controls.Grid
    $dlgRoot.Margin = New-Object System.Windows.Thickness(14)
    '*', 'Auto' | ForEach-Object {
        $rowDef = New-Object System.Windows.Controls.RowDefinition
        $rowDef.Height = if ($_ -eq '*') { [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
        [void]$dlgRoot.RowDefinitions.Add($rowDef)
    }
    $dlg.Content = $dlgRoot

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = "Auto"
    [System.Windows.Controls.Grid]::SetRow($scroll, 0)
    $content = New-Object System.Windows.Controls.StackPanel
    $scroll.Content = $content
    [void]$dlgRoot.Children.Add($scroll)

    $ctrls = @{}

    function New-Section {
        param([string]$Title)
        $b = New-Object System.Windows.Controls.Border
        $b.Background = $panelDark
        $b.BorderBrush = $borderDark
        $b.BorderThickness = New-Object System.Windows.Thickness(1)
        $b.CornerRadius = New-Object System.Windows.CornerRadius(6)
        $b.Padding = New-Object System.Windows.Thickness(12)
        $b.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
        $sp = New-Object System.Windows.Controls.StackPanel
        $b.Child = $sp
        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = $Title
        $header.FontWeight = "Bold"
        $header.Foreground = $accent
        $header.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
        [void]$sp.Children.Add($header)
        [void]$content.Children.Add($b)
        $sp
    }

    function New-FieldRow {
        param($Parent, [string]$LabelText, $Control, [string]$Tooltip)
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Orientation = "Horizontal"
        $row.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $LabelText
        $lbl.Foreground = $textLight
        $lbl.Width = 150
        $lbl.VerticalAlignment = "Center"
        if ($Tooltip) { $lbl.ToolTip = $Tooltip; if (-not $Control.ToolTip) { $Control.ToolTip = $Tooltip } }
        [void]$row.Children.Add($lbl)
        [void]$row.Children.Add($Control)
        [void]$Parent.Children.Add($row)
    }

    # Input
    $sec = New-Section "Input"
    $ctrls.UseWindowFocus = New-DarkCheckBox -Text "Auto-focus WoW window" -Checked ([bool]$settings.UseWindowFocus) -Tooltip "Auto focus the WoW window before sending input."
    [void]$sec.Children.Add($ctrls.UseWindowFocus)
    $ctrls.UsePi = New-DarkCheckBox -Text "Use Raspberry Pi Pico for input (Recommended)" -Checked ([bool]$settings.UsePi) -Tooltip "Safer to use: Send keypresses through a Raspberry Pi Pico instead of simulating input."
    [void]$sec.Children.Add($ctrls.UsePi)
    $ctrls.PicoComPort = New-DarkTextBox -Text ([string]$settings.PicoComPort) -Width 60 -MaxLength 6
    $picoComPortPanel = New-Object System.Windows.Controls.StackPanel
    New-FieldRow -Parent $picoComPortPanel -LabelText "Pico COM port:" -Control $ctrls.PicoComPort -Tooltip "COM port the Pico is connected to, eg: 'COM4', or 'AUTO' to detect it automatically."
    [void]$sec.Children.Add($picoComPortPanel)
    $picoComPortPanel.Visibility = if ($settings.UsePi) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $ctrls.UsePi.Add_Checked({ $picoComPortPanel.Visibility = [System.Windows.Visibility]::Visible }.GetNewClosure())
    $ctrls.UsePi.Add_Unchecked({ $picoComPortPanel.Visibility = [System.Windows.Visibility]::Collapsed }.GetNewClosure())
    $ctrls.WowInstallPath = New-DarkTextBox -Text ([string]$settings.WowInstallPath) -Width 300 -MaxLength 260
    $browseWowPathBtn = New-AccentButton -Text "Browse..." -Background $accent
    $browseWowPathBtn.Width = 80
    $browseWowPathBtn.Height = 26
    $browseWowPathBtn.FontSize = 12
    $browseWowPathBtn.Margin = New-Object System.Windows.Thickness(8, 0, 0, 0)
    $browseWowPathBtn.Add_Click({
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = "Select your World of Warcraft install folder"
        if ($ctrls.WowInstallPath.Text -and (Test-Path $ctrls.WowInstallPath.Text)) {
            $folderDialog.SelectedPath = $ctrls.WowInstallPath.Text
        }
        if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $ctrls.WowInstallPath.Text = $folderDialog.SelectedPath
        }
    }.GetNewClosure())
    $wowInstallPathPanel = New-Object System.Windows.Controls.StackPanel
    $wowInstallPathPanel.Orientation = "Horizontal"
    [void]$wowInstallPathPanel.Children.Add($ctrls.WowInstallPath)
    [void]$wowInstallPathPanel.Children.Add($browseWowPathBtn)
    New-FieldRow -Parent $sec -LabelText "WoW install path:" -Control $wowInstallPathPanel -Tooltip "Folder where World of Warcraft is installed eg, 'C:\Program Files\World of Warcraft', or 'AUTO' to detect it automatically."

    # Keybinds
    $sec = New-Section "Keybinds"
    $ctrls.PrimaryKeybind = New-DarkTextBox -Text ([string]$settings.PrimaryKeybind) -Width 80 -MaxLength 20
    New-FieldRow -Parent $sec -LabelText "Primary keybind:" -Control $ctrls.PrimaryKeybind -Tooltip "Set this to the same keybind you set in the LorewalkingHelper Addon in-game with /lw kb. This is the primary keybind for the app and is required."
    $ctrls.FailsafeKeybind = New-DarkTextBox -Text ([string]$settings.FailsafeKeybind) -Width 80 -MaxLength 20
    New-FieldRow -Parent $sec -LabelText "Failsafe keybind:" -Control $ctrls.FailsafeKeybind -Tooltip "Set this to the same keybind you set in the LorewalkingHelper Addon in-game with /lw kbfailsafe This is used to reset the app if it gets stuck. Optional."
    $ctrls.Logout = New-DarkTextBox -Text ([string]$settings.Logout) -Width 80 -MaxLength 20
    New-FieldRow -Parent $sec -LabelText "Logout keybind:" -Control $ctrls.Logout -Tooltip "Set this to the same keybind you set in the LorewalkingHelper Addon in-game with /lw kblogout. This is used to log the character out when auto-logout is triggered. Optional."
    $ctrls.EnableFailsafe = New-DarkCheckBox -Text "Enable failsafe auto-restart (Requires Failsafe keybind)" -Checked ([bool]$settings.EnableFailsafe) -Tooltip "Tries and resets the toon back to the Lorewalking starting quest if the toon is not on the right step."
    [void]$sec.Children.Add($ctrls.EnableFailsafe)

    # Discord Notifications
    $sec = New-Section "Discord Notifications"
    $ctrls.EnableNotifications = New-DarkCheckBox -Text "Enable notifications" -Checked ([bool]$settings.EnableNotifications) -Tooltip "Send status messages to a Discord channel via webhook."
    [void]$sec.Children.Add($ctrls.EnableNotifications)
    $notifyDetailsPanel = New-Object System.Windows.Controls.StackPanel
    $ctrls.DiscordWebhook = New-DarkTextBox -Text ([string]$settings.DiscordWebhook) -Width 350 -MaxLength 400
    New-FieldRow -Parent $notifyDetailsPanel -LabelText "Webhook URL:" -Control $ctrls.DiscordWebhook -Tooltip "The Discord webhook URL notifications will be posted to."
    $notifyTooltips = @{
        OnStart   = 'Send a notification when the app starts running.'
        OnStop    = 'Send a notification when the app stops running.'
        OnError   = 'Send a notification when an error occurs.'
        OnLevelUp = 'Send a notification when the character levels up.'
    }
    foreach ($n in @(
        @{Key = 'OnStart';   Label = 'Notify on start'},
        @{Key = 'OnStop';    Label = 'Notify on stop'},
        @{Key = 'OnError';   Label = 'Notify on error'},
        @{Key = 'OnLevelUp'; Label = 'Notify on level up'}
    )) {
        $cb = New-DarkCheckBox -Text $n.Label -Checked ([bool]$settings[$n.Key]) -Tooltip $notifyTooltips[$n.Key]
        $ctrls[$n.Key] = $cb
        [void]$notifyDetailsPanel.Children.Add($cb)
    }
    [void]$sec.Children.Add($notifyDetailsPanel)
    $notifyDetailsPanel.Visibility = if ($settings.EnableNotifications) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $ctrls.EnableNotifications.Add_Checked({ $notifyDetailsPanel.Visibility = [System.Windows.Visibility]::Visible }.GetNewClosure())
    $ctrls.EnableNotifications.Add_Unchecked({ $notifyDetailsPanel.Visibility = [System.Windows.Visibility]::Collapsed }.GetNewClosure())

    # Addon Screen Location
    $sec = New-Section "Addon Screen Location"
    $ctrls.WindowTitle = New-DarkTextBox -Text ([string]$settings.WindowTitle) -Width 200 -MaxLength 100
    New-FieldRow -Parent $sec -LabelText "WoW window title:" -Control $ctrls.WindowTitle -Tooltip "The title of the WoW window, used to locate it on screen."

    $comboLocation = New-Object System.Windows.Controls.ComboBox
    $comboLocation.Width                    = 160
    $comboLocation.Background               = $bgDark
    $comboLocation.Foreground               = $textLight
    $comboLocation.BorderBrush              = $borderDark
    $comboLocation.VerticalContentAlignment = "Center"
    $comboLocation.Template                 = $locationComboTemplate
    $comboLocation.ItemContainerStyle       = $locationComboItemStyle
    foreach ($opt in @('BOTTOMLEFT', 'BOTTOMRIGHT', 'BOTTOMMIDDLE')) { [void]$comboLocation.Items.Add($opt) }
    $comboLocation.SelectedItem = [string]$settings.AddonScreenLocation
    if (-not $comboLocation.SelectedItem) { $comboLocation.SelectedIndex = 0 }
    $ctrls.AddonScreenLocation = $comboLocation
    New-FieldRow -Parent $sec -LabelText "Screen location:" -Control $comboLocation -Tooltip "Where the addon's status display is anchored on screen, used to locate it for reading."

    $ctrls.UseMyOwnCoordinates = New-DarkCheckBox -Text "Use custom coordinates instead" -Checked ([bool]$settings.UseMyOwnCoordinates) -Tooltip "Override the screen location preset with exact pixel coordinates you specify below."
    [void]$sec.Children.Add($ctrls.UseMyOwnCoordinates)

    $coordPanel = New-Object System.Windows.Controls.StackPanel
    $coordPanel.Margin = New-Object System.Windows.Thickness(0, 4, 0, 0)

    $rowTL = New-Object System.Windows.Controls.StackPanel
    $rowTL.Orientation = "Horizontal"
    $rowTL.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $lblTL = New-Object System.Windows.Controls.TextBlock
    $lblTL.Text = "Top-left X / Y:"
    $lblTL.Foreground = $textLight
    $lblTL.Width = 150
    $lblTL.VerticalAlignment = "Center"
    $lblTL.ToolTip = "Pixel coordinates of the top-left corner of the addon's status display region."
    [void]$rowTL.Children.Add($lblTL)
    $ctrls.TopLeftX = New-DarkTextBox -Text ([string][int]$settings.TopLeftX) -Width 60 -MaxLength 6
    $ctrls.TopLeftX.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    [void]$rowTL.Children.Add($ctrls.TopLeftX)
    $ctrls.TopLeftY = New-DarkTextBox -Text ([string][int]$settings.TopLeftY) -Width 60 -MaxLength 6
    [void]$rowTL.Children.Add($ctrls.TopLeftY)
    [void]$coordPanel.Children.Add($rowTL)

    $rowBR = New-Object System.Windows.Controls.StackPanel
    $rowBR.Orientation = "Horizontal"
    $lblBR = New-Object System.Windows.Controls.TextBlock
    $lblBR.Text = "Bottom-right X / Y:"
    $lblBR.Foreground = $textLight
    $lblBR.Width = 150
    $lblBR.VerticalAlignment = "Center"
    $lblBR.ToolTip = "Pixel coordinates of the bottom-right corner of the addon's status display region."
    [void]$rowBR.Children.Add($lblBR)
    $ctrls.BottomRightX = New-DarkTextBox -Text ([string][int]$settings.BottomRightX) -Width 60 -MaxLength 6
    $ctrls.BottomRightX.Margin = New-Object System.Windows.Thickness(0, 0, 8, 0)
    [void]$rowBR.Children.Add($ctrls.BottomRightX)
    $ctrls.BottomRightY = New-DarkTextBox -Text ([string][int]$settings.BottomRightY) -Width 60 -MaxLength 6
    [void]$rowBR.Children.Add($ctrls.BottomRightY)
    [void]$coordPanel.Children.Add($rowBR)

    [void]$sec.Children.Add($coordPanel)
    $coordPanel.Visibility = if ($settings.UseMyOwnCoordinates) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $ctrls.UseMyOwnCoordinates.Add_Checked({ $coordPanel.Visibility = [System.Windows.Visibility]::Visible }.GetNewClosure())
    $ctrls.UseMyOwnCoordinates.Add_Unchecked({ $coordPanel.Visibility = [System.Windows.Visibility]::Collapsed }.GetNewClosure())

    # Save / Cancel
    $btnRow = New-Object System.Windows.Controls.DockPanel
    $btnRow.LastChildFill = $false
    $btnRow.Margin = New-Object System.Windows.Thickness(6, 0, -8, 0)
    [System.Windows.Controls.Grid]::SetRow($btnRow, 1)

    $saveCancelPanel = New-Object System.Windows.Controls.StackPanel
    $saveCancelPanel.Orientation = "Horizontal"
    [System.Windows.Controls.DockPanel]::SetDock($saveCancelPanel, [System.Windows.Controls.Dock]::Right)

    $saveBtn = New-AccentButton -Text "Save" -Background $accent
    $saveBtn.Width = 100
    $cancelBtn = New-AccentButton -Text "Cancel" -Background $stopColor
    $cancelBtn.Width = 100
    $cancelBtn.Foreground = $textLight

    $saveBtn.Add_Click({
        $settings.UseWindowFocus       = $ctrls.UseWindowFocus.IsChecked -eq $true
        $settings.UsePi                = $ctrls.UsePi.IsChecked -eq $true
        $settings.PicoComPort          = if ($ctrls.PicoComPort.Text) { $ctrls.PicoComPort.Text } else { "AUTO" }
        $settings.WowInstallPath       = if ($ctrls.WowInstallPath.Text) { $ctrls.WowInstallPath.Text } else { "AUTO" }
        $settings.PrimaryKeybind       = $ctrls.PrimaryKeybind.Text
        $settings.FailsafeKeybind      = $ctrls.FailsafeKeybind.Text
        $settings.Logout               = $ctrls.Logout.Text
        $settings.EnableFailsafe       = $ctrls.EnableFailsafe.IsChecked -eq $true
        $settings.EnableNotifications  = $ctrls.EnableNotifications.IsChecked -eq $true
        $settings.DiscordWebhook       = $ctrls.DiscordWebhook.Text
        $settings.OnStart              = $ctrls.OnStart.IsChecked -eq $true
        $settings.OnStop               = $ctrls.OnStop.IsChecked -eq $true
        $settings.OnError              = $ctrls.OnError.IsChecked -eq $true
        $settings.OnLevelUp            = $ctrls.OnLevelUp.IsChecked -eq $true
        $settings.WindowTitle          = $ctrls.WindowTitle.Text
        $settings.AddonScreenLocation  = if ($ctrls.AddonScreenLocation.SelectedItem) { $ctrls.AddonScreenLocation.SelectedItem } else { "BOTTOMLEFT" }
        $settings.UseMyOwnCoordinates  = $ctrls.UseMyOwnCoordinates.IsChecked -eq $true
        $settings.TopLeftX             = if ($ctrls.TopLeftX.Text -match '^-?\d+$') { [int]$ctrls.TopLeftX.Text } else { 0 }
        $settings.TopLeftY             = if ($ctrls.TopLeftY.Text -match '^-?\d+$') { [int]$ctrls.TopLeftY.Text } else { 0 }
        $settings.BottomRightX         = if ($ctrls.BottomRightX.Text -match '^-?\d+$') { [int]$ctrls.BottomRightX.Text } else { 0 }
        $settings.BottomRightY         = if ($ctrls.BottomRightY.Text -match '^-?\d+$') { [int]$ctrls.BottomRightY.Text } else { 0 }

        Export-Settings -settings $settings
        $dlg.Close()
    }.GetNewClosure())
    $cancelBtn.Add_Click({ $dlg.Close() }.GetNewClosure())

    # A UIElement can only have one parent, so a fresh Image is created each time this dialog opens
    # rather than reusing the module-level $gitImageCtrl (which would already be parented to a closed dialog)
    $dlgGitImageCtrl = New-Object System.Windows.Controls.Image
    $dlgGitImageCtrl.Source = $gitImage
    $dlgGitImageCtrl.Width  = 32
    $dlgGitImageCtrl.Height = 32
    $dlgGitImageCtrl.Cursor = [System.Windows.Input.Cursors]::Hand
    $dlgGitImageCtrl.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
    $dlgGitImageCtrl.Add_MouseLeftButtonUp({ Start-Process "https://github.com/Glacerr/LorewalkingHelper" })
    [System.Windows.Controls.DockPanel]::SetDock($dlgGitImageCtrl, [System.Windows.Controls.Dock]::Left)
    [void]$btnRow.Children.Add($dlgGitImageCtrl)
    [void]$saveCancelPanel.Children.Add($saveBtn)
    [void]$saveCancelPanel.Children.Add($cancelBtn)
    [void]$btnRow.Children.Add($saveCancelPanel)
    [void]$dlgRoot.Children.Add($btnRow)

    [void]$dlg.ShowDialog()
}

$window = New-Object System.Windows.Window
$window.Title                  = "Lorewalking Helper"
$window.Width                  = 640
$window.Height                 = 680
$window.MinWidth               = 580
$window.MinHeight              = 480
$window.WindowStartupLocation  = "CenterScreen"
$window.Background             = $bgDark
$window.Foreground             = $textLight
$window.FontFamily             = "Segoe UI"
$window.FontSize               = 14
$window.Icon                   = $logoImage
$window.UseLayoutRounding      = $true # snaps sibling elements to the same device pixels so edges line up at non-100% display scaling
Enable-DarkTitleBar -Window $window

$root = New-Object System.Windows.Controls.Grid
$root.Margin = New-Object System.Windows.Thickness(14)
'Auto', 'Auto', 'Auto', '*', 'Auto' | ForEach-Object {
    $rowDef = New-Object System.Windows.Controls.RowDefinition
    $rowDef.Height = if ($_ -eq '*') { [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
    [void]$root.RowDefinitions.Add($rowDef)
}
$window.Content = $root

# Header: logo + title (left), start/stop toggle button (top-right)
$header = New-Object System.Windows.Controls.Grid
$header.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
[System.Windows.Controls.Grid]::SetRow($header, 0)
$headerColLeft = New-Object System.Windows.Controls.ColumnDefinition
$headerColLeft.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
$headerColRight = New-Object System.Windows.Controls.ColumnDefinition
$headerColRight.Width = [System.Windows.GridLength]::Auto
[void]$header.ColumnDefinitions.Add($headerColLeft)
[void]$header.ColumnDefinitions.Add($headerColRight)

$headerLeft = New-Object System.Windows.Controls.StackPanel
$headerLeft.Orientation = "Horizontal"
$headerLeft.VerticalAlignment = "Center"
[System.Windows.Controls.Grid]::SetColumn($headerLeft, 0)

$logoImageCtrl = New-Object System.Windows.Controls.Image
$logoImageCtrl.Source = $logoImage
$logoImageCtrl.Width  = 60
$logoImageCtrl.Height = 60
#$logoImageCtrl.Cursor = [System.Windows.Input.Cursors]::Hand
$logoImageCtrl.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)
#$logoImageCtrl.Add_MouseLeftButtonUp({ Start-App })

$titleText = New-Object System.Windows.Controls.TextBlock
$titleText.Text = "Lorewalking Helper"
$titleText.FontSize = 24
$titleText.FontWeight = "Bold"
$titleText.Foreground = $accent
$titleText.VerticalAlignment = "Center"

[void]$headerLeft.Children.Add($logoImageCtrl)
[void]$headerLeft.Children.Add($titleText)
[void]$header.Children.Add($headerLeft)

$headerRight = New-Object System.Windows.Controls.StackPanel
$headerRight.Orientation = "Horizontal"
$headerRight.VerticalAlignment = "Center"
[System.Windows.Controls.Grid]::SetColumn($headerRight, 1)

$startBtn = New-AccentButton -Text "Start" -Background $accent
$startBtn.Margin = New-Object System.Windows.Thickness(0)
$startBtn.VerticalAlignment = "Center"
$startBtn.Add_Click({
    if ($script:proc -and -not $script:proc.HasExited) { Stop-App } else { Start-App }
})
[void]$headerRight.Children.Add($startBtn)

[void]$header.Children.Add($headerRight)

[void]$root.Children.Add($header)

# Settings panel
$settingsBorder = New-Object System.Windows.Controls.Border
$settingsBorder.Background = $panelDark
$settingsBorder.BorderBrush = $borderDark
$settingsBorder.BorderThickness = New-Object System.Windows.Thickness(1)
$settingsBorder.CornerRadius = New-Object System.Windows.CornerRadius(6)
$settingsBorder.Padding = New-Object System.Windows.Thickness(12)
$settingsBorder.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
[System.Windows.Controls.Grid]::SetRow($settingsBorder, 1)

$settingsDock = New-Object System.Windows.Controls.DockPanel
$settingsBorder.Child = $settingsDock

$labelAdvanced = New-Object System.Windows.Controls.TextBlock
$labelAdvanced.Text = [char]0xE700
$labelAdvanced.FontFamily = "Segoe MDL2 Assets"
$labelAdvanced.FontSize = 24
$labelAdvanced.Foreground = $accent
$labelAdvanced.Cursor = [System.Windows.Input.Cursors]::Hand
$labelAdvanced.VerticalAlignment = "Center"
$labelAdvanced.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
$labelAdvanced.ToolTip = "Advanced settings"
$labelAdvanced.Add_MouseLeftButtonUp({ Show-AdvancedSettingsDialog })
$hamburgerFadeDuration = [TimeSpan]::FromMilliseconds(120)
$labelAdvanced.Add_MouseEnter({
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.6, $hamburgerFadeDuration)
    $labelAdvanced.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty, $anim)
}.GetNewClosure())
$labelAdvanced.Add_MouseLeave({
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(1, $hamburgerFadeDuration)
    $labelAdvanced.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty, $anim)
}.GetNewClosure())
[System.Windows.Controls.DockPanel]::SetDock($labelAdvanced, [System.Windows.Controls.Dock]::Right)
[void]$settingsDock.Children.Add($labelAdvanced)

$settingsPanel = New-Object System.Windows.Controls.WrapPanel
[void]$settingsDock.Children.Add($settingsPanel)

$checkboxAutoStop = New-DarkCheckBox -Text "Auto Stop" -Checked ([bool]$settings.autoStop) -Tooltip "Automatically stop the app after it has been running for the specified time."

$autoStopTimePanel = New-Object System.Windows.Controls.StackPanel
$autoStopTimePanel.Orientation = "Horizontal"
$autoStopTimePanel.Margin = New-Object System.Windows.Thickness(0, 0, 20, 8)
$autoStopTimePanel.ToolTip = "How long the app should run before it automatically stops."

$labelIn = New-Object System.Windows.Controls.TextBlock
$labelIn.Text = "in"
$labelIn.Foreground = $textLight
$labelIn.VerticalAlignment = "Center"
$labelIn.Margin = New-Object System.Windows.Thickness(0, 0, 4, 0)

$textBoxAutoStopTime = New-DarkTextBox -Text ([string][int]$settings.autoStopTime)

$labelMin = New-Object System.Windows.Controls.TextBlock
$labelMin.Text = "min."
$labelMin.Foreground = $textLight
$labelMin.VerticalAlignment = "Center"
$labelMin.Margin = New-Object System.Windows.Thickness(4, 0, 0, 0)

[void]$autoStopTimePanel.Children.Add($labelIn)
[void]$autoStopTimePanel.Children.Add($textBoxAutoStopTime)
[void]$autoStopTimePanel.Children.Add($labelMin)

$checkboxAutoLogout = New-DarkCheckBox -Text "Logout" -Checked ([bool]$settings.autoLogout) -Tooltip "Log the character out of WoW when Auto Stop triggers."
$checkboxAutoSleep  = New-DarkCheckBox -Text "Sleep PC" -Checked ([bool]$settings.autoSleep) -Tooltip "Put the PC to sleep when Auto Stop triggers."

$loadingTimePanel = New-Object System.Windows.Controls.StackPanel
$loadingTimePanel.Orientation = "Horizontal"
$loadingTimePanel.Margin = New-Object System.Windows.Thickness(0, 0, 20, 8)
$loadingTimePanel.ToolTip = "How long to wait for the game world to load before starting to act."

$labelLoadTime = New-Object System.Windows.Controls.TextBlock
$labelLoadTime.Text = "Loading Screen Duration:"
$labelLoadTime.Foreground = $textLight
$labelLoadTime.VerticalAlignment = "Center"
$labelLoadTime.Margin = New-Object System.Windows.Thickness(0, 0, 4, 0)

$textBoxLoadingTime = New-DarkTextBox -Text ([string][int]$settings.loadingTime)

$labelSec = New-Object System.Windows.Controls.TextBlock
$labelSec.Text = "sec."
$labelSec.Foreground = $textLight
$labelSec.VerticalAlignment = "Center"
$labelSec.Margin = New-Object System.Windows.Thickness(4, 0, 0, 0)

[void]$loadingTimePanel.Children.Add($labelLoadTime)
[void]$loadingTimePanel.Children.Add($textBoxLoadingTime)
[void]$loadingTimePanel.Children.Add($labelSec)

[void]$settingsPanel.Children.Add($checkboxAutoStop)
[void]$settingsPanel.Children.Add($autoStopTimePanel)
[void]$settingsPanel.Children.Add($checkboxAutoLogout)
[void]$settingsPanel.Children.Add($checkboxAutoSleep)
[void]$settingsPanel.Children.Add($loadingTimePanel)

$autoStopTimePanel.Visibility = if ($settings.autoStop) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
$checkboxAutoLogout.Visibility = $autoStopTimePanel.Visibility
$checkboxAutoSleep.Visibility  = $autoStopTimePanel.Visibility

$checkboxAutoStop.Add_Checked({
    $autoStopTimePanel.Visibility  = [System.Windows.Visibility]::Visible
    $checkboxAutoLogout.Visibility = [System.Windows.Visibility]::Visible
    $checkboxAutoSleep.Visibility  = [System.Windows.Visibility]::Visible
})
$checkboxAutoStop.Add_Unchecked({
    $autoStopTimePanel.Visibility  = [System.Windows.Visibility]::Collapsed
    $checkboxAutoLogout.Visibility = [System.Windows.Visibility]::Collapsed
    $checkboxAutoSleep.Visibility  = [System.Windows.Visibility]::Collapsed
})

[void]$root.Children.Add($settingsBorder)

# Activity + progress bar
$statusPanel = New-Object System.Windows.Controls.StackPanel
$statusPanel.Margin = New-Object System.Windows.Thickness(0, 0, 0, 10)
[System.Windows.Controls.Grid]::SetRow($statusPanel, 2)

$activityText = New-Object System.Windows.Controls.TextBlock
$activityText.Text = ""
$activityText.Foreground = $textLight
$activityText.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)

$progressBar = New-Object System.Windows.Controls.ProgressBar
$progressBar.Height = 15
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Background = $panelDark
$progressBar.Foreground = $accent
$progressBar.BorderBrush = $borderDark

[void]$statusPanel.Children.Add($activityText)
[void]$statusPanel.Children.Add($progressBar)
$statusPanel.Visibility = [System.Windows.Visibility]::Hidden
[void]$root.Children.Add($statusPanel)

# Log output
$logBox = New-Object System.Windows.Controls.RichTextBox
$logBox.Background = "#000000"
$logBox.Foreground = "#DCDCDC"
$logBox.BorderBrush = $borderDark
$logBox.BorderThickness = New-Object System.Windows.Thickness(1)
$logBox.FontFamily = "Consolas"
$logBox.FontSize = 14
$logBox.IsReadOnly = $true
$logBox.IsDocumentEnabled = $false
$logBox.VerticalScrollBarVisibility = "Auto"
$logBox.HorizontalScrollBarVisibility = "Auto"
[System.Windows.Controls.Grid]::SetRow($logBox, 3)
[void]$root.Children.Add($logBox)

# Footer: Statistics panel. Header row shows the title
# Running elapsed-time clock (right). live stats from LorewalkingHelper.ps1 via Write-GuiEvent
$footerBorder = New-Object System.Windows.Controls.Border
$footerBorder.Background = $panelDark
$footerBorder.BorderBrush = $borderDark
$footerBorder.BorderThickness = New-Object System.Windows.Thickness(1)
$footerBorder.CornerRadius = New-Object System.Windows.CornerRadius(6)
$footerBorder.Padding = New-Object System.Windows.Thickness(12)
$footerBorder.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
[System.Windows.Controls.Grid]::SetRow($footerBorder, 4)

$footerContent = New-Object System.Windows.Controls.StackPanel
$footerBorder.Child = $footerContent

# Header row: "Statistics" title (left) + running elapsed-time clock (right)
$footerHeaderRow = New-Object System.Windows.Controls.DockPanel
$footerHeaderRow.LastChildFill = $false
$footerHeaderRow.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
[void]$footerContent.Children.Add($footerHeaderRow)

$footerHeader = New-Object System.Windows.Controls.TextBlock
$footerHeader.Text = "Statistics"
$footerHeader.FontWeight = "Bold"
$footerHeader.Foreground = $accent
# use this if i re-enable the collapse feature
#$footerHeader.Cursor = [System.Windows.Input.Cursors]::Hand
[System.Windows.Controls.DockPanel]::SetDock($footerHeader, [System.Windows.Controls.Dock]::Left)
[void]$footerHeaderRow.Children.Add($footerHeader)

$elapsedTimeText = New-Object System.Windows.Controls.TextBlock
$elapsedTimeText.Foreground = $textLight
$elapsedTimeText.VerticalAlignment = "Center"
$elapsedTimeText.Visibility = [System.Windows.Visibility]::Collapsed
[System.Windows.Controls.DockPanel]::SetDock($elapsedTimeText, [System.Windows.Controls.Dock]::Right)
[void]$footerHeaderRow.Children.Add($elapsedTimeText)

$footer = New-Object System.Windows.Controls.Grid
$footerColLeft = New-Object System.Windows.Controls.ColumnDefinition
$footerColLeft.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
$footerColRight = New-Object System.Windows.Controls.ColumnDefinition
$footerColRight.Width = [System.Windows.GridLength]::Auto
[void]$footer.ColumnDefinitions.Add($footerColLeft)
[void]$footer.ColumnDefinitions.Add($footerColRight)
[void]$footerContent.Children.Add($footer)

# not using for now
# Toggles the stats grid's visibility, collapsing/expanding the footer without hiding its header.
#$footerHeader.Add_MouseLeftButtonUp({
#    $footer.Visibility = if ($footer.Visibility -eq [System.Windows.Visibility]::Visible) {
#        [System.Windows.Visibility]::Collapsed
#    } else {
#        [System.Windows.Visibility]::Visible
#    }
#}.GetNewClosure())

# Left side of the footer - live stats, updated by LorewalkingHelper.ps1 via {type:'stats'} GuiEvents
$footerLeft = New-Object System.Windows.Controls.StackPanel
$footerLeft.Orientation = "Vertical"
$footerLeft.VerticalAlignment = "Center"
[System.Windows.Controls.Grid]::SetColumn($footerLeft, 0)
[void]$footer.Children.Add($footerLeft)

# Creates one line of the stats panel and returns the TextBlock so its text can be updated later
function New-StatLine {
    param([string]$Text)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.Foreground = $textLight
    $tb.FontFamily = "Consolas"
    [void]$footerLeft.Children.Add($tb)
    $tb
}

$currentLevelText    = New-StatLine "Current level:    -"
$questsCompletedText = New-StatLine "Quests completed: -"
$lastQuestTimeText   = New-StatLine "Time per quest:   -"
$etaNextLevelText    = New-StatLine "ETA next level:   -"
$etaMaxLevelText     = New-StatLine "ETA max level:    -"

# Updates the footer's stat lines from a {type:'stats'} GuiEvent. Any field left out of $Evt is left unchanged.
function Update-Stats {
    param($Evt)
    if ($null -ne $Evt.currentLevel)    { $currentLevelText.Text    = "Current level:    $($Evt.currentLevel)" }
    if ($null -ne $Evt.questsCompleted) { $questsCompletedText.Text = "Quests completed: $($Evt.questsCompleted)" }
    if ($null -ne $Evt.lastQuestTime)   { $lastQuestTimeText.Text   = "Time per quest:   $($Evt.lastQuestTime)" }
    if ($null -ne $Evt.etaNextLevel)    { $etaNextLevelText.Text    = "ETA next level:   $($Evt.etaNextLevel)" }
    if ($null -ne $Evt.etaMaxLevel)     { $etaMaxLevelText.Text     = "ETA max level:    $($Evt.etaMaxLevel)" }
}

# Resets all stat lines back to their placeholder text (called when a new run starts)
function Reset-Stats {
    $currentLevelText.Text    = "Current level:    -"
    $questsCompletedText.Text = "Quests completed: -"
    $lastQuestTimeText.Text   = "Time per quest:   -"
    $etaNextLevelText.Text    = "ETA next level:   -"
    $etaMaxLevelText.Text     = "ETA max level:    -"
}

# Right side of the footer - reserved for future stats
$footerRight = New-Object System.Windows.Controls.StackPanel
$footerRight.Orientation = "Horizontal"
$footerRight.VerticalAlignment = "Center"
[System.Windows.Controls.Grid]::SetColumn($footerRight, 1)

[void]$footer.Children.Add($footerRight)
[void]$root.Children.Add($footerBorder)

# Updates the footer's "Session Time" clock, ticked once a second while the app is running
function Update-ElapsedTime {
    if (-not $script:appStartTime) { return }
    $elapsed = (Get-Date) - $script:appStartTime
    $elapsedTimeText.Text = "Session Time: " + $elapsed.ToString('hh\:mm\:ss')
}

# Starts the footer clock from zero
function Start-ElapsedTimer {
    $script:appStartTime = Get-Date
    $elapsedTimeText.Visibility = [System.Windows.Visibility]::Visible
    Update-ElapsedTime
    $elapsedTimer.Start()
}

# Stops the footer clock and hides it
function Stop-ElapsedTimer {
    $elapsedTimer.Stop()
    $script:appStartTime = $null
    $elapsedTimeText.Visibility = [System.Windows.Visibility]::Collapsed
    $elapsedTimeText.Text = ""
}

$elapsedTimer = New-Object System.Windows.Threading.DispatcherTimer
$elapsedTimer.Interval = [TimeSpan]::FromSeconds(1)
$elapsedTimer.Add_Tick({ Update-ElapsedTime })

# Timer that pumps queued app output onto the UI thread
$consoleTimer = New-Object System.Windows.Threading.DispatcherTimer
$consoleTimer.Interval = [TimeSpan]::FromMilliseconds(100)
$consoleTimer.Add_Tick({ Update-Console })

# Save settings and stop the app on window closing
$window.Add_Closing({
    $consoleTimer.Stop()
    # Kill the process (closing its stdout/stderr streams) before stopping the readers - otherwise
    # the reader threads are still blocked in a synchronous ReadLine() call that Stop()/Dispose()
    # can't interrupt, which hangs the UI thread and freezes the whole GUI.
    if ($script:proc -and -not $script:proc.HasExited) {
        try { $script:proc.Kill() } catch {}
    }
    if ($script:proc) {
        try { $script:proc.Dispose() } catch {}
    }
    Stop-StreamReaders

    $settings.AutoStop     = $checkboxAutoStop.IsChecked -eq $true
    $settings.AutoStopTime = if ($Null -ne $textBoxAutoStopTime.Text -and $textBoxAutoStopTime.Text -match '^\d+$' ) {$textBoxAutoStopTime.Text} else {300}
    $settings.AutoLogout   = $checkboxAutoLogout.IsChecked -eq $true
    $settings.AutoSleep    = $checkboxAutoSleep.IsChecked -eq $true
    $settings.LoadingTime  = if ($Null -ne $textBoxLoadingTime.Text -and $textBoxLoadingTime.Text -match '^\d+$' ) {$textBoxLoadingTime.Text} else {10}
    Export-Settings -settings $settings
})

[void]$window.ShowDialog()
