#requires -Version 5.1
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message) { if(-not $Condition) { throw $Message } }
function Save-Preview($Form,[string]$Name) {
    [Windows.Forms.Application]::DoEvents()
    $bitmap=[Drawing.Bitmap]::new($Form.Width,$Form.Height)
    try { $Form.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$Form.Width,$Form.Height)); $bitmap.Save((Join-Path $env:TEMP $Name)) }
    finally { $bitmap.Dispose() }
}
$global:TaskPloppUiFailure=$null
$testConfig=Join-Path $env:TEMP ('TaskPlopp-audio-ui-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($testConfig,'{"ShowOpenWindows":false,"AutoLockEnabled":false,"Programs":[{"Name":"Fixture","ProcessName":"taskplopp-audio-fixture","TitleContains":""}]}',[Text.UTF8Encoding]::new($true))
& (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -SmokeTest -ConfigFile $testConfig -OnShown {
    param($sender,$eventArgs)
    $smokeTimer.Stop()
    try {
        $content=$sender.Controls.Find('TaskContent',$true)[0]
        $firstTask=@($content.Controls | Where-Object {$_ -is [Windows.Forms.Button]})[0].Text
        $toggle=$sender.Controls.Find('AudioToggle',$true)[0]
        $script:AudioUiDevices = @(
            @(
                [pscustomobject]@{Id='r'; Name='Lautsprecher (3- Realtek(R) Audio)'}
                [pscustomobject]@{Id='lg'; Name='LG ULTRAWIDE (NVIDIA High Definition Audio)'}
                [pscustomobject]@{Id='j'; Name='Lautsprecher (Jabra Link 380)'}
            ),
            @(
                [pscustomobject]@{Id='z'; Name='Mikrofon (Zubehör mit besonders langem Namen für die Anzeige)'}
                [pscustomobject]@{Id='m2'; Name='Mikrofon (2- Doppelgerät)'}
                [pscustomobject]@{Id='m1'; Name='Mikrofon (1- Doppelgerät)'}
                [pscustomobject]@{Id='cam'; Name='Mikrofon (Insta360 Link 2 Pro)'}
            )
        )
        $script:AudioUiDefaults = @(@('j','j','j'), @('m1','m1','m2'))
        $script:AudioUiSelected = $null
        function script:Get-TaskPloppAudioDevices($Flow) { $script:AudioUiDevices[$Flow] }
        function script:Get-TaskPloppAudioDefaults($Flow) {
            foreach ($role in 0..2) {
                $id = $script:AudioUiDefaults[$Flow][$role]
                $readError = if ($id -eq 'm2') { 'Fixture role read error' } else { '' }
                [pscustomobject]@{ Id=$id; Role=$role; Error=$readError }
            }
        }
        function script:Set-TaskPloppAudioDefault($Id) {
            $script:AudioUiSelected = $Id
            $script:AudioUiDefaults[0] = @($Id,$Id,$Id)
        }
        $sender.Size=[Drawing.Size]::new(760,650)
        $watch=[Diagnostics.Stopwatch]::StartNew()
        $toggle.PerformClick(); $watch.Stop()
        Assert $sender.AudioView 'Audioansicht nicht aktiviert.'
        Assert ($content.Controls.Count -eq 1 -and $content.Controls[0].Name -eq 'AudioColumns') 'Tasks wurden nicht ersetzt.'
        Assert ($content.Controls[0].Controls.Count -eq 2) 'Zwei Audiospalten fehlen.'
        $expectedIds = @('j','lg','r','m1','m2','cam','z')
        $expectedLabels = @(
            'Jabra Link 380', 'LG ULTRAWIDE', 'Realtek(R) Audio', 'Mikrofon (1- Doppelgerät)',
            'Mikrofon (2- Doppelgerät)', 'Insta360 Link 2 Pro', 'Zubehör mit besonders langem Namen für die Anzeige'
        )
        $expectedColors = @('FDE047','F87171','60A5FA','4ADE80','F472B6','FB923C','FDE047')
        function Assert-AudioRows([string]$StandardId) {
            $buttons = $sender.SelectionButtons
            Assert ($buttons.Count -eq $expectedIds.Count) 'Synthetische Geraeteliste unvollstaendig.'
            for ($i=0; $i -lt $expectedIds.Count; $i++) {
                $button = $buttons[$i]
                $id = $expectedIds[$i]
                Assert ($button.Tag.Device.Id -eq $id) "Falsches Geraet an Position $i."
                Assert ($button.Text -ceq ('[{0}]  {1}' -f ($i+1),$expectedLabels[$i])) "Anzeige oder Tastennummer falsch: $($button.Text)"
                Assert ($button.ForeColor.ToArgb() -eq [Drawing.Color]::Black.ToArgb()) 'Schrift ist nicht schwarz.'
                foreach ($background in @($button.BackColor,$button.FlatAppearance.MouseOverBackColor,$button.FlatAppearance.MouseDownBackColor)) {
                    $actualHex = '{0:X2}{1:X2}{2:X2}' -f $background.R,$background.G,$background.B
                    Assert ($actualHex -eq $expectedColors[$i]) "Farbe an Position $i abweichend: $actualHex"
                    $rgb = @($background.R,$background.G,$background.B | ForEach-Object {
                        $x = $_ / 255.0
                        if ($x -le 0.04045) { $x / 12.92 } else { [Math]::Pow(($x + 0.055)/1.055,2.4) }
                    })
                    $contrast = (0.2126*$rgb[0]+0.7152*$rgb[1]+0.0722*$rgb[2]+0.05)/0.05
                    Assert ($contrast -ge 7) "Kontrast unter 7:1: $actualHex"
                }
                $border = if ($id -in @($StandardId,'m1')) { 3 } else { 1 }
                Assert ($button.FlatAppearance.BorderSize -eq $border) "Aktivrahmen falsch: $id"
                $tooltip = $content.Controls[0].Tag.GetToolTip($button)
                $expectedHint = $button.Tag.Device.Name
                if ($id -eq $StandardId) { $expectedHint += [Environment]::NewLine + 'Standard: Console, Multimedia, Kommunikation' }
                if ($id -eq 'm1') { $expectedHint += [Environment]::NewLine + 'Standard: Console, Multimedia' }
                Assert ($tooltip -ceq $expectedHint) "Tooltip falsch: $tooltip"
            }
        }
        Assert-AudioRows 'j'
        $sender.SelectionButtons[1].PerformClick()
        Assert ($script:AudioUiSelected -eq 'lg') 'Audio-Button schaltet falsche Endpoint-ID.'
        Assert-AudioRows 'lg'
        $bar=$sender.Controls.Find('Messages',$true)[0]
        Set-TaskPloppMessage Warning ('Eine laengere Warnung muss in der ersten Zeile lesbar bleiben. ' * 5) ('Auch die zweite Zeile darf lang sein. ' * 8)
        Assert $bar.IsScrolling 'Laufschrift fuer lange Texte fehlt.'
        Save-Preview $sender 'TaskPlopp-audio.png'
        for($tick=0;$tick -lt 5;$tick++) { Start-Sleep -Milliseconds 35; [Windows.Forms.Application]::DoEvents() }
        $offsets=$bar.Tag.Offsets
        Assert ($offsets[0] -gt 0 -and $offsets[1] -gt 0) 'Laufschrift-Timer bewegt die Zeilen nicht.'
        Set-TaskPloppMessage Success 'Geraet gesetzt' 'Kurzer Text'
        Assert (-not $bar.IsScrolling -and $bar.BackColor.G -gt $bar.BackColor.R) 'Kurze Erfolgsmeldung laeuft oder ist nicht gruen.'
        Set-TaskPloppMessage Error 'Wechsel fehlgeschlagen' 'Bitte erneut versuchen.'
        Assert ($bar.BackColor.R -gt $bar.BackColor.G) 'Fehlermeldung nicht rot.'
        $sender.Size=[Drawing.Size]::new(420,350)
        [Windows.Forms.Application]::DoEvents()
        $top=$sender.Controls.Find('TopArea',$true)[0]
        $toolbar=$sender.Controls.Find('Toolbar',$true)[0]
        Assert (@($toolbar.Controls | ForEach-Object Top | Select-Object -Unique).Count -eq 1) 'Kompakte Toolbar bricht bei Minimumgroesse um.'
        Assert ($bar.Top -ge $toolbar.Bottom -and $content.Top -ge $top.Bottom) 'Toolbar/Meldungen ueberdecken den Inhalt.'
        $grid=$content.Controls[0]
        foreach($column in $grid.Controls) {
            foreach($button in $column.Controls | Where-Object {$_ -is [Windows.Forms.Button]}) {
                Assert ($button.Width -le $grid.Width/2) 'Task-Resize zerstoert Audiospalten.'
                Assert ($button.Text -match '^\[[0-9A-Z]\]') 'Tastaturpraefix nach Aufbau verloren.'
            }
        }
        Save-Preview $sender 'TaskPlopp-audio-small.png'
        $sender.Size=[Drawing.Size]::new(650,700)
        $sender.Font=[Drawing.Font]::new('Segoe UI',15)
        Save-Preview $sender 'TaskPlopp-audio-large-font.png'
        $sender.Font=[Drawing.Font]::new('Segoe UI',10)
        $sender.Size=[Drawing.Size]::new(580,650)
        if([Windows.Forms.Form]::ActiveForm -eq $sender) {
            Assert ($sender.TrySelectKey([Windows.Forms.Keys]::Escape)) 'Escape nicht verarbeitet.'
        } else {
            [Console]::WriteLine('SKIP: physische Escape-Pruefung; kein aktives Desktopfenster. Rueckkehr ueber Button wird geprueft.')
            $toggle.PerformClick()
        }
        Assert (-not $sender.AudioView) 'Escape kehrt nicht zu Tasks zurueck.'
        Assert (@($content.Controls | Where-Object {$_ -is [Windows.Forms.Button]})[0].Text -eq $firstTask) 'Favoritenreihenfolge/Taste veraendert.'
        $toggle.PerformClick()
        function Get-TaskPloppOpenAIKeyPath {Join-Path $env:TEMP ('TaskPlopp-unconfigured-key-test-'+$PID+'.dpapi')}
            Show-TaskPloppConfiguration -OnShown { param($dialog,$args) $dialog.Controls.Find('CloseSettings',$true)[0].PerformClick() }
        Assert $sender.AudioView 'Konfigurationsrueckkehr hat Audio verlassen.'
        Show-TaskPlopp
        [Windows.Forms.Application]::DoEvents() # Finish the asynchronous restore before testing Hide.
        Assert (-not $sender.AudioView) 'Hotkey-/Tray-Rueckkehr oeffnet nicht Tasks.'
        Assert (@($content.Controls | Where-Object {$_ -is [Windows.Forms.Button]})[0].Text -eq $firstTask) 'Hotkey-Rueckkehr hat Favoritentaste veraendert.'
        Set-TaskPloppMessage Notice ('Langer Hinweis ' * 30) ('Langes Detail ' * 30)
        Assert $bar.IsScrolling 'Laufschrift vor Ausblenden nicht aktiv.'
        $sender.Hide(); [Windows.Forms.Application]::DoEvents()
        Assert (-not $bar.IsScrolling) 'Versteckte GUI laesst Laufschrift weiterlaufen.'
        $sender.Show()
        [Console]::WriteLine("OK: Audio/Tasks, zwei Spalten, Zurueck, Konfigurations-/Hotkey-Rueckkehr, Farben/Laufschrift, Minimumgroesse und grosse Schrift. Audioaufbau: $($watch.ElapsedMilliseconds) ms. Escape nur bei aktivem Desktop pruefbar.")
    } catch { $global:TaskPloppUiFailure=$_; [Console]::WriteLine($_.ToString()) }
    finally { $sender.Close() }
}
[IO.File]::Delete($testConfig)
if($global:TaskPloppUiFailure) { throw $global:TaskPloppUiFailure }
