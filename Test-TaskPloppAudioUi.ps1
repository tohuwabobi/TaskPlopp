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
& (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -SmokeTest -OnShown {
    param($sender,$eventArgs)
    $smokeTimer.Stop()
    try {
        $content=$sender.Controls.Find('TaskContent',$true)[0]
        $firstTask=@($content.Controls | Where-Object {$_ -is [Windows.Forms.Button]})[0].Text
        $toggle=$sender.Controls.Find('AudioToggle',$true)[0]
        $watch=[Diagnostics.Stopwatch]::StartNew()
        $toggle.PerformClick(); $watch.Stop()
        Assert $sender.AudioView 'Audioansicht nicht aktiviert.'
        Assert ($content.Controls.Count -eq 1 -and $content.Controls[0].Name -eq 'AudioColumns') 'Tasks wurden nicht ersetzt.'
        Assert ($content.Controls[0].Controls.Count -eq 2) 'Zwei Audiospalten fehlen.'
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
        Show-TaskPloppConfiguration -OnShown { param($dialog,$args) $dialog.Controls.Find('CancelSettings',$true)[0].PerformClick() }
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
if($global:TaskPloppUiFailure) { throw $global:TaskPloppUiFailure }
