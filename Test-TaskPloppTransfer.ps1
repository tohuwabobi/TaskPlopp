#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Reject([scriptblock]$Action,[string]$Message){$caught=$false;try{& $Action|Out-Null}catch{$caught=$true};Assert $caught $Message}
function Show-TaskPloppView {}
$root=Join-Path $env:TEMP ('TaskPlopp-transfer-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root);$script:ConfigPath=Join-Path $root 'config.json'
$script:HotkeysEnabled=$false;$script:DictationPhase='Ready'
try{
    $lnkPath=Join-Path $root 'Original.lnk';$shell=New-Object -ComObject WScript.Shell
    try{
        $lnk=$shell.CreateShortcut($lnkPath);$lnk.TargetPath=Join-Path $env:WINDIR 'explorer.exe'
        $lnk.Arguments='"C:\Kein echter Ordner"';$lnk.WorkingDirectory=$root;$lnk.IconLocation=$lnk.TargetPath+',0';$lnk.Save()
        $expected=@{TargetPath=$lnk.TargetPath;Arguments=$lnk.Arguments;WorkingDirectory=$lnk.WorkingDirectory;IconLocation=$lnk.IconLocation}
    }finally{$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($lnk);$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($shell)}
    $originalBytes=[IO.File]::ReadAllBytes($lnkPath)
    $settings=ConvertTo-TaskPloppSettings ([pscustomobject]@{ShowOpenWindows=$false;AutoLockEnabled=$false;AutoLockMinutes=17;DictationEngine='Vosk';Programs=@(
        [pscustomobject]@{Name='Profil 1';ProcessName='chrome';TitleContains='';StartKind='Path';StartTarget=$lnkPath;LaunchAlways=$true},
        [pscustomobject]@{Name='Profil 2';ProcessName='chrome';TitleContains='';StartKind='Path';StartTarget=$lnkPath;LaunchAlways=$true},
        [pscustomobject]@{Name='Fehlende EXE';ProcessName='demo';TitleContains='';StartKind='Path';StartTarget='C:\TaskPlopp-Missing-Fixture.exe'},
        [pscustomobject]@{Name='Paket';ProcessName='demo';TitleContains='';StartKind='AppId';StartTarget='Demo_xyz!App'})})
    Save-Settings $settings;$raw=[IO.File]::ReadAllBytes($script:ConfigPath)
    $data=Get-TaskPloppTransferData
    Assert ($data.Links.Count-eq1-and$data.Settings.Programs[0].StartTarget-eq'links/0001.lnk'-and$data.Settings.Programs[1].StartTarget-eq'links/0001.lnk') 'Link-Deduplizierung fehlt'
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($script:ConfigPath))-eq[Convert]::ToBase64String($raw)) 'Export veraendert aktive Config'
    $zip=Join-Path $root 'Export.zip';$null=Write-TaskPloppTransferZip $data $zip
    $package=Read-TaskPloppTransferZip $zip
    $archive=[IO.Compression.ZipFile]::OpenRead($zip)
    try{Assert ($archive.Entries.Count-eq2-and$null-eq$archive.GetEntry('manifest.json')) 'ZIP ist nicht einfach oder hat Manifest'}finally{$archive.Dispose()}
    Assert ([Convert]::ToBase64String($package.Links['links/0001.lnk'])-eq[Convert]::ToBase64String($originalBytes)) 'Linkbytes veraendert'
    Assert ($package.Settings.Programs[0].Name-eq'Profil 1'-and$package.Settings.Programs[1].Name-eq'Profil 2'-and$package.Settings.AutoLockMinutes-eq17-and$package.Settings.DictationEngine-eq'Vosk') 'Einstellungen/Reihenfolge verloren'
    $storage=Join-Path $root 'Anderer-PC';$backup=Import-TaskPloppTransfer $package $storage
    $restored=Get-Settings
    Assert ($restored.Programs[0].StartTarget-eq$restored.Programs[1].StartTarget-and$restored.Programs[0].StartTarget.StartsWith($storage)) 'Importpfade falsch'
    $shell=New-Object -ComObject WScript.Shell
    try{
        $lnk=$shell.CreateShortcut($restored.Programs[0].StartTarget)
        foreach($field in $expected.Keys){Assert ($lnk.$field-eq$expected[$field]) "LNK-Eigenschaft veraendert: $field"}
    }finally{$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($lnk);$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($shell)}
    $savedLink=$restored.Programs[0].StartTarget
    $null=Write-TaskPloppTransferZip (Get-TaskPloppTransferData) (Join-Path $root 'Wiederexport.zip')
    Assert (Test-Path -LiteralPath $backup) 'Vorimport-Sicherung fehlt'
    $backupZip=[IO.Compression.ZipFile]::OpenRead($backup)
    try{$stream=$backupZip.GetEntry('config-original.json').Open();$mem=[IO.MemoryStream]::new();try{$stream.CopyTo($mem);Assert ([Convert]::ToBase64String($mem.ToArray())-eq[Convert]::ToBase64String($raw)) 'Originalbytes nicht gesichert'}finally{$stream.Dispose();$mem.Dispose()}}finally{$backupZip.Dispose()}
    Assert (@(Get-TaskPloppTransferWarnings $package).Count-ge2) 'Fehlendes EXE-Ziel/Profilhinweis fehlt'
    Reject {Write-TaskPloppTransferZip $data $script:ConfigPath} 'Export ueberschreibt Config'
    Reject {Write-TaskPloppTransferZip $data $zip} 'Export ueberschreibt ohne Bestaetigung'
    $script:DictationPhase='Recording';Reject {Import-TaskPloppTransfer $package $storage} 'Import waehrend Aufnahme erlaubt';$script:DictationPhase='Ready'
    $script:DictationInstaller=[pscustomobject]@{};Reject {Import-TaskPloppTransfer $package $storage} 'Import waehrend Einrichtung erlaubt';$script:DictationInstaller=$null
    # Independent malformed ZIP fixtures, never extracting entry paths.
    foreach($case in 'Traversal','Duplicate','MissingLink','Unreferenced','InvalidJson','NoConfig'){
        $bad=Join-Path $root ($case+'.zip');$archive=[IO.Compression.ZipFile]::Open($bad,[IO.Compression.ZipArchiveMode]::Create)
        try{
            if($case-ne'NoConfig'){$json=if($case-eq'InvalidJson'){'{bad'}else{$package.Settings|ConvertTo-Json -Depth 8};Write-TaskPloppZipEntry $archive config.json ([Text.Encoding]::UTF8.GetBytes($json))}
            if($case-eq'Duplicate'){Write-TaskPloppZipEntry $archive config.json ([byte[]]@(123,125))}
            if($case-eq'Traversal'){Write-TaskPloppZipEntry $archive '../outside.lnk' $originalBytes}
            if($case-eq'Unreferenced'){Write-TaskPloppZipEntry $archive 'links/9999.lnk' $originalBytes}
        }finally{$archive.Dispose()}
        Reject {Read-TaskPloppTransferZip $bad} "Defektes Paket akzeptiert: $case"
    }
    # A valid restore must work despite invalid old JSON and missing old links.
    [IO.File]::WriteAllText($script:ConfigPath,'{kaputt',[Text.UTF8Encoding]::new($true));$damagedRaw=[IO.File]::ReadAllBytes($script:ConfigPath)
    $damagedBackup=Import-TaskPloppTransfer $package $storage
    Reject {Read-TaskPloppTransferZip $damagedBackup} 'Rohsnapshot als gueltiges Importpaket behandelt'
    $archive=[IO.Compression.ZipFile]::OpenRead($damagedBackup)
    try{$stream=$archive.GetEntry('config-original.json').Open();$mem=[IO.MemoryStream]::new();try{$stream.CopyTo($mem);Assert ([Convert]::ToBase64String($mem.ToArray())-eq[Convert]::ToBase64String($damagedRaw)) 'Beschaedigte Originalbytes verloren'}finally{$stream.Dispose();$mem.Dispose()}}finally{$archive.Dispose()}
    $broken=Get-Settings;$broken.Programs[0].StartTarget=Join-Path $root 'Missing.lnk';Save-Settings $broken
    $null=Import-TaskPloppTransfer $package $storage
    # Exercise exceptions before and immediately after the real atomic save.
    $save=${function:Save-TaskPloppSettingsWithHotkey};$before=[IO.File]::ReadAllBytes($script:ConfigPath)
    function Save-TaskPloppSettingsWithHotkey($Settings){throw 'Fixture vor Save'}
    Reject {Import-TaskPloppTransfer $package $storage} 'Schreibfehler verschluckt'
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($script:ConfigPath))-eq[Convert]::ToBase64String($before)) 'Vor-Save-Fehler veraendert Config'
    function Save-TaskPloppSettingsWithHotkey($Settings){Save-Settings $Settings;throw 'Fixture nach Save'}
    Reject {Import-TaskPloppTransfer $package $storage} 'Nach-Save-Fehler verschluckt'
    $written=Get-Settings
    Assert (Test-Path -LiteralPath $written.Programs[0].StartTarget) 'Nach-Save-Fehler loescht aktive Linkkopie'
    Set-Item Function:\Save-TaskPloppSettingsWithHotkey $save
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($lnkPath))-eq[Convert]::ToBase64String($originalBytes)) 'Originalverknuepfung ueberschrieben'
    'OK: ZIP/LNK-Roundtrip, Reihenfolge, Deduplizierung, exakte Originalbytes/Eigenschaften, Wiederexport, Vorschauhinweise, defekte Pakete, Importsperre, Rohsicherung und Vor-/Nach-Save-Fehler.'
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-transfer-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
