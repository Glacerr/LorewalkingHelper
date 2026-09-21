####################################################
###              Lorewalking Helper              ###
####################################################
# Requirements:                                    #
#   - World of Warcraft Account                    #
#   - Windows 10/11                                #
# Info:                                            #
#   - https://github.com/Glacerr/LorewalkingHelper #
####################################################

##########################
### GENERAL SETTINGS ####
##########################
#Region Settings
using namespace Windows.Storage
using namespace Windows.Graphics.Imaging

# Default General Settings. These can get overridden by the LorewalkingHelperGui. Don't set these manually here
[CmdletBinding()]
param (
    $autoStop     = $True,  # $False to disable
    $autoStopTime = 300,    # in minutes
    $autoLogout   = $False, # if $True, your char will logout after the $autoStopTime is reached and $autoStop is set to $True
    $autoSleep    = $False, # if $True, sleeps the computer after the $autostop time is reached and $Autostop is set to $True. Will first logout if that is set to $True though.
    $loadingTime  = 10,     # Seconds for default loading time. Set to what you think your average loading time is between Zones. 20 seconds will be added on to this to continue checking before the script stops.

    ##########################
    ### ADVANCED SETTINGS ####
    ##########################
    # These are all editable from LorewalkingHelperGui.ps1's Advanced Settings dialog (saved to LorewalkingHelperSettings.json).
    # Don't set these manually here - the values below are only the fallback defaults.

    $useWindowFocus = $False, # If set to $False, you need to make sure wow is focused yourself. Set to $True to have it be focused each time a command needs to be sent to it.
    $usePi          = $False, # If using a raspberry pi pico, set to $True. Pi is safer for hardware input. Costs 4$ USD, pretty worth.
    $picoComPort    = "AUTO", # set to pi pico com port if using a pi. Manually set com port if you need (ie: "COM3"), otherwise leave at "AUTO", and it will try to auto-detect
    $wowInstallPath = "AUTO", # Manually set your wow install path if the "AUTO" detection does not detect it properly. ie: "C:\Program Files (x86)\World of Warcraft"
    $questXpModifier = 0,     # Percentage bonus (eg: warmode/warband/etc) added on top of the base XpPerQuest values in $script:levelXpTable when estimating leveling ETAs.

    ### Main Lorewalking Helper Addon Settings ###
    $PrimaryKeybind  = "F12", # Primary Keybind that the LorewalkingHelper addon is set to with in-game command: /lw keybind <keybind>
    $FailsafeKeybind = "F11", # Failsafe Keybind. Requires manual macro created with: /lw startover
    $logout          = "F10", # Keybind for logging out /logout macro manually created in-game required and keybound
    $enableFailsafe  = $True, # This is a failsafe in case the char gets stuck and can't progress. If $True, after 30 failed checks have lapsed, it will try and reset itself back at the start of Lorewalking Helper and try again.
                              # This is allowed to happen 3x per session. After that, the app will stop and you should check out why it's not working.
                              # This requires the FailsafeKeybind to be set in-game and keybound to a macro that runs /lw startover. Set $False to disable this option and not try to start over. 

    ### Notification Settings ###
    # Only Discord Supported currently
    $discordWebhook,
    $enableNotifications = $True, # $False to disable
    $onStart             = $True,
    $onStop              = $True,
    $onError             = $True,
    $onLevelUp           = $True,

    ### Lorewalking Helper Addon Screen Location ###
    $windowTitle         = 'World of Warcraft', # change this for the wow version, eg retail: 'World of Warcraft', classic: 'WoW Classic' etc. Name of the actual windows title bar.
    $AddonScreenLocation = "BOTTOMLEFT",         # Options: "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMMIDDLE". This is ignored if you set your own coordinates below.
    $useMyOwnCoordinates = $False,               # Set this to $True and then set your own x/y coordinates below. If set to $false, will use the positioning from the $AddonScreenLocation above.
    $topleftX     = 0,
    $topLeftY     = 0,
    $bottomRightX = 0,
    $bottomRightY = 0,

    # Current Expansion Max level
    $currentMaxLevel = 90
)

#Endregion Settings
##################################
### DONT EDIT BELOW THIS LINE ####
##################################

# Normalize boolean-like params: the GUI passes these as "True"/"False" strings via the command line,
# and a non-empty string is always truthy in PowerShell, so string values must be parsed explicitly.
function ConvertTo-Bool($Value) {
    if ($Value -is [bool]) { return $Value }
    return [string]$Value -match '^(?i:true|1)$'
}
$autoStop             = ConvertTo-Bool $autoStop
$autoLogout           = ConvertTo-Bool $autoLogout
$autoSleep            = ConvertTo-Bool $autoSleep
$useWindowFocus       = ConvertTo-Bool $useWindowFocus
$usePi                = ConvertTo-Bool $usePi
$enableFailsafe       = ConvertTo-Bool $enableFailsafe
$enableNotifications  = ConvertTo-Bool $enableNotifications
$onStart              = ConvertTo-Bool $onStart
$onStop               = ConvertTo-Bool $onStop
$onError              = ConvertTo-Bool $onError
$onLevelUp            = ConvertTo-Bool $onLevelUp
$useMyOwnCoordinates  = ConvertTo-Bool $useMyOwnCoordinates


#Region Helper functions

# Emits a single structured JSON line to stdout for the GUI to parse
function Write-GuiEvent {
    param([hashtable]$Evt)
    # Writes directly to the real stdout stream (not the success pipeline) so it can't be captured/
    # swallowed by callers that wrap a call in (...) or assign it, eg: if (-not (Start-Check ...))
    [Console]::Out.WriteLine(($Evt | ConvertTo-Json -Compress -Depth 4))
}

# Base (no bonus XP) values for XP (as of Midnight patch 12.1) gained per quest and XP required to reach the next level.
# $questXpModifier applies any warmode/warband/etc bonus % on top of these when estimating leveling ETAs.
# 4,963,065 Total XP For 80-90
$script:levelXpTable = @{
    80 = @{ XpPerQuest = 11750; XpToNext = 403725 }
    81 = @{ XpPerQuest = 11900; XpToNext = 423390 }
    82 = @{ XpPerQuest = 12050; XpToNext = 443395 }
    83 = @{ XpPerQuest = 12150; XpToNext = 463740 }
    84 = @{ XpPerQuest = 12300; XpToNext = 484430 }
    85 = @{ XpPerQuest = 12450; XpToNext = 505455 }
    86 = @{ XpPerQuest = 12600; XpToNext = 526825 }
    87 = @{ XpPerQuest = 12700; XpToNext = 548535 }
    88 = @{ XpPerQuest = 12850; XpToNext = 570590 }
    89 = @{ XpPerQuest = 13000; XpToNext = 592980 }
}
$script:totalQuestTime = [TimeSpan]::Zero

# Sends the GUI's live "Statistics" footer values: current level, quests completed, average time per
# quest, and ETA to the next level / max level, derived from $script:levelXpTable above.
function Update-LevelingStats {

    $avgTimePerQuest = if ($script:count -gt 0) {
        [TimeSpan]::FromTicks([long]($script:totalQuestTime.Ticks / $script:count))
    } else {
        [TimeSpan]::Zero
    }

    $etaNextLevel = $Null
    $etaMaxLevel  = $Null
    $level = [int]$script:currentLevel
    $xpModifier = 1 + ([double]$questXpModifier / 100)

    if ($level -ge $currentMaxLevel) {
        $etaNextLevel = [TimeSpan]::Zero
        $etaMaxLevel  = [TimeSpan]::Zero
    } elseif ($script:levelXpTable.ContainsKey($level) -and $avgTimePerQuest -gt [TimeSpan]::Zero) {
        # Subtract XP already earned toward this level so the ETA reflects only the XP remaining
        $xpRemainingThisLevel = [Math]::Max(0, $script:levelXpTable[$level].XpToNext - [double]$script:currentXP)
        $questsToNext = [Math]::Ceiling($xpRemainingThisLevel / ($script:levelXpTable[$level].XpPerQuest * $xpModifier))
        $etaNextLevel = [TimeSpan]::FromTicks([long]($avgTimePerQuest.Ticks * $questsToNext))

        $totalQuestsToMax = $questsToNext
        for ($lvl = $level + 1; $lvl -lt $currentMaxLevel; $lvl++) {
            if (-not $script:levelXpTable.ContainsKey($lvl)) { continue }
            $totalQuestsToMax += [Math]::Ceiling($script:levelXpTable[$lvl].XpToNext / ($script:levelXpTable[$lvl].XpPerQuest * $xpModifier))
        }
        $etaMaxLevel = [TimeSpan]::FromTicks([long]($avgTimePerQuest.Ticks * $totalQuestsToMax))
    }

    $script:avgTimePerQuest = $avgTimePerQuest.ToString('hh\:mm\:ss')
    $script:etaNextLevel = if ($Null -ne $etaNextLevel) { $etaNextLevel.ToString('hh\:mm\:ss') } else { 'Unknown' }
    $script:etaMaxLevel  = if ($Null -ne $etaMaxLevel) { $etaMaxLevel.ToString('hh\:mm\:ss') } else { 'Unknown' }
    
    Write-GuiEvent -Evt @{
        type            = 'stats'
        currentLevel    = $script:currentLevel
        questsCompleted = $script:count
        avgTimePerQuest = $script:avgTimePerQuest
        etaNextLevel    = $script:etaNextLevel
        etaMaxLevel     = $script:etaMaxLevel
    }
}

function Write-AppLog {
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [string]$Object = "",
        [string]$ForegroundColor = "White",
        [switch]$NoNewline
    )
    Write-GuiEvent -Evt @{ type = 'log'; text = $Object; color = $ForegroundColor; noNewline = $NoNewline.IsPresent }
}

# Tells the GUI to clear its log
function Clear-AppLog {
    Write-GuiEvent -Evt @{ type = 'clear' }
    return
}

function Send-Notification {
    param(
        [string]$Title           = "Lorewalking",
        [string]$Color           = "Green",
        [string]$Desc            = $Null,
        [string]$QuestsCompleted = $Null,
        [string]$Runtime         = $Null,
        [string]$PicPath         = $Null,
        [string]$CurrentLevel    = $Null,
        [string]$AvgTimePerQuest = $Null,
        [string]$EtaNextLevel    = $Null,
        [string]$EtaMaxLevel     = $Null

    )

    # Convert friendly color name to Discord decimal color
    $Color = switch ($Color) {
        Red     { '15158332' } # #E74C3C
        Green   { '3066993'  } # #2ECC71
        Yellow  { '16705372' } # #F1C40F
        Blue    { '3447003'  } # #3498DB
        Orange  { '15105570' } # #E67E22
        Purple  { '10181046' } # #9B59B6
        Gray    { '9807270'  } # #95A5A6
        default {throw "Unknown Discord embed color: $Color"}
    }

    # Build optional fields
    $fields = @()

    if (-not [string]::IsNullOrWhiteSpace($currentLevel)) {
        $fields += @{
            name   = "Cur Lvl"
            value  = $currentLevel
            inline = $True
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($questsCompleted)) {
        $fields += @{
            name   = "Quests done"
            value  = $Count
            inline = $True
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Runtime)) {
        $fields += @{
            name   = "Runtime"
            value  = $Runtime
            inline = $True
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($avgTimePerQuest)) {
        $fields += @{
            name   = "Avg time/quest"
            value  = $avgTimePerQuest
            inline = $True
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($etaNextLevel)) {
        $fields += @{
            name   = "ETA nxt Lvl"
            value  = $etaNextLevel
            inline = $True
        }
    }

        if (-not [string]::IsNullOrWhiteSpace($etaMaxLevel)) {
        $fields += @{
            name   = "ETA max Lvl"
            value  = $etaMaxLevel
            inline = $True
        }
    }

    # Base embed
    $embed = @{
        title       = $Title
        color       = [int]$Color
        footer = @{
            text = "$Env:ComputerName"
        }
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
    }

    # Add desc and fields only if present
    if ($desc) {
        $embed.description = $desc
    }        
    if ($fields.Count -gt 0) {
        $embed.fields = $fields
    }

    # Add image only when a valid screenshot exists
    if ($PicPath -and (Test-Path -LiteralPath $PicPath)) {
        $fileName = [System.IO.Path]::GetFileName($PicPath)
        $embed.image = @{
            url = "attachment://$fileName"
        }
    }

    # Build Discord JSON
    # alt: "https://raw.githubusercontent.com/Glacerr/wow_assets/main/img/world-of-warcraft.png"
    $discordBody = @{
        username   = "Lorewalker Li Li"
        avatar_url = "https://raw.githubusercontent.com/Glacerr/wow_assets/main/img/lili.png"
        embeds     = @($embed)
    } | ConvertTo-Json -Depth 10

    $httpClient = New-Object System.Net.Http.HttpClient
    $form = New-Object System.Net.Http.MultipartFormDataContent

    try {

        # Add JSON payload
        $jsonContent = New-Object System.Net.Http.StringContent(
            $discordBody,
            [System.Text.Encoding]::UTF8,
            "application/json"
        )

        $form.Add($jsonContent, "payload_json")

        # Add screenshot
        if ($PicPath -and (Test-Path -LiteralPath $PicPath)) {

            $fileBytes = [System.IO.File]::ReadAllBytes($PicPath)
            $fileContent = New-Object System.Net.Http.ByteArrayContent((,$fileBytes))
            $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
            $form.Add($fileContent, "files[0]", $fileName)
        }

        # Send to Discord
        $response = $httpClient.PostAsync($discordWebHook, $form).GetAwaiter().GetResult()

        if (-not $response.IsSuccessStatusCode) {
            $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            Write-AppLog "Failed to send Discord notification: $($response.StatusCode) $responseBody" -ForegroundColor Red
        }
    } Catch {
        Write-AppLog "Failed to send Discord notification: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        $form.Dispose()
        $httpClient.Dispose()
    }
}

function Start-Press {
    param(
        [string]$key="",                # key to press
        [string]$msg="$($key) pressed", # message to display when pressing key
        [float]$waitMin=1.1,            # min delay in seconds after pressing key
        [float]$waitMax=1.5,            # max delay in seconds after pressing key
        [float]$amount=1,               # how many times to press the key. Default = 1
        [string]$color="White",         # Set the Write-AppLog Color
        [switch]$silent                 # Do not output
    )

    $waitMin = $waitMin * 1000
    $waitMax = $waitMax * 1000

    for ($i = 1; $i -le $amount; $i++) {
        if ($silent -eq $False) {
            if ($amount -eq 1) {
                Write-AppLog $msg -ForegroundColor $color
            } else {
                Write-AppLog "$msg [Press $i of $amount]" -ForegroundColor $color
            }
        }

        if ($useWindowFocus -eq $True) {
            Write-AppLog "Focusing" -ForegroundColor Cyan
            if ([WoWScreenHelper]::IsIconic($process.MainWindowHandle)) {
                [WoWScreenHelper]::ShowWindow($process.MainWindowHandle, 9) | Out-Null
            } else {
                [WoWScreenHelper]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
            }
            [System.Threading.Thread]::Sleep(200)
        }

        # press
        Try {
            if ($usePi -eq $True) {
                $port.WriteLine("$key")
            } else {
                [System.Windows.Forms.SendKeys]::SendWait("{$key}")
            }
        } Catch {
            Write-AppLog "Failed to press key" -ForegroundColor Red
        }
        # Wait a random amount after pressing
        $waitAfterPress = Get-Random -Minimum $waitMin -Maximum $waitMax
        [System.Threading.Thread]::Sleep($waitAfterPress) # Wait a sec before doing other stuff
    }
}

function Start-SleepWithProgress([Int]$Seconds, [String]$Activity, [Switch]$nosleep) {

    for ($i = 1; $i -le $Seconds; $i++) {
        $secondsRemaining = $Seconds - $i

        Write-GuiEvent -Evt @{ type = 'progress'; activity = $Activity; secondsRemaining = $secondsRemaining; totalSeconds = $Seconds }

        if (!$nosleep) {
            [System.Threading.Thread]::Sleep(1000)
        }
    }
    Write-GuiEvent -Evt @{ type = 'progress'; activity = $Activity; secondsRemaining = 0; totalSeconds = $Seconds; done = $true }
}

function Get-RunningTime {
    # Wall-clock based (not Stopwatch) so it keeps counting through system sleep/hibernate, matching the GUI's Session Time
    $totalSeconds = [Math]::Floor(((Get-Date) - $runStartTime).TotalSeconds)
    $hours   = [int]($totalSeconds / 3600)
    $minutes = [int](($totalSeconds % 3600) / 60)
    $seconds = [int]($totalSeconds % 60)
    $parts = @()

    if ($hours -gt 0) {
        $parts += "$hours hour" + ($(if ($hours -ne 1) {"s"}))
    }
    if ($minutes -gt 0) {
        $parts += "$minutes min" + ($(if ($minutes -ne 1) {"s"}))
    }
    if ($seconds -gt 0) {
        $parts += "$seconds sec" + ($(if ($seconds -ne 1) {"s"}))
    }
    if ($parts.Count -eq 0) {
        return "less than a second"
    }

    return $parts -join ' '
}

function Invoke-AutoStop {
    if ( ($script:maxLevel -eq $True) -or ($autoStop -and ((Get-Date) -gt $autoEndTime)) -or ($script:failsafeTriggered -gt 3) ) {
        # end script
        if ($script:maxLevel -ne $True -and ($autoStop -and ((Get-Date) -gt $autoEndTime)) -and ($script:failsafeTriggered -le 3)) {
            Write-AppLog "Time Limit Reached - Lorewalking Stopped" -ForegroundColor Yellow
            Update-LevelingStats
            Send-Notification -Title "Lorewalking Stopped" -Desc "AutoStop time reached after $($autoStopTime)m" -Runtime $ranFor `
                              -CurrentLevel $script:currentLevel -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                              -EtaNextLevel $script:etaNextLevel -EtaMaxLevel $script:etaMaxLevel -Color 'Red' -PicPath "$path\WoWLorewalkingFull.png"
        }
        
        if ($autoLogout) {
            Start-Press -Key $logout -Msg 'Logging Out' -Color 'Yellow'
            Start-SleepWithProgress -Seconds 25 "Waiting for Logout"
        }

        if ($port.IsOpen) { $port.close() }

        If ($autoSleep -eq $True) {
            Write-AppLog "Sleeping PC.. Lorewalking Stopped" -ForegroundColor Yellow
            # a little more complicated than i want, but it helps to call sleep from a seperate process so the script can exit cleanly first.
            Start-Process -FilePath "powershell.exe" -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "Start-Sleep -Seconds 2;rundll32.exe powrprof.dll,SetSuspendState 0,1,0"
            Exit
        }

        Write-AppLog "Lorewalking Stopped"
        Exit
    }
}

# Screenshot function
function Get-WoWScreenShot {
    [CmdletBinding()]
    param(
        [int]$TopLeftX,
        [int]$TopLeftY,
        [int]$BottomRightX,
        [int]$BottomRightY,
        [string]$PicPath="$path\WoWLorewalking.png"
    )

    $width  = $BottomRightX - $TopLeftX
    $height = $BottomRightY - $TopLeftY

    if ($width -le 0) {
        throw "Screenshot width must be greater than zero."
    }
    if ($height -le 0) {
        throw "Screenshot height must be greater than zero."
    }

    $pic = New-Object System.Drawing.Bitmap($width,$height)
    $graphics = [System.Drawing.Graphics]::FromImage($pic)

    try {
        $graphics.CopyFromScreen($TopLeftX,$TopLeftY,0,0,[System.Drawing.Size]::new($width,$height))
        $pic.Save($PicPath)
    }
    finally {
        $graphics.Dispose()
        $pic.Dispose()
    }
}

# OCR Scan Function
# Uses windows 10/11 builtin ocr, may need to set language pack type stuff if not default english
function Get-Ocr {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path
    )

    begin {

        # Create the OCR engine using the user's configured Windows languages.
        $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()

        if ($null -eq $ocrEngine) {
            throw "Unable to create the Windows OCR engine. Make sure a supported OCR language is installed."
        }

        # Find the WinRT GetAwaiter<T> method.
        # Windows PowerShell 5.1 and PowerShell 7 expose the WinRT async
        # support somewhat differently, so locate the method dynamically rather than relying on a particular overload.
        $getAwaiterBaseMethod = [WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object {
                $_.Name -eq 'GetAwaiter' -and
                $_.IsGenericMethod -and
                $_.GetParameters().Count -eq 1 -and
                $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
            } |
            Select-Object -First 1

        if ($null -eq $getAwaiterBaseMethod) {
            throw "Unable to locate Windows Runtime GetAwaiter<T> method."
        }

        function Await {
            param(
                [Parameter(Mandatory = $true)]
                $AsyncOperation,

                [Parameter(Mandatory = $true)]
                [Type]$ResultType
            )

            $awaiter = $getAwaiterBaseMethod.MakeGenericMethod($ResultType).Invoke(
                $null,
                @($AsyncOperation)
            )

            $awaiter.GetResult()
        }
    }

    process {

        foreach ($p in $Path) {

            $fileStream = $null
            $softwareBitmap = $null

            try {

                # Convert PowerShell's path to a real filesystem path
                $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)

                # Open the image file
                $storageFile = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($p)) ([Windows.Storage.StorageFile])

                # Open the file as a WinRT random-access stream.
                $fileStream = Await ($storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])

                # Decode the image.
                $bitmapDecoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($fileStream)) ([Windows.Graphics.Imaging.BitmapDecoder])

                # Convert the decoded image to a SoftwareBitmap.
                $softwareBitmap = Await ($bitmapDecoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])

                # Perform OCR.
                $result = Await ($ocrEngine.RecognizeAsync($softwareBitmap)) ([Windows.Media.Ocr.OcrResult])

                # Output the recognized text.
                $result.Text
            }
            catch {
                Write-Warning "OCR failed for '$p': $($_.Exception.Message)"
            }
            finally {

                if ($null -ne $fileStream) {
                    $fileStream.Dispose()
                }

                $softwareBitmap = $null
                $fileStream = $null
            }
        }
    }
}

# get window and sizes function
function Get-Window {
    [CmdletBinding()]
    param(
        [string]$windowTitle,
        [int]$windowHandle,
        [string]$processName
    )

    $clientRect = New-Object RECT
    if (-not [WoWScreenHelper]::GetClientRect($windowHandle, [ref]$clientRect)) {
        Write-AppLog "Getting WoW screen position failed.`nCheck that window is visible, WoW is running or the window title in settings." -ForegroundColor 'Red'
    }

    # Client coordinate (0,0) -> screen coordinate
    $screenPoint = New-Object POINT
    $screenPoint.X = 0
    $screenPoint.Y = 0
    if (-not [WoWScreenHelper]::ClientToScreen($windowHandle, [ref]$screenPoint)) {
                Write-AppLog "Getting WoW screen coordinates failed.`nCheck that window is visible, WoW is running or the window title in settings." -ForegroundColor 'Red'
    }

    $left   = $screenPoint.X
    $top    = $screenPoint.Y
    $width  = $clientRect.Right - $clientRect.Left
    $height = $clientRect.Bottom - $clientRect.Top
    $right  = $left + $width
    $bottom = $top + $height

    [pscustomobject]@{
        ProcessName = $processName
        WindowTitle = $windowTitle
        Handle      = $windowHandle
        Left        = $left
        Top         = $top
        Right       = $right
        Bottom      = $bottom
        Width       = $width
        Height      = $height
    }

    if ( ([WoWScreenHelper]::IsIconic($windowHandle)) -or (-not [WoWScreenHelper]::IsWindowVisible($windowHandle)) -or ($top -lt 0 -AND $left -lt 0) ) {
        Write-AppLog "Could not determine screen capture coordinates.`nVerify the window is not minimized or adjust it's position." -ForegroundColor 'Red'
        Return
    }
}

# Get screen coordinates for capture
function Get-ScreenCoordinates {
    if ($useMyOwnCoordinates -eq $False) {
        $window = Get-Window -windowTitle $process.MainWindowTitle -windowHandle $process.MainWindowHandle -processName $process.ProcessName
        if (-not $window) {
            Write-AppLog "Is WoW started? Could not determine window coordinates for screen capture" -ForegroundColor 'Red'
            Return
        }

        # Always get full screen coordinates
        $full_topLeftX = $window.left
        $full_topLeftY = $window.top
        $full_bottomRightX = $window.right
        $full_bottomRightY = $window.bottom

        switch ($AddonScreenLocation) {
            "BOTTOMLEFT" {
                # Bottom-left 1/4 corner of the window.
                $left_topLeftX     = $window.left
                $left_topLeftY     = [math]::Floor((($window.height * 0.66) + $window.top))
                $left_bottomRightX = [math]::floor(($window.width / 4) + $window.left)
                $left_bottomRightY = $window.bottom

                $addon_topLeftX     = $left_topLeftX
                $addon_topLeftY     = $left_topLeftY
                $addon_bottomRightX = $left_bottomRightX
                $addon_bottomRightY = $left_bottomRightY
            }
            "BOTTOMRIGHT" {
                # bottom-right 1/4 corner of the window
                $right_topLeftX = [math]::Floor((($window.width / 4) * 3) + $window.left)
                $right_topLeftY = [math]::Floor((($window.height * 0.66) + $window.top))
                $right_bottomRightX = $window.right
                $right_bottomRightY = $window.Bottom

                $addon_topLeftX     = $right_topLeftX
                $addon_topLeftY     = $right_topLeftY
                $addon_bottomRightX = $right_bottomRightX
                $addon_bottomRightY = $right_bottomRightY
            }
            "BOTTOMMIDDLE" {
                # bottom middle third of the window
                $bottom_TopLeftX = [math]::floor(($window.width / 3) + $window.left) # middle 3rd horizontal
                $bottom_topLeftY = [math]::Floor(($window.height * 0.66) + $window.top) # perc of window height. ie: 0.75 = bottom 25%, 0.60 = bottom 40 %
                $bottom_bottomRightX = [math]::floor((($window.width / 3) * 2) + $window.left)
                $bottom_bottomRightY = $window.bottom

                $addon_topLeftX     = $bottom_TopLeftX
                $addon_topLeftY     = $bottom_topLeftY
                $addon_bottomRightX = $bottom_bottomRightX
                $addon_bottomRightY = $bottom_bottomRightY
            }
            default {
                Write-AppLog "Invalid AddonScreenLocation specified" -ForegroundColor Red
                Return
            }
        }

    } else {
        # set users own coordinates
        $addon_topLeftX     = $topLeftX
        $addon_topLeftY     = $topLeftY
        $addon_bottomRightX = $bottomRightX
        $addon_bottomRightY = $bottomRightY

        $window = Get-Window -windowTitle $process.MainWindowTitle -windowHandle $process.MainWindowHandle -processName $process.ProcessName
        if (-not $window) {
            Write-AppLog "Is WoW started? Could not determine window coordinates for screen capture" -ForegroundColor 'Red'
            Return
        } else {
            # always get full screen coordinates
            $full_topLeftX = $window.left
            $full_topLeftY = $window.top
            $full_bottomRightX = $window.right
            $full_bottomRightY = $window.bottom
        }
    }

    [pscustomobject]@{
        addon_topLeftX     = $addon_topLeftX
        addon_topLeftY     = $addon_topLeftY
        addon_bottomRightX = $addon_bottomRightX
        addon_bottomRightY = $addon_bottomRightY
        full_topLeftX      = $full_topLeftX
        full_topLeftY      = $full_topLeftY
        full_bottomRightX  = $full_bottomRightX
        full_bottomRightY  = $full_bottomRightY
    }
}
#endregion Helper Functions

function Start-Check {
    Param(
        [string]$word,
        [int]$retryCount = 30
    )
    # $activity = "Waiting for keyword '$word'"
    $activity = "Waiting for next step"
    try {
        $screen = Get-ScreenCoordinates
        for ($i = 0; $i -lt $retryCount; $i++) {
            [System.Threading.Thread]::Sleep(500)
            Get-WoWScreenShot -TopLeftX $screen.addon_topLeftX -TopLeftY $screen.addon_topLeftY -BottomRightX $screen.addon_bottomRightX -BottomRightY $screen.addon_bottomRightY -PicPath "$path\WoWLorewalking.png"
            $ocr = Get-Ocr -Path "$path\WoWLorewalking.png"

            # extract current level and xp on first run
            if ($script:count -eq 0 -and $script:firstUpdate -eq $True) {
                $ocr -match "lvl.*?(\d+)" | Out-Null
                if ($matches) {
                    $level = $matches[1]
                    $script:currentLevel = $level
                }

                $ocr -match "xp.*?(\d+)" | Out-Null
                if ($matches) {
                    $xp = $matches[1]
                    $script:currentXP = $xp
                }
                Update-LevelingStats
                $script:firstUpdate = $False
            }

            if ($ocr -like "*$word*") {
                return $true
            } elseif ($ocr -like "*congrat*") {
                $ranFor = Get-RunningTime
                Write-AppLog "CONGRATS! You've reached max level!" -ForeGroundColor Green
                Write-AppLog "Ran for: $ranFor"
                Update-LevelingStats
                if ($enableNotifications -and $onStop) {
                    Get-WoWScreenShot -topleftX $screen.full_topLeftX -topLeftY $screen.full_topLeftY -bottomRightX $screen.full_bottomRightX -bottomRightY $screen.full_bottomRightY -picPath "$path\WoWLorewalkingFull.png"
                    Send-Notification -Title "Lorewalking Completed" -Desc "CONGRATS!`nYou've reached max level!" -Runtime $ranFor `
                              -CurrentLevel "90" -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                              -Color 'Green' -PicPath "$path\WoWLorewalkingFull.png"
                
                }
                $script:maxLevel = $True
                $script:currentLevel = $currentMaxLevel
                Update-LevelingStats
                return
            } elseif ($ocr -like "*ding*") {
                # level
                $ocr -match "lvl.*?(\d+)" | Out-Null
                $ranFor = Get-RunningTime
                if ($matches) {
                    $level = $matches[1]
                    $script:currentLevel = $level
                    Update-LevelingStats
                    Write-AppLog "CONGRATS! You've reached level $level!" -ForeGroundColor Green
                    if ($enableNotifications -and $onLevelUp) {
                    Get-WoWScreenShot -topleftX $screen.full_topLeftX -topLeftY $screen.full_topLeftY -bottomRightX $screen.full_bottomRightX -bottomRightY $screen.full_bottomRightY -picPath "$path\WoWLorewalkingFull.png"
                        Send-Notification -Title "Lorewalking Level Up" -Desc "CONGRATS!`nYou've reached level $level!" -Runtime $ranFor `
                                          -CurrentLevel $script:currentLevel -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                                          -EtaNextLevel $script:etaNextLevel -EtaMaxLevel $script:etaMaxLevel -Color 'Green' -PicPath "$path\WoWLorewalkingFull.png"
                    }
                } else {
                    Write-AppLog "CONGRATS! You've leveled up!" -ForeGroundColor Green
                    Update-LevelingStats
                    if ($enableNotifications -and $onLevelUp) {
                        Get-WoWScreenShot -topleftX $screen.full_topLeftX -topLeftY $screen.full_topLeftY -bottomRightX $screen.full_bottomRightX -bottomRightY $screen.full_bottomRightY -picPath "$path\WoWLorewalkingFull.png"
                        Send-Notification -Title "Lorewalking Level Up" -Desc "CONGRATS! You've leveled up!" -Runtime $ranFor `
                                          -CurrentLevel $script:currentLevel -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                                          -EtaNextLevel $script:etaNextLevel -EtaMaxLevel $script:etaMaxLevel -Color 'Green' -PicPath "$path\WoWLorewalkingFull.png"
                    }
                }
                # xp
                $ocr -match "xp.*?(\d+)" | Out-Null
                $ranFor = Get-RunningTime
                if ($matches) {
                    $xp = $matches[1]
                    $script:currentXP = $xp
                    Update-LevelingStats
                }

                return $true
            } else {
                # start progress bar, exit early in finally if word is matched
                Write-GuiEvent -Evt @{ type = 'progress'; activity = $activity; secondsRemaining = ($retryCount - ($i + 1)); totalSeconds = $retryCount }
            }
            [System.Threading.Thread]::Sleep(500)
        }

        # Try to start over and go again if enableFailsafe is true
        if ( $enableFailsafe -eq $True) {
            # Allowed to happen 3x
            $script:failsafeTriggered++
            $ranFor = Get-RunningTime
            Update-LevelingStats
            if ($script:failsafeTriggered -gt 3) {
                Write-AppLog "Failsafe triggered 3x. Stopping." -ForegroundColor Red
                Write-AppLog "Ran for: $ranFor"
                if ($enableNotifications -and $onStop) {
                    Get-WoWScreenShot -topleftX $screen.full_topLeftX -topLeftY $screen.full_topLeftY -bottomRightX $screen.full_bottomRightX -bottomRightY $screen.full_bottomRightY -picPath "$path\WoWLorewalkingFull.png"
                    Send-Notification -Title "Lorewalking Failed" -Desc "Failsafe triggered 3x. Stopping.`nCheck screenshot for details" -Runtime $ranFor `
                                      -CurrentLevel $script:currentLevel -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                                      -EtaNextLevel $script:etaNextLevel -EtaMaxLevel $script:etaMaxLevel -Color 'Red' -PicPath "$path\WoWLorewalkingFull.png"
                }
                return
            }
            # try and exit lorewalking
            if ($enableNotifications -and $onError) {
                Get-WoWScreenShot -topleftX $screen.full_topLeftX -topLeftY $screen.full_topLeftY -bottomRightX $screen.full_bottomRightX -bottomRightY $screen.full_bottomRightY -picPath "$path\WoWLorewalkingFull.png"
                Send-Notification -Title "Lorewalking Failsafe Triggered (${script:failsafeTriggered} of 3)" -Desc "Will try and restart the Lorewalking story.`nCheck screenshot for details." -Runtime $ranFor `
                                  -CurrentLevel $script:currentLevel -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                                  -EtaNextLevel $script:etaNextLevel -EtaMaxLevel $script:etaMaxLevel -Color 'Yellow' -PicPath "$path\WoWLorewalkingFull.png"
            }
            Write-AppLog "All tries exhausted, but Failsafe is enabled. Will try and restart the Lorewalking story.. (${script:failsafeTriggered} of 3)" -ForegroundColor Yellow
            Start-Press $FailsafeKeybind "Starting Failsafe"
            Get-WoWScreenShot -TopLeftX $screen.addon_topLeftX -TopLeftY $screen.addon_topLeftY -BottomRightX $screen.addon_bottomRightX -BottomRightY $screen.addon_bottomRightY -PicPath "$path\WoWLorewalking.png"
            $ocr = Get-Ocr -Path "$path\WoWLorewalking.png"
            if ($ocr -like "*reset*") {
                Start-Press $PrimaryKeybind "Trying to Exit Lorewalking" 1.5 2.5
                Start-Press $PrimaryKeybind -Silent
                Start-SleepWithProgress -Seconds 25 "Wait for Exit/Reload"
            }
            Write-AppLog "Failsafe completed, lets see if it worked.."
            # Start from beginning
            Start-Lorewalking

        } else {
            $ranFor = Get-RunningTime
            Update-LevelingStats
            $script:failsafeTriggered = 4 # mark it as failed for autostop purposes
            Write-AppLog "All retries exhausted. Stopping." -ForegroundColor Yellow
            Write-AppLog "Ran for: $ranFor"
            if ($enableNotifications -and $onStop) {
                Get-WoWScreenShot -topleftX $screen.full_topLeftX -topLeftY $screen.full_topLeftY -bottomRightX $screen.full_bottomRightX -bottomRightY $screen.full_bottomRightY -picPath "$path\WoWLorewalkingFull.png"
                Send-Notification -Title "Lorewalking Failed" -Desc "$retryCount unsuccessful checks in a row. Stopping.`nCheck screenshot for details." -Runtime $ranFor `
                                  -CurrentLevel $script:currentLevel -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                                  -EtaNextLevel $script:etaNextLevel -EtaMaxLevel $script:etaMaxLevel -Color 'Red' -PicPath "$path\WoWLorewalkingFull.png"
            }
            Invoke-AutoStop
            return
        }
        Invoke-AutoStop
        return
    } finally {
        # Always closes out the GUI's progress bar, whether it exits early (keyword found) or the retries are exhausted
        Write-GuiEvent -Evt @{ type = 'progress'; activity = $activity; secondsRemaining = 0; totalSeconds = $retryCount; done = $true }
    }
}

function Start-Lorewalking {
    Clear-AppLog
    if ($script:count -lt 1 -and $script:firstStat -eq $True) {
        Write-AppLog "Lorewalking Helper Started. Good luck, don't get banned! ;-)" -ForegroundColor Green
    }
    while ($True) {
        $script:loopStartTime = Get-Date
        if (-not (Start-Check "start")) {return}
        Start-Press $PrimaryKeybind "Target Li Li"
        Start-Press $PrimaryKeybind "Listen to Story"
        Start-SleepWithProgress 63 "Waiting for story"
        # Screenshot for confirmation of story progress
        if (-not (Start-Check "let")) {
            return
        } elseif ($script:failsafeTriggered -gt 0) {
            # failsafe was triggered, but we think it was good so reset it's count now
            $script:failsafeTriggered = 0
            if ($enableNotifications -and $onError) {
                $ranFor = Get-RunningTime
                Update-LevelingStats
                Send-Notification -Title "Lorewalking Failsafe Successfull" -Desc "Failsafe was able to correct the Lorewalking issue" -Runtime $ranFor `
                                  -CurrentLevel $script:currentLevel -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                                  -EtaNextLevel $script:etaNextLevel -EtaMaxLevel $script:etaMaxLevel -Color 'Green'
            }
        }

        Start-Press $PrimaryKeybind -Silent # Targets again for safety
        Start-Press $PrimaryKeybind "Enter Lorewalking" # "Interact"
        Start-SleepWithProgress $loadingTime "Loading Screen"
        if (-not (Start-Check "king")) { return }

        Start-Press $PrimaryKeybind "Exit Bench/Target King"
        Start-Press $PrimaryKeybind -Silent # "Interact"
        Start-SleepWithProgress 5 "Running to King"
        if (-not (Start-Check "warpack")) { return }

        Start-Press $PrimaryKeybind "Exit Lorewalking"
        Start-SleepWithProgress $loadingTime "Loading Screen"
        if (-not (Start-Check "resume")) { return }

        [System.Threading.Thread]::Sleep(300) # Slight delay for extra NPC load-in time
        Start-Press $PrimaryKeybind "Target Li Li"
        Start-Press $PrimaryKeybind -Silent # "Interact"
        [System.Threading.Thread]::Sleep(400) # Slight delay for seating animation
        Start-Press $PrimaryKeybind -Silent # "Targets" again
        Start-Press $PrimaryKeybind "Resume Lorewalking" # "Interact"

        Start-SleepWithProgress $loadingTime "Loading Screen"
        if (-not (Start-Check "gonk")) { return }

        Start-Press $PrimaryKeybind "Target Gonk"
        Start-Press $PrimaryKeybind "Complete Quest"
        if (-not (Start-Check "complete")) { return }

        Start-Press $PrimaryKeybind "Exit Lorewalking"
        Start-SleepWithProgress $loadingTime "Loading Screen"

        # clear frame
        Clear-AppLog
        $script:totalQuestTime += (Get-Date) - $script:loopStartTime
        $script:count++
        Update-LevelingStats
        # needs 1 itteration to get quest time for stats
        if ($script:count -eq 1 -and $script:firstStat -eq $True) {
            if ($enableNotifications -and $onStart) {
            $ranFor = Get-RunningTime
            Send-Notification -Title "Lorewalking Stats" -Desc "Initial stats and ETA's" -Runtime $ranFor `
                              -CurrentLevel $script:currentLevel -QuestsCompleted $script:count -AvgTimePerQuest $script:avgTimePerQuest `
                              -EtaNextLevel $script:etaNextLevel -EtaMaxLevel $script:etaMaxLevel -Color 'Green'
            $script:firstStat = $False
            }
        }
        # check if needing to stop
        Invoke-AutoStop
    }
    Invoke-AutoStop
}
#Endregion Main function

#Region Main
# import winform and Screenshot method, http for discord, runtime for ocr
Add-Type -AssemblyName System.Windows.Forms,System.Drawing,System.Net.Http,System.Runtime.WindowsRuntime -ErrorAction Stop

# Add the WinRT assembly, and load the appropriate WinRT types
# made it 5.1 and 7 workable. below is needed for 5.1
# Windows Runtime support.

# Force-load the WinRT types needed. 
$null = [Windows.Storage.StorageFile,                 Windows.Storage,          ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine,                 Windows.Media.Ocr,        ContentType = WindowsRuntime]
$null = [Windows.Foundation.IAsyncOperation`1,        Windows.Foundation,       ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap,     Windows.Foundation,       ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder,      Windows.Graphics.Imaging, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams,  ContentType = WindowsRuntime]

# make process DPI aware for screenshots + screenshot C# .net helpers
# Makes the PowerShell process use physical screen coordinates rather than DPI-virtualized coordinates.
if (-not ("WoWScreenHelper" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class WoWScreenHelper
{
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiAwarenessContext);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd,out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr hWnd,ref POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}

[StructLayout(LayoutKind.Sequential)]
public struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

[StructLayout(LayoutKind.Sequential)]
public struct POINT
{
    public int X;
    public int Y;
}
"@
}

# DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
$DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = [IntPtr](-4)

try {
    $result = [WoWScreenHelper]::SetProcessDpiAwarenessContext(
        $DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    )

    if (-not $result) {
        [void][WoWScreenHelper]::SetProcessDPIAware()
    }
}
catch {
    # SetProcessDpiAwarenessContext is unavailable.
    # Fall back to the older DPI-aware API.
    [void][WoWScreenHelper]::SetProcessDPIAware()
}

# Screenshot Location to save temporary img to for OCR Scan
$path = $env:temp

# Start App
Write-AppLog "########################" -ForegroundColor Magenta
Write-AppLog "   Lorewalking Helper   " -ForegroundColor Magenta
Write-AppLog "########################" -ForegroundColor Magenta

# Verify wow process and inital window state
$process = Get-Process | Where-Object {$_.MainWindowTitle -like $windowTitle} -ErrorAction SilentlyContinue |
           Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
           Select-Object -First 1
if (-not $process) {
    Write-AppLog "Is WoW running? Could not find the WoW window for '$windowTitle'.`nVerify WoW is running and the window title is correct in settings" -ForegroundColor 'Red'
    return
}

if (-not $useWindowFocus) {
    Write-AppLog "Not Auto-Focusing WoW. Make sure you have the window up and focused." -ForegroundColor Yellow
}

if ($port.IsOpen) { $port.close() }

# PI Pico
if ($usePi -eq $True) {
    # auto-detect pico com port
    Write-AppLog "Using Pi for hardware input" -ForegroundColor Yellow
    if ($picoComPort -eq "AUTO") {
        $portCheck = (Get-CimInstance -ClassName CIM_SerialController | Where-Object {$_.PNPDeviceID -like "*2E8A*" -or $_.PNPDeviceID -like "*239A*"}) | Select-Object Status, DeviceId # pico hex vendor id
        if ($portCheck.Status -eq "OK" -and $portCheck.DeviceId.Count -eq 1) {
            $picoComPort = $portCheck.DeviceId
            # No Output really needed. Keeping for deugging purposes.
            # Write-AppLog "Pico COM port auto-detected as: $picoComPort" -ForegroundColor Gray
        } else {
            Write-AppLog "Cannot Auto-discover COM port. Please manually enter your pico's COM port in the settings and try again" -ForegroundColor Red
            Return
        }
    }
    
    $port = new-Object System.IO.Ports.SerialPort $picoComPort, 115200, None, 8, One
    try {
        $port.Open()
        Write-AppLog "Pi Connection Established" -ForegroundColor Green
    } Catch {
        Write-AppLog "Pi Connection Failed!" -ForegroundColor Red
        Write-AppLog "Check settings or COM port of Pi. Or uncheck the Raspberry Pi Pico option in settings." -ForegroundColor Yellow
        Return
    }
} else {
    Write-AppLog "NOT using Pi - input will be software based (not as ideal, go get yourself a 5$ Pi Pico)" -ForegroundColor Yellow # injected
}

Write-AppLog "Note: If you restart wow while this app is running, you need to stop/start this app as well."
Write-AppLog "Stand in front of Lorewalker Li Li and make sure the WoW window is visible." -ForegroundColor Yellow
Start-SleepWithProgress 10 "Lorewalking Starts in"

# send start notification
if ($enableNotifications -and $onStart) {
    Send-Notification -Title 'Lorewalking started' -Color 'Green'
}

if ($autoStop -eq $True) {
    $autoEndTime = (Get-Date).AddMinutes($autoStopTime)
} else {
    $autoEndTime = (Get-Date).AddHours(12) # foreeeeeeverrrrr (well, half a day anyways)
}
#Endregion Main

# Run it
$runStartTime = Get-Date
$script:firstUpdate = $True
$script:firstStat = $True
$script:count = 0
Start-Lorewalking
