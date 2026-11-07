#requires -Version 5.1
[CmdletBinding()]
param([switch]$StoreLaunch)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$testDir = Join-Path $env:TEMP ('TaskPlopp-apps-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDir)
$script:ConfigPath = Join-Path $testDir 'config.json'
try {
    $legacy = [pscustomobject]@{ ShowOpenWindows = $true; Programs = @(
        [pscustomobject]@{ Name = 'Explorer'; ProcessName = 'explorer'; TitleContains = '' }) }
    Save-Settings $legacy
    $script:Settings = Get-Settings
    Assert ($script:Settings.Programs[0].Name -eq 'Explorer') 'Alter Favorit verloren.'
    Assert ($script:Settings.Programs[0].StartKind -eq '') 'Migration muss fehlendes Startziel akzeptieren.'
    $explorer = Resolve-FavoriteStart $script:Settings.Programs[0]
    Assert ($explorer.Kind -eq 'Path' -and (Test-Path -LiteralPath $explorer.Target)) 'Explorer-Startziel nicht erkannt.'
    $windowA = [pscustomobject]@{ ProcessName = 'ChatGPT'; ExecutablePath = 'C:\A\ChatGPT.exe'; AppId = 'Demo.Codex_xyz!App'; Title = 'Erste Rechnung' }
    $windowB = [pscustomobject]@{ ProcessName = 'ChatGPT'; ExecutablePath = 'C:\B\ChatGPT.exe'; AppId = 'Demo.Chat_xyz!App'; Title = 'Zweite Rechnung' }
    $favorite = [pscustomobject]@{ Name='Codex'; ProcessName='ChatGPT'; ExecutablePath=''; AppId=$windowA.AppId; TitleContains=''; StartKind='AppId'; StartTarget=$windowA.AppId }
    Assert (Test-WindowMatch $windowA $favorite) 'App-ID-Match fehlt.'
    Assert (-not (Test-WindowMatch $windowB $favorite)) 'Verschiedene Apps mit gleichem Prozessnamen vermischt.'
    $favorite.TitleContains = 'rechnung'
    Assert (Test-WindowMatch $windowA $favorite) 'Titelfilter muss Gross-/Kleinschreibung ignorieren.'
    $favorite.TitleContains = 'fehlend'
    Assert (-not (Test-WindowMatch $windowA $favorite)) 'Titelfilter ignoriert.'
    $favorite.TitleContains = ''
    $script:Settings.Programs = @($favorite)
    $script:Settings.HiddenWindows = @([pscustomobject]@{ Name='Chat'; ProcessName='ChatGPT'; ExecutablePath=''; AppId=$windowB.AppId; TitleContains='' })
    Assert (@(Get-OtherWindows @($windowA,$windowB) $script:Settings).Count -eq 0) 'Favorit-Duplikat oder ausgeblendetes Fenster sichtbar.'
    Save-Settings $script:Settings
    Assert (@((Get-Settings).HiddenWindows).Count -eq 1) 'Ausblendung nicht gespeichert.'
    $script:Settings.HiddenWindows = @()
    Assert (@(Get-OtherWindows @($windowA,$windowB) $script:Settings).Count -eq 1) 'Wiedereinblenden fehlgeschlagen.'
    Write-Output 'OK: Altkonfiguration, Explorer-Startziel, App-Identitaeten, Titelfilter, Duplikate, Ausblenden/Wiederanzeigen.'
    $orderedSettings = ConvertTo-TaskPloppSettings ([pscustomobject]@{ ShowOpenWindows=$true; Programs=@(
        $favorite, [pscustomobject]@{ Name='Dateien'; ProcessName='explorer'; TitleContains=''; FolderPath='C:\Downloads' }) })
    $folderWindow = [pscustomobject]@{ ProcessName='explorer'; Title='Downloads'; FolderPath='C:\Downloads'; ExecutablePath=''; AppId='' }
    $otherFolder = [pscustomobject]@{ ProcessName='explorer'; Title='Desktop'; FolderPath='C:\Desktop'; ExecutablePath=''; AppId='' }
    Assert (Test-WindowMatch $folderWindow $orderedSettings.Programs[1]) 'Downloads-Fenster nicht erkannt.'
    Assert (-not (Test-WindowMatch $otherFolder $orderedSettings.Programs[1])) 'Anderer Explorer-Ordner faelschlich aktiviert.'
    $specs = @(Get-FavoriteButtonSpecs @($windowA,$windowA,$folderWindow) $orderedSettings)
    Assert ($specs.Count -eq 2 -and $specs[0].Favorite.Name -eq 'Codex' -and $specs[1].Favorite.Name -eq 'Dateien') 'Mehrere Fenster verschieben Favoritentasten.'
    $orderedSettings.Programs[0].LaunchAlways=$true
    $specs = @(Get-FavoriteButtonSpecs @($windowA) $orderedSettings)
    Assert (@($specs[0].Windows).Count -eq 0 -and $specs[0].Text -like '*Startziel*') 'Profilfavorit darf kein beliebiges offenes Fenster verwenden.'
    Write-Output 'OK: Ein Tastaturplatz pro Favorit, ordnerspezifische Explorer-Zuordnung und Profil-Startmodus.'

    $normal = New-Object Windows.Forms.Form
    $tool = New-Object Windows.Forms.Form
    try {
        $normal.Text='TaskPlopp Filtertest'; $normal.Show()
        $tool.Text='TaskPlopp Hilfsfenster'; $tool.FormBorderStyle='FixedToolWindow'; $tool.ShowInTaskbar=$false; $tool.Show()
        [Windows.Forms.Application]::DoEvents()
        Assert ([TaskPlopp.Native]::IsSwitchable($normal.Handle)) 'Normales Fenster ausgefiltert.'
        Assert (-not [TaskPlopp.Native]::IsSwitchable($tool.Handle)) 'Hilfsfenster nicht ausgefiltert.'
        $normal.WindowState='Minimized'; [Windows.Forms.Application]::DoEvents()
        Assert ([TaskPlopp.Native]::IsSwitchable($normal.Handle)) 'Minimiertes Fenster muss erhalten bleiben.'
        $normal.Hide()
        Assert (-not [TaskPlopp.Native]::IsSwitchable($normal.Handle)) 'Unsichtbares Fenster nicht ausgefiltert.'
    } finally { $normal.Dispose(); $tool.Dispose() }
    Write-Output 'OK: Normales/minimiertes Fenster erhalten, verstecktes Fenster und Toolfenster ausgeschlossen.'

    # A self-closing executable verifies real EXE and LNK activation without touching user applications.
    $exe = Join-Path $testDir 'TaskPloppFixture.exe'
    $marker = Join-Path $testDir 'started.txt'
    $env:TASKPLOPP_TEST_MARKER = $marker
    Add-Type -OutputAssembly $exe -OutputType WindowsApplication -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.IO;
using System.Windows.Forms;
public static class TaskPloppLaunchFixture {
    [STAThread] public static void Main() {
        File.WriteAllText(Environment.GetEnvironmentVariable("TASKPLOPP_TEST_MARKER"), "started");
        var form = new Form { Text="TaskPlopp Starttest" };
        var timer = new Timer { Interval=700 };
        timer.Tick += delegate { timer.Stop(); form.Close(); };
        timer.Start(); Application.Run(form); timer.Dispose(); form.Dispose();
    }
}
'@
    $launch = [pscustomobject]@{ Name='Test'; ProcessName='TaskPloppFixture'; ExecutablePath=$exe; AppId=''; TitleContains=''; StartKind='Path'; StartTarget=$exe }
    Start-FavoriteApplication $launch
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while (-not (Test-Path -LiteralPath $marker) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    Assert (Test-Path -LiteralPath $marker) 'EXE wurde nicht gestartet.'
    Remove-Item -LiteralPath $marker
    $shell = New-Object -ComObject WScript.Shell
    $linkPath = Join-Path $testDir 'Fixture.lnk'
    try { $link = $shell.CreateShortcut($linkPath); $link.TargetPath=$exe; $link.Save() }
    finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($link); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
    $launch.StartTarget = $linkPath
    Start-FavoriteApplication $launch
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while (-not (Test-Path -LiteralPath $marker) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    Assert (Test-Path -LiteralPath $marker) 'LNK wurde nicht gestartet.'
    $launch.StartTarget = Join-Path $testDir 'missing.exe'
    $rejected = $false
    try { Start-FavoriteApplication $launch -Preview } catch { $rejected = $true }
    Assert $rejected 'Fehlende Startdatei nicht abgewiesen.'
    Write-Output 'OK: EXE und LNK real gestartet; fehlendes Startziel abgewiesen.'

    # Test editing through the actual modal dialog, with isolated settings.
    $script:Main = New-Object Windows.Forms.Form
    $script:Main.Font = [Drawing.Font]::new('Segoe UI',10)
    function Show-TaskPloppView { }
    $script:Settings.Programs = @($favorite, [pscustomobject]@{ Name='Explorer'; ProcessName='explorer'; TitleContains=''; ExecutablePath=''; AppId=''; StartKind='Path'; StartTarget=$explorer.Target })
    $script:UiFailure = $null
    Show-TaskPloppConfiguration -OnShown {
        param($sender,$eventArgs)
        try {
            $list = $sender.Controls.Find('FavoriteList',$true)[0]
            $name = $sender.Controls.Find('FavoriteName',$true)[0]
            $list.SelectedIndex=1; $name.Text='Dateien'; $list.SelectedIndex=0
            $bitmap = [Drawing.Bitmap]::new($sender.Width,$sender.Height)
            try { $sender.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$sender.Width,$sender.Height)); $bitmap.Save((Join-Path $env:TEMP 'TaskPlopp-configuration.png')) }
            finally { $bitmap.Dispose() }
            $sender.Controls.Find('SaveSettings',$true)[0].PerformClick()
        } catch { $script:UiFailure=$_; $sender.Close() }
    }
    if ($script:UiFailure) { throw $script:UiFailure }
    $saved = Get-Settings
    Assert ($saved.Programs[1].Name -eq 'Dateien') 'Bearbeitung im Dialog nicht gespeichert.'
    Assert ($saved.Programs[0].AppId -eq $favorite.AppId -and $saved.Programs[0].StartKind -eq 'AppId') 'App-Identitaet beim Wechsel der Auswahl verloren.'
    Show-TaskPloppConfiguration -OnShown {
        param($sender,$eventArgs)
        $sender.Controls.Find('FavoriteName',$true)[0].Text='Nicht speichern'
        $sender.Controls.Find('CancelSettings',$true)[0].PerformClick()
    }
    Assert ($script:Settings.Programs[0].Name -eq 'Codex') 'Abbrechen hat Einstellungen veraendert.'
    Write-Output 'OK: Konfigurationsdialog bearbeiten/speichern/abbrechen; App-Identitaet erhalten.'
    Show-TaskPloppConfiguration -OnShown {
        param($sender,$eventArgs)
        try {
            $list=$sender.Controls.Find('FavoriteList',$true)[0]
            $up=$sender.Controls.Find('MoveFavoriteUp',$true)[0]
            $down=$sender.Controls.Find('MoveFavoriteDown',$true)[0]
            Assert (-not $up.Enabled -and $down.Enabled) 'Grenzschaltflaechen am Listenanfang falsch.'
            $down.PerformClick()
            Assert ($list.SelectedIndex -eq 1 -and $up.Enabled -and -not $down.Enabled) 'Verschieben nach unten fehlgeschlagen.'
            $up.PerformClick(); $down.PerformClick()
            $bitmap=[Drawing.Bitmap]::new($sender.Width,$sender.Height)
            try { $sender.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$sender.Width,$sender.Height)); $bitmap.Save((Join-Path $env:TEMP 'TaskPlopp-configuration.png')) }
            finally { $bitmap.Dispose() }
            $sender.Controls.Find('SaveSettings',$true)[0].PerformClick()
        } catch { $script:UiFailure=$_; $sender.Close() }
    }
    if ($script:UiFailure) { throw $script:UiFailure }
    $saved=Get-Settings
    Assert ($saved.Programs[0].Name -eq 'Dateien' -and $saved.Programs[1].AppId -eq $favorite.AppId) 'Reihenfolge oder App-ID beim Sortieren verloren.'
    Show-TaskPloppConfiguration -OnShown {
        param($sender,$eventArgs)
        $sender.Controls.Find('FavoriteList',$true)[0].SelectedIndex=0
        $sender.Controls.Find('MoveFavoriteDown',$true)[0].PerformClick()
        $sender.Controls.Find('CancelSettings',$true)[0].PerformClick()
    }
    Assert ($script:Settings.Programs[0].Name -eq 'Dateien') 'Abbrechen hat Sortierung uebernommen.'
    Write-Output 'OK: Favoriten hoch/runter, Grenzen, Speichern/Neuladen und Abbrechen.'

    $apps = @(Get-InstalledAppChoices | Where-Object AppId -match '!')
    Assert ($apps.Count -gt 0) 'Keine installierten Paket-Apps gefunden.'
    $shell = New-Object -ComObject Shell.Application
    $folder = $null; $item = $null
    try {
        $folder = $shell.NameSpace('shell:AppsFolder')
        $app = $apps | Where-Object { $_.AppId -like 'Microsoft.WindowsCalculator_*!*' } | Select-Object -First 1
        if ($app) {
            $item = $folder.ParseName($app.AppId)
            Assert ($null -ne $item) 'Store-App nicht im Shell-Appkatalog gefunden.'
            if ($StoreLaunch) {
                $before = @(Get-Process | ForEach-Object Id)
                $alreadyOpen = @(Get-AppWindows | Where-Object AppId -eq $app.AppId)
                if ($alreadyOpen.Count -eq 0) {
                    $storeFavorite = [pscustomobject]@{ Name=$app.Name; ProcessName='CalculatorApp'; ExecutablePath=''; AppId=$app.AppId; TitleContains=''; StartKind='AppId'; StartTarget=$app.AppId }
                    Start-FavoriteApplication $storeFavorite
                    $opened = @(); $deadline=[DateTime]::UtcNow.AddSeconds(10)
                    while ($opened.Count -eq 0 -and [DateTime]::UtcNow -lt $deadline) {
                        Start-Sleep -Milliseconds 100
                        $opened = @(Get-AppWindows | Where-Object AppId -eq $app.AppId)
                    }
                    Assert ($opened.Count -gt 0) 'Store-App wurde nicht aktiviert.'
                    foreach ($window in $opened) {
                        if ($window.ProcessId -notin $before) { [void](Get-Process -Id $window.ProcessId).CloseMainWindow() }
                    }
                    Write-Output 'OK: Rechner als Store-App real gestartet und per App-ID wiedererkannt.'
                } else { Write-Output 'Store-Start uebersprungen: Rechner war bereits geoeffnet.' }
            }
        }
        Write-Output "OK: $($apps.Count) installierte Paket-Apps im Startkatalog erkannt."
    } finally {
        if ($null -ne $item) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($item) }
        if ($null -ne $folder) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($folder) }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
} finally {
    if (Get-Variable Main -Scope Script -ErrorAction SilentlyContinue) { $script:Main.Dispose() }
    Remove-Item Env:\TASKPLOPP_TEST_MARKER -ErrorAction SilentlyContinue
    # Let the two self-closing fixtures release the executable before cleanup.
    Start-Sleep -Milliseconds 900
    $resolved = [IO.Path]::GetFullPath($testDir)
    if ($resolved.StartsWith(([IO.Path]::GetFullPath($env:TEMP) + '\'), [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved) -like 'TaskPlopp-apps-*') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
