function Select-TaskPloppItem([string]$Title, [object[]]$Items, [string]$DisplayProperty) {
    $owner = [Windows.Forms.Form]::ActiveForm
    if ($null -eq $owner) { $owner = $script:Main }
    $picker = New-Object Windows.Forms.Form
    $picker.Icon = $script:Main.Icon
    $picker.Text = $Title; $picker.Size = [Drawing.Size]::new(720, 440)
    $picker.StartPosition = 'CenterParent'; $picker.Font = $script:Main.Font
    $list = New-Object Windows.Forms.ListBox
    $list.Dock = 'Fill'; $list.HorizontalScrollbar = $true; $list.DisplayMember = $DisplayProperty
    foreach ($item in $Items) { [void]$list.Items.Add($item) }
    $actions = New-Object Windows.Forms.FlowLayoutPanel
    $actions.Dock = 'Bottom'; $actions.Height = 42
    $ok = New-Object Windows.Forms.Button
    $ok.Text = 'Auswaehlen'; $ok.AutoSize = $true
    $ok.Add_Click({ if ($list.SelectedIndex -ge 0) { $picker.Tag = $list.SelectedItem; $picker.DialogResult = 'OK' } })
    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = 'Abbrechen'; $cancel.AutoSize = $true; $cancel.DialogResult = 'Cancel'
    $actions.Controls.AddRange(@($ok,$cancel))
    $picker.Controls.Add($list); $picker.Controls.Add($actions)
    $picker.AcceptButton = $ok; $picker.CancelButton = $cancel
    try { if ($picker.ShowDialog($owner) -eq 'OK') { return $picker.Tag } }
    finally { $picker.Dispose() }
}

function Select-TaskPloppFile {
    $owner = [Windows.Forms.Form]::ActiveForm
    if ($null -eq $owner) { $owner = $script:Main }
    $file = New-Object Windows.Forms.OpenFileDialog
    $file.Title = 'Programm oder Startverknuepfung auswaehlen'
    $file.Filter = 'Programme und Verknuepfungen|*.exe;*.lnk'
    $file.DereferenceLinks = $false
    try { if ($file.ShowDialog($owner) -eq 'OK') { return $file.FileName } }
    finally { $file.Dispose() }
    return ''
}

function Get-ShortcutProcessName([string]$Path) {
    if ([IO.Path]::GetExtension($Path) -ieq '.lnk') {
        $shell = New-Object -ComObject WScript.Shell
        $link = $null
        try {
            $link = $shell.CreateShortcut($Path)
            if ($link.TargetPath) { return [IO.Path]::GetFileNameWithoutExtension($link.TargetPath) }
        } finally {
            if ($null -ne $link) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($link) }
            [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
        }
    }
    return [IO.Path]::GetFileNameWithoutExtension($Path)
}

function Show-TaskPloppConfiguration {
    param([scriptblock]$OnShown)
    # Edit a copy; cancellation never changes the live configuration.
    $working = ConvertTo-TaskPloppSettings ($script:Settings | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    $dialog = New-Object Windows.Forms.Form
    $dialog.Icon = $script:Main.Icon
    $dialog.Text = 'TaskPlopp - Konfiguration'; $dialog.Size = [Drawing.Size]::new(900, 600)
    $dialog.MinimumSize = $dialog.Size; $dialog.Font = $script:Main.Font
    $dialog.StartPosition = 'CenterParent'
    $tabs = New-Object Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $favoritesTab = New-Object Windows.Forms.TabPage
    $favoritesTab.Text = 'Favoriten'
    $hiddenTab = New-Object Windows.Forms.TabPage
    $hiddenTab.Text = 'Ausgeblendete Programme'
    $lockTab=New-Object Windows.Forms.TabPage
    $lockTab.Name='AutoLockTab'; $lockTab.Text='PC-Sperre'
    $lockLayout=New-Object Windows.Forms.FlowLayoutPanel
    $lockLayout.Dock='Fill'; $lockLayout.FlowDirection='TopDown'; $lockLayout.WrapContents=$false
    $lockLayout.Padding=[Windows.Forms.Padding]::new(16)
    $lockEnabled=New-Object Windows.Forms.CheckBox
    $lockEnabled.Name='AutoLockEnabled'; $lockEnabled.Text='Automatische PC-Sperre aktivieren'
    $lockEnabled.AutoSize=$true; $lockEnabled.Checked=$working.AutoLockEnabled
    $lockLabel=New-Object Windows.Forms.Label
    $lockLabel.Text='Sperren nach Minuten ohne Maus-/Tastaturaktivitaet:'; $lockLabel.AutoSize=$true
    $lockMinutes=New-Object Windows.Forms.NumericUpDown
    $lockMinutes.Name='AutoLockMinutes'; $lockMinutes.Minimum=1; $lockMinutes.Maximum=480
    $lockMinutes.Value=$working.AutoLockMinutes; $lockMinutes.Width=100
    $lockHelp=New-Object Windows.Forms.Label
    $lockHelp.Size=[Drawing.Size]::new(700,110)
    $lockHelp.Text="Beim Aktivieren oder Aendern der Minuten beginnt die Frist neu.`r`nDas X blendet TaskPlopp aus; die Ueberwachung laeuft weiter.`r`nErst 'TaskPlopp beenden' im Infobereich beendet auch die Ueberwachung.`r`nWindows-eigene Sperrvorgaben bleiben unveraendert. Audio/Diktate pausieren die Sperre nicht."
    $lockLayout.Controls.AddRange(@($lockEnabled,$lockLabel,$lockMinutes,$lockHelp))
    $lockTab.Controls.Add($lockLayout)
    $tabs.TabPages.AddRange(@($favoritesTab,$hiddenTab,$lockTab))
    $dictationTab=New-Object Windows.Forms.TabPage
    $dictationTab.Name='DictationTab';$dictationTab.Text='Diktat'
    $dictationLayout=New-Object Windows.Forms.FlowLayoutPanel
    $dictationLayout.Dock='Fill';$dictationLayout.FlowDirection='TopDown';$dictationLayout.WrapContents=$false
    $dictationLayout.Padding=[Windows.Forms.Padding]::new(16)
    $dictationLabel=New-Object Windows.Forms.Label
    $dictationLabel.Text='Lokale Engine fuer das naechste Diktat (Deutsch):';$dictationLabel.AutoSize=$true
    $dictationChoice=New-Object Windows.Forms.ComboBox
    $dictationChoice.Name='DictationEngine';$dictationChoice.DropDownStyle='DropDownList';$dictationChoice.Width=260
    $dictationChoice.Items.AddRange(@('whisper.cpp (lokal)','Vosk (lokal)'))
    $dictationChoice.SelectedIndex=if($working.DictationEngine -eq 'Vosk'){1}else{0}
    $dictationReady=New-Object Windows.Forms.Label
    $dictationReady.Name='DictationReadiness';$dictationReady.AutoSize=$true
    $dictationInstall=New-Object Windows.Forms.Button
    $dictationInstall.Name='InstallDictation';$dictationInstall.Text='Diktat-Komponenten installieren';$dictationInstall.AutoSize=$true
    $dictationInstall.Add_Click({Start-TaskPloppDictationInstall})
    $dictationInstallStatus=New-Object Windows.Forms.Label
    $dictationInstallStatus.Name='DictationInstallStatus';$dictationInstallStatus.AutoSize=$true
    $dictationInstallStatus.MaximumSize=[Drawing.Size]::new(700,0)
    $dictationHelp=New-Object Windows.Forms.Label
    $dictationHelp.AutoSize=$true
    $dictationHelp.Text="Beide Engines und deutsche Modelle werden benutzerlokal eingerichtet.`r`nDownload etwa 220 MB; normalerweise keine Adminrechte erforderlich.`r`nEinrichtung gilt sofort, unabhaengig von Speichern/Abbrechen.`r`nEngine-Auswahl gilt nach Speichern fuer das naechste Diktat.`r`nMikrofon wird ueber Audio gewaehlt. Keine Cloud, kein Audioarchiv.`r`nErster Mikrofonklick: Aufnahme. Zweiter Klick: Transkription.`r`nRechtsklick auf Mikrofon: Verwerfen oder erneut kopieren."
    $dictationLayout.Controls.AddRange(@($dictationLabel,$dictationChoice,$dictationReady,$dictationInstall,$dictationInstallStatus,$dictationHelp))
    $dictationTab.Controls.Add($dictationLayout);[void]$tabs.TabPages.Add($dictationTab)
    $dictationStatusTimer=New-Object Windows.Forms.Timer
    $dictationStatusTimer.Interval=500
    $updateDictationConfiguration={
        $whisperReady=(Get-TaskPloppDictationPaths 'Whisper').Ready
        $voskReady=(Get-TaskPloppDictationPaths 'Vosk').Ready
        $dictationReady.Text="whisper.cpp: $(if($whisperReady){'Bereit'}else{'Nicht eingerichtet'})`r`nVosk: $(if($voskReady){'Bereit'}else{'Nicht eingerichtet'})"
        $dictationInstall.Enabled=$script:DictationPhase -eq 'Ready' -and $null -eq $script:DictationInstaller
        if($null -ne $script:DictationInstaller){
            $dictationInstallStatus.Text=$script:DictationInstaller.LastLine
            $dictationInstallStatus.ForeColor=[Drawing.Color]::DarkOrange
        } elseif($script:DictationInstallError){
            $dictationInstallStatus.Text=$script:DictationInstallError
            $dictationInstallStatus.ForeColor=[Drawing.Color]::DarkRed
        } else {
            $dictationInstallStatus.Text=if($whisperReady -and $voskReady){'Beide Engines sind bereit.'}else{'Einrichtung ueber den Button starten.'}
            $dictationInstallStatus.ForeColor=if($whisperReady -and $voskReady){[Drawing.Color]::DarkGreen}else{[Drawing.Color]::DarkOrange}
        }
    }
    & $updateDictationConfiguration
    $dictationStatusTimer.Add_Tick($updateDictationConfiguration)
    $dictationStatusTimer.Start()
    $hotkeyTab=New-Object Windows.Forms.TabPage
    $hotkeyTab.Name='HotkeyTab';$hotkeyTab.Text='Tastenkombination'
    $hotkeyLayout=New-Object Windows.Forms.FlowLayoutPanel
    $hotkeyLayout.Dock='Fill';$hotkeyLayout.FlowDirection='TopDown';$hotkeyLayout.WrapContents=$false
    $hotkeyLayout.Padding=[Windows.Forms.Padding]::new(16)
    $hotkeyLabel=New-Object Windows.Forms.Label
    $hotkeyLabel.Text='TaskPlopp global oeffnen:';$hotkeyLabel.AutoSize=$true
    $hotkeyModifiers=New-Object Windows.Forms.FlowLayoutPanel
    $hotkeyModifiers.AutoSize=$true;$hotkeyModifiers.WrapContents=$false
    $hotkeyChecks=@()
    foreach($item in @(@('Strg',2),@('Alt',1),@('Umschalt',4),@('Win',8))){
        $check=New-Object Windows.Forms.CheckBox
        $check.Name='HotkeyModifier'+$item[1];$check.Text=$item[0];$check.Tag=[int]$item[1];$check.AutoSize=$true
        $check.Checked=($working.HotkeyModifiers -band $check.Tag) -ne 0
        $hotkeyChecks+=$check;[void]$hotkeyModifiers.Controls.Add($check)
    }
    $hotkeyKey=New-Object Windows.Forms.ComboBox
    $hotkeyKey.Name='HotkeyKey';$hotkeyKey.DropDownStyle='DropDownList';$hotkeyKey.Width=160
    $keys=@(1..24 | Where-Object {$_ -ne 12} | ForEach-Object {"F$_"})+@(65..90 | ForEach-Object {[string][char]$_})+@(0..9 | ForEach-Object {[string]$_})
    $hotkeyKey.Items.AddRange([object[]]$keys);$hotkeyKey.SelectedItem=$working.HotkeyKey
    $hotkeyPreview=New-Object Windows.Forms.Label
    $hotkeyPreview.Name='HotkeyPreview';$hotkeyPreview.AutoSize=$true
    $updateHotkeyPreview={
        $bits=0;foreach($check in $hotkeyChecks){if($check.Checked){$bits=$bits -bor [int]$check.Tag}}
        $hotkeyPreview.Text=if($bits){'Auswahl: '+(Get-TaskPloppHotkeySpec ([pscustomobject]@{HotkeyModifiers=$bits;HotkeyKey=[string]$hotkeyKey.SelectedItem})).Label}else{'Bitte mindestens eine Zusatztaste waehlen.'}
    }
    foreach($check in $hotkeyChecks){$check.Add_CheckedChanged($updateHotkeyPreview)}
    $hotkeyKey.Add_SelectedIndexChanged($updateHotkeyPreview)
    & $updateHotkeyPreview
    $hotkeyHelp=New-Object Windows.Forms.Label
    $hotkeyHelp.AutoSize=$true;$hotkeyHelp.MaximumSize=[Drawing.Size]::new(700,0)
    $hotkeyHelp.Text="Speichern prueft und aktiviert die Kombination sofort.`r`nIst sie belegt, bleiben bisherige Kombination und Einstellungen erhalten.`r`nStandard: Strg+Alt+F10. F12 ist fuer Windows reserviert.`r`nCitrix kann Tastenkombinationen an die entfernte Sitzung weiterreichen.`r`nBitte die gewaehlte Kombination auch im Citrix-Vollbild testen."
    $hotkeyLayout.Controls.AddRange(@($hotkeyLabel,$hotkeyModifiers,$hotkeyKey,$hotkeyPreview,$hotkeyHelp))
    $hotkeyTab.Controls.Add($hotkeyLayout);[void]$tabs.TabPages.Add($hotkeyTab)

    $favoriteList = New-Object Windows.Forms.ListBox
    $favoriteList.Name = 'FavoriteList'
    $favoriteList.Dock = 'Fill'; $favoriteList.DisplayMember = 'Name'
    $favoriteList.HorizontalScrollbar = $true
    foreach ($entry in @($working.Programs)) { [void]$favoriteList.Items.Add($entry) }
    $favoriteColumn = New-Object Windows.Forms.Panel
    $favoriteColumn.Dock = 'Left'; $favoriteColumn.Width = 220
    $sortActions = New-Object Windows.Forms.FlowLayoutPanel
    $sortActions.Dock = 'Bottom'; $sortActions.Height = 76
    $up = New-Object Windows.Forms.Button
    $up.Name = 'MoveFavoriteUp'; $up.Text = 'Nach oben'; $up.Width = 100; $up.Enabled = $false
    $down = New-Object Windows.Forms.Button
    $down.Name = 'MoveFavoriteDown'; $down.Text = 'Nach unten'; $down.Width = 100; $down.Enabled = $false
    $sortHint = New-Object Windows.Forms.Label
    $sortHint.Text = 'Reihenfolge = Tasten 1-9, 0, A-Z'; $sortHint.AutoSize = $true
    $sortActions.Controls.AddRange(@($up,$down,$sortHint))
    $favoriteColumn.Controls.Add($favoriteList); $favoriteColumn.Controls.Add($sortActions)
    $editor = New-Object Windows.Forms.FlowLayoutPanel
    $editor.Dock = 'Fill'; $editor.FlowDirection = 'TopDown'; $editor.WrapContents = $false
    $editor.Padding = [Windows.Forms.Padding]::new(12)
    $nameBox = New-Object Windows.Forms.TextBox
    $nameBox.Name = 'FavoriteName'
    $titleBox = New-Object Windows.Forms.TextBox
    $processBox = New-Object Windows.Forms.TextBox
    $targetBox = New-Object Windows.Forms.TextBox
    $targetBox.ReadOnly = $true
    foreach ($spec in @(@('Buttonname', $nameBox), @('Programmkennung (automatisch erkannt)', $processBox),
        @('Nur Fenster mit diesem Text im Titel (optional)', $titleBox), @('Startziel bei geschlossenem Programm', $targetBox))) {
        $label = New-Object Windows.Forms.Label
        $label.Text = $spec[0]; $label.AutoSize = $true
        $spec[1].Width = 550
        $editor.Controls.Add($label); $editor.Controls.Add($spec[1])
    }
    $startButtons = New-Object Windows.Forms.FlowLayoutPanel
    $startButtons.Size = [Drawing.Size]::new(550, 40)
    $fileButton = New-Object Windows.Forms.Button
    $fileButton.Text = 'Startdatei waehlen...'; $fileButton.AutoSize = $true
    $appButton = New-Object Windows.Forms.Button
    $appButton.Text = 'Installierte App waehlen...'; $appButton.AutoSize = $true
    $startButtons.Controls.AddRange(@($fileButton,$appButton)); $editor.Controls.Add($startButtons)
    $always = New-Object Windows.Forms.CheckBox
    $always.Text = 'Startziel immer ausfuehren (z.B. Chrome-Profil)'; $always.Width = 550
    $editor.Controls.Add($always)
    $help = New-Object Windows.Forms.Label
    $help.Size = [Drawing.Size]::new(550, 84)
    $help.Text = "Klick auf den Favoriten: offenes Fenster aktivieren, sonst Programm starten.`r`nDer Titelfilter waehlt vorhandene Fenster aus. Er oeffnet keine Dokumente oder Browser-Tabs.`r`nDie Programmkennung nur korrigieren, falls die automatische Zuordnung nicht passt."
    $editor.Controls.Add($help)
    $favoriteActions = New-Object Windows.Forms.FlowLayoutPanel
    $favoriteActions.Dock = 'Bottom'; $favoriteActions.Height = 48
    $addWindow = New-Object Windows.Forms.Button
    $addWindow.Text = 'Offenes Fenster hinzufuegen...'; $addWindow.AutoSize = $true
    $addFile = New-Object Windows.Forms.Button
    $addFile.Text = 'Programmdatei hinzufuegen...'; $addFile.AutoSize = $true
    $remove = New-Object Windows.Forms.Button
    $remove.Text = 'Favorit entfernen'; $remove.AutoSize = $true
    $addApp = New-Object Windows.Forms.Button
    $addApp.Text = 'Installierte App hinzufuegen...'; $addApp.AutoSize = $true
    $favoriteActions.Controls.AddRange(@($addWindow,$addFile,$addApp,$remove))
    $favoritesTab.Controls.Add($editor); $favoritesTab.Controls.Add($favoriteColumn); $favoritesTab.Controls.Add($favoriteActions)
    $favoriteList.Add_SelectedIndexChanged({
        $entry = $favoriteList.SelectedItem
        $editor.Enabled = ($null -ne $entry)
        $up.Enabled = ($favoriteList.SelectedIndex -gt 0)
        $down.Enabled = ($favoriteList.SelectedIndex -ge 0 -and $favoriteList.SelectedIndex -lt $favoriteList.Items.Count - 1)
        if ($null -ne $entry) {
            $nameBox.Text = $entry.Name; $processBox.Text = $entry.ProcessName
            $titleBox.Text = $entry.TitleContains
            $always.Checked = [bool]$entry.LaunchAlways
            $targetBox.Text = if ($entry.StartTarget) { $entry.StartTarget } else { 'Noch kein Startziel bekannt - bitte auswaehlen.' }
        }
    })
    $up.Add_Click({
        $index = $favoriteList.SelectedIndex
        if ($index -gt 0) {
            $entry = $favoriteList.SelectedItem
            $favoriteList.Items.RemoveAt($index); $favoriteList.Items.Insert($index - 1,$entry)
            $favoriteList.SelectedIndex = $index - 1
        }
    })
    $down.Add_Click({
        $index = $favoriteList.SelectedIndex
        if ($index -ge 0 -and $index -lt $favoriteList.Items.Count - 1) {
            $entry = $favoriteList.SelectedItem
            $favoriteList.Items.RemoveAt($index); $favoriteList.Items.Insert($index + 1,$entry)
            $favoriteList.SelectedIndex = $index + 1
        }
    })
    $always.Add_CheckedChanged({ if ($favoriteList.SelectedIndex -ge 0) { $favoriteList.SelectedItem.LaunchAlways = [bool]$always.Checked } })
    $nameBox.Add_TextChanged({
        if ($favoriteList.SelectedIndex -ge 0) {
            $entry = $favoriteList.SelectedItem; $entry.Name = $nameBox.Text
        }
    })
    $nameBox.Add_Leave({
        if ($favoriteList.SelectedIndex -ge 0) {
            $index = $favoriteList.SelectedIndex
            $favoriteList.Items[$index] = $favoriteList.SelectedItem
        }
    })
    $processBox.Add_TextChanged({ if ($favoriteList.SelectedIndex -ge 0) {
        $entry = $favoriteList.SelectedItem
        if ($entry.ProcessName -ine $processBox.Text) { $entry.ExecutablePath = ''; $entry.AppId = '' }
        $entry.ProcessName = $processBox.Text.Trim() -replace '\.exe$', ''
    } })
    $titleBox.Add_TextChanged({ if ($favoriteList.SelectedIndex -ge 0) { $favoriteList.SelectedItem.TitleContains = $titleBox.Text } })
    $fileButton.Add_Click({
        try {
            $path = Select-TaskPloppFile
            if ($path) {
                $entry = $favoriteList.SelectedItem; $entry.StartKind = 'Path'; $entry.StartTarget = $path
                $targetBox.Text = $path
            }
        } catch { Show-Notice $_.Exception.Message }
    })
    $appButton.Add_Click({
        try {
            $app = Select-TaskPloppItem 'Installierte App auswaehlen' @(Get-InstalledAppChoices | Where-Object AppId -match '!') 'Name'
            if ($app) {
                $entry = $favoriteList.SelectedItem
                $entry.StartKind = 'AppId'; $entry.StartTarget = $app.AppId; $entry.AppId = $app.AppId
                $entry.ExecutablePath = ''; $targetBox.Text = $app.AppId
            }
        } catch { Show-Notice $_.Exception.Message }
    })
    $addWindow.Add_Click({
        try {
            $items = @(Get-AppWindows | Sort-Object ProcessName,Title | ForEach-Object {
                $_ | Add-Member -NotePropertyName DisplayName -NotePropertyValue ("{0} | {1}" -f (Get-AppDisplayName $_.ProcessName $_.AppId),$_.Title) -PassThru
            })
            $window = Select-TaskPloppItem 'Fenster fuer neuen Favoriten auswaehlen' $items 'DisplayName'
            if ($window) {
                $entry = New-FavoriteFromWindow $window
                [void]$favoriteList.Items.Add($entry); $favoriteList.SelectedItem = $entry
            }
        } catch { Show-Notice $_.Exception.Message }
    })
    $addFile.Add_Click({
        try {
            $path = Select-TaskPloppFile
            if ($path) {
                $entry = [pscustomobject]@{ Name = [IO.Path]::GetFileNameWithoutExtension($path)
                    ProcessName = Get-ShortcutProcessName $path; TitleContains = ''; ExecutablePath = ''
                    AppId = ''; StartKind = 'Path'; StartTarget = $path }
                $entry | Add-Member -NotePropertyName LaunchAlways -NotePropertyValue $false
                $entry | Add-Member -NotePropertyName FolderPath -NotePropertyValue ''
                if ([IO.Path]::GetExtension($path) -ieq '.exe') { $entry.ExecutablePath = $path }
                [void]$favoriteList.Items.Add($entry); $favoriteList.SelectedItem = $entry
            }
        } catch { Show-Notice $_.Exception.Message }
    })
    $addApp.Add_Click({
        try {
            $app = Select-TaskPloppItem 'Installierte App auswaehlen' @(Get-InstalledAppChoices | Where-Object AppId -match '!') 'Name'
            if ($app) {
                $entry = [pscustomobject]@{ Name = $app.Name; ProcessName = $app.Name; TitleContains = ''
                    ExecutablePath = ''; AppId = $app.AppId; StartKind = 'AppId'; StartTarget = $app.AppId; LaunchAlways = $false; FolderPath = '' }
                [void]$favoriteList.Items.Add($entry); $favoriteList.SelectedItem = $entry
            }
        } catch { Show-Notice $_.Exception.Message }
    })
    $remove.Add_Click({ if ($favoriteList.SelectedIndex -ge 0) { $favoriteList.Items.RemoveAt($favoriteList.SelectedIndex) } })

    $hidden = New-Object Windows.Forms.ListBox
    $hidden.Dock = 'Fill'; $hidden.DisplayMember = 'Name'
    foreach ($rule in @($working.HiddenWindows)) { [void]$hidden.Items.Add($rule) }
    $restore = New-Object Windows.Forms.Button
    $restore.Text = 'Ausgewaehltes Programm wieder anzeigen'; $restore.Dock = 'Bottom'; $restore.Height = 40
    $restore.Add_Click({ if ($hidden.SelectedIndex -ge 0) { $hidden.Items.RemoveAt($hidden.SelectedIndex) } })
    $hiddenTab.Controls.Add($hidden); $hiddenTab.Controls.Add($restore)

    $footer = New-Object Windows.Forms.FlowLayoutPanel
    $footer.Dock = 'Bottom'; $footer.Height = 48
    $show = New-Object Windows.Forms.CheckBox
    $show.Text = 'Weitere offene Fenster anzeigen'; $show.Width = 280; $show.Checked = $working.ShowOpenWindows
    $save = New-Object Windows.Forms.Button
    $save.Name = 'SaveSettings'
    $save.Text = 'Speichern'; $save.AutoSize = $true
    $cancel = New-Object Windows.Forms.Button
    $cancel.Name = 'CancelSettings'
    $cancel.Text = 'Abbrechen'; $cancel.AutoSize = $true; $cancel.DialogResult = 'Cancel'
    $save.Add_Click({
        try {
            $working.Programs = @($favoriteList.Items | ForEach-Object { $_ })
            $working.HiddenWindows = @($hidden.Items | ForEach-Object { $_ })
            $working.ShowOpenWindows = [bool]$show.Checked
            $working.AutoLockEnabled=[bool]$lockEnabled.Checked
            $working.AutoLockMinutes=[int]$lockMinutes.Value
            $working.DictationEngine=if($dictationChoice.SelectedIndex -eq 1){'Vosk'}else{'Whisper'}
            $working.HotkeyModifiers=0
            foreach($check in $hotkeyChecks){if($check.Checked){$working.HotkeyModifiers=$working.HotkeyModifiers -bor [int]$check.Tag}}
            $working.HotkeyKey=[string]$hotkeyKey.SelectedItem
            foreach ($entry in $working.Programs) {
                $entry.Name = $entry.Name.Trim(); $entry.ProcessName = $entry.ProcessName.Trim()
                if (-not $entry.Name -or -not $entry.ProcessName) { throw 'Bitte Buttonname und Programmkennung ausfuellen.' }
                if (-not $entry.StartKind) {
                    $target = Resolve-FavoriteStart $entry
                    $entry.StartKind = $target.Kind; $entry.StartTarget = $target.Target
                }
            }
            $hotkeyChanged=$script:Settings.HotkeyModifiers -ne $working.HotkeyModifiers -or $script:Settings.HotkeyKey -ne $working.HotkeyKey
            Save-TaskPloppSettingsWithHotkey $working
            $script:Settings = $working
            Update-TaskPloppTrayText
            Apply-TaskPloppIdleSettings -Notify
            if($hotkeyChanged){Set-TaskPloppMessage 'Success' 'Tastenkombination gespeichert' (Get-TaskPloppHotkeySpec $working).Label}
            $dialog.DialogResult = 'OK'
        } catch { Show-Notice $_.Exception.Message }
    })
    $footer.Controls.AddRange(@($show,$save,$cancel))
    $dialog.Controls.Add($tabs); $dialog.Controls.Add($footer); $dialog.CancelButton = $cancel
    $editor.Enabled = $false
    if ($favoriteList.Items.Count -gt 0) { $favoriteList.SelectedIndex = 0 }
    if ($OnShown) { $dialog.Add_Shown($OnShown) }
    try { [void]$dialog.ShowDialog($script:Main) } finally { $dictationStatusTimer.Dispose();$dialog.Dispose() }
    Show-TaskPloppView
}
