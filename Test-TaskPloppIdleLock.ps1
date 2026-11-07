#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Condition,[string]$Message) { if(-not $Condition) { throw $Message } }
function Sample([int]$X=10,[bool]$Key=$false,[uint32]$Tick=1,[bool]$Available=$true) {
    [pscustomobject]@{Available=$Available;X=$X;Y=20;KeyDown=$Key;InputTick=$Tick}
}
$state=New-TaskPloppIdleState $true 30
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample) 0)) 'Erste Probe startet Frist nicht neu.'
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample) 1799)) 'Sperre zu frueh.'
Assert (Test-TaskPloppIdleTimeout $state (Sample) 1800) 'Nach 30 Minuten fehlt Sperrentscheidung.'
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample) 1801)) 'Sperre sofort wiederholt.'
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample -X 11) 3599)) 'Mausbewegung ignoriert.'
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample -X 11 -Key $true) 4000)) 'Gedrueckte Taste ignoriert.'
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample -X 11 -Tick 2) 5000)) 'Kurze Eingabe zwischen Abfragen ignoriert.'
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample -Available $false) 9000)) 'Nicht verfuegbarer Desktop darf nicht erneut gesperrt werden.'
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample) 10000)) 'Entsperren/erste verfuegbare Probe muss neu beginnen.'
$state.Enabled=$false
Assert (-not (Test-TaskPloppIdleTimeout $state (Sample) 999999)) 'Deaktivierte Sperre hat ausgeloest.'
Write-Output 'OK: 30 Minuten, Maus, gehaltene/kurze Taste, fehlender Desktop, Wiederholung und deaktivierte Sperre; keine echte Sperre ausgeloest.'

$testDir=Join-Path $env:TEMP ('TaskPlopp-idle-test-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDir)
$global:TaskPloppIdleTestConfig=Join-Path $testDir 'config.json'
$global:TaskPloppIdleTestFailure=$null
try {
    $legacy=[pscustomobject]@{ShowOpenWindows=$false;Programs=@([pscustomobject]@{Name='Test';ProcessName='not-running';TitleContains=''})}
    Save-Settings $legacy -Path $global:TaskPloppIdleTestConfig
    $settings=Get-Settings -Path $global:TaskPloppIdleTestConfig
    Assert ($settings.AutoLockEnabled -and $settings.AutoLockMinutes -eq 30) 'Alte Konfiguration nicht auf 30 Minuten migriert.'
    foreach($bad in @(0,481,1.5,'30')) {
        $settings.AutoLockMinutes=$bad
        $rejected=$false
        try { Save-Settings $settings -Path $global:TaskPloppIdleTestConfig } catch { $rejected=$true }
        Assert $rejected 'Ungueltige Minuten akzeptiert.'
    }
    Assert ((Get-Settings -Path $global:TaskPloppIdleTestConfig).AutoLockMinutes -eq 30) 'Fehlgeschlagenes Speichern hat Minuten veraendert.'
    $script:Settings=Get-Settings -Path $global:TaskPloppIdleTestConfig
    $script:IdleState=New-TaskPloppIdleState $true 30
    $script:Main=New-Object Windows.Forms.Form
    $script:LockButton=New-Object Windows.Forms.Button
    $script:ToolbarToolTip=New-Object Windows.Forms.ToolTip
    function Set-TaskPloppMessage($Kind,$Summary,$Detail) { }
    $script:IdleState.LastActivity=123
    Apply-TaskPloppIdleSettings
    Assert ($script:IdleState.LastActivity -eq 123) 'Unveraenderte Einstellungen starten Frist neu.'
    $script:Settings.AutoLockMinutes=17
    Apply-TaskPloppIdleSettings
    Assert ($script:IdleState.Minutes -eq 17 -and $script:IdleState.LastActivity -ne 123) 'Neue Minuten setzen Frist nicht zurueck.'
    $script:Settings.AutoLockEnabled=$false
    Apply-TaskPloppIdleSettings
    Assert (-not $script:IdleState.Enabled) 'Ausschalten nicht angewendet.'
    $script:Settings.AutoLockEnabled=$true
    Apply-TaskPloppIdleSettings
    Assert ($script:IdleState.Enabled -and $script:IdleState.LastSample -eq $null) 'Aktivieren nicht mit neuer Frist gestartet.'
    $script:Main.Dispose(); $script:LockButton.Dispose(); $script:ToolbarToolTip.Dispose()
    # New UI scope; test file is isolated and SmokeTest never starts a real lock timer.
    & (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -SmokeTest -ConfigFile $global:TaskPloppIdleTestConfig -OnShown {
        param($sender,$args)
        try {
            $toggle=$sender.Controls.Find('AutoLockToggle',$true)[0]
            Assert ($toggle.AccessibleName -like '*aktiv:*30*') 'Initialer Sperrstatus fehlt.'
            $toggle.PerformClick()
            $disk=Get-Settings -Path $global:TaskPloppIdleTestConfig
            Assert (-not $disk.AutoLockEnabled) 'Toolbar-Aus nicht gespeichert.'
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $enabled=$dialog.Controls.Find('AutoLockEnabled',$true)[0]
                $minutes=$dialog.Controls.Find('AutoLockMinutes',$true)[0]
                $tab=$dialog.Controls.Find('AutoLockTab',$true)[0]
                $tab.Parent.SelectedTab=$tab
                $enabled.Checked=$true; $minutes.Value=17
                $bitmap=[Drawing.Bitmap]::new($dialog.Width,$dialog.Height)
                try { $dialog.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$dialog.Width,$dialog.Height)); $bitmap.Save((Join-Path $env:TEMP 'TaskPlopp-idle-config.png')) }
                finally { $bitmap.Dispose() }
                $dialog.Controls.Find('SaveSettings',$true)[0].PerformClick()
            }
            $disk=Get-Settings -Path $global:TaskPloppIdleTestConfig
            Assert ($disk.AutoLockEnabled -and $disk.AutoLockMinutes -eq 17) 'Konfiguration nicht gespeichert.'
            Assert ($toggle.AccessibleName -like '*aktiv:*17*') 'Toolbar nicht mit Konfiguration synchron.'
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $dialog.Controls.Find('AutoLockEnabled',$true)[0].Checked=$false
                $dialog.Controls.Find('AutoLockMinutes',$true)[0].Value=5
                $dialog.Controls.Find('CancelSettings',$true)[0].PerformClick()
            }
            $disk=Get-Settings -Path $global:TaskPloppIdleTestConfig
            Assert ($disk.AutoLockEnabled -and $disk.AutoLockMinutes -eq 17) 'Abbrechen hat Sperreinstellung veraendert.'
            $sender.Size=[Drawing.Size]::new(420,350)
            [Windows.Forms.Application]::DoEvents()
            $toolbar=$sender.Controls.Find('Toolbar',$true)[0]
            Assert (@($toolbar.Controls | ForEach-Object Top | Select-Object -Unique).Count -eq 1) 'Neues Schloss erzeugt Toolbar-Umbruch.'
            $monitor=Get-Variable -Name idleTimer -ValueOnly -ErrorAction Stop
            $global:TaskPloppIdleTimerForTest=$monitor
            $monitor.Start()
            $sender.Hide(); [Windows.Forms.Application]::DoEvents()
            Assert $monitor.Enabled 'Ausblenden beendet die Ueberwachung.'
            $sender.Show()
            [Console]::WriteLine('OK: Toolbar Ein/Aus, Minuten speichern, Abbrechen, gemeinsame Anzeige und kompakte Toolbar.')
        } catch { $global:TaskPloppIdleTestFailure=$_; [Console]::WriteLine($_.ToString()); $sender.Close() }
    }
    if($global:TaskPloppIdleTestFailure) { throw $global:TaskPloppIdleTestFailure }
    Assert (-not $global:TaskPloppIdleTimerForTest.Enabled) 'Vollstaendiges Beenden laesst Ueberwachung weiterlaufen.'
    Write-Output 'OK: Ueberwachung bleibt beim Ausblenden aktiv und endet mit dem Hauptfenster.'
} finally {
    foreach($file in Get-ChildItem -LiteralPath $testDir -File) { Remove-Item -LiteralPath $file.FullName }
    Remove-Item -LiteralPath $testDir
}
