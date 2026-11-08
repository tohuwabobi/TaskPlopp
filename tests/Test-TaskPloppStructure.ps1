#requires -Version 5.1
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $project 'src\TaskPlopp.Paths.ps1')
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
$root=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('TaskPlopp-structure-'+[guid]::NewGuid().ToString('N'))))
$null=[IO.Directory]::CreateDirectory($root)
function Fixture([string]$Name){$p=Join-Path $root $Name;$null=[IO.Directory]::CreateDirectory($p);return $p}
function Text([string]$Path,[string]$Value){$null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,$Value,[Text.UTF8Encoding]::new($true))}
function Same([string]$Path,[byte[]]$Bytes){[Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))-ceq[Convert]::ToBase64String($Bytes)}
function Child([string]$File,[string]$Arguments=''){
    $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),('-NoProfile -STA -ExecutionPolicy Bypass -File "'+$File+'" '+$Arguments))
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WorkingDirectory=$env:TEMP;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $p=[Diagnostics.Process]::Start($info);$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
    try{if(-not$p.WaitForExit(15000)){$p.Kill();throw 'Child timeout'};if($p.ExitCode-ne0){throw ('Child failed: '+$stderr.GetAwaiter().GetResult())};$stdout.GetAwaiter().GetResult()}finally{$p.Dispose()}
}
try{
    $fresh=Fixture fresh;$result=Initialize-TaskPloppData $fresh
    Assert ($result.ConfigPath-eq(Join-Path $fresh 'data\config.json')-and-not[IO.File]::Exists($result.ConfigPath)) ('Fresh install path wrong: '+($result|ConvertTo-Json -Compress)+' expected '+(Join-Path $fresh 'data\config.json'))
    $old=Fixture legacy;$legacy=Join-Path $old 'config.json';Text $legacy '{"ShowOpenWindows":false,"Programs":[]}'
    $bytes=[IO.File]::ReadAllBytes($legacy);Text (Join-Path $old 'config.before-first.json') 'original backup'
    Text (Join-Path $old 'data\backups\config.before-first.json') 'existing backup'
    Text (Join-Path $old 'config.before-first.sync-conflict-test.json') 'untouched conflict'
    $result=Initialize-TaskPloppData $old
    Assert ((Same $result.ConfigPath $bytes)-and-not[IO.File]::Exists($legacy)) 'Legacy config changed or not moved'
    Assert (@(Get-ChildItem (Join-Path $old 'data\backups')).Count-eq2) 'Backup collision lost content'
    Assert ([IO.File]::Exists((Join-Path $old 'config.before-first.sync-conflict-test.json'))) 'Conflict file moved'
    $count=@(Get-ChildItem $old -Recurse -File).Count;$again=Initialize-TaskPloppData $old
    Assert (@(Get-ChildItem $old -Recurse -File).Count-eq$count-and$again.Notice-eq'') 'Migration not idempotent'
    foreach($same in @($false,$true)){
        $both=Fixture ('both-'+$same);Text (Join-Path $both 'config.json') 'legacy';Text (Join-Path $both 'data\config.json') $(if($same){'legacy'}else{'canonical'})
        $before=[IO.File]::ReadAllBytes((Join-Path $both 'data\config.json'));$oldBytes=[IO.File]::ReadAllBytes((Join-Path $both 'config.json'))
        $result=Initialize-TaskPloppData $both
        Assert (Same $result.ConfigPath $before) 'Existing canonical overwritten'
        $archive=@(Get-ChildItem (Join-Path $both 'data\legacy') -File)
        Assert ($archive.Count-eq1-and(Same $archive[0].FullName $oldBytes)-and$result.Notice) 'Legacy duplicate not preserved/noticed'
    }
    $blocked=Fixture locked;$legacy=Join-Path $blocked 'config.json';Text $legacy 'locked original'
    $lock=[IO.File]::Open($legacy,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{$result=Initialize-TaskPloppData $blocked}finally{$lock.Dispose()}
    Assert ($result.ConfigPath-eq$legacy-and[IO.File]::ReadAllText($legacy)-eq'locked original'-and$result.Notice) 'Move failure did not preserve fallback'
    Write-Host 'OK: Fresh/legacy data, byte equality, collision backups, conflicts untouched, canonical+legacy preserved, idempotence, locked-source fallback.'

    $copy=Fixture 'project with spaces'
    foreach($folder in @('src','tools','assets')){Copy-Item -LiteralPath (Join-Path $project $folder) -Destination (Join-Path $copy $folder) -Recurse}
    Copy-Item -LiteralPath (Join-Path $project 'Start-TaskPlopp.ps1') -Destination $copy
    Text (Join-Path $copy 'config.json') '{"ShowOpenWindows":false,"AutoLockEnabled":false,"Programs":[]}'
    $before=[IO.File]::ReadAllBytes((Join-Path $copy 'config.json'))
    $null=Child (Join-Path $copy 'src\TaskPlopp.ps1') -Arguments '-LibraryOnly'
    Assert ((Same (Join-Path $copy 'config.json') $before)-and-not[IO.File]::Exists((Join-Path $copy 'data\config.json'))) 'LibraryOnly migrated data'
    $null=Child (Join-Path $copy 'Start-TaskPlopp.ps1') -Arguments '-LibraryOnly'
    $override=Join-Path $copy 'explicit.json';Text $override '{"ShowOpenWindows":false,"AutoLockEnabled":false,"Programs":[]}'
    $null=Child (Join-Path $copy 'src\TaskPlopp.ps1') -Arguments ('-SmokeTest -ConfigFile "'+$override+'"')
    $null=Child (Join-Path $copy 'src\TaskPlopp.ps1') -Arguments ('-ResidentTest -ConfigFile "'+$override+'"')
    Assert ((Same (Join-Path $copy 'config.json') $before)-and-not[IO.File]::Exists((Join-Path $copy 'data\config.json'))) 'Test/config override migrated real defaults'
    $created=$false;$wake=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,'Local\TaskPlopp-Wake',[ref]$created)
    try{
        if($created){$null=Child (Join-Path $copy 'Start-TaskPlopp.ps1');Assert ($wake.WaitOne(1000)-and(Same (Join-Path $copy 'config.json') $before)) 'Running-instance wake moved data'}
        else{Write-Host 'SKIP: Running-instance fixture; real resident instance exists.'}
    }finally{$wake.Dispose()}
    $shortcut=Join-Path $copy 'Desktop test.lnk'
    $null=Child (Join-Path $copy 'tools\Install-Shortcut.ps1') -Arguments ('-Update -ShortcutPath "'+$shortcut+'"')
    $shell=New-Object -ComObject WScript.Shell;$link=$null
    try{
        $link=$shell.CreateShortcut($shortcut)
        Assert ($link.Arguments-like('*-File "'+(Join-Path $copy 'Start-TaskPlopp.ps1')+'"')-and$link.WorkingDirectory-eq$copy-and$link.IconLocation-like('*'+(Join-Path $copy 'assets\TaskPlopp.ico')+'*')) 'Shortcut points inside tools or lost root/icon'
        $link.Arguments='-File "C:\another-project.ps1"';$link.Save()
        $caught=$false;try{$null=Child (Join-Path $copy 'tools\Install-Shortcut.ps1') -Arguments ('-Update -ShortcutPath "'+$shortcut+'"')}catch{$caught=$true}
        Assert $caught 'Foreign shortcut overwritten'
    }finally{if($link){[void][Runtime.InteropServices.Marshal]::ReleaseComObject($link)};[void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)}
    Write-Host 'OK: Space-containing project, arbitrary cwd, library/root start, smoke/resident/config override skip migration, wake existing app, isolated installer shortcut and foreign-link protection.'
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-structure-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
