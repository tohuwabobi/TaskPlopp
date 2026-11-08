#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
$script:Settings=ConvertTo-TaskPloppSettings ([pscustomobject]@{Programs=@();ShowOpenWindows=$false})
Assert ($script:Settings.HotkeyModifiers -eq 3 -and $script:Settings.HotkeyKey -eq 'F10') 'Migration verliert Standard'
$spec=Get-TaskPloppHotkeySpec $script:Settings
Assert ($spec.Label -eq 'Strg+Alt+F10' -and $spec.Modifiers -eq 0x4003 -and $spec.Key -eq 0x79) 'Falscher Standard-Keycode'
$number=Get-TaskPloppHotkeySpec ([pscustomobject]@{HotkeyModifiers=12;HotkeyKey='0'})
Assert ($number.Key -eq 0x30 -and $number.Label -eq 'Umschalt+Win+0') 'Ziffer/Modifier falsch'
$calc=ConvertTo-TaskPloppSettings ([pscustomobject]@{Programs=@();HotkeyModifiers=0;HotkeyKey='Taschenrechner'})
$calcSpec=Get-TaskPloppHotkeySpec $calc
Assert ($calcSpec.Key-eq0xB7-and$calcSpec.Modifiers-eq0x4000-and$calcSpec.Label-eq'Taschenrechner') 'Calculator key/code without modifiers invalid'
foreach($bad in @(@(0,'P'),@(16,'P'),@(3,'F12'),@(3,'Escape'),@(3,'p'))){
    $data=[pscustomobject]@{Programs=@();HotkeyModifiers=$bad[0];HotkeyKey=$bad[1]}
    $caught=$false;try{$null=ConvertTo-TaskPloppSettings $data}catch{$caught=$true}
    Assert $caught 'Ungueltige Kombination akzeptiert'
}
. (Join-Path $PSScriptRoot '..\Start-TaskPlopp.ps1') -LibraryOnly
$root=Join-Path $env:TEMP ('TaskPlopp-hotkey-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$script:ConfigPath=Join-Path $root 'config.json'
$script:HotkeysEnabled=$true
$reservations=@()
$script:WakeEvent=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset)
try {
    $calculatorListener=$null
    try{
        try{$calculatorListener=New-TaskPloppHotkeyListener $calcSpec}catch{Write-Host 'SKIP: Calculator key already registered locally; physical key still requires manual test.'}
        if($calculatorListener){
            $null=[TaskPloppInterop.User]::PostThreadMessageW($calculatorListener.State.ThreadId,0x312,[IntPtr]1,[IntPtr]0)
            Assert ($script:WakeEvent.WaitOne(2000)) 'Calculator listener did not wake'
            Write-Host 'OK: Calculator key registered without modifiers, synthetic notification received, registration released.'
        }
    }finally{if($calculatorListener){$calculatorListener.Dispose()}}
    foreach($testKeyName in @('F20','F21','F22','F23','F24','F19','F18')){
        $data=ConvertTo-TaskPloppSettings ([pscustomobject]@{Programs=@();ShowOpenWindows=$false;HotkeyModifiers=7;HotkeyKey=$testKeyName})
        $spec=Get-TaskPloppHotkeySpec $data
        try {$listener=(New-TaskPloppHotkeyListener $spec)}catch{continue}
        $reservations+=[pscustomobject]@{Data=$data;Spec=$spec;Listener=$listener}
        if($reservations.Count -eq 3){break}
    }
    Assert ($reservations.Count -eq 3) 'Drei freie Testkombinationen fehlen'
    $script:Settings=$reservations[0].Data
    $script:HotkeyListener=$reservations[0].Listener;$script:ActiveHotkey=$reservations[0].Spec
    Save-Settings $script:Settings
    $reservations[1].Listener.Dispose()
    Save-TaskPloppSettingsWithHotkey $reservations[1].Data
    $active=$script:HotkeyListener
    $null=[TaskPloppInterop.User]::PostThreadMessageW($active.State.ThreadId,0x312,[IntPtr]1,[IntPtr]0)
    Assert ($script:WakeEvent.WaitOne(2000)) 'Neuer Hotkey hat WakeEvent nicht ausgeloest'
    Assert ((Get-Settings).HotkeyKey -eq $reservations[1].Data.HotkeyKey) 'Neue Kombination nicht gespeichert'
    $oldProbe=(New-TaskPloppHotkeyListener $reservations[0].Spec);$oldProbe.Dispose()
    $caught=$false;try{$probe=(New-TaskPloppHotkeyListener $reservations[1].Spec);$probe.Dispose()}catch{$caught=$true}
    Assert $caught 'Neue Kombination nicht aktiv'
    Save-TaskPloppSettingsWithHotkey $reservations[1].Data
    Assert ([object]::ReferenceEquals($active,$script:HotkeyListener)) 'Unveraenderten Hotkey neu registriert'
    $before=(Get-FileHash $script:ConfigPath).Hash
    $caught=$false;try{Save-TaskPloppSettingsWithHotkey $reservations[2].Data}catch{$caught=$true}
    Assert ($caught -and [object]::ReferenceEquals($active,$script:HotkeyListener)) 'Belegte Kombination zerstoert aktiven Hotkey'
    Assert ((Get-FileHash $script:ConfigPath).Hash -eq $before) 'Konflikt veraendert Datei'
    $realPath=$script:ConfigPath;$script:ConfigPath=Join-Path $root 'missing\config.json'
    $caught=$false;try{Save-TaskPloppSettingsWithHotkey $reservations[0].Data}catch{$caught=$true}
    $script:ConfigPath=$realPath
    Assert ($caught -and [object]::ReferenceEquals($active,$script:HotkeyListener)) 'Speicherfehler zerstoert aktiven Hotkey'
    $probe=(New-TaskPloppHotkeyListener $reservations[0].Spec);$probe.Dispose()
    'OK: Defaults/Validierung, echter Wechsel, unveraendertes Speichern, Konflikt erhaelt Hotkey/Datei, Speicherfehler gibt Kandidat frei.'
} finally {
    if(Get-Variable HotkeyListener -Scope Script -ErrorAction SilentlyContinue){$script:HotkeyListener.Dispose()}
    foreach($entry in $reservations){$entry.Listener.Dispose()}
    Get-ChildItem -LiteralPath $root -File | ForEach-Object {Remove-Item -LiteralPath $_.FullName}
    Remove-Item -LiteralPath $root
    $script:WakeEvent.Dispose();$script:WakeEvent=$null
    $script:HotkeyListener=$null;$script:ActiveHotkey=$null;$script:HotkeysEnabled=$false
}

$testConfig=Join-Path $env:TEMP ('TaskPlopp-hotkey-ui-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($testConfig,'{"Programs":[],"ShowOpenWindows":false}',[Text.UTF8Encoding]::new($true))
$global:HotkeyUiFailure=$null
function Press-CaptureKey($Dialog,[Windows.Forms.Keys]$Keys){
    $input=$Dialog.Controls.Find('HotkeyCapture',$true)[0]
    $event=[Windows.Forms.KeyEventArgs]::new($Keys)
    [Windows.Forms.Control].GetMethod('OnKeyDown',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($input,[object[]]@($event))|Out-Null
}
try {
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -SmokeTest -ConfigFile $testConfig -OnShown {
        param($sender,$args)
        try {
            function Get-TaskPloppOpenAIKeyPath {Join-Path $env:TEMP ('TaskPlopp-unconfigured-key-test-'+$PID+'.dpapi')}
            $script:CaptureTestKeys=@()
            function Get-TaskPloppPressedCaptureKeys {$script:CaptureTestKeys}
            function Get-TaskPloppPressedModifiers {0}
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $tab=$dialog.Controls.Find('HotkeyTab',$true)[0];$tab.Parent.SelectedTab=$tab
                Assert ($dialog.Controls.Find('HotkeyKey',$true).Count-eq0) 'Old key dropdown retained'
                $button=$dialog.Controls.Find('CaptureHotkey',$true)[0]
                $button.PerformClick()
                Press-CaptureKey $dialog ([Windows.Forms.Keys]::ControlKey)
                Assert ((Get-Settings -Path $testConfig).HotkeyKey-eq'F10') 'Modifier alone saved'
                Press-CaptureKey $dialog ([Windows.Forms.Keys]::Control-bor[Windows.Forms.Keys]::Alt-bor[Windows.Forms.Keys]::Shift-bor[Windows.Forms.Keys]::P)
                Assert ($dialog.Controls.Find('HotkeyPreview',$true)[0].Text-eq'Aktuell: Strg+Alt+Umschalt+P') 'Recorded preview wrong'
                Assert ((Get-Settings -Path $testConfig).HotkeyKey-eq'P') 'Recorded combination not autosaved'
                $button.PerformClick();Press-CaptureKey $dialog ([Windows.Forms.Keys]::Escape)
                Assert ((Get-Settings -Path $testConfig).HotkeyKey-eq'P') 'Escape changed settings'
                $button.PerformClick();Press-CaptureKey $dialog ([Windows.Forms.Keys]::LaunchApplication2)
                Assert ((Get-Settings -Path $testConfig).HotkeyModifiers-eq0-and(Get-Settings -Path $testConfig).HotkeyKey-eq'Taschenrechner') 'Calculator capture without modifiers failed'
                $button.PerformClick();$script:CaptureTestKeys=@(180)
                [Windows.Forms.Form].GetMethod('OnDeactivate',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($dialog,[object[]]@([EventArgs]::Empty))|Out-Null
                Assert ((Get-Settings -Path $testConfig).HotkeyKey-eq'LaunchMail') 'Special key polling on deactivation not saved'
                $script:CaptureTestKeys=@()
                $button.PerformClick();Press-CaptureKey $dialog ([Windows.Forms.Keys]::LaunchApplication2)
                $button.PerformClick();Press-CaptureKey $dialog ([Windows.Forms.Keys]::P)
                Assert ((Get-Settings -Path $testConfig).HotkeyKey-eq'Taschenrechner') 'Plain letter replaced hotkey'
                $button.PerformClick();Press-CaptureKey $dialog ([Windows.Forms.Keys]::F12-bor[Windows.Forms.Keys]::Control)
                Assert ((Get-Settings -Path $testConfig).HotkeyKey-eq'Taschenrechner') 'Reserved F12 replaced hotkey'
                $button.PerformClick();Press-CaptureKey $dialog ([Windows.Forms.Keys]::Control-bor[Windows.Forms.Keys]::F9)
                $button.PerformClick();$button.PerformClick()
                Assert ($dialog.Controls.Find('HotkeyCapture',$true)[0].Text-like'*abgebrochen*') 'Cancel button restarts capture'
                $button.PerformClick();$tab.Parent.SelectedIndex=0
                Assert ($button.Text-eq'Tastenkombination aufnehmen') 'Tab change retains capture'
                $dialog.Controls.Find('CloseSettings',$true)[0].PerformClick()
            }
            Assert ((Get-Settings -Path $testConfig).HotkeyKey-eq'F9') 'Capture close lost settings'
            Write-Host 'OK: Press-to-record UI, modifiers ignored alone, immediate save, calculator, invalid/F12 preserve old key, Escape/button/tab cancel.'
        }catch{$global:HotkeyUiFailure=$_;Write-Host $_.ToString()}
    }
    if($global:HotkeyUiFailure){throw $global:HotkeyUiFailure}
}finally{if(Test-Path $testConfig){Remove-Item -LiteralPath $testConfig}}
