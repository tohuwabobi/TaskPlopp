# Register a replacement before saving/releasing the old hotkey.
function Get-TaskPloppHotkeySpec($Settings) {
    $keyName=if($Settings.HotkeyKey -match '^\d$'){'D'+$Settings.HotkeyKey}else{$Settings.HotkeyKey}
    $names=@()
    if($Settings.HotkeyModifiers -band 2){$names+='Strg'}
    if($Settings.HotkeyModifiers -band 1){$names+='Alt'}
    if($Settings.HotkeyModifiers -band 4){$names+='Umschalt'}
    if($Settings.HotkeyModifiers -band 8){$names+='Win'}
    $names+=$Settings.HotkeyKey
    [pscustomobject]@{Modifiers=[uint32]($Settings.HotkeyModifiers -bor 0x4000);Key=[uint32][Windows.Forms.Keys]::$keyName;Label=$names -join '+'}
}
function New-TaskPloppHotkeyListener($Spec) {
    . (Join-Path $PSScriptRoot 'Start-TaskPlopp.ps1') -LibraryOnly
    $listener=[TaskPloppHotkey.Listener]::new($Spec.Modifiers,$Spec.Key)
    $listener.add_Pressed({Show-TaskPlopp})
    return $listener
}
function Initialize-TaskPloppHotkey {
    $spec=Get-TaskPloppHotkeySpec $script:Settings
    $script:HotkeyListener=New-TaskPloppHotkeyListener $spec
    $script:ActiveHotkey=$spec
    Update-TaskPloppTrayText
}
function Save-TaskPloppSettingsWithHotkey($Settings) {
    $Settings=ConvertTo-TaskPloppSettings $Settings
    $candidate=$null
    $enabled=(Get-Variable HotkeysEnabled -Scope Script -ValueOnly -ErrorAction SilentlyContinue) -eq $true
    $spec=Get-TaskPloppHotkeySpec $Settings
    $active=Get-Variable ActiveHotkey -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if($enabled -and ($null -eq $active -or $active.Modifiers -ne $spec.Modifiers -or $active.Key -ne $spec.Key)) {
        try {$candidate=New-TaskPloppHotkeyListener $spec}
        catch {throw "Die Tastenkombination $($spec.Label) konnte nicht registriert werden. Sie ist moeglicherweise bereits belegt. Bisherige Einstellungen bleiben erhalten. $($_.Exception.Message)"}
    }
    try {Save-Settings $Settings}
    catch {if($null -ne $candidate){$candidate.Dispose()};throw}
    if($null -ne $candidate){
        $old=Get-Variable HotkeyListener -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        $script:HotkeyListener=$candidate;$script:ActiveHotkey=$spec
        if($null -ne $old){$old.Dispose()}
    }
}
function Update-TaskPloppTrayText {
    $tray=Get-Variable Tray -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if($null -eq $tray){return}
    $phase=Get-Variable DictationPhase -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if($phase -eq 'Recording'){$tray.Text='TaskPlopp: AUFNAHME LAEUFT'}
    elseif($phase -eq 'Transcribing'){$tray.Text='TaskPlopp: Transkription laeuft'}
    elseif($null -ne (Get-Variable HotkeyListener -Scope Script -ValueOnly -ErrorAction SilentlyContinue)){
        $tray.Text='TaskPlopp: '+(Get-TaskPloppHotkeySpec $script:Settings).Label
    } else {$tray.Text='TaskPlopp: Hotkey nicht verfuegbar'}
}
