#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Settings([string]$Open,[string]$Dictation){ConvertTo-TaskPloppSettings ([pscustomobject]@{Programs=@();ShowOpenWindows=$false;HotkeyModifiers=7;HotkeyKey=$Open;DictationHotkeyModifiers=7;DictationHotkeyKey=$Dictation})}
function Clone($Value){$Value|ConvertTo-Json -Depth 8|ConvertFrom-Json}
function Reject($Action){$failed=$false;try{&$Action|Out-Null}catch{$failed=$true};Assert $failed 'Expected rejection'}
$root=Join-Path $env:TEMP ('TaskPlopp-dictation-hotkey-'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($root)
$script:ConfigPath=Join-Path $root 'config.json';$script:HotkeysEnabled=$true
$script:WakeEvent=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset)
$script:DictationHotkeyEvent=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset)
$script:HotkeyListener=$null;$script:DictationHotkeyListener=$null;$script:ActiveHotkey=$null;$script:ActiveDictationHotkey=$null
$external=$null
try{
    $legacy=ConvertTo-TaskPloppSettings ([pscustomobject]@{Programs=@();ShowOpenWindows=$false;HotkeyModifiers=2;HotkeyKey='NumPad1'})
    Assert ($legacy.HotkeyKey-eq'NumPad1'-and$legacy.DictationHotkeyKey-eq'NumPad1'-and$legacy.DictationHotkeyModifiers-eq2) 'Legacy default collision rejected/migrated'
    $spec=Get-TaskPloppHotkeySpec $legacy Dictation
    Assert ($spec.Modifiers-eq0x4002-and$spec.Key-eq0x61) 'Wrong dictation default'
    $free=@()
    foreach($key in @('F24','F23','F22','F21','F20','F19','F18','F17','F16')){
        $p=$null
        try{$p=New-TaskPloppHotkeyListener (Get-TaskPloppHotkeySpec (Settings $key F1));$free+=$key}catch{}finally{if($p){$p.Dispose()}}
        if($free.Count-eq6){break}
    }
    Assert ($free.Count-eq6) 'Not enough free isolated test hotkeys'
    $script:Settings=Settings $free[0] $free[1];Save-Settings $script:Settings
    Initialize-TaskPloppHotkey;Initialize-TaskPloppHotkey Dictation
    $open=$script:HotkeyListener;$dict=$script:DictationHotkeyListener
    $null=[TaskPloppInterop.User]::PostThreadMessageW($dict.State.ThreadId,0x312,[IntPtr]1,[IntPtr]0)
    Assert ($script:DictationHotkeyEvent.WaitOne(2000)-and-not$script:WakeEvent.WaitOne(0)) 'Dictation event misrouted'
    $null=[TaskPloppInterop.User]::PostThreadMessageW($open.State.ThreadId,0x312,[IntPtr]1,[IntPtr]0)
    Assert ($script:WakeEvent.WaitOne(2000)-and-not$script:DictationHotkeyEvent.WaitOne(0)) 'Open event misrouted'
    Save-TaskPloppSettingsWithHotkey $script:Settings
    Assert ([object]::ReferenceEquals($open,$script:HotkeyListener)-and[object]::ReferenceEquals($dict,$script:DictationHotkeyListener)) 'Unchanged listeners replaced'
    $next=Settings $free[2] $free[3]
    $external=New-TaskPloppHotkeyListener (Get-TaskPloppHotkeySpec $next Dictation)
    $hash=(Get-FileHash $script:ConfigPath).Hash
    Reject {Save-TaskPloppSettingsWithHotkey $next}
    Assert ((Get-FileHash $script:ConfigPath).Hash-eq$hash-and[object]::ReferenceEquals($open,$script:HotkeyListener)-and[object]::ReferenceEquals($dict,$script:DictationHotkeyListener)) 'Conflict changed file/old listener'
    $p=New-TaskPloppHotkeyListener (Get-TaskPloppHotkeySpec $next);$p.Dispose()
    # Real import uses active hotkeys, unlike the older transfer test's disabled bindings.
    $data=[pscustomobject]@{Settings=$next;Links=@{}}
    Reject {Import-TaskPloppTransfer $data (Join-Path $root 'store')}
    Assert ((Get-FileHash $script:ConfigPath).Hash-eq$hash-and[object]::ReferenceEquals($open,$script:HotkeyListener)-and[object]::ReferenceEquals($dict,$script:DictationHotkeyListener)) 'Import conflict changed old bindings/file'
    $external.Dispose();$external=$null
    Save-TaskPloppSettingsWithHotkey $next;$script:Settings=$next
    Assert ($open.Closed-and$dict.Closed) 'Successful replacement did not release both old listeners'
    $open=$script:HotkeyListener;$dict=$script:DictationHotkeyListener
    $goodPath=$script:ConfigPath;$script:ConfigPath=Join-Path $root 'absent\config.json'
    try{Reject {Save-TaskPloppSettingsWithHotkey (Settings $free[4] $free[5])}}finally{$script:ConfigPath=$goodPath}
    Assert ([object]::ReferenceEquals($open,$script:HotkeyListener)-and[object]::ReferenceEquals($dict,$script:DictationHotkeyListener)) 'Failed save replaced active listeners'
    foreach($key in @($free[4],$free[5])){$p=New-TaskPloppHotkeyListener (Get-TaskPloppHotkeySpec (Settings $key F1));$p.Dispose()}
    $alias=Clone $next;$alias.HotkeyModifiers=0;$alias.HotkeyKey='LaunchApplication2';$alias.DictationHotkeyModifiers=0;$alias.DictationHotkeyKey='Taschenrechner'
    Reject {Save-TaskPloppSettingsWithHotkey $alias}
    $open.Dispose();$dict.Dispose();$script:HotkeyListener=$null;$script:DictationHotkeyListener=$null;$script:ActiveHotkey=$null;$script:ActiveDictationHotkey=$null
    $same=Settings $free[0] $free[0];$script:Settings=$same;Save-Settings $same
    Initialize-TaskPloppHotkey;Reject {Initialize-TaskPloppHotkey Dictation}
    $unrelated=Clone $same;$unrelated.ShowOpenWindows=$true
    Save-TaskPloppSettingsWithHotkey $unrelated
    Assert ($null-ne$script:HotkeyListener-and$null-eq$script:DictationHotkeyListener-and(Get-Settings).ShowOpenWindows) 'Unbound unchanged hotkey blocks unrelated save'
    $script:HotkeyListener.Dispose();$script:HotkeyListener=$null;$script:ActiveHotkey=$null
    $script:Settings=Settings $free[0] $free[1]
    $external=New-TaskPloppHotkeyListener (Get-TaskPloppHotkeySpec $script:Settings)
    Reject {Initialize-TaskPloppHotkey};Initialize-TaskPloppHotkey Dictation
    Assert ($null-ne$script:DictationHotkeyListener) 'Open conflict prevents independent dictation startup'
    Write-Host 'OK: Two real listeners/events, changed-pair rollback, active import conflict, write failure cleanup, aliases, legacy collision, independent startup.'
}finally{
    foreach($listener in @($script:HotkeyListener,$script:DictationHotkeyListener,$external)){if($listener){$listener.Dispose()}}
    $script:WakeEvent.Dispose();$script:DictationHotkeyEvent.Dispose()
    $script:HotkeyListener=$null;$script:DictationHotkeyListener=$null;$script:ActiveHotkey=$null;$script:ActiveDictationHotkey=$null
    $script:HotkeysEnabled=$false
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-dictation-hotkey-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
# No microphone or engine: fixed state fakes verify dispatch/focus and stop-pending behavior.
$script:ProbeShows=0;$script:ProbeStarts=0;$script:ProbeStops=0
function Show-TaskPlopp {$script:ProbeShows++}
function Invoke-TaskPloppDictation {$script:ProbeStarts++;$script:DictationPhase='Recording';$script:DictationRecorder=[pscustomobject]@{Shared=@{Stop=$false}}}
function Stop-TaskPloppRecording {$script:ProbeStops++;$script:DictationRecorder.Shared.Stop=$true}
$script:ConfigurationOpen=$false;$script:TransferDialog=$null;$script:LayoutJob=$null;$script:DictationInstaller=$null;$script:DictationPurpose='Dictation';$script:DictationPhase='Ready'
Invoke-TaskPloppDictationHotkey
Assert ($script:ProbeShows-eq1-and$script:ProbeStarts-eq1) 'Start does not show/record once'
Invoke-TaskPloppDictationHotkey;Invoke-TaskPloppDictationHotkey
Assert ($script:ProbeShows-eq1-and$script:ProbeStops-eq1) 'Stop changes focus or repeats request'
$script:DictationPhase='Transcribing';Invoke-TaskPloppDictationHotkey
$script:DictationPurpose='Layout';$script:DictationPhase='Recording';$script:DictationRecorder.Shared.Stop=$false;Invoke-TaskPloppDictationHotkey
$script:DictationPurpose='Dictation';$script:DictationPhase='Ready'
$script:LayoutJob=[pscustomobject]@{Fake=$true};Invoke-TaskPloppDictationHotkey;$script:LayoutJob=$null
$script:DictationInstaller=[pscustomobject]@{Fake=$true};Invoke-TaskPloppDictationHotkey;$script:DictationInstaller=$null
$script:ConfigurationOpen=$true;Invoke-TaskPloppDictationHotkey;$script:ConfigurationOpen=$false
$script:TransferDialog=[pscustomobject]@{IsDisposed=$false};Invoke-TaskPloppDictationHotkey;$script:TransferDialog=$null
Assert ($script:ProbeShows-eq1-and$script:ProbeStarts-eq1-and$script:ProbeStops-eq1) 'Busy/dialog route invokes recording/focus'
Write-Host 'OK: Ready shows once; stop/pending/transcribing do not focus; layout/installer/config/transfer ignored without audio access.'

# GUI dispatch through the existing timer; audio and clipboard are memory-only fakes.
$config=Join-Path $env:TEMP ('TaskPlopp-dictation-hotkey-ui-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($config,'{"Programs":[],"ShowOpenWindows":false,"AutoLockEnabled":false}',[Text.UTF8Encoding]::new($true))
$global:DictationHotkeyUiFailure=$null
try{
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -SmokeTest -ConfigFile $config -OnShown {
        param($sender,$args)
        $smokeTimer.Stop();$dictationTimer.Stop();$peer=$null
        function Pump-Hotkey {for($i=0;$i-lt5;$i++){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 50}}
        try{
            function Invoke-TaskPloppDictation {
                $script:DictationRecorder=[pscustomobject]@{Disposed=$false;StopWatch=$null;Shared=@{Stop=$false;Closed=$true}}
                $script:DictationPhase='Recording';$script:DictationPurpose='Dictation'
                Show-TaskPloppDictationStatus;Update-TaskPloppDictationButton;Update-TaskPloppActivity 0.6 1
            }
            function Set-TaskPloppDictationClipboard([string]$Text){$script:HotkeyCopiedText=$Text}
            Minimize-TaskPlopp;Pump-Hotkey
            $null=$script:DictationHotkeyEvent.Set();Pump-Hotkey
            Assert ($sender.WindowState-eq'Normal'-and$script:CurrentView-eq'Tasks'-and$script:MessageBar.Tag.Activity-eq'Recording'-and$script:MessageBar.Tag.Peaks[63]-gt0.5) 'Start event did not show recording/peak'
            $fixture=Join-Path $PSScriptRoot 'fixtures\TaskPloppFocusFixture.ps1'
            $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),('-NoProfile -STA -ExecutionPolicy Bypass -File "'+$fixture+'" -Token "dictation-hotkey" -OwnerPid '+$PID))
            $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$peer=[Diagnostics.Process]::Start($info)
            $line=$peer.StandardOutput.ReadLineAsync();$watch=[Diagnostics.Stopwatch]::StartNew()
            while(-not$line.IsCompleted-and$watch.Elapsed.TotalSeconds-lt10){Pump-Hotkey}
            Assert $line.IsCompleted 'Own external GUI did not start'
            $handle=[IntPtr][long]$line.Result
            $focused=[TaskPloppInterop.User]::SetForegroundWindow($handle);Pump-Hotkey
            $heldForeground=[TaskPloppInterop.User]::GetForegroundWindow()
            if($heldForeground-ne$handle){Write-Host 'SKIP: Windows denied synthetic foreground activation; stop/result must still preserve the actual foreground handle.'}

            $null=$script:DictationHotkeyEvent.Set();Pump-Hotkey
            Assert ($script:DictationRecorder.Shared.Stop-and[TaskPloppInterop.User]::GetForegroundWindow()-eq$heldForeground) 'Stop event steals focus or fails stop'
            $script:DictationRecorder=$null;$script:DictationPhase='Transcribing'
            $script:DictationJob=[pscustomobject]@{Disposed=$true;Done=$true;Error='';Text='Synthetic hotkey transcript'}
            Invoke-TaskPloppDictationTick;Pump-Hotkey
            Assert ($script:HotkeyCopiedText-eq'Synthetic hotkey transcript'-and$script:DictationPhase-eq'Ready'-and[TaskPloppInterop.User]::GetForegroundWindow()-eq$heldForeground) 'Completed transcription steals focus or loses text'
            function Invoke-TaskPloppDictation {Set-TaskPloppMessage Error 'Synthetic unavailable engine' 'No audio access'}
            $null=$script:DictationHotkeyEvent.Set();Pump-Hotkey
            Assert ($sender.Visible-and$sender.WindowState-eq'Normal'-and$script:MessageBar.Tag.Lines[0]-like'*unavailable engine*') 'Start error not visible in foreground'
            Write-Host 'OK: GUI timer shows recording/peak and start errors; stop and real completion path preserve foreground. No microphone/clipboard mutation.'
        }catch{$global:DictationHotkeyUiFailure=$_}
        finally{
            if($peer){if(-not$peer.HasExited){$null=$peer.CloseMainWindow();if(-not$peer.WaitForExit(1000)){$peer.Kill();$peer.WaitForExit()}};$peer.Dispose()}
            $script:DictationRecorder=$null;$script:DictationJob=$null;$script:DictationPhase='Ready';$sender.Close()
        }
    }
    if($global:DictationHotkeyUiFailure){throw $global:DictationHotkeyUiFailure}
}finally{[IO.File]::Delete($config)}
