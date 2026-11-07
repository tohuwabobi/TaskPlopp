# Core settings, app matching and launch functions. Loaded by TaskPlopp.ps1.
function Get-TextProperty($Object, [string]$Name) {
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) { return [string]$Object.$Name }
    return ''
}

function ConvertTo-TaskPloppSettings($Data) {
    if($Data.PSObject.Properties.Name -notcontains 'DictationEngine') {
        $Data | Add-Member -NotePropertyName DictationEngine -NotePropertyValue 'Whisper'
    }
    if($Data.DictationEngine -notin @('Whisper','Vosk')) { throw 'Diktat: Unbekannte lokale Engine.' }
    if($Data.PSObject.Properties.Name -notcontains 'AutoLockEnabled') {
        $Data | Add-Member -NotePropertyName AutoLockEnabled -NotePropertyValue $true
    }
    if($Data.PSObject.Properties.Name -notcontains 'AutoLockMinutes') {
        $Data | Add-Member -NotePropertyName AutoLockMinutes -NotePropertyValue 30
    }
    if($Data.AutoLockEnabled -isnot [bool]) { throw 'Automatische Sperre: Ein/Aus muss ein Wahrheitswert sein.' }
    if(($Data.AutoLockMinutes -isnot [int] -and $Data.AutoLockMinutes -isnot [long]) -or
        $Data.AutoLockMinutes -lt 1 -or $Data.AutoLockMinutes -gt 480) {
        throw 'Automatische Sperre: Bitte ganze Minuten zwischen 1 und 480 waehlen.'
    }
    foreach ($entry in @($Data.Programs)) {
        foreach ($field in @('ExecutablePath', 'AppId', 'StartKind', 'StartTarget', 'FolderPath')) {
            if ($entry.PSObject.Properties.Name -notcontains $field) {
                $entry | Add-Member -NotePropertyName $field -NotePropertyValue ''
            } elseif ($entry.$field -isnot [string]) { throw "Ungueltiges Feld: $field" }
        }
        if ($entry.PSObject.Properties.Name -notcontains 'LaunchAlways') {
            $entry | Add-Member -NotePropertyName LaunchAlways -NotePropertyValue $false
        } elseif ($entry.LaunchAlways -isnot [bool]) { throw 'LaunchAlways muss ein Wahrheitswert sein.' }
        if ($entry.StartKind -notin @('', 'Path', 'AppId')) { throw 'Unbekannter Starttyp.' }
        if ($entry.StartKind -and -not $entry.StartTarget.Trim()) { throw 'Startziel fehlt.' }
        if ($entry.StartKind -eq 'AppId' -and $entry.StartTarget -notmatch '^[\w.\-]+![\w.\-]+$') { throw 'Ungueltige App-ID.' }
    }
    if ($Data.PSObject.Properties.Name -notcontains 'HiddenWindows') {
        $Data | Add-Member -NotePropertyName HiddenWindows -NotePropertyValue @()
    }
    foreach ($rule in @($Data.HiddenWindows)) {
        foreach ($field in @('Name','ProcessName','ExecutablePath','AppId','TitleContains')) {
            if ($rule.PSObject.Properties.Name -notcontains $field -or $rule.$field -isnot [string]) { throw "Ungueltige Ausblendregel: $field" }
        }
        if (-not $rule.ProcessName -and -not $rule.AppId -and -not $rule.ExecutablePath) { throw 'Ausblendregel ohne Programm.' }
    }
    return $Data
}

function Test-WindowMatch($Window, $Rule) {
    $folder = Get-TextProperty $Rule 'FolderPath'
    if ($folder -and (Get-TextProperty $Window 'FolderPath').TrimEnd('\') -ine $folder.TrimEnd('\')) { return $false }
    $appId = Get-TextProperty $Rule 'AppId'
    $path = Get-TextProperty $Rule 'ExecutablePath'
    if ($appId) {
        if ((Get-TextProperty $Window 'AppId') -ine $appId) { return $false }
    } elseif ($path) {
        if ((Get-TextProperty $Window 'ExecutablePath') -ine $path) { return $false }
    } elseif ($Window.ProcessName -ine ($Rule.ProcessName -replace '\.exe$', '')) { return $false }
    $title = Get-TextProperty $Rule 'TitleContains'
    return (-not $title -or $Window.Title.IndexOf($title, [StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Get-ExplorerFolderPaths {
    $result = @{}
    $shell = New-Object -ComObject Shell.Application
    $windows = $null
    try {
        $windows = $shell.Windows()
        foreach ($window in $windows) {
            $document = $null; $folder = $null; $self = $null
            try {
                $document = $window.Document; $folder = $document.Folder; $self = $folder.Self
                $result[[long]$window.HWND] = [string]$self.Path
            } catch { } finally {
                foreach ($object in @($self,$folder,$document,$window)) {
                    if ($null -ne $object -and [Runtime.InteropServices.Marshal]::IsComObject($object)) {
                        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($object)
                    }
                }
            }
        }
    } finally {
        if ($null -ne $windows) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($windows) }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
    return $result
}

function Get-FavoriteButtonSpecs([object[]]$Windows, $Settings) {
    foreach ($favorite in @($Settings.Programs)) {
        $matches = @( $Windows | Where-Object { Test-WindowMatch $_ $favorite } )
        $always = $favorite.PSObject.Properties.Name -contains 'LaunchAlways' -and $favorite.LaunchAlways
        if ($always) { $text = "$($favorite.Name) | Startziel oeffnen"; $matches = @() }
        elseif ($matches.Count -eq 0) { $text = "$($favorite.Name) | Starten" }
        elseif ($matches.Count -eq 1) { $text = "$($favorite.Name) | $($matches[0].Title)" }
        else { $text = "$($favorite.Name) | $($matches.Count) Fenster (Rechtsklick: auswaehlen)" }
        [pscustomobject]@{ Text = $text; Favorite = $favorite; Windows = $matches }
    }
}

function Get-OtherWindows([object[]]$Windows, $Settings) {
    foreach ($window in $Windows) {
        $omit = $false
        foreach ($rule in @($Settings.Programs) + @($Settings.HiddenWindows)) {
            if (Test-WindowMatch $window $rule) { $omit = $true; break }
        }
        if (-not $omit) { $window }
    }
}

function Get-InstalledAppChoices {
    if (-not (Get-Variable InstalledApps -Scope Script -ErrorAction SilentlyContinue)) {
        $script:InstalledApps = @(Get-StartApps -ErrorAction Stop | Sort-Object Name)
    }
    return $script:InstalledApps
}

function Get-AppDisplayName([string]$ProcessName, [string]$AppId) {
    if ($AppId) {
        try {
            $app = Get-InstalledAppChoices | Where-Object AppId -eq $AppId | Select-Object -First 1
            if ($app) { return $app.Name }
        } catch { }
    }
    return $ProcessName
}

function Resolve-FavoriteStart($Favorite) {
    # Explicit user choice always wins. No configuration file is written here.
    if ($Favorite.StartKind -and $Favorite.StartTarget) {
        return [pscustomobject]@{ Kind = $Favorite.StartKind; Target = $Favorite.StartTarget }
    }
    if ($Favorite.AppId) { return [pscustomobject]@{ Kind = 'AppId'; Target = $Favorite.AppId } }
    $path = $Favorite.ExecutablePath
    if (-not $path) {
        $known = @(Get-AppWindows | Where-Object { Test-WindowMatch $_ $Favorite })
        if ($known.Count -gt 0) {
            if ($known[0].AppId) { return [pscustomobject]@{ Kind = 'AppId'; Target = $known[0].AppId } }
            $path = $known[0].ExecutablePath
        }
    }
    if (-not $path) {
        # Resolve only actual executable files, never aliases/functions or arbitrary commands.
        $exeName = ($Favorite.ProcessName -replace '\.exe$', '') + '.exe'
        $command = Get-Command -Name $exeName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $path = $command.Source }
    }
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [pscustomobject]@{ Kind = 'Path'; Target = $path }
    }
    return [pscustomobject]@{ Kind = ''; Target = '' }
}

function Start-FavoriteApplication($Favorite, [switch]$Preview) {
    $target = Resolve-FavoriteStart $Favorite
    if (-not $target.Kind) { throw 'Kein Startziel bekannt. Bitte in der Konfiguration ein Programm oder eine Verknuepfung auswaehlen.' }
    if ($target.Kind -eq 'Path') {
        if (-not (Test-Path -LiteralPath $target.Target -PathType Leaf) -or
            [IO.Path]::GetExtension($target.Target) -notin @('.exe','.lnk')) {
            throw 'Das Startziel fehlt oder ist keine EXE-/LNK-Datei. Bitte in der Konfiguration neu auswaehlen.'
        }
    } elseif ($target.Kind -eq 'AppId') {
        if ($target.Target -notmatch '^[\w.\-]+![\w.\-]+$') { throw 'Ungueltige App-ID.' }
    } else { throw 'Unbekannter Starttyp.' }
    if ($Preview) { return $target }
    if ($target.Kind -eq 'AppId') {
        # Let the Windows shell use the registered app activation contract, also for packaged desktop apps.
        $shell = New-Object -ComObject Shell.Application
        $folder = $null; $item = $null
        try {
            $folder = $shell.NameSpace('shell:AppsFolder')
            $item = $folder.ParseName($target.Target)
            if ($null -eq $item) { throw 'Diese App ist auf diesem PC nicht registriert.' }
            $item.InvokeVerb('open')
        } finally {
            if ($null -ne $item) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($item) }
            if ($null -ne $folder) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($folder) }
            [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
        }
    } else {
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $target.Target; $info.UseShellExecute = $true
        $info.WorkingDirectory = [IO.Path]::GetDirectoryName($target.Target)
        $process = [Diagnostics.Process]::Start($info)
        if ($process) { $process.Dispose() }
    }
}

function New-FavoriteFromWindow($Window) {
    $entry = [pscustomobject]@{
        Name = $Window.ProcessName; ProcessName = $Window.ProcessName; TitleContains = ''
        ExecutablePath = $Window.ExecutablePath; AppId = $Window.AppId
        StartKind = ''; StartTarget = ''
        LaunchAlways = $false; FolderPath = Get-TextProperty $Window 'FolderPath'
    }
    $target = Resolve-FavoriteStart $entry
    $entry.StartKind = $target.Kind; $entry.StartTarget = $target.Target
    $entry.Name = Get-AppDisplayName $entry.ProcessName $entry.AppId
    return $entry
}
