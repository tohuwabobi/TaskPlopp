#requires -Version 5.1
[CmdletBinding()]
param([switch]$DownloadsFirst)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -LibraryOnly
$settings = Get-Settings
$statePath = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\Local State'
$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
$chrome = Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'
if (-not (Test-Path -LiteralPath $chrome)) { throw 'Chrome-Programmdatei nicht gefunden.' }
$profileDefinitions = @(
    [pscustomobject]@{ Directory='Profile 1'; Name='Chrome - hspwo.de' },
    [pscustomobject]@{ Directory='Default'; Name='Chrome - Mein Chrome' }
)
foreach ($definition in $profileDefinitions) {
    if ($state.profile.info_cache.PSObject.Properties.Name -notcontains $definition.Directory) {
        throw "Chrome-Profil fehlt: $($definition.Directory)"
    }
}
$shortcutDir = Join-Path $script:ProjectRoot 'shortcuts'
[void][IO.Directory]::CreateDirectory($shortcutDir)
$wscript = New-Object -ComObject WScript.Shell
$shell = New-Object -ComObject Shell.Application
$namespace = $null; $self = $null
try {
    $namespace = $shell.NameSpace('shell:Downloads'); $self = $namespace.Self
    $downloads = [string]$self.Path
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not (Test-Path -LiteralPath $downloads -PathType Container) -or
        -not (Test-Path -LiteralPath $desktop -PathType Container)) { throw 'Downloads oder Desktop nicht gefunden.' }
    $chromeFavorites = @(
        foreach ($definition in $profileDefinitions) {
            $linkPath = Join-Path $shortcutDir ($definition.Name + '.lnk')
            $link = $wscript.CreateShortcut($linkPath)
            try {
                $link.TargetPath=$chrome; $link.Arguments='--profile-directory="' + $definition.Directory + '"'
                $link.WorkingDirectory=[IO.Path]::GetDirectoryName($chrome); $link.Description=$definition.Name
                $link.Save()
            } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($link) }
            [pscustomobject]@{ Name=$definition.Name; ProcessName='chrome'; TitleContains=''
                ExecutablePath=$chrome; AppId=''; StartKind='Path'; StartTarget=$linkPath
                LaunchAlways=$true; FolderPath='' }
        }
    )
    $folderFavorites = @(
        foreach ($definition in @(@('Downloads',$downloads),@('Desktop',$desktop))) {
            $linkPath=Join-Path $shortcutDir ($definition[0] + '.lnk')
            $link=$wscript.CreateShortcut($linkPath)
            try {
                $link.TargetPath=Join-Path $env:SystemRoot 'explorer.exe'; $link.Arguments='"' + $definition[1] + '"'
                $link.Description=$definition[0]; $link.Save()
            } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($link) }
            [pscustomobject]@{ Name=$definition[0]; ProcessName='explorer'; TitleContains=''
                ExecutablePath=(Join-Path $env:SystemRoot 'explorer.exe'); AppId=''; StartKind='Path'; StartTarget=$linkPath
                LaunchAlways=$false; FolderPath=$definition[1] }
        }
    )
    # Replace only the generic Chrome/Explorer entries and the same dedicated entries on reruns.
    $managedNames = @($chromeFavorites.Name) + @($folderFavorites.Name)
    $others = @($settings.Programs | Where-Object {
        $_.Name -notin $managedNames -and -not (
            $_.ProcessName -in @('chrome','explorer') -and -not $_.TitleContains -and
            -not $_.FolderPath -and -not $_.LaunchAlways)
    })
    if ($DownloadsFirst) { $settings.Programs = $folderFavorites + $chromeFavorites + $others }
    else { $settings.Programs = $chromeFavorites + $folderFavorites + $others }
    $null=[IO.Directory]::CreateDirectory((Join-Path $script:DataRoot 'backups'))
    $backup = Join-Path (Join-Path $script:DataRoot 'backups') ('config.before-local-favorites-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss') + '.json')
    Copy-Item -LiteralPath $script:ConfigPath -Destination $backup -ErrorAction Stop
    Save-Settings $settings
    Write-Output "Konfiguration gesichert: $backup"
    $settings.Programs | Select-Object Name,FolderPath,LaunchAlways,StartTarget
} finally {
    if ($null -ne $self) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($self) }
    if ($null -ne $namespace) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($namespace) }
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wscript)
}
