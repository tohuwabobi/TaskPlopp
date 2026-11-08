#requires -Version 5.1
[CmdletBinding()]
param([switch]$Update,[string]$ShortcutPath=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'TaskPlopp.lnk'))
$ErrorActionPreference = 'Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$path = [IO.Path]::GetFullPath($ShortcutPath)
if ((Test-Path -LiteralPath $path) -and -not $Update) {
    throw "Die Verknuepfung existiert bereits: $path. Bitte bei Bedarf manuell anpassen."
}
$shell = New-Object -ComObject WScript.Shell
try {
    $shortcut = $shell.CreateShortcut($path)
    if ((Test-Path -LiteralPath $path) -and
        $shortcut.Arguments -notlike ('*-File "' + (Join-Path $projectRoot '*.ps1') + '"')) {
        throw 'Die vorhandene Verknuepfung gehoert nicht zu diesem TaskPlopp-Projekt.'
    }
    $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $projectRoot 'Start-TaskPlopp.ps1') + '"'
    $shortcut.WorkingDirectory = $projectRoot
    $shortcut.Description = 'Lokale Fenster mit TaskPlopp in den Vordergrund holen'
    $shortcut.Hotkey = ''
    $shortcut.IconLocation = (Join-Path $projectRoot 'assets\TaskPlopp.ico') + ',0'
    $shortcut.Save()
    Write-Output "Verknuepfung eingerichtet: $path (startet den dauerhaft laufenden TaskPlopp-Prozess)"
} finally {
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
}
