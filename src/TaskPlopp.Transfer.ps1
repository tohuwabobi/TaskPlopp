# A plain ZIP containing config.json and the directly referenced shortcuts.
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
function ConvertFrom-TaskPloppTransferJson([string]$Json) {
    $data=$Json.TrimStart([char]0xFEFF)|ConvertFrom-Json
    if($null-eq$data-or$data-is[array]-or$data.PSObject.Properties.Name-notcontains'Programs'-or$data.PSObject.Properties.Name-notcontains'ShowOpenWindows'-or$data.ShowOpenWindows-isnot[bool]){throw 'Ungueltige Konfiguration im Paket.'}
    foreach($program in @($data.Programs)){
        foreach($key in 'Name','ProcessName','TitleContains'){if($program.PSObject.Properties.Name-notcontains$key-or$program.$key-isnot[string]){throw "Ungueltiger Favorit: $key"}}
        if(-not$program.Name.Trim()-or-not$program.ProcessName.Trim()){throw 'Favorit ohne Name oder Programmkennung.'}
    }
    $known=@('ShowOpenWindows','Programs','HiddenWindows','AutoLockEnabled','AutoLockMinutes','DictationEngine','WindowLayoutModel','HotkeyModifiers','HotkeyKey')
    if(@($data.PSObject.Properties.Name|Where-Object{$_-notin$known}).Count){throw 'Unbekannte Konfigurationsfelder im Paket.'}
    ConvertTo-TaskPloppSettings $data
}
function Get-TaskPloppTransferData([switch]$Snapshot) {
    $raw=$null;$settings=$null;$notes=New-Object 'Collections.Generic.List[string]'
    if(Test-Path -LiteralPath $script:ConfigPath -PathType Leaf -ErrorAction Stop){
        $raw=[IO.File]::ReadAllBytes($script:ConfigPath)
        try{$settings=ConvertFrom-TaskPloppTransferJson ([Text.Encoding]::UTF8.GetString($raw))}
        catch{if(-not$Snapshot){throw};$notes.Add('Alte Konfiguration ungueltig: '+$_.Exception.Message)}
    }else{
        if(-not$Snapshot){throw 'Keine gespeicherte Konfiguration vorhanden.'}
        $notes.Add('Vorher war keine Konfigurationsdatei vorhanden.')
        $settings=Get-Settings
    }
    $links=@{};$sources=@{}
    if($null-ne$settings){
        foreach($favorite in @($settings.Programs)){
            if($favorite.StartKind-ne'Path'-or[IO.Path]::GetExtension($favorite.StartTarget)-ine'.lnk'){continue}
            try{
                $source=[IO.Path]::GetFullPath($favorite.StartTarget)
                if(-not$sources.ContainsKey($source)){
                    $bytes=[IO.File]::ReadAllBytes($source)
                    $relative='links/{0:D4}.lnk'-f($sources.Count+1)
                    $sources[$source]=$relative;$links[$relative]=$bytes
                }
                $favorite.StartTarget=$sources[$source]
            }catch{if(-not$Snapshot){throw "Verknuepfung nicht lesbar: $($favorite.StartTarget). $($_.Exception.Message)"};$notes.Add('Alte Verknuepfung nicht lesbar: '+$favorite.StartTarget)}
        }
    }
    [pscustomobject]@{Settings=$settings;Links=$links;Original=$raw;Notes=$notes.ToArray()}
}
function Write-TaskPloppZipEntry($Zip,[string]$Name,[byte[]]$Bytes) {
    $stream=$Zip.CreateEntry($Name).Open()
    try{$stream.Write($Bytes,0,$Bytes.Length)}finally{$stream.Dispose()}
}
function Write-TaskPloppTransferZip($Data,[string]$Path,[switch]$Snapshot,[switch]$Overwrite) {
    $pathFull=[IO.Path]::GetFullPath($Path)
    if([IO.Path]::GetExtension($pathFull)-ine'.zip'-or$pathFull-ieq[IO.Path]::GetFullPath($script:ConfigPath)){throw 'Bitte eine ZIP-Datei ausserhalb der Konfigurationsdatei waehlen.'}
    if([IO.File]::Exists($pathFull)-and-not$Overwrite){throw 'Die ZIP-Datei existiert bereits.'}
    $temporary=$pathFull+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try{
        $zip=[IO.Compression.ZipFile]::Open($temporary,[IO.Compression.ZipArchiveMode]::Create)
        try{
            if($null-ne$Data.Settings){$json=($Data.Settings|ConvertTo-Json -Depth 8)-replace"`r?`n","`r`n";Write-TaskPloppZipEntry $zip config.json ([Text.Encoding]::UTF8.GetBytes($json+"`r`n"))}
            foreach($name in $Data.Links.Keys){Write-TaskPloppZipEntry $zip $name $Data.Links[$name]}
            if($Snapshot-and$null-ne$Data.Original){Write-TaskPloppZipEntry $zip config-original.json $Data.Original}
            if($Data.Notes.Count){Write-TaskPloppZipEntry $zip hinweise.txt ([Text.Encoding]::UTF8.GetBytes(($Data.Notes-join"`r`n")))}
        }finally{$zip.Dispose()}
        if($null-ne$Data.Settings){$null=Read-TaskPloppTransferZip $temporary}
        else{
            $check=[IO.Compression.ZipFile]::OpenRead($temporary)
            try{$entry=$check.GetEntry('config-original.json');if($null-eq$entry-or$entry.Length-ne$Data.Original.Length){throw 'Rohsicherung konnte nicht bestaetigt werden.'}}finally{$check.Dispose()}
        }
        if([IO.File]::Exists($pathFull)){[IO.File]::Replace($temporary,$pathFull,[Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move($temporary,$pathFull)}
        return $pathFull
    }finally{if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}
}
function Read-TaskPloppTransferZip([string]$Path) {
    $zip=[IO.Compression.ZipFile]::OpenRead($Path);$entries=@{}
    try{
        foreach($entry in $zip.Entries){
            $name=$entry.FullName
            if($entries.ContainsKey($name)-or$name-cnotmatch'^(?:config\.json|config-original\.json|hinweise\.txt|links/[0-9]{4,}\.lnk)$'){throw "Unerwarteter oder doppelter ZIP-Eintrag: $name"}
            $stream=$entry.Open();$memory=[IO.MemoryStream]::new()
            try{$stream.CopyTo($memory);$entries[$name]=$memory.ToArray()}finally{$stream.Dispose();$memory.Dispose()}
        }
    }finally{$zip.Dispose()}
    if(-not$entries.ContainsKey('config.json')){throw 'Das Paket enthaelt keine gueltige config.json. Eine Rohsicherung muss manuell entnommen werden.'}
    $settings=ConvertFrom-TaskPloppTransferJson ([Text.Encoding]::UTF8.GetString($entries['config.json']))
    $links=@{};$used=@{}
    foreach($favorite in @($settings.Programs)){
        $target=$favorite.StartTarget
        if($favorite.StartKind-eq'Path'-and$target-cmatch'^links/[0-9]{4,}\.lnk$'){
            if(-not$entries.ContainsKey($target)){throw "Paketverknuepfung fehlt: $target"}
            $links[$target]=$entries[$target];$used[$target]=$true
        }elseif($favorite.StartKind-eq'Path'-and($target-match'^links[\\/]' -or (-not[IO.Path]::IsPathRooted($target)-and[IO.Path]::GetExtension($target)-ieq'.lnk'))){throw 'Ungueltiger relativer Paketpfad.'}
    }
    foreach($name in $entries.Keys){if($name-like'links/*'-and-not$used.ContainsKey($name)){throw "Nicht referenzierte Paketverknuepfung: $name"}}
    [pscustomobject]@{Settings=$settings;Links=$links}
}
function Get-TaskPloppTransferWarnings($Data) {
    $linkWarnings=@{}
    foreach($name in $Data.Links.Keys){
        $temporary=Join-Path $env:TEMP ('TaskPlopp-preview-'+[guid]::NewGuid().ToString('N')+'.lnk');$shell=$null;$link=$null
        try{
            [IO.File]::WriteAllBytes($temporary,$Data.Links[$name]);$shell=New-Object -ComObject WScript.Shell;$link=$shell.CreateShortcut($temporary)
            $issues=@()
            if(-not$link.TargetPath){$issues+='Verknuepfungsziel nicht eindeutig lesbar.'}
            elseif(-not(Test-Path -LiteralPath $link.TargetPath)){$issues+='Verknuepfungsziel fehlt ('+$link.TargetPath+').'}
            if($link.WorkingDirectory-and-not(Test-Path -LiteralPath $link.WorkingDirectory -PathType Container)){$issues+='Arbeitsordner fehlt ('+$link.WorkingDirectory+').'}
            $linkWarnings[$name]=$issues
        }catch{$linkWarnings[$name]=@('Verknuepfungsziel konnte nicht geprueft werden.')}
        finally{if($null-ne$link){$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($link)};if($null-ne$shell){$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($shell)};if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}
    }
    foreach($favorite in @($Data.Settings.Programs)){
        if($favorite.FolderPath-and-not(Test-Path -LiteralPath $favorite.FolderPath -PathType Container)){"$($favorite.Name): Ordner fehlt ($($favorite.FolderPath))."}
        if($Data.Links.ContainsKey($favorite.StartTarget)){foreach($issue in @($linkWarnings[$favorite.StartTarget])){"$($favorite.Name): $issue"}}
        elseif($favorite.StartKind-eq'Path'-and-not(Test-Path -LiteralPath $favorite.StartTarget -PathType Leaf)){"$($favorite.Name): Startziel fehlt ($($favorite.StartTarget))."}
    }
    'Chrome-Profile und Pfade auf diesem PC pruefen. Verknuepfungen werden unveraendert uebernommen.'
}
function Test-TaskPloppImportAllowed {
    $phase=Get-Variable DictationPhase -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    $installer=Get-Variable DictationInstaller -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    return (($null-eq$phase-or$phase-eq'Ready')-and$null-eq$installer)
}
function Import-TaskPloppTransfer($Data,[string]$StorageRoot=(Join-Path $env:LOCALAPPDATA 'TaskPlopp')) {
    if(-not(Test-TaskPloppImportAllowed)){throw 'Import erst nach Ende von Aufnahme, Erkennung und Einrichtung moeglich.'}
    # Revalidate a copy; callers cannot alter a previously reviewed import object.
    $settings=ConvertFrom-TaskPloppTransferJson ($Data.Settings|ConvertTo-Json -Depth 8)
    $snapshot=Get-TaskPloppTransferData -Snapshot
    $backupDirectory=Join-Path $StorageRoot 'Backups';$null=[IO.Directory]::CreateDirectory($backupDirectory)
    $backupPath=Join-Path $backupDirectory ('Vor-Import-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N')+'.zip')
    $backupPath=Write-TaskPloppTransferZip $snapshot $backupPath -Snapshot
    $importDirectory=$null;$saveStarted=$false
    try{
        if($Data.Links.Count){
            $importDirectory=Join-Path $StorageRoot ('ImportedShortcuts\'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($importDirectory)
            foreach($name in $Data.Links.Keys){
                if($name-cnotmatch'^links/[0-9]{4,}\.lnk$'){throw 'Ungueltiger Paketlink.'}
                [IO.File]::WriteAllBytes((Join-Path $importDirectory ([IO.Path]::GetFileName($name))),$Data.Links[$name])
            }
            foreach($favorite in @($settings.Programs)){if($favorite.StartKind-eq'Path'-and$Data.Links.ContainsKey($favorite.StartTarget)){$favorite.StartTarget=Join-Path $importDirectory ([IO.Path]::GetFileName($favorite.StartTarget))}}
        }
        $saveStarted=$true
        Save-TaskPloppSettingsWithHotkey $settings
    }catch{
        if(-not$saveStarted-and$importDirectory){foreach($file in [IO.Directory]::GetFiles($importDirectory)){[IO.File]::Delete($file)};[IO.Directory]::Delete($importDirectory)}
        $detail=if($saveStarted){try{$saved=Get-Settings;'Datei nachgelesen; aktuelle Favoriten: '+@($saved.Programs).Count+'. Bitte gespeicherten Stand pruefen.'}catch{'Gespeicherter Stand konnte nicht bestaetigt werden.'}}else{'Einstellungen wurden noch nicht geschrieben.'}
        throw "Import nicht vollstaendig bestaetigt. $detail Sicherung: $backupPath. $($_.Exception.Message)"
    }
    $script:Settings=$settings
    try{Update-TaskPloppTrayText;Apply-TaskPloppIdleSettings;Show-TaskPloppView}
    catch{throw "Konfiguration gespeichert; Anzeige konnte nicht erneuert werden. Sicherung: $backupPath. $($_.Exception.Message)"}
    return $backupPath
}
function New-TaskPloppTransferPicker([switch]$Save) {
    if($Save){$picker=[Windows.Forms.SaveFileDialog]::new();$picker.DefaultExt='zip';$picker.FileName='TaskPlopp-Konfiguration.zip';$picker.OverwritePrompt=$false;$picker.CreatePrompt=$false}
    else{$picker=[Windows.Forms.OpenFileDialog]::new()}
    $picker.Filter='ZIP-Sicherung|*.zip';$picker.CheckFileExists=$false;$picker.CheckPathExists=$false;$picker.ValidateNames=$false
    return $picker
}
function Resolve-TaskPloppTransferFile([string]$Path,[switch]$Save) {
    $full=[IO.Path]::GetFullPath($Path)
    if([IO.Path]::GetExtension($full)-ine'.zip'){throw 'Bitte eine ZIP-Datei waehlen.'}
    if($Save){if(-not[IO.Directory]::Exists([IO.Path]::GetDirectoryName($full))){throw 'Der Zielordner fehlt.'};if($full-ieq[IO.Path]::GetFullPath($script:ConfigPath)){throw 'Die Konfiguration darf nicht ueberschrieben werden.'}}
    elseif(-not[IO.File]::Exists($full)){throw 'Die ausgewaehlte ZIP-Datei fehlt.'}
    return $full
}
function Select-TaskPloppTransferFile([switch]$Save) {
    $picker=New-TaskPloppTransferPicker -Save:$Save
    try{
        if($picker.ShowDialog($script:TransferDialog)-ne'OK'){return ''}
        return Resolve-TaskPloppTransferFile $picker.FileName -Save:$Save
    }finally{$picker.Dispose()}
}
function Clear-TaskPloppTransferPreparation($Dialog) {
    $Dialog.Tag.Pending=$null;$Dialog.Tag.Apply.Enabled=$false
}
function Show-TaskPloppTransfer {
    param([scriptblock]$OnShown)
    $existing=Get-Variable TransferDialog -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if($existing-and-not$existing.IsDisposed){$existing.Activate();return}
    if((Get-Variable ConfigurationOpen -Scope Script -ValueOnly -ErrorAction SilentlyContinue)-eq$true){return}
    $dialog=[Windows.Forms.Form]::new();$script:TransferDialog=$dialog
    $dialog.Text='TaskPlopp - Konfiguration sichern/uebertragen';$dialog.Icon=$script:Main.Icon
    $dialog.Size=[Drawing.Size]::new(640,400);$dialog.MinimumSize=$dialog.Size;$dialog.StartPosition='CenterParent';$dialog.Font=$script:Main.Font
    $actions=[Windows.Forms.FlowLayoutPanel]::new();$actions.Dock='Top';$actions.AutoSize=$true;$actions.MinimumSize=[Drawing.Size]::new(0,45)
    $export=[Windows.Forms.Button]::new();$export.Name='ExportSettings';$export.Text='Exportieren';$export.AutoSize=$true
    $import=[Windows.Forms.Button]::new();$import.Name='ImportSettings';$import.Text='Importieren';$import.AutoSize=$true
    $apply=[Windows.Forms.Button]::new();$apply.Name='ApplyTransfer';$apply.Text='Anwenden';$apply.AutoSize=$true;$apply.Enabled=$false
    $close=[Windows.Forms.Button]::new();$close.Name='CloseTransfer';$close.Text='Schliessen';$close.AutoSize=$true;$close.DialogResult='Cancel'
    $text=[Windows.Forms.TextBox]::new();$text.Name='TransferNotice';$text.Multiline=$true;$text.ReadOnly=$true;$text.Dock='Fill';$text.ScrollBars='Vertical'
    $text.Text='Gespeicherte Einstellungen und Verknuepfungen sichern. Import ersetzt die gesamte Konfiguration; vorher wird automatisch gesichert.'
    $dialog.Tag=[pscustomobject]@{Pending=$null;Apply=$apply}
    $actions.Controls.AddRange(@($export,$import,$apply,$close));$dialog.Controls.Add($text);$dialog.Controls.Add($actions);$dialog.CancelButton=$close;$dialog.ActiveControl=$export
    $export.Add_Click({
        Clear-TaskPloppTransferPreparation $dialog
        try{
            $path=Select-TaskPloppTransferFile -Save
            if(-not$path){$text.Text='Auswahl abgebrochen.';return}
            if([IO.File]::Exists($path)){
                $dialog.Tag.Pending=[pscustomobject]@{Kind='Export';Path=$path;Data=$null};$apply.Enabled=$true
                $text.Text="Diese ZIP-Datei existiert bereits:`r`n$path`r`n`r`nAnwenden ersetzt sie. Schliessen bricht ab."
                Set-TaskPloppMessage Notice 'Export zum Ersetzen vorbereitet' $path;return
            }
            $written=Write-TaskPloppTransferZip (Get-TaskPloppTransferData) $path
            $text.Text='Gesichert: '+$written;Set-TaskPloppMessage Success 'Konfiguration exportiert' $written
        }catch{$text.Text=$_.Exception.Message;Set-TaskPloppMessage Error 'Export fehlgeschlagen' $text.Text}
    })
    $import.Add_Click({
        Clear-TaskPloppTransferPreparation $dialog
        try{
            if(-not(Test-TaskPloppImportAllowed)){throw 'Import erst nach Ende von Aufnahme, Erkennung und Einrichtung moeglich.'}
            $path=Select-TaskPloppTransferFile
            if(-not$path){$text.Text='Auswahl abgebrochen.';return}
            $data=Read-TaskPloppTransferZip $path;$old=Get-TaskPloppTransferData -Snapshot
            $text.Text="Favoriten: $(@($data.Settings.Programs).Count); Verknuepfungen: $($data.Links.Count).`r`n"+((@(Get-TaskPloppTransferWarnings $data)+@($old.Notes))-join"`r`n")+"`r`n`r`nAnwenden ersetzt die gesamte Konfiguration nach vorheriger Sicherung. Schliessen bricht ab."
            $dialog.Tag.Pending=[pscustomobject]@{Kind='Import';Path=$path;Data=$data};$apply.Enabled=$true
            Set-TaskPloppMessage Notice 'Import vorbereitet' 'Vorschau pruefen und im Transferdialog Anwenden waehlen.'
        }catch{$text.Text=$_.Exception.Message;Set-TaskPloppMessage Error 'Import nicht vorbereitet' $text.Text}
    })
    $apply.Add_Click({
        $pending=$dialog.Tag.Pending
        Clear-TaskPloppTransferPreparation $dialog
        if($null-eq$pending){return}
        try{
            if($pending.Kind-eq'Import'){
                $backup=Import-TaskPloppTransfer $pending.Data
                $text.Text='Importiert. Vorherige Konfiguration gesichert: '+$backup
                Set-TaskPloppMessage Success 'Konfiguration importiert' ('Sicherung: '+$backup)
            }else{
                $written=Write-TaskPloppTransferZip (Get-TaskPloppTransferData) $pending.Path -Overwrite
                $text.Text='Gesichert: '+$written;Set-TaskPloppMessage Success 'Konfiguration exportiert' $written
            }
        }catch{$text.Text=$_.Exception.Message;Set-TaskPloppMessage Error 'Anwenden nicht vollstaendig bestaetigt' $text.Text}
    })
    if($OnShown){$dialog.Add_Shown($OnShown)}
    try{$null=$dialog.ShowDialog($script:Main)}finally{Clear-TaskPloppTransferPreparation $dialog;$dialog.Dispose();$script:TransferDialog=$null}
}
