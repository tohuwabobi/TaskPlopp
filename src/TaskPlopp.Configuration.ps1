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
    $picker.AutoScaleDimensions=[Drawing.SizeF]::new(7,17);$picker.AutoScaleMode='Font'
    try { if ($picker.ShowDialog($owner) -eq 'OK') { return $picker.Tag } }
    finally { $picker.Dispose() }
}

function Resolve-TaskPloppProgramFile([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    if([IO.Path]::GetExtension($full)-notin@('.exe','.lnk')-or-not(Test-Path -LiteralPath $full -PathType Leaf)){throw 'Bitte eine vorhandene EXE- oder LNK-Datei auswaehlen.'}
    return $full
}
function Select-TaskPloppFile {
    $owner = [Windows.Forms.Form]::ActiveForm
    if ($null -eq $owner) { $owner = $script:Main }
    $file = New-Object Windows.Forms.OpenFileDialog
    $file.Title = 'Programm oder Startverknuepfung auswaehlen'
    $file.Filter = 'Programme und Verknuepfungen|*.exe;*.lnk'
    $file.DereferenceLinks = $false
    $file.CheckFileExists=$false;$file.CheckPathExists=$false;$file.ValidateNames=$false
    try {
        if($file.ShowDialog($owner)-eq'OK'){
            return Resolve-TaskPloppProgramFile $file.FileName
        }
    }
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
    if($null-ne$script:LayoutJob){Set-TaskPloppMessage Notice 'Fensterordner arbeitet' 'Konfiguration bitte nach Abschluss oder Abbruch oeffnen.';return}
    # Controls edit candidates; completed changes are saved immediately.
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
    $dictationHelp.Text="Beide Engines und deutsche Modelle werden benutzerlokal eingerichtet.`r`nDownload etwa 220 MB; normalerweise keine Adminrechte erforderlich.`r`nEinrichtung gilt sofort.`r`nEngine-Auswahl wird sofort fuer das naechste Diktat gespeichert.`r`nMikrofon wird ueber Audio gewaehlt. Keine Cloud, kein Audioarchiv.`r`nErster Mikrofonklick: Aufnahme. Zweiter Klick: Transkription.`r`nRechtsklick auf Mikrofon: Verwerfen oder erneut kopieren."
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
    $layoutTab=[Windows.Forms.TabPage]::new();$layoutTab.Text='Fensterordner';$layoutTab.Name='WindowLayoutTab'
    $layoutSettings=[Windows.Forms.FlowLayoutPanel]::new();$layoutSettings.Dock='Fill';$layoutSettings.FlowDirection='TopDown';$layoutSettings.WrapContents=$false;$layoutSettings.AutoScroll=$true;$layoutSettings.Padding=[Windows.Forms.Padding]::new(16)
    $layoutLabel=[Windows.Forms.Label]::new();$layoutLabel.AutoSize=$true;$layoutLabel.Text='OpenAI-Modell fuer den KI-Fensterordner:'
    $layoutModel=[Windows.Forms.TextBox]::new();$layoutModel.Name='WindowLayoutModel';$layoutModel.Width=320;$layoutModel.Text=$working.WindowLayoutModel
    $layoutHelp=[Windows.Forms.Label]::new();$layoutHelp.AutoSize=$true;$layoutHelp.MaximumSize=[Drawing.Size]::new(700,0)
    $layoutHelp.Text="Erster Klick: Arbeitsziel sprechen. Zweiter Klick: Fenster anordnen.`r`nSprache wird lokal transkribiert. Desktopbilder und Fenstertitel werden`r`nan OpenAI gesendet; API-Nutzung kann Kosten verursachen.`r`nRechtsklick auf Fensterordner: letzte Anordnung rueckgaengig.`r`nDer Key gilt fuer dieses Windows-Konto und wird nicht exportiert. Keine Fenster werden geschlossen."
    $keyLabel=[Windows.Forms.Label]::new();$keyLabel.AutoSize=$true;$keyLabel.Text='OpenAI-API-Key fuer diesen PC:'
    $keyInput=[Windows.Forms.TextBox]::new();$keyInput.Name='OpenAIKey';$keyInput.Width=420;$keyInput.UseSystemPasswordChar=$true
    $keyState=[Windows.Forms.Label]::new();$keyState.Name='OpenAIKeyState';$keyState.AutoSize=$true
    $updateKeyState={
        $keyState.Text=if(Test-TaskPloppOpenAIKey){'Lokal eingerichtet (nicht online geprueft).'}elseif([IO.File]::Exists((Get-TaskPloppOpenAIKeyPath))){'Vorhandene Schluesseldatei ist nicht verwendbar. Bitte Key neu speichern.'}else{'Noch kein API-Key eingerichtet.'}
    }
    & $updateKeyState
    $keyHelp=[Windows.Forms.Label]::new();$keyHelp.AutoSize=$true;$keyHelp.MaximumSize=[Drawing.Size]::new(700,0)
    $keyHelp.Text="Neue Eingabe wird beim Verlassen des Feldes automatisch gespeichert.`r`nEin leeres Feld behaelt den vorhandenen Key; er wird nie angezeigt."
    $layoutSettings.Controls.AddRange(@($layoutLabel,$layoutModel,$keyLabel,$keyInput,$keyState,$keyHelp,$layoutHelp));$layoutTab.Controls.Add($layoutSettings);[void]$tabs.TabPages.Add($layoutTab)
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
    $hotkeyHelp.Text="Jede Auswahl prueft und aktiviert die Kombination sofort.`r`nIst sie belegt, bleiben bisherige Kombination und Einstellungen erhalten.`r`nStandard: Strg+Alt+F10. F12 ist fuer Windows reserviert.`r`nCitrix kann Tastenkombinationen an die entfernte Sitzung weiterreichen.`r`nBitte die gewaehlte Kombination auch im Citrix-Vollbild testen."
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
    $editor.Dock = 'Fill'; $editor.FlowDirection = 'TopDown'; $editor.WrapContents = $false; $editor.AutoScroll=$true
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
    $hidden = New-Object Windows.Forms.ListBox
    $hidden.Dock = 'Fill'; $hidden.DisplayMember = 'Name'
    foreach ($rule in @($working.HiddenWindows)) { [void]$hidden.Items.Add($rule) }
    $restore = New-Object Windows.Forms.Button
    $restore.Text = 'Ausgewaehltes Programm wieder anzeigen'; $restore.Dock = 'Bottom'; $restore.Height = 40

    $hiddenTab.Controls.Add($hidden); $hiddenTab.Controls.Add($restore)

    $footer = New-Object Windows.Forms.FlowLayoutPanel
    $footer.Dock = 'Bottom'; $footer.Height = 48
    $show = New-Object Windows.Forms.CheckBox
    $show.Text = 'Weitere offene Fenster anzeigen'; $show.Width = 280; $show.Checked = $working.ShowOpenWindows
    $close=[Windows.Forms.Button]::new();$close.Name='CloseSettings';$close.Text='Schliessen';$close.AutoSize=$true;$close.DialogResult='OK'
    $footer.Controls.AddRange(@($show,$close))
    $script:ConfigurationMessageBar=New-TaskPloppMessageBar
    $script:ConfigurationMessageBar.Name='ConfigurationMessages';$script:ConfigurationMessageBar.Dock='Fill'
    $script:ConfigurationMessageBar.Margin=[Windows.Forms.Padding]::new(0)
    $footerHost=[Windows.Forms.TableLayoutPanel]::new();$footerHost.Dock='Bottom';$footerHost.AutoSize=$true;$footerHost.AutoSizeMode='GrowAndShrink'
    $footerHost.ColumnCount=1;$footerHost.RowCount=2;$footerHost.Padding=[Windows.Forms.Padding]::new(10,3,10,3)
    $footer.Margin=[Windows.Forms.Padding]::new(0);$footer.Dock='Fill'
    $footerHost.Controls.Add($script:ConfigurationMessageBar,0,0);$footerHost.Controls.Add($footer,0,1)
    $dialog.Controls.Add($tabs);$dialog.Controls.Add($footerHost);$dialog.CancelButton=$close
    $editor.Enabled = $false

    $nameBox.Name='FavoriteName';$processBox.Name='FavoriteProcess';$titleBox.Name='FavoriteTitle';$targetBox.Name='FavoriteTarget'
    $always.Name='FavoriteAlways';$hidden.Name='HiddenWindowList';$restore.Name='RestoreHiddenWindow';$show.Name='ShowOpenWindows'
    $addWindow.Name='AddWindowFavorite';$addFile.Name='AddFileFavorite';$addApp.Name='AddAppFavorite';$remove.Name='RemoveFavorite'
    $configState=@{Loading=$true;EditingIndex=-1;LastError=''}
    $loadFavorite={
        param([int]$index)
        $configState.Loading=$true
        try{
            $favoriteList.SelectedIndex=$index;$configState.EditingIndex=$index
            $editor.Enabled=$index-ge0;$up.Enabled=$index-gt0;$down.Enabled=$index-ge0-and$index-lt$favoriteList.Items.Count-1
            if($index-ge0){$entry=$script:Settings.Programs[$index];$nameBox.Text=$entry.Name;$processBox.Text=$entry.ProcessName;$titleBox.Text=$entry.TitleContains;$always.Checked=$entry.LaunchAlways;$targetBox.Text=$entry.StartTarget}
            else{$nameBox.Clear();$processBox.Clear();$titleBox.Clear();$targetBox.Clear();$always.Checked=$false}
        }finally{$configState.Loading=$false}
    }
    $reload={
        param([int]$selection)
        $configState.Loading=$true
        try{
            $favoriteList.Items.Clear();foreach($entry in @($script:Settings.Programs)){[void]$favoriteList.Items.Add($entry)}
            $hidden.Items.Clear();foreach($rule in @($script:Settings.HiddenWindows)){[void]$hidden.Items.Add($rule)}
            $lockEnabled.Checked=$script:Settings.AutoLockEnabled;$lockMinutes.Value=$script:Settings.AutoLockMinutes
            $show.Checked=$script:Settings.ShowOpenWindows;$layoutModel.Text=$script:Settings.WindowLayoutModel
            $dictationChoice.SelectedIndex=if($script:Settings.DictationEngine-eq'Vosk'){1}else{0}
            foreach($check in $hotkeyChecks){$check.Checked=($script:Settings.HotkeyModifiers-band[int]$check.Tag)-ne0}
            $hotkeyKey.SelectedItem=$script:Settings.HotkeyKey
            $selection=[Math]::Min($selection,$favoriteList.Items.Count-1)
            & $loadFavorite $selection
        }finally{$configState.Loading=$false}
    }
    $commit={
        param([scriptblock]$Change,[int]$Selection=-2)
        if($configState.Loading){return}
        if($Selection-eq-2){$Selection=$configState.EditingIndex}
        try{
            $candidate=ConvertTo-TaskPloppSettings ($script:Settings|ConvertTo-Json -Depth 8|ConvertFrom-Json)
            & $Change $candidate
            $candidate=ConvertTo-TaskPloppSettings $candidate
            if(($candidate|ConvertTo-Json -Depth 8 -Compress)-ceq($script:Settings|ConvertTo-Json -Depth 8 -Compress)){return}
            Save-TaskPloppSettingsWithHotkey $candidate
        }catch{
            $configState.LastError='Aenderung nicht uebernommen. Bisheriger Wert wiederhergestellt. '+$_.Exception.Message
            & $reload $configState.EditingIndex
            Set-TaskPloppMessage Error 'Konfiguration nicht uebernommen' $configState.LastError
            return
        }
        $script:Settings=$candidate;$configState.LastError=''
        try{
            & $reload $Selection
            Update-TaskPloppTrayText;Apply-TaskPloppIdleSettings
            if($script:HotkeyCleanupWarning){Set-TaskPloppMessage Warning 'Einstellung gespeichert' $script:HotkeyCleanupWarning}
            else{Set-TaskPloppMessage Success 'Einstellung gespeichert' ''}
        }catch{Set-TaskPloppMessage Warning 'Einstellung gespeichert, Anzeige nicht vollstaendig aktualisiert' 'Die gespeicherte Aenderung bleibt erhalten. Konfiguration erneut oeffnen.'}
    }
    $commitFavorite={
        if($configState.Loading-or$configState.EditingIndex-lt0){return}
        $index=$configState.EditingIndex;$newName=$nameBox.Text.Trim();$newProcess=$processBox.Text.Trim()-replace'\.exe$','';$newTitle=$titleBox.Text
        & $commit {
            param($c)
            if(-not$newName-or-not$newProcess){throw 'Bitte Buttonname und Programmkennung ausfuellen.'}
            $entry=$c.Programs[$index];$entry.Name=$newName;$entry.TitleContains=$newTitle
            if($entry.ProcessName-ine$newProcess){$entry.ExecutablePath='';$entry.AppId=''}
            $entry.ProcessName=$newProcess
        }
    }
    $commitKey={
        if($configState.Loading-or-not$keyInput.Text){return}
        try{Save-TaskPloppOpenAIKey $keyInput.Text}
        catch{
            $keyInput.Clear();$configState.LastError='API-Key nicht uebernommen. Der bisherige Key bleibt erhalten. Eingabe und Schreibrechte pruefen.'
            Set-TaskPloppMessage Error 'API-Key nicht gespeichert' $configState.LastError
            return
        }
        $keyInput.Clear();$configState.LastError='';$keyState.Text='Lokal eingerichtet (nicht online geprueft).'
        Set-TaskPloppMessage Success 'API-Key lokal gespeichert' 'Gilt sofort auf diesem PC. Keine Online-Pruefung durchgefuehrt.'
    }
    foreach($box in @($nameBox,$processBox,$titleBox)){$box.Add_Leave($commitFavorite)}
    $layoutModel.Add_Leave({$value=$layoutModel.Text.Trim();& $commit {param($c)$c.WindowLayoutModel=$value}})
    $keyInput.Add_Leave($commitKey)
    $favoriteList.Add_SelectedIndexChanged({if(-not$configState.Loading){$next=$favoriteList.SelectedIndex;& $commitFavorite;& $loadFavorite $next}})
    $up.Add_Click({& $commitFavorite;$index=$configState.EditingIndex;if($index-gt0){& $commit {param($c)$swap=$c.Programs[$index-1];$c.Programs[$index-1]=$c.Programs[$index];$c.Programs[$index]=$swap} ($index-1)}})
    $down.Add_Click({& $commitFavorite;$index=$configState.EditingIndex;if($index-ge0-and$index-lt$script:Settings.Programs.Count-1){& $commit {param($c)$swap=$c.Programs[$index+1];$c.Programs[$index+1]=$c.Programs[$index];$c.Programs[$index]=$swap} ($index+1)}})
    $always.Add_CheckedChanged({if(-not$configState.Loading-and$configState.EditingIndex-ge0){$index=$configState.EditingIndex;$value=$always.Checked;& $commit {param($c)$c.Programs[$index].LaunchAlways=$value}}})
    $fileButton.Add_Click({
        try{$path=Select-TaskPloppFile;if($path){$index=$configState.EditingIndex;& $commit {param($c)$c.Programs[$index].StartKind='Path';$c.Programs[$index].StartTarget=$path}}}
        catch{Set-TaskPloppMessage Error 'Startziel nicht uebernommen' $_.Exception.Message}
    })
    $appButton.Add_Click({
        try{$app=Select-TaskPloppItem 'Installierte App auswaehlen' @(Get-InstalledAppChoices|Where-Object AppId -match '!') Name
            if($app){$index=$configState.EditingIndex;& $commit {param($c)$entry=$c.Programs[$index];$entry.StartKind='AppId';$entry.StartTarget=$app.AppId;$entry.AppId=$app.AppId;$entry.ExecutablePath=''}}}
        catch{Set-TaskPloppMessage Error 'Startziel nicht uebernommen' $_.Exception.Message}
    })
    $addWindow.Add_Click({
        try{$items=@(Get-AppWindows|Sort-Object ProcessName,Title|ForEach-Object {$_|Add-Member NoteProperty DisplayName ("{0} | {1}"-f(Get-AppDisplayName $_.ProcessName $_.AppId),$_.Title) -PassThru})
            $window=Select-TaskPloppItem 'Fenster fuer neuen Favoriten auswaehlen' $items DisplayName
            if($window){$entry=New-FavoriteFromWindow $window;& $commit {param($c)$c.Programs=@($c.Programs)+@($entry)} $script:Settings.Programs.Count}}
        catch{Set-TaskPloppMessage Error 'Favorit nicht hinzugefuegt' $_.Exception.Message}
    })
    $addFile.Add_Click({
        try{$path=Select-TaskPloppFile;if($path){$entry=[pscustomobject]@{Name=[IO.Path]::GetFileNameWithoutExtension($path);ProcessName=(Get-ShortcutProcessName $path);TitleContains='';ExecutablePath='';AppId='';StartKind='Path';StartTarget=$path;LaunchAlways=$false;FolderPath=''}
            if([IO.Path]::GetExtension($path)-ieq'.exe'){$entry.ExecutablePath=$path}
            & $commit {param($c)$c.Programs=@($c.Programs)+@($entry)} $script:Settings.Programs.Count}}
        catch{Set-TaskPloppMessage Error 'Favorit nicht hinzugefuegt' $_.Exception.Message}
    })
    $addApp.Add_Click({
        try{$app=Select-TaskPloppItem 'Installierte App auswaehlen' @(Get-InstalledAppChoices|Where-Object AppId -match '!') Name
            if($app){$entry=[pscustomobject]@{Name=$app.Name;ProcessName=$app.Name;TitleContains='';ExecutablePath='';AppId=$app.AppId;StartKind='AppId';StartTarget=$app.AppId;LaunchAlways=$false;FolderPath=''}
                & $commit {param($c)$c.Programs=@($c.Programs)+@($entry)} $script:Settings.Programs.Count}}
        catch{Set-TaskPloppMessage Error 'Favorit nicht hinzugefuegt' $_.Exception.Message}
    })
    $remove.Add_Click({$index=$configState.EditingIndex;if($index-ge0){& $commit {param($c)$c.Programs=@(for($i=0;$i-lt$c.Programs.Count;$i++){if($i-ne$index){$c.Programs[$i]}})} ([Math]::Max(0,$index-1))}})
    $restore.Add_Click({$index=$hidden.SelectedIndex;if($index-ge0){& $commit {param($c)$c.HiddenWindows=@(for($i=0;$i-lt$c.HiddenWindows.Count;$i++){if($i-ne$index){$c.HiddenWindows[$i]}})}}})
    $show.Add_CheckedChanged({$value=$show.Checked;& $commit {param($c)$c.ShowOpenWindows=$value}})
    $lockEnabled.Add_CheckedChanged({$value=$lockEnabled.Checked;& $commit {param($c)$c.AutoLockEnabled=$value}})
    $lockMinutes.Add_ValueChanged({$value=[int]$lockMinutes.Value;& $commit {param($c)$c.AutoLockMinutes=$value}})
    $dictationChoice.Add_SelectedIndexChanged({$value=if($dictationChoice.SelectedIndex-eq1){'Vosk'}else{'Whisper'};& $commit {param($c)$c.DictationEngine=$value}})
    $hotkeyChanged={
        if($configState.Loading){return}
        $bits=0;foreach($check in $hotkeyChecks){if($check.Checked){$bits=$bits-bor[int]$check.Tag}}
        $value=[string]$hotkeyKey.SelectedItem;& $commit {param($c)$c.HotkeyModifiers=$bits;$c.HotkeyKey=$value}
    }
    foreach($check in $hotkeyChecks){$check.Add_CheckedChanged($hotkeyChanged)}
    $hotkeyKey.Add_SelectedIndexChanged($hotkeyChanged)
    $dialog.Add_FormClosing({
        & $commitFavorite
        $value=$layoutModel.Text.Trim();& $commit {param($c)$c.WindowLayoutModel=$value}
        & $commitKey
    })
    & $reload $(if($favoriteList.Items.Count){0}else{-1})
    if ($OnShown) { $dialog.Add_Shown($OnShown) }
    $dialog.AutoScaleDimensions=[Drawing.SizeF]::new(7,17);$dialog.AutoScaleMode='Font'
    $dialog.PerformAutoScale()
    $area=[Windows.Forms.Screen]::FromControl($script:Main).WorkingArea
    $fit=[Drawing.Size]::new([Math]::Min($dialog.Width,$area.Width-40),[Math]::Min($dialog.Height,$area.Height-40))
    $dialog.MinimumSize=$fit;$dialog.Size=$fit
    $script:ConfigurationOpen=$true
    try { [void]$dialog.ShowDialog($script:Main) } finally { $script:ConfigurationOpen=$false;$keyInput.Clear();$dictationStatusTimer.Dispose();$dialog.Dispose();$script:ConfigurationMessageBar=$null }
    Show-TaskPloppView
    if($configState.LastError){Set-TaskPloppMessage Error 'Aenderung nicht uebernommen' $configState.LastError}
}
