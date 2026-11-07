#requires -Version 5.1
[CmdletBinding()]
param([switch]$CheckHotkey,[switch]$LibraryOnly,[uint32]$Modifiers=0x4003,[uint32]$Key=0x79)
$ErrorActionPreference='Stop'
if($LibraryOnly-or$CheckHotkey){
    . (Join-Path $PSScriptRoot 'TaskPlopp.Native.ps1')
    . (Join-Path $PSScriptRoot 'TaskPlopp.Hotkey.ps1')
    if($CheckHotkey){$listener=New-TaskPloppHotkeyListener ([pscustomobject]@{Modifiers=$Modifiers;Key=$Key});Close-TaskPloppHotkeyListener $listener;Write-Output 'OK: Hotkey registriert und wieder freigegeben.'}
    return
}
& (Join-Path $PSScriptRoot 'TaskPlopp.ps1')
