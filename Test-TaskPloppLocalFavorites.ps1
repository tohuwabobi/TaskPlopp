#requires -Version 5.1
[CmdletBinding()]
param([switch]$OpenFolders)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
$settings=Get-Settings
$expected=@('Chrome - hspwo.de','Chrome - Mein Chrome','Downloads','Desktop')
for($index=0;$index -lt 4;$index++) {
    if($settings.Programs[$index].Name -ne $expected[$index]) { throw 'Unerwartete Favoritenreihenfolge.' }
}
$shell=New-Object -ComObject WScript.Shell
try {
    foreach($pair in @(@('Chrome - hspwo.de','Profile 1'),@('Chrome - Mein Chrome','Default'))) {
        $entry=$settings.Programs | Where-Object Name -eq $pair[0] | Select-Object -First 1
        $link=$shell.CreateShortcut($entry.StartTarget)
        try {
            if(-not $entry.LaunchAlways -or $link.Arguments -ne ('--profile-directory="' + $pair[1] + '"') -or
                -not (Test-Path -LiteralPath $link.TargetPath)) { throw "Fehlerhaftes Profil-Startziel: $($pair[0])" }
        } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($link) }
    }
    foreach($name in @('Downloads','Desktop')) {
        $entry=$settings.Programs | Where-Object Name -eq $name | Select-Object -First 1
        $link=$shell.CreateShortcut($entry.StartTarget)
        try {
            if($link.Arguments -ne ('"' + $entry.FolderPath + '"') -or
                -not (Test-Path -LiteralPath $entry.FolderPath -PathType Container)) { throw "Fehlerhaftes Ordner-Startziel: $name" }
        } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($link) }
    }
} finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
Write-Output 'OK: Chrome hspwo.de auf 1, Mein Chrome auf 2; korrekte Profilargumente. Downloads auf 3 und Desktop auf 4 mit lokalen Ordnerpfaden.'
if($OpenFolders) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TaskPloppLocalTestClose {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint message, IntPtr w, IntPtr l);
}
'@
    foreach($name in @('Downloads','Desktop')) {
        $entry=$settings.Programs | Where-Object Name -eq $name | Select-Object -First 1
        $before=@(Get-AppWindows)
        $matches=@($before | Where-Object { Test-WindowMatch $_ $entry })
        if($matches.Count -gt 0) { Write-Output "OK: Offenes $name-Fenster ueber Ordnerpfad erkannt."; continue }
        try {
            Start-FavoriteApplication $entry
            $deadline=[DateTime]::UtcNow.AddSeconds(8)
            while($matches.Count -eq 0 -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
                $matches=@(Get-AppWindows | Where-Object { Test-WindowMatch $_ $entry })
            }
            if($matches.Count -eq 0) { throw "Ordnerfenster fuer $name wurde nicht erkannt." }
            Write-Output "OK: $name real geoeffnet und ueber exakten Ordnerpfad erkannt."
        } finally {
            # Close only new, precisely matched windows created by this test, never an Explorer process.
            foreach($window in $matches) {
                if($window.Handle -notin @($before | ForEach-Object Handle)) {
                    [void][TaskPloppLocalTestClose]::PostMessage($window.Handle,0x10,[IntPtr]::Zero,[IntPtr]::Zero)
                }
            }
        }
    }
}
