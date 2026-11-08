#requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -LibraryOnly
$path = Join-Path $env:TEMP ('TaskPlopp-test-' + [guid]::NewGuid().ToString('N') + '.json')
try {
    $settings = [pscustomobject]@{
        ShowOpenWindows = $false
        Programs = @([pscustomobject]@{ Name = 'Test'; ProcessName = 'notepad'; TitleContains = 'Beispiel' })
    }
    Save-Settings $settings -Path $path
    $loaded = Get-Settings -Path $path
    if ($loaded.ShowOpenWindows -ne $false -or @($loaded.Programs).Count -ne 1 -or
        $loaded.Programs[0].TitleContains -ne 'Beispiel') { throw 'Konfigurations-Roundtrip fehlgeschlagen.' }
    $settings.Programs = @()
    Save-Settings $settings -Path $path
    if (@((Get-Settings -Path $path).Programs).Count -ne 0) { throw 'Leere Favoritenliste fehlgeschlagen.' }
    $settings.Programs = @([pscustomobject]@{ Name = ''; ProcessName = 'test'; TitleContains = '' })
    $rejected = $false
    try { Save-Settings $settings -Path $path } catch { $rejected = $true }
    if (-not $rejected) { throw 'Ungueltiger Favorit wurde akzeptiert.' }
    if (@((Get-Settings -Path $path).Programs).Count -ne 0) { throw 'Ungueltiger Schreibversuch hat die Konfiguration veraendert.' }
    $windows = @(Get-AppWindows)
    Write-Output "OK: Konfiguration speichern/ersetzen, leere Liste, Validierung, Schutz vorhandener Daten; $($windows.Count) lokale Fenster erkannt."
    $fixture = New-Object Windows.Forms.Form
    $fixture.Text = 'TaskPlopp Testfenster'
    try {
        $fixture.Show()
        [Windows.Forms.Application]::DoEvents()
        $hasDesktop=[Windows.Forms.Form]::ActiveForm-eq$fixture
        $fixture.WindowState = 'Minimized'
        [Windows.Forms.Application]::DoEvents()
        $activated=Activate-TaskPloppWindow $fixture.Handle
        if($hasDesktop-and-not$activated){throw 'Testfenster wurde nicht aktiviert.'}
        if(-not$hasDesktop){Write-Output 'SKIP: echter Vordergrundwechsel; kein aktiver Desktop. Wiederherstellen/Minimieren werden separat geprueft.'}
        [Windows.Forms.Application]::DoEvents()
        if ($fixture.WindowState -eq 'Minimized') { throw 'Testfenster wurde nicht wiederhergestellt.' }
        if ((Activate-TaskPloppWindow ([IntPtr]::Zero))) { throw 'Ungueltiges Fenster wurde akzeptiert.' }
        Write-Output 'OK: Minimiertes Testfenster wiederhergestellt; ungueltiges Fenster abgelehnt.'
        $cover = New-Object Windows.Forms.Form
        $cover.Text = 'TaskPlopp Test - ueberdeckendes Fenster'
        $cover.TopMost = $true
        try {
            $cover.Show()
            [Windows.Forms.Application]::DoEvents()
            $hasDesktop=[Windows.Forms.Form]::ActiveForm-eq$fixture
        $fixture.WindowState = 'Minimized'
            $activated=Activate-TaskPloppCoveredWindow $fixture.Handle ([IntPtr[]]@($cover.Handle))
            if ($hasDesktop -and -not $activated) {
                throw 'Fensterwechsel mit ueberdeckendem Fenster fehlgeschlagen.'
            }
            [Windows.Forms.Application]::DoEvents()
            if ($cover.WindowState -ne 'Minimized' -or $fixture.WindowState -eq 'Minimized') {
                throw 'Ueberdeckendes Fenster nicht minimiert oder Ziel nicht wiederhergestellt.'
            }
            $activated=Activate-TaskPloppCoveredWindow $fixture.Handle ([IntPtr[]]@($fixture.Handle))
            if ($hasDesktop -and -not $activated) {
                throw 'Ziel darf nicht selbst minimiert werden.'
            }
            Write-Output 'OK: Ueberdeckendes Topmost-Fenster minimiert, Ziel wiederhergestellt; Ziel selbst ausgeschlossen.'
        } finally { $cover.Dispose() }
    } finally { $fixture.Dispose() }
} finally {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
}
