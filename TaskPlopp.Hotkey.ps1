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
    $wake=Get-Variable WakeEvent -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    $state=[hashtable]::Synchronized(@{ThreadId=[uint32]0;Registered=$false;Cleaned=$false;Error='';Wake=$wake})
    $ready=[Threading.ManualResetEventSlim]::new($false);$stop=[Threading.ManualResetEventSlim]::new($false)
    $space=[RunspaceFactory]::CreateRunspace();$space.ApartmentState='STA';$space.ThreadOptions='ReuseThread';$space.Open()
    $ps=[PowerShell]::Create();$ps.Runspace=$space
    $worker={param($helper,$modifiers,$key,$state,$ready,$stop)
        $ErrorActionPreference='Stop';. $helper;$memory=[IntPtr]::Zero
        try {
            $state.ThreadId=[TaskPloppInterop.Kernel]::GetCurrentThreadId()
            if(-not[TaskPloppInterop.User]::RegisterHotKey([IntPtr]::Zero,1,$modifiers,$key)){throw [ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error())}
            $state.Registered=$true;$memory=[Runtime.InteropServices.Marshal]::AllocHGlobal(64)
            $null=[TaskPloppInterop.User]::PeekMessageW($memory,[IntPtr]::Zero,0x312,0x312,0)
            $ready.Set()
            while(-not$stop.IsSet){
                while([TaskPloppInterop.User]::PeekMessageW($memory,[IntPtr]::Zero,0x312,0x312,1)){if($null-ne$state.Wake){$null=$state.Wake.Set()}}
                $null=$stop.Wait(10)
            }
        } catch {$state.Error=$_.Exception.Message;$ready.Set()}
        finally {if($state.Registered){$state.Cleaned=[TaskPloppInterop.User]::UnregisterHotKey([IntPtr]::Zero,1)};if($memory-ne[IntPtr]::Zero){[Runtime.InteropServices.Marshal]::FreeHGlobal($memory)}}
    }
    $null=$ps.AddScript($worker.ToString()).AddArgument((Join-Path $PSScriptRoot 'TaskPlopp.Native.ps1')).AddArgument($Spec.Modifiers).AddArgument($Spec.Key).AddArgument($state).AddArgument($ready).AddArgument($stop)
    $async=$ps.BeginInvoke()
    $listener=[pscustomobject]@{State=$state;Ready=$ready;Stop=$stop;PowerShell=$ps;Runspace=$space;Async=$async;Closed=$false}
    $listener | Add-Member ScriptMethod Dispose {Close-TaskPloppHotkeyListener $this}
    if(-not$ready.Wait(3000)-or$state.Error){$errorText=$state.Error;Close-TaskPloppHotkeyListener $listener;throw "Hotkey nicht registriert. $errorText"}
    return $listener
}
function Close-TaskPloppHotkeyListener($Listener) {
    if($Listener.Closed){return};$Listener.Stop.Set()
    if(-not$Listener.Async.AsyncWaitHandle.WaitOne(2000)){throw 'Hotkey-Thread hat die Freigabe noch nicht bestaetigt.'}
    $null=$Listener.PowerShell.EndInvoke($Listener.Async)
    $Listener.PowerShell.Dispose();$Listener.Runspace.Dispose();$Listener.Ready.Dispose();$Listener.Stop.Dispose();$Listener.Closed=$true
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
