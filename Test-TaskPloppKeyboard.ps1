#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'TaskPlopp.Keyboard.ps1')
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
$form = New-Object TaskPlopp.KeyboardForm
$form.Text = 'TaskPlopp Tastaturtest'
$form.TopMost = $true
$buttons = @(); $script:ClickedIndex = -1
try {
    for ($index = 0; $index -lt 37; $index++) {
        $button = New-Object Windows.Forms.Button
        $button.Text = "Fenster $index"; $button.Tag = $index
        $button.Add_Click({ param($sender,$eventArgs) $script:ClickedIndex = [int]$sender.Tag })
        $form.Controls.Add($button); $form.RegisterSelectionButton($button)
        $buttons += $button
    }
    $form.Show(); $form.Activate(); [Windows.Forms.Application]::DoEvents()
    Assert ($buttons[0].Text -like '[[]1[]]*') 'Erster Button ohne 1.'
    Assert ($buttons[9].Text -like '[[]0[]]*') 'Zehnter Button ohne 0.'
    Assert ($buttons[10].Text -like '[[]A[]]*') 'Elfter Button ohne A.'
    Assert ($buttons[35].Text -like '[[]Z[]]*') 'Sechsunddreissigster Button ohne Z.'
    Assert ($buttons[36].Text -eq 'Fenster 36') 'Mehr als 36 Direktwahlen vergeben.'
    foreach ($keyCase in @(@('D1',0),@('D9',8),@('D0',9),@('NumPad1',0),@('NumPad0',9),@('A',10),@('Z',35))) {
        $script:ClickedIndex=-1
        Assert ($form.TrySelectKey([Windows.Forms.Keys]$keyCase[0])) "Taste $($keyCase[0]) nicht verarbeitet."
        Assert ($script:ClickedIndex -eq $keyCase[1]) "Falscher Button fuer $($keyCase[0])."
    }
    Assert ($form.TrySelectKey([Windows.Forms.Keys]::A -bor [Windows.Forms.Keys]::Shift)) 'Umschalt+A nicht unterstuetzt.'
    $script:ClickedIndex=-1
    Assert (-not $form.TrySelectKey([Windows.Forms.Keys]::D1 -bor [Windows.Forms.Keys]::Control)) 'Strg-Kombination abgefangen.'
    Assert (-not $form.TrySelectKey([Windows.Forms.Keys]::A -bor [Windows.Forms.Keys]::Alt)) 'Alt-Kombination abgefangen.'
    Assert ($script:ClickedIndex -eq -1) 'Modifizierte Taste hat Button ausgeloest.'
    $buttons[0].Enabled=$false
    Assert (-not $form.TrySelectKey([Windows.Forms.Keys]::D1)) 'Deaktivierten Button ausgefuehrt.'
    $buttons[0].Enabled=$true
    $dialog = New-Object Windows.Forms.Form
    try {
        $dialog.Show($form); $dialog.Activate(); [Windows.Forms.Application]::DoEvents()
        Assert (-not $form.TrySelectKey([Windows.Forms.Keys]::D1)) 'Auswahl bei aktivem anderem Dialog ausgefuehrt.'
    } finally { $dialog.Dispose() }
    $form.Activate(); [Windows.Forms.Application]::DoEvents()
    $form.ClearSelectionButtons()
    Assert (-not $form.TrySelectKey([Windows.Forms.Keys]::D1)) 'Veraltete Tastenzuordnung nach Aktualisierung aktiv.'
    $replacement = New-Object Windows.Forms.Button
    $replacement.Text='Neues Fenster'; $replacement.Tag=99
    $replacement.Add_Click({ param($sender,$eventArgs) $script:ClickedIndex = [int]$sender.Tag })
    $form.Controls.Add($replacement); $form.RegisterSelectionButton($replacement)
    Assert ($form.TrySelectKey([Windows.Forms.Keys]::D1)) 'Neue Tastenzuordnung nicht aktiv.'
    Assert ($script:ClickedIndex -eq 99) 'Neue Taste hat alten Button aktiviert.'
    Assert (-not $form.TrySelectKey([Windows.Forms.Keys]::A)) 'Nicht mehr vorhandenen Button ausgefuehrt.'
    $form.Hide()
    Assert (-not $form.TrySelectKey([Windows.Forms.Keys]::D1)) 'Tastenauswahl bei ausgeblendeter GUI aktiv.'
    Write-Output 'OK: 1-9, 0, A-Z, Ziffernblock, Shift, 36er-Grenze, Modifier-/Dialogschutz und Aktualisierung.'
} finally { $form.Dispose() }
