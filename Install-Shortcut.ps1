#requires -Version 5.1
[CmdletBinding()]
param([switch]$Update)
$ErrorActionPreference = 'Stop'
$desktop = [Environment]::GetFolderPath('Desktop')
$path = Join-Path $desktop 'TaskPlopp.lnk'
if ((Test-Path -LiteralPath $path) -and -not $Update) {
    throw "Die Verknuepfung existiert bereits: $path. Bitte bei Bedarf manuell anpassen."
}
$shell = New-Object -ComObject WScript.Shell
try {
    $shortcut = $shell.CreateShortcut($path)
    if ((Test-Path -LiteralPath $path) -and
        $shortcut.Arguments -notlike ('*-File "' + (Join-Path $PSScriptRoot '*.ps1') + '"')) {
        throw 'Die vorhandene Verknuepfung gehoert nicht zu diesem TaskPlopp-Projekt.'
    }
    $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $PSScriptRoot 'Start-TaskPlopp.ps1') + '"'
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = 'Lokale Fenster mit TaskPlopp in den Vordergrund holen'
    $shortcut.Hotkey = ''
    $shortcut.IconLocation = (Join-Path $PSScriptRoot 'assets\TaskPlopp.ico') + ',0'
    $shortcut.Save()
    Write-Output "Verknuepfung eingerichtet: $path (startet den dauerhaft laufenden TaskPlopp-Prozess)"
} finally {
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
}
