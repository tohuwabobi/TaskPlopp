#requires -Version 5.1
$ErrorActionPreference='Stop'
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Leave($Control){[Windows.Forms.Control].GetMethod('OnLeave',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($Control,[object[]]@([EventArgs]::Empty))|Out-Null}
function PumpFor([int]$Milliseconds){$watch=[Diagnostics.Stopwatch]::StartNew();while($watch.ElapsedMilliseconds-lt$Milliseconds){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 15}}
$root=Join-Path $env:TEMP ('TaskPlopp-autosave-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root);$config=Join-Path $root 'config.json'
$data=@{ShowOpenWindows=$false;AutoLockEnabled=$false;Programs=@(@{Name='First';ProcessName='fixture1';TitleContains=''},@{Name='Second';ProcessName='fixture2';TitleContains=''})}
[IO.File]::WriteAllText($config,($data|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($true))
$global:AutoFailure=$null;$global:AutoSaveCalls=0
try{
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -SmokeTest -ConfigFile $config -OnShown {
        param($sender,$args)
        $smokeTimer.Stop()
        $global:AutoSaveOriginal=${function:Save-TaskPloppSettingsWithHotkey}
        function Save-TaskPloppSettingsWithHotkey($Settings){$global:AutoSaveCalls++;& $global:AutoSaveOriginal $Settings}
        function Get-TaskPloppOpenAIKeyPath {Join-Path $root 'OpenAI.dpapi'}
        function ConfigTest([scriptblock]$Test){
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$eventArgs)
                try{& $Test $dialog}catch{$global:AutoFailure=$_}finally{if(-not$dialog.IsDisposed){$dialog.Close()}}
            }
            if($global:AutoFailure){throw $global:AutoFailure}
        }
        try{
            $initialClock=$script:IdleState.LastActivity
            ConfigTest {param($dialog)
                Assert ($dialog.Controls.Find('SaveSettings',$true).Count-eq0-and$dialog.Controls.Find('SaveOpenAIKey',$true).Count-eq0-and$dialog.Controls.Find('CancelSettings',$true).Count-eq0) 'Save/cancel buttons remain'
                Assert ($global:AutoSaveCalls-eq0) 'Opening writes settings'
                $name=$dialog.Controls.Find('FavoriteName',$true)[0];$name.Text='Renamed'
                Assert ((Get-Settings).Programs[0].Name-eq'First') 'Text saved during typing'
                $bar=$dialog.Controls.Find('ConfigurationMessages',$true)[0]
                Assert ($bar.BackColor.ToArgb()-eq[Drawing.Color]::FromArgb(255,226,163).ToArgb()-and$bar.Tag.Lines[0]-like'*noch nicht gespeichert*') 'Typing leaves stale green success'
                Leave $name;Assert ((Get-Settings).Programs[0].Name-eq'Renamed') 'Leave did not save'
                Assert ($bar.Tag.Lines[1]-match'Gespeichert um \d\d:\d\d:\d\d\.\d{3}') 'Repeated saves have no distinct timestamp'
                PumpFor 2300
                Assert ($bar.Tag.Lines[0]-eq''-and$bar.BackColor.ToArgb()-eq$bar.Parent.BackColor.ToArgb()) 'Success did not return to existing neutral background'
                Set-TaskPloppMessage Success 'Temporary fixture success' '' -Seconds 2
                $name.Text='Pending text'
                Assert ($bar.Tag.ExpireAt-eq0-and-not(Update-TaskPloppMessageTimeout $bar)-and$bar.Tag.Lines[0]-like'*noch nicht gespeichert*') 'Old success timeout can clear new pending input'
                Set-TaskPloppMessage Success 'Temporary fixture success' '' -Seconds 2
                Set-TaskPloppMessage Error 'Fixture error' ''
                Assert ($bar.Tag.ExpireAt-eq0-and-not(Update-TaskPloppMessageTimeout $bar)-and$bar.BackColor.ToArgb()-eq[Drawing.Color]::FromArgb(255,198,198).ToArgb()) 'Old success timeout clears newer error'
                Set-TaskPloppActivity Recording
                Assert ($script:MessageBar.Tag.ExpireAt-eq0-and$script:MessageBar.Tag.Activity-eq'Recording') 'Recording status expires like a save confirmation'
                $name.Text='Renamed'
                $count=$global:AutoSaveCalls;Leave $name;Assert ($global:AutoSaveCalls-eq$count) 'Unchanged Leave rewrites'
                $name.Text='';Leave $name
                Assert ($name.Text-eq'Renamed'-and(Get-Settings).Programs[0].Name-eq'Renamed') 'Invalid name not restored'
                $dialog.Controls.Find('DictationEngine',$true)[0].SelectedIndex=1
                Assert ((Get-Settings).DictationEngine-eq'Vosk') 'Independent change blocked'
                $list=$dialog.Controls.Find('FavoriteList',$true)[0];$name.Text='First committed on selection';$list.SelectedIndex=1
                Assert ((Get-Settings).Programs[0].Name-eq'First committed on selection'-and$name.Text-eq'Second') 'Selection saved wrong favorite'
                $dialog.Controls.Find('MoveFavoriteUp',$true)[0].PerformClick()
                Assert ((Get-Settings).Programs[0].Name-eq'Second'-and$list.SelectedIndex-eq0) 'Order not saved'
                $dialog.Controls.Find('ShowOpenWindows',$true)[0].Checked=$true
                Assert (Get-Settings).ShowOpenWindows 'Checkbox not saved'
                $model=$dialog.Controls.Find('WindowLayoutModel',$true)[0];$model.Text='model-close-test'
            }
            Assert ((Get-Settings).WindowLayoutModel-eq'model-close-test') 'Closing did not commit focused text'
            Assert ($script:IdleState.LastActivity-eq$initialClock) 'Unrelated changes reset lock clock'
            ConfigTest {param($dialog)
                $model=$dialog.Controls.Find('WindowLayoutModel',$true)[0];$model.Text='bad model with spaces';Leave $model
                Assert ($model.Text-eq'model-close-test') 'Invalid model not restored'
                $lock=[IO.File]::Open($config,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
                try{$dialog.Controls.Find('ShowOpenWindows',$true)[0].Checked=$false}finally{$lock.Dispose()}
                Assert ((Get-Settings).ShowOpenWindows-and$dialog.Controls.Find('ShowOpenWindows',$true)[0].Checked) 'Failed save changed file/UI'
                $dialog.Controls.Find('ShowOpenWindows',$true)[0].Checked=$false
                Assert (-not(Get-Settings).ShowOpenWindows) 'Recovery after write failure failed'
                $tab=$dialog.Controls.Find('WindowLayoutTab',$true)[0];$tab.Parent.SelectedTab=$tab
                $key=$dialog.Controls.Find('OpenAIKey',$true)[0];$key.Text='sk-taskplopp-FAKE-autosave'
                Assert (-not[IO.File]::Exists((Get-TaskPloppOpenAIKeyPath))) 'Key saved during typing'
                Leave $key;Assert ($key.Text-eq''-and(Test-TaskPloppOpenAIKey)) 'Key leave did not save/clear'
                $before=[Convert]::ToBase64String([IO.File]::ReadAllBytes((Get-TaskPloppOpenAIKeyPath)))
                $key.Text='invalid';Leave $key
                Assert ($key.Text-eq''-and[Convert]::ToBase64String([IO.File]::ReadAllBytes((Get-TaskPloppOpenAIKeyPath)))-eq$before) 'Invalid key changed old file'
                $key.Text='sk-taskplopp-FAKE-close'
            }
            Assert (Test-TaskPloppOpenAIKey) 'Key close did not save'
            ConfigTest {param($dialog)$dialog.Controls.Find('FavoriteName',$true)[0].Text=''}
            Assert ($script:MessageBar.Tag.Lines[0]-like'*nicht uebernommen*') 'Close failure invisible in main status'
            $global:AutoTrayOriginal=${function:Update-TaskPloppTrayText}
            function Update-TaskPloppTrayText {throw 'Fixture failure after file publication'}
            ConfigTest {param($dialog)
                $model=$dialog.Controls.Find('WindowLayoutModel',$true)[0];$model.Text='published-model';Leave $model
                Assert ((Get-Settings).WindowLayoutModel-eq'published-model'-and$script:Settings.WindowLayoutModel-eq'published-model') 'Post-save display failure lost publication'
                Assert ($dialog.Controls.Find('ConfigurationMessages',$true)[0].Tag.Lines[0]-like'*gespeichert, Anzeige*') 'Post-save failure reported as failed storage'
            }
            Set-Item Function:Update-TaskPloppTrayText $global:AutoTrayOriginal
            Write-Host 'OK: No save buttons, field boundaries/close, ordering/selection, write failure rollback/recovery, idle clock, isolated masked key, main close error.'
        }catch{$global:AutoFailure=$_}
        finally{$sender.Close()}
    }
    if($global:AutoFailure){throw $global:AutoFailure}
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-autosave-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
