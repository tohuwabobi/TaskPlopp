#requires -Version 5.1
$ErrorActionPreference='Stop'
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Client-Bounds($Control,$Form){$point=$Form.PointToClient($Control.PointToScreen([Drawing.Point]::Empty));[Drawing.Rectangle]::new($point,$Control.Size)}
$root=Join-Path $env:TEMP ('TaskPlopp-layout-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root);$config=Join-Path $root 'config.json'
$global:LayoutPrograms=@(1..30|ForEach-Object{[pscustomobject]@{Name="Testfavorit $_";ProcessName="taskplopp-layout-fixture-$_";TitleContains=''}})
$data=[pscustomobject]@{ShowOpenWindows=$true;AutoLockEnabled=$false;Programs=$global:LayoutPrograms}
[IO.File]::WriteAllText($config,($data|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($true))
$global:LayoutFailure=$null
try{
    . (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -SmokeTest -ConfigFile $config -OnShown {
        param($sender,$args)
        $smokeTimer.Stop()
        try{
            $script:LayoutPrograms=@($script:Settings.Programs)
            function Get-AppWindows {param([switch]$Raw) @()}
            $bar=$sender.Controls.Find('Messages',$true)[0]
            $content=$sender.Controls.Find('TaskContent',$true)[0]
            $left=$sender.Controls.Find('ToolbarLeft',$true)[0];$right=$sender.Controls.Find('ToolbarRight',$true)[0]
            Assert (($left.Controls.Name-join',')-eq'CitrixButton,AudioToggle,AutoLockToggle,DictationToggle') 'Linke Toolbargruppe falsch'
            Assert (($right.Controls.Name-join',')-eq'RefreshButton,ConfigurationButton') 'Rechte Toolbargruppe falsch'
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
                Assert ($rects[0].Left-eq10-and$rects[5].Right-eq$sender.ClientSize.Width-10) 'Toolbar falsch ausgerichtet'
                Assert ($rects[4].Left-$rects[3].Right-ge12) 'Toolbargruppen ueberlappen'
                $top=$sender.Controls.Find('TopArea',$true)[0];$toolbar=$sender.Controls.Find('Toolbar',$true)[0]
                Assert ($bar.Top-$toolbar.Bottom-eq3-and$top.ClientSize.Height-$bar.Bottom-eq3) 'Statusrahmen fehlt'
                Write-Host "OK: Layout $($case[0])x$($case[1]), Font $($case[2]), $($case[3]) Favoriten, Inset $expected."
            }
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
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $local=$dialog.Controls.Find('ConfigurationMessages',$true)[0]
                $timer=$local.Tag.Timer
                $dialog.Controls.Find('FavoriteName',$true)[0].Text=''
                $dialog.Controls.Find('SaveSettings',$true)[0].PerformClick()
                Assert ($dialog.Visible-and$local.Tag.Lines[0]-like'*nicht uebernommen*') 'Validierungsfehler im Dialog unsichtbar'
                Set-TaskPloppMessage Error ('Langer Fehler '*30) ('Langes Detail '*30)
                Assert $local.IsScrolling 'Lokale Status-Laufschrift fehlt'
                $script:LayoutConfigTimer=$timer
                $dialog.Controls.Find('CancelSettings',$true)[0].PerformClick()
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
    . (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -SmokeTest -ConfigFile $badConfig -OnShown {
        param($sender,$args)
        try{Assert ($script:MessageBar.Tag.Lines[0]-like'*Start nicht vollstaendig*'-and$script:MessageBar.Tag.Lines[1]-like'*Konfiguration*') 'Startfehler nicht in Statusleiste'}
        catch{$global:LayoutFailure=$_}
        finally{$sender.Close()}
    }
    if($global:LayoutFailure){throw $global:LayoutFailure}
    Assert ([IO.File]::ReadAllText($badConfig)-eq'{kaputt') 'Defekte Config ueberschrieben'
    foreach($file in @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'TaskPlopp*.ps1')+@(Get-Item (Join-Path $PSScriptRoot 'Start-TaskPlopp.ps1'))){Assert (-not([IO.File]::ReadAllText($file.FullName)-match'MessageBox|ShowBalloonTip|Show-Notice')) ('Popupquelle uebrig: '+$file.Name)}
    Write-Host 'OK: Startupfehler ohne Dialog, Config unveraendert, keine Popupquellen, GUI-Exceptionhandler abgemeldet.'
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-layout-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
