#requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
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
        $fixture.WindowState = 'Minimized'
        [Windows.Forms.Application]::DoEvents()
        if (-not [TaskPlopp.Native]::Activate($fixture.Handle)) { throw 'Testfenster wurde nicht aktiviert.' }
        [Windows.Forms.Application]::DoEvents()
        if ($fixture.WindowState -eq 'Minimized') { throw 'Testfenster wurde nicht wiederhergestellt.' }
        if ([TaskPlopp.Native]::Activate([IntPtr]::Zero)) { throw 'Ungueltiges Fenster wurde akzeptiert.' }
        Write-Output 'OK: Minimiertes Testfenster wiederhergestellt und aktiviert; ungueltiges Fenster abgelehnt.'
        $cover = New-Object Windows.Forms.Form
        $cover.Text = 'TaskPlopp Test - ueberdeckendes Fenster'
        $cover.TopMost = $true
        try {
            $cover.Show()
            [Windows.Forms.Application]::DoEvents()
            $fixture.WindowState = 'Minimized'
            if (-not [TaskPlopp.Native]::ActivateWithCoverWindows($fixture.Handle, [IntPtr[]]@($cover.Handle))) {
                throw 'Fensterwechsel mit ueberdeckendem Fenster fehlgeschlagen.'
            }
            [Windows.Forms.Application]::DoEvents()
            if ($cover.WindowState -ne 'Minimized' -or $fixture.WindowState -eq 'Minimized') {
                throw 'Ueberdeckendes Fenster nicht minimiert oder Ziel nicht wiederhergestellt.'
            }
            if (-not [TaskPlopp.Native]::ActivateWithCoverWindows($fixture.Handle, [IntPtr[]]@($fixture.Handle))) {
                throw 'Ziel darf nicht selbst minimiert werden.'
            }
            Write-Output 'OK: Ueberdeckendes Topmost-Fenster minimiert, Ziel wiederhergestellt und aktiviert; Ziel selbst ausgeschlossen.'
        } finally { $cover.Dispose() }
    } finally { $fixture.Dispose() }
} finally {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
}
