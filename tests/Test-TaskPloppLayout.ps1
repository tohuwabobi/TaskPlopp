#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.Native.ps1')
$null=[TaskPloppInterop.Geometry]::SetThreadDpiAwarenessContext([IntPtr](-4))
function Complete-TextEdit($Control){[Windows.Forms.Control].GetMethod('OnLeave',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($Control,[object[]]@([EventArgs]::Empty))|Out-Null}
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Client-Bounds($Control,$Form){$point=$Form.PointToClient($Control.PointToScreen([Drawing.Point]::Empty));[Drawing.Rectangle]::new($point,$Control.Size)}
$root=Join-Path $env:TEMP ('TaskPlopp-layout-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root);$config=Join-Path $root 'config.json'
$global:LayoutPrograms=@(1..30|ForEach-Object{[pscustomobject]@{Name="Testfavorit $_";ProcessName="taskplopp-layout-fixture-$_";TitleContains=''}})
$data=[pscustomobject]@{ShowOpenWindows=$true;AutoLockEnabled=$false;Programs=$global:LayoutPrograms}
[IO.File]::WriteAllText($config,($data|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($true))
$global:LayoutFailure=$null
try{
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -SmokeTest -ConfigFile $config -OnShown {
        param($sender,$args)
        $smokeTimer.Stop()
        try{
            $script:LayoutPrograms=@($script:Settings.Programs)
            function Get-AppWindows {param([switch]$Raw) @()}
            $bar=$sender.Controls.Find('Messages',$true)[0]
            $content=$sender.Controls.Find('TaskContent',$true)[0]
            $left=$sender.Controls.Find('ToolbarLeft',$true)[0];$right=$sender.Controls.Find('ToolbarRight',$true)[0]
            Assert (($left.Controls.Name-join',')-eq'CitrixButton,AudioToggle,AutoLockToggle,DictationToggle,WindowLayoutToggle') 'Linke Toolbargruppe falsch'
            Assert (($right.Controls.Name-join',')-eq'HelpButton,RefreshButton,ConfigurationButton') 'Rechte Toolbargruppe falsch'
            foreach($case in @(@(760,1200,10,3),@(420,350,10,30),@(420,350,15,30),@(420,350,15,0),@(760,1200,10,3))){
                $sender.Font=[Drawing.Font]::new('Segoe UI',$case[2]);$sender.Size=[Drawing.Size]::new($case[0],$case[1])
                $script:Settings.Programs=@($script:LayoutPrograms|Select-Object -First $case[3]);Update-WindowList
                for($n=0;$n-lt5;$n++){[Windows.Forms.Application]::DoEvents()}
                $buttons=@($content.Controls|Where-Object{$_-is[Windows.Forms.Button]})
                $bounds=Client-Bounds $bar $sender
                Assert ([Math]::Abs($bounds.Left-($sender.ClientSize.Width-$bounds.Right))-le1) 'Statusraender ungleich'
                Assert (-not$content.HorizontalScroll.Visible) 'Horizontale Scrollbar durch Inhalt'
                if($buttons.Count){$task=Client-Bounds $buttons[0] $sender;Assert ($task.Left-eq$bounds.Left-and$task.Right-eq$bounds.Right) 'Task-/Statuskanten nicht deckungsgleich'}
                $expected=10+$(if($content.VerticalScroll.Visible){[Windows.Forms.SystemInformation]::VerticalScrollBarWidth}else{0})
                Assert ($bounds.Left-eq$expected) 'Scrollbar nicht symmetrisch ausgeglichen'
                foreach($heading in @($content.Controls|Where-Object{$_-is[Windows.Forms.Label]})){Assert ($heading.Right-le$content.ClientSize.Width-$content.Padding.Right) 'Heading zu breit'}
                $toolbarButtons=@($left.Controls)+@($right.Controls)
                $rects=@($toolbarButtons|ForEach-Object{Client-Bounds $_ $sender})
                Assert (@($rects.Top|Select-Object -Unique).Count-eq1) 'Toolbar bricht um'
                Assert ($rects[0].Left-eq10-and$rects[-1].Right-eq$sender.ClientSize.Width-10) 'Toolbar falsch ausgerichtet'
                Assert ($rects[5].Left-$rects[4].Right-ge12) 'Toolbargruppen ueberlappen'
                Assert (@($rects|Where-Object {$_.Left-lt0-or$_.Right-gt$sender.ClientSize.Width}).Count-eq0) 'Toolbarbutton ausserhalb des Fensters'
                $top=$sender.Controls.Find('TopArea',$true)[0];$toolbar=$sender.Controls.Find('Toolbar',$true)[0]
                Assert ($bar.Top-$toolbar.Bottom-eq3-and$top.ClientSize.Height-$bar.Bottom-eq3) 'Statusrahmen fehlt'
                Write-Host "OK: Layout $($case[0])x$($case[1]), Font $($case[2]), $($case[3]) Favoriten, Inset $expected."
            }
            function Get-TaskPloppAudioDevices {param($Flow) @()}
            function Get-TaskPloppAudioDefaults {param($Flow) @()}
            function Get-TaskPloppOpenAIKeyPath {Join-Path $env:TEMP ('TaskPlopp-unconfigured-key-test-'+$PID+'.dpapi')}
            function Pump-Help {for($i=0;$i-lt4;$i++){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 15}}
            function Press-HelpEscape {
                $e=[Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::Escape)
                [Windows.Forms.Control].GetMethod('OnKeyDown',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($script:Main,[object[]]@($e))|Out-Null
                Assert $e.Handled 'Help Escape not handled'
            }
            $sender.Font=[Drawing.Font]::new('Segoe UI',15);$sender.Size=[Drawing.Size]::new(760,900)
            $helpButton=$sender.Controls.Find('HelpButton',$true)[0]
            $top=$sender.Controls.Find('TopArea',$true)[0];$toolbar=$sender.Controls.Find('Toolbar',$true)[0]
            Set-TaskPloppMessage Warning 'Keep while reading help' 'Fixture detail'
            $formCount=[Windows.Forms.Application]::OpenForms.Count
            $helpButton.PerformClick();Pump-Help
            $help=$sender.Controls.Find('HelpText',$true)[0]
            Assert ($sender.HelpView-and-not$bar.Visible-and$top.GetRowHeights()[1]-eq0-and[Windows.Forms.Application]::OpenForms.Count-eq$formCount) 'Help is popup or status retains space'
            Assert ($help.Text-like'*Strg+NumPad0*'-and$help.ReadOnly-and$help.Font.Size-eq$sender.Font.Size) 'Help lacks active hotkey or font'
            $helpBounds=Client-Bounds $help $sender;$toolbarBounds=Client-Bounds $toolbar $sender
            Assert ($helpBounds.Top-eq$toolbarBounds.Bottom+$content.Padding.Top-and$helpBounds.Bottom-eq$sender.ClientSize.Height-$content.Padding.Bottom) 'Help does not fill whole content below toolbar'
            Assert ($sender.SelectionButtons.Count-eq0) 'Help retains favorite keys'
            $script:RefreshButton.PerformClick();Update-WindowList;Update-TaskPloppAudioView;Pump-Help
            Assert ($sender.Controls.Find('HelpText',$true).Count-eq1-and$bar.Tag.Lines[0]-like'*Keep while reading*') 'Refresh/renderer replaces help or clears hidden status'
            Show-TaskPloppConfiguration -OnShown {param($dialog,$args) $dialog.Controls.Find('CloseSettings',$true)[0].PerformClick()}
            Assert ($script:CurrentView-eq'Help'-and$sender.Controls.Find('HelpText',$true).Count-eq1) 'Configuration return lost help'
            $sender.Activate();Raise-TaskPloppWindow $sender.Handle;Pump-Help
            Assert ([Windows.Forms.Form]::ActiveForm-eq$sender) 'Test requires active Main for Help Escape'
            $script:CancelFromHelp=0
            function Cancel-TaskPloppWindowLayout {$script:CancelFromHelp++}
            $script:LayoutJob=[pscustomobject]@{Fixture=$true};$jobBefore=$script:LayoutJob
            try{
                Press-HelpEscape
                Assert ($script:CurrentView-eq'Tasks'-and[object]::ReferenceEquals($jobBefore,$script:LayoutJob)-and$script:CancelFromHelp-eq0) 'Help Escape cancelled worker'
            }finally{$script:LayoutJob=$null}
            Pump-Help
            Assert ($bar.Visible-and$top.GetRowHeights()[1]-gt0) 'Return did not restore status space'
            Show-TaskPloppView Audio
            Set-TaskPloppActivity Recording;$bar.Tag.Peaks[4]=0.4
            $helpButton.PerformClick();Pump-Help;$helpButton.PerformClick();Pump-Help
            Assert ($script:CurrentView-eq'Audio'-and$bar.Tag.Activity-eq'Recording'-and$bar.Tag.Peaks[4]-gt0.3) 'Help->Audio erased recording activity/peaks'
            $helpButton.PerformClick();Set-TaskPloppMessage Success 'Result received during help' 'Keep this';$helpButton.PerformClick()
            Assert ($bar.Tag.Lines[0]-like'*Result received*') 'Audio ready notice replaces result from help'
            $helpButton.PerformClick();Set-TaskPloppMessage Success 'Expired while reading' '' -Seconds 2;$bar.Tag.ExpireAt=[long]1
            $helpButton.PerformClick()
            Assert ($bar.Tag.Lines[0]-eq''-and$bar.Tag.ExpireAt-eq0) 'Expired status flashes again on return'
            $helpButton.PerformClick();$script:AudioButton.PerformClick()
            Assert ($script:CurrentView-eq'Audio'-and$bar.Visible) 'Audio button cannot leave help'
            $helpButton.PerformClick();Show-TaskPlopp;Pump-Help
            Assert ($script:CurrentView-eq'Tasks'-and$bar.Visible) 'Global reopen retains help'
            $helpButton.PerformClick();Pump-Help
            $area=[Windows.Forms.Screen]::FromControl($sender).WorkingArea
            $sender.Location=[Drawing.Point]::new(($area.X+20),($area.Y+20))
            $sender.Activate();$sender.Refresh();Pump-Help
            if([TaskPloppInterop.User]::GetForegroundWindow()-eq$sender.Handle-and$area.Contains((Get-TaskPloppLayoutRect $sender.Handle -Raw))){
                $capture=[Drawing.Bitmap]::new($sender.ClientSize.Width,$sender.ClientSize.Height);$g=[Drawing.Graphics]::FromImage($capture)
                try{$g.CopyFromScreen($sender.PointToScreen([Drawing.Point]::Empty),[Drawing.Point]::Empty,$sender.ClientSize);$capture.Save((Join-Path $env:TEMP 'TaskPlopp-help-screen.png'))}finally{$g.Dispose();$capture.Dispose()}
            }
            $sender.Size=$sender.MinimumSize;Pump-Help
            $help=$sender.Controls.Find('HelpText',$true)[0];$helpBounds=Client-Bounds $help $sender
            Assert ($helpBounds.Right-le$sender.ClientSize.Width-and$helpBounds.Bottom-le$sender.ClientSize.Height-and-not$content.HorizontalScroll.Visible) 'Help clipped at minimum size'
            $helpButton.PerformClick();$sender.Size=[Drawing.Size]::new(760,900);Pump-Help
            Write-Host 'OK: Full-window help, preserved status/activity, two Escape handlers, config/refresh/audio/global navigation, minimum toolbar width.'
            $sender.Controls.Find('CitrixButton',$true)[0].PerformClick()
            $bitmap=[Drawing.Bitmap]::new($sender.Width,$sender.Height)
            try{$sender.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$sender.Width,$sender.Height));$bitmap.Save((Join-Path $env:TEMP 'TaskPlopp-layout-frame.png'))}finally{$bitmap.Dispose()}
            Assert ($bar.Tag.Lines[0]-like'*Kein sichtbares Citrix*'-and$bar.BackColor.ToArgb()-eq[Drawing.Color]::FromArgb(255,226,163).ToArgb()) 'Citrix-Hinweis nicht in vorhandener Hinweisfarbe'
            Open-Window ([pscustomobject]@{Handle=[IntPtr]::Zero;ProcessName='fixture'})
            Assert ($bar.Tag.Lines[0]-like'*geschlossen*') 'Geschlossenes Fenster nicht als Status gemeldet'
            function Activate-TaskPloppCoveredWindow {return $false}
            Open-Window ([pscustomobject]@{Handle=$sender.Handle;ProcessName='fixture'})
            Assert ($bar.Tag.Lines[0]-like'*nicht aktiviert*'-and$bar.BackColor.ToArgb()-eq[Drawing.Color]::FromArgb(255,198,198).ToArgb()) 'Fokusfehler nicht rot'
            Open-Favorite $script:Settings.Programs[0]
            Assert ($bar.Tag.Lines[0]-like'*Startziel fehlt*'-and(Get-Variable ConfigurationOpen -Scope Script -ValueOnly -ErrorAction SilentlyContinue)-ne$true) 'Fehlendes Startziel oeffnet automatisch Konfiguration'
            function Get-TaskPloppOpenAIKeyPath {Join-Path $env:TEMP ('TaskPlopp-unconfigured-key-test-'+$PID+'.dpapi')}
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $local=$dialog.Controls.Find('ConfigurationMessages',$true)[0]
                $timer=$local.Tag.Timer
                $dialog.Controls.Find('FavoriteName',$true)[0].Text=''
                Complete-TextEdit $dialog.Controls.Find('FavoriteName',$true)[0]
                Assert ($dialog.Visible-and$local.Tag.Lines[0]-like'*nicht uebernommen*') 'Validierungsfehler im Dialog unsichtbar'
                Set-TaskPloppMessage Error ('Langer Fehler '*30) ('Langes Detail '*30)
                Assert $local.IsScrolling 'Lokale Status-Laufschrift fehlt'
                $script:LayoutConfigTimer=$timer
                $dialog.Controls.Find('CloseSettings',$true)[0].PerformClick()
            }
            Assert (-not$script:LayoutConfigTimer.Enabled) 'Dialogstatus-Timer laeuft nach Schliessen weiter'
            $sender.Hide();Set-TaskPloppMessage Error 'Unsichtbarer Testhinweis' 'Nicht hervorholen.'
            Assert (-not$sender.Visible) 'Meldung holt Fenster hervor'
            $sender.Show()
            $method=[Windows.Forms.Application].GetMethod('OnThreadException',[Reflection.BindingFlags]'Static,Public,NonPublic')
            $null=$method.Invoke($null,[object[]]@([Exception]::new('Isolierter UI-Fehler')))
            Assert ($bar.Tag.Lines[1]-like'*Isolierter UI-Fehler*') 'UI-Ausnahme nicht in Status geroutet'
            Write-Host 'OK: Status statt Popups bei Citrix, Fenster-/Fokusfehler, fehlendem Ziel, Konfigurationsfehler und UI-Ausnahme; keine Fremdaktion.'
        }catch{$global:LayoutFailure=$_;Write-Host $_.ToString()}
        finally{$sender.Close()}
    }
    if($global:LayoutFailure){throw $global:LayoutFailure}
    $raw=[IO.File]::ReadAllText($config)|ConvertFrom-Json
    Assert ($raw.Programs.Count-eq30) 'Test hat Konfiguration veraendert'
    $contextType=[Windows.Forms.Application].GetNestedType('ThreadContext',[Reflection.BindingFlags]'NonPublic')
    $context=$contextType.GetMethod('FromCurrent',[Reflection.BindingFlags]'Static,Public,NonPublic').Invoke($null,@())
    Assert ($null-eq$contextType.GetField('threadExceptionHandler',[Reflection.BindingFlags]'Instance,NonPublic').GetValue($context)) 'GUI-Exceptionhandler nach Ende noch registriert'
    $badConfig=Join-Path $root 'broken.json';[IO.File]::WriteAllText($badConfig,'{kaputt')
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -SmokeTest -ConfigFile $badConfig -OnShown {
        param($sender,$args)
        try{Assert ($script:MessageBar.Tag.Lines[0]-like'*Start nicht vollstaendig*'-and$script:MessageBar.Tag.Lines[1]-like'*Konfiguration*') 'Startfehler nicht in Statusleiste'}
        catch{$global:LayoutFailure=$_}
        finally{$sender.Close()}
    }
    if($global:LayoutFailure){throw $global:LayoutFailure}
    Assert ([IO.File]::ReadAllText($badConfig)-eq'{kaputt') 'Defekte Config ueberschrieben'
    foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\src') -Filter 'TaskPlopp*.ps1')+@(Get-Item (Join-Path $PSScriptRoot '..\Start-TaskPlopp.ps1'))){Assert (-not([IO.File]::ReadAllText($file.FullName)-match'MessageBox|ShowBalloonTip|Show-Notice')) ('Popupquelle uebrig: '+$file.Name)}
    Write-Host 'OK: Startupfehler ohne Dialog, Config unveraendert, keine Popupquellen, GUI-Exceptionhandler abgemeldet.'
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-layout-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
