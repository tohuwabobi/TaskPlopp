#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Reject($Action,[string]$Expected){try{&$Action;throw 'NOT_REJECTED'}catch{Assert ($_.Exception.Message-eq$Expected) ('Expected '+$Expected+', got '+$_.Exception.Message)}}
$root=Join-Path $env:TEMP ('TaskPlopp-key-window-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root)
$global:KeyWindowPath=Join-Path $root 'Secrets\OpenAI.dpapi'
$config=Join-Path $root 'config.json'
[IO.File]::WriteAllText($config,'{"Programs":[],"ShowOpenWindows":false,"AutoLockEnabled":false}',[Text.UTF8Encoding]::new($true))
$global:KeyWindowFailure=$null
try{
    Assert (-not(Test-TaskPloppOpenAIKey $global:KeyWindowPath)) 'Missing file accepted'
    Save-TaskPloppOpenAIKey ' sk-taskplopp-FAKE-first ' $global:KeyWindowPath
    Assert (Test-TaskPloppOpenAIKey $global:KeyWindowPath) 'First save not decryptable'
    $original=[IO.File]::ReadAllBytes($global:KeyWindowPath)
    Reject {Save-TaskPloppOpenAIKey '' $global:KeyWindowPath} KEY_FORMAT
    Reject {Save-TaskPloppOpenAIKey 'not-an-openai-key' $global:KeyWindowPath} KEY_FORMAT
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($global:KeyWindowPath))-eq[Convert]::ToBase64String($original)) 'Invalid input changed old file'
    $lock=[IO.File]::Open($global:KeyWindowPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{Reject {Save-TaskPloppOpenAIKey 'sk-taskplopp-FAKE-replacement' $global:KeyWindowPath} KEY_SAVE}finally{$lock.Dispose()}
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($global:KeyWindowPath))-eq[Convert]::ToBase64String($original)) 'Failed replacement changed original'
    Assert (@(Get-ChildItem (Split-Path $global:KeyWindowPath) -Filter '*.tmp').Count-eq0) 'Encrypted temporary file retained'
    Save-TaskPloppOpenAIKey 'sk-taskplopp-FAKE-second' $global:KeyWindowPath
    $plain=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($global:KeyWindowPath),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    try{Assert ([Text.Encoding]::UTF8.GetString($plain)-ceq'sk-taskplopp-FAKE-second') 'Replacement key mismatch'}finally{[Array]::Clear($plain,0,$plain.Length)}
    [IO.File]::WriteAllBytes($global:KeyWindowPath,[byte[]]@(1,2,3))
    Assert (-not(Test-TaskPloppOpenAIKey $global:KeyWindowPath)) 'Corrupt file accepted'
    Write-Host 'OK: Isolated DPAPI first save, atomic replacement, invalid/empty input, locked destination preserves old bytes, corrupt file, encrypted temp cleanup.'
    . (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -ResidentTest -ConfigFile $config -OnShown {
        param($sender,$args)
        $smokeTimer.Stop()
        function Get-TaskPloppOpenAIKeyPath {$global:KeyWindowPath}
        function Get-AppWindows {param([switch]$Raw) @()}
        function Pump {for($i=0;$i-lt10;$i++){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 10}}
        try{
            Pump
            Assert ((Get-TaskPloppOpenAIKeyPath)-eq$global:KeyWindowPath) 'Test must use isolated key path'
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $tab=$dialog.Controls.Find('WindowLayoutTab',$true)[0];$tab.Parent.SelectedTab=$tab
                $input=$dialog.Controls.Find('OpenAIKey',$true)[0];$save=$dialog.Controls.Find('SaveOpenAIKey',$true)[0];$state=$dialog.Controls.Find('OpenAIKeyState',$true)[0]
                Assert ($input.UseSystemPasswordChar-and$input.Text-eq'') 'Key is visible or prefilled'
                Assert ($state.Text-like'*nicht verwendbar*') 'Corrupt file status missing'
                $input.Text='invalid';$save.PerformClick()
                $bar=$dialog.Controls.Find('ConfigurationMessages',$true)[0]
                Assert ($dialog.Visible-and$bar.Tag.Lines[0]-like'*nicht gespeichert*'-and$bar.BackColor.ToArgb()-eq[Drawing.Color]::FromArgb(255,198,198).ToArgb()) 'Key failure not in local red status'
                $input.Text='sk-taskplopp-FAKE-gui';$save.PerformClick()
                Assert ($input.Text-eq''-and$state.Text-like'*nicht online geprueft*'-and$bar.Tag.Lines[0]-like'*lokal gespeichert*'-and$bar.BackColor.ToArgb()-eq[Drawing.Color]::FromArgb(205,239,211).ToArgb()) 'Local save success not clear'
                $dialog.Controls.Find('WindowLayoutModel',$true)[0].Text='unsaved-model'
                $dialog.Controls.Find('CancelSettings',$true)[0].PerformClick()
            }
            Assert ((Test-TaskPloppOpenAIKey $global:KeyWindowPath)-and$script:Settings.WindowLayoutModel-eq'gpt-4.1-mini') 'Cancel lost separate key save or saved model draft'
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $tab=$dialog.Controls.Find('WindowLayoutTab',$true)[0];$tab.Parent.SelectedTab=$tab
                Assert ($dialog.Controls.Find('OpenAIKey',$true)[0].Text-eq'') 'Existing key prefilled on reopening'
                Assert ($dialog.Controls.Find('OpenAIKeyState',$true)[0].Text-like'Lokal eingerichtet*') 'Existing usable key status missing'
                $input=$dialog.Controls.Find('OpenAIKey',$true)[0];$input.Text='sk-taskplopp-FAKE-locked-gui'
                $lock=[IO.File]::Open($global:KeyWindowPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
                try{$dialog.Controls.Find('SaveOpenAIKey',$true)[0].PerformClick()}finally{$lock.Dispose()}
                Assert ($input.Text-eq'sk-taskplopp-FAKE-locked-gui'-and$dialog.Controls.Find('ConfigurationMessages',$true)[0].Tag.Lines[0]-like'*nicht gespeichert*') 'Failed UI save lost input or did not report failure'
                $dialog.Controls.Find('CancelSettings',$true)[0].PerformClick()
            }
            Pump
            $null=[TaskPloppInterop.User]::SendMessageW($sender.Handle,0x112,[IntPtr]0xF020,[IntPtr]::Zero);Pump
            Assert ($sender.Visible-and$sender.ShowInTaskbar-and$sender.WindowState-eq'Minimized'-and[TaskPloppInterop.User]::IsIconic($sender.Handle)) 'Minimize removes taskbar window'
            $sender.Close();Pump
            Assert (-not$sender.IsDisposed-and-not$sender.Visible) 'X while minimized must hide resident GUI'
            Show-TaskPlopp;Pump
            Assert ($sender.Visible-and$sender.ShowInTaskbar-and-not[TaskPloppInterop.User]::IsIconic($sender.Handle)) 'Wake does not restore after minimized X'
            function Activate-TaskPloppCoveredWindow {return $true}
            Open-Window ([pscustomobject]@{Handle=$sender.Handle;ProcessName='fixture'});Pump
            Assert ($sender.Visible-and[TaskPloppInterop.User]::IsIconic($sender.Handle)) 'Window selection must minimize, not hide'
            Show-TaskPlopp;Pump
            function Start-FavoriteApplication {param($Favorite,[switch]$Preview)}
            function Resolve-FavoriteStart {param($Favorite) [pscustomobject]@{Kind='Path';Target='fixture'}}
            Open-Favorite ([pscustomobject]@{LaunchAlways=$true});Pump
            Assert ($sender.Visible-and[TaskPloppInterop.User]::IsIconic($sender.Handle)) 'Favorite launch must minimize, not hide'
            Show-TaskPlopp;Pump
            function Get-AppWindows {param([switch]$Raw) if($Raw){[pscustomobject]@{Handle=$script:Main.Handle;ProcessName='wfica32'}}}
            function Minimize-TaskPloppWindow {param([IntPtr]$Handle) return $true}
            $sender.Controls.Find('CitrixButton',$true)[0].PerformClick();Pump
            Assert ($sender.Visible-and[TaskPloppInterop.User]::IsIconic($sender.Handle)) 'Citrix action must minimize TaskPlopp to taskbar'
            function Get-AppWindows {param([switch]$Raw) @()}
            Show-TaskPlopp;Pump
            foreach($mode in @('Apply','Undo')){
                $result=if($mode-eq'Apply'){@{Ok=$true;Mutated=1;Snapshots=@();Applied=1;Warnings=0;Reason='Fixture'}}else{@{Ok=$true;Restored=1;Warnings=0}}
                $reader=[IO.StringReader]::new(($result|ConvertTo-Json -Compress)+"`n");$errors=[IO.StringReader]::new('')
                $process=[pscustomobject]@{HasExited=$true;StandardOutput=$reader};$process|Add-Member ScriptMethod Dispose {}
                $script:LayoutMode=$mode
                $script:LayoutJob=[pscustomobject]@{Process=$process;Output=$reader.ReadLineAsync();Errors=$errors.ReadToEndAsync();Write=[Threading.Tasks.Task]::Delay(0);InputClosed=$true;Result=$null;Watch=[Diagnostics.Stopwatch]::StartNew()}
                Invoke-TaskPloppLayoutTick;Pump
                Assert ($sender.Visible-and[TaskPloppInterop.User]::IsIconic($sender.Handle)) ($mode+' must minimize, not hide: visible='+$sender.Visible+', state='+$sender.WindowState+', status='+($script:MessageBar.Tag.Lines-join' | '))
                $reader.Dispose();$errors.Dispose();Show-TaskPlopp;Pump
            }
            $sender.Close();Pump
            Assert (-not$sender.Visible-and-not$sender.IsDisposed) 'Normal X must hide resident GUI'
            Show-TaskPlopp;Pump
            Assert ($sender.Visible-and-not$sender.IsDisposed) 'Resident GUI did not reopen'
            Assert (-not([IO.File]::ReadAllText($config)-match'sk-taskplopp')) 'Config contains fake key'
            Write-Host 'OK: Masked local key UI, status colors, separate save/cancel, empty reopen, minimize -> X -> wake, favorites/AI minimize, resident exit.'
        }catch{$global:KeyWindowFailure=$_}
        finally{$script:ExitRequested=$true;$script:LayoutJob=$null;$sender.Close()}
    }
    if($global:KeyWindowFailure){throw $global:KeyWindowFailure}
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-key-window-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
