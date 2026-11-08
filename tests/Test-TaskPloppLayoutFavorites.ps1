#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.Native.ps1')
$null=[TaskPloppInterop.Geometry]::SetThreadDpiAwarenessContext([IntPtr](-4))
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
$root=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('TaskPlopp-layout-favorites-'+[guid]::NewGuid().ToString('N'))))
$null=[IO.Directory]::CreateDirectory($root)
$fixture=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'fixtures\TaskPloppLayoutFixture.ps1'))
$shell=New-Object -ComObject WScript.Shell
$monitor=@(Get-TaskPloppLayoutMonitors)[0]
function Favorite([string]$Token,[string]$Mode='Window',[switch]$Minimized){
    $linkPath=Join-Path $root ($Token+'-'+$Mode+'.lnk');$link=$shell.CreateShortcut($linkPath)
    try{
        $link.TargetPath=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $link.Arguments='-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$fixture+'" -Token "'+$Token+'" -Mode '+$Mode+' -Signal "'+(Join-Path $root ($Token+'.signal'))+'"'
        if($Minimized){$link.Arguments+=' -Minimized -InitiallyMaximized'}
        $link.WorkingDirectory=$root;$link.Save()
    }finally{[void][Runtime.InteropServices.Marshal]::ReleaseComObject($link)}
    [pscustomobject]@{Name=$Token;ProcessName='powershell';TitleContains=$Token;ExecutablePath='';AppId='';FolderPath='';StartKind='Path';StartTarget=$linkPath;LaunchAlways=$false}
}
function Context([object[]]$Favorites){$i=0;[pscustomobject]@{Monitors=@(Get-TaskPloppLayoutMonitors);ParentProcessId=0;Windows=@();Favorites=@(foreach($f in $Favorites){$i++;[pscustomobject]@{id="f$i";Name=$f.Name;Favorite=$f}})}}
function Answer([string[]]$Ids=@('f1')){[pscustomobject]@{reason='Owned favorite fixtures';windows=@(foreach($id in $Ids){[pscustomobject]@{id=$id;state='normal';monitorId=$monitor.id;x=($monitor.work.x+40);y=($monitor.work.y+50);width=640;height=480}})}}
function Worker([string]$Mode,$Request){
    $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),('-NoProfile -STA -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot '..\src\TaskPlopp.WindowLayoutWorker.ps1')+'" -Mode '+$Mode))
    $bytes=[Text.Encoding]::UTF8.GetBytes(($Request|ConvertTo-Json -Depth 12 -Compress));$job=New-TaskPloppProcess $info $bytes
    try{
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while(-not$job.Done){[Windows.Forms.Application]::DoEvents();Update-TaskPloppProcess $job;Start-Sleep -Milliseconds 15;if($watch.Elapsed.TotalSeconds-gt35){throw 'Fixture worker timeout'}}
        if(-not$job.Text){throw $job.Error};$job.Text|ConvertFrom-Json
    }finally{Close-TaskPloppProcess $job}
}
function Matching([string]$Token){@(Get-AppWindows|Where-Object {$_.ProcessName-eq'powershell'-and$_.Title.IndexOf($Token,[StringComparison]::Ordinal)-ge0})}
function Wait-OwnWindow([string]$Token){
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do{$found=@(Matching $Token);if($found.Count){return $found[0]};Start-Sleep -Milliseconds 50}while($watch.Elapsed.TotalSeconds-lt10)
    throw 'Owned fixture did not open'
}
function CatalogProbe($Form,$Favorite){
    function Get-AppWindows {param([switch]$Raw) [pscustomobject]@{Handle=$Form.Handle;Title=$Form.Text;ProcessId=$PID;ProcessName='powershell';ExecutablePath='';AppId='';FolderPath=''}}
    function Get-TaskPloppLayoutRect {throw 'MINIMIZED_DWM_MUST_NOT_BE_READ'}
    $catalog=Get-TaskPloppLayoutContext 0 @($Favorite)
    Assert ($catalog.Windows.Count-eq1-and$catalog.Windows[0].minimized-and$null-eq$catalog.Windows[0].x-and$catalog.Favorites.Count-eq1) 'Minimized window/Favorite lost from catalog'
}
$profiles=[pscustomobject]@{Favorites=@([pscustomobject]@{id='f1';Name='Chrome Arbeit';Favorite=[pscustomobject]@{ProcessName='chrome'}},[pscustomobject]@{id='f2';Name='Chrome Privat';Favorite=[pscustomobject]@{ProcessName='chrome'}})}
$a=Select-TaskPloppLayoutNamedFavorites (Answer) $profiles 'Maximiere Chrome.'
Assert ($a.windows.Count-eq0-and$a.reason-like'*Chrome Arbeit*'-and$a.reason-like'*Chrome Privat*') 'Ambiguous profile accepted'
$a=Select-TaskPloppLayoutNamedFavorites (Answer) $profiles 'Maximiere Chrome Arbeit.'
Assert ($a.windows.Count-eq1) 'Named profile rejected'
Write-Host 'OK: ambiguous profile omitted, explicit name retained.'
$form=[Windows.Forms.Form]::new()
try{
    $form.Text='Owned catalog probe';$form.Show();$form.WindowState='Minimized';[Windows.Forms.Application]::DoEvents()
    $f=Favorite ('tp-'+[guid]::NewGuid().ToString('N'))
    CatalogProbe $form $f
    function EmptyCatalogProbe($Favorite){function Get-AppWindows {param([switch]$Raw) @()};$c=Get-TaskPloppLayoutContext 0 @($Favorite);Assert ($c.Windows.Count-eq0-and$c.Favorites.Count-eq1) 'Closed-only favorite catalog is empty'}
    EmptyCatalogProbe $f
    $c=Context @($f);$a=Answer;Assert-TaskPloppLayout $a $c
    $public=@(Get-TaskPloppLayoutPublicFavorites $c)|ConvertTo-Json -Depth 5 -Compress
    Assert (-not$public.Contains($f.StartTarget)-and$public-notmatch'StartTarget|ExecutablePath|FolderPath') 'Private launch data leaked into AI catalog'
    $bad=$a|ConvertTo-Json -Depth 8|ConvertFrom-Json;$bad.windows[0].state='minimized'
    $rejected=$false;try{Assert-TaskPloppLayout $bad $c}catch{$rejected=$true};Assert $rejected 'Unknown state accepted'
    $bad.windows[0].state='maximized';$rejected=$false;try{Assert-TaskPloppLayout $bad $c}catch{$rejected=$true};Assert $rejected 'Maximized partial work rectangle accepted'
    Write-Host 'OK: Minimized catalog without DWM bounds, favorites without windows, known favorite IDs, state/maximize contract.'

    $result=Worker Apply @{Answer=$a;Context=$c}
    Assert ($result.Ok-and$result.Started-eq1-and$result.Applied-eq1-and$result.Mutated-eq1) ('Favorite launch failed: '+($result|ConvertTo-Json -Depth 5 -Compress))
    $first=$result.Snapshots[0].Window;$firstHandle=[IntPtr][long]$first.Handle
    $alias=Context @($f);$alias.Windows=@($first);$alias.Windows[0].id='w1'
    $duplicate=Worker Apply @{Answer=(Answer @('w1','f1'));Context=$alias}
    Assert ($duplicate.Mutated-eq0-and$duplicate.Started-eq0-and$duplicate.Warnings-ge1) 'Favorite/window alias moved twice'
    $undo=Worker Undo @{Snapshots=@($result.Snapshots)}
    Assert ($undo.Restored-eq1-and[TaskPloppInterop.User]::IsWindow($firstHandle)) 'Undo closed newly started app'
    $null=[TaskPloppInterop.User]::ShowWindowAsync($firstHandle,3);Start-Sleep -Milliseconds 100
    $null=[TaskPloppInterop.User]::ShowWindowAsync($firstHandle,6);Start-Sleep -Milliseconds 100
    $result=Worker Apply @{Answer=$a;Context=$c}
    Assert ($result.Started-eq0-and$result.Applied-eq1-and$result.Snapshots[0].Window.Handle-eq$first.Handle) 'Minimized favorite not reused'
    $undo=Worker Undo @{Snapshots=@($result.Snapshots)};Assert ($undo.Restored-eq1-and[TaskPloppInterop.User]::IsIconic($firstHandle)) 'Reused minimized favorite undo failed'
    $f.LaunchAlways=$true;$c=Context @($f)
    $result=Worker Apply @{Answer=$a;Context=$c}
    Assert ($result.Started-eq1-and$result.Applied-eq1-and$result.Snapshots[0].Window.Handle-ne$first.Handle-and@(Matching $f.Name).Count-eq2) 'LaunchAlways not executed once/new target wrong'
    Assert ([TaskPloppInterop.User]::IsIconic($firstHandle)) 'Other profile fixture restored'
    $undo=Worker Undo @{Snapshots=@($result.Snapshots)};Assert ($undo.Restored-eq1) 'New LaunchAlways fixture undo failed'

    $token='tp-'+[guid]::NewGuid().ToString('N');$seed=Favorite $token -Minimized
    Start-FavoriteApplication $seed;$old=Wait-OwnWindow $token;$oldHandle=$old.Handle
    for($i=0;$i-lt100-and-not[TaskPloppInterop.User]::IsIconic($oldHandle);$i++){Start-Sleep -Milliseconds 20}
    $launcher=Favorite $token Launcher;$launcher.LaunchAlways=$true
    $result=Worker Apply @{Answer=(Answer);Context=(Context @($launcher))}
    Assert ($result.Applied-eq1-and$result.Started-eq1-and$result.Snapshots[0].Window.Handle-eq$oldHandle.ToInt64()) 'Launcher reuse not resolved'
    $launcherId=[int][IO.File]::ReadAllText((Join-Path $root ($token+'.signal.launcherPid')))
    Assert ($launcherId-ne$result.Snapshots[0].Window.OwnerId) 'Start PID confused with real window owner'
    $undo=Worker Undo @{Snapshots=@($result.Snapshots)}
    Assert ($undo.Restored-eq1-and[TaskPloppInterop.User]::IsIconic($oldHandle)) 'Pre-launch minimized state lost'
    $null=[TaskPloppInterop.User]::ShowWindowAsync($oldHandle,9);Start-Sleep -Milliseconds 100
    Assert ([TaskPloppInterop.Geometry]::IsZoomed($oldHandle)) 'Pre-launch restore-to-maximized flag lost'
    Write-Host 'OK: Real LNK start/parameters, reuse without launch, LaunchAlways once, unique new window, launcher/owner PID distinction, pre-launch undo and new app stays open.'

    $partial=Favorite ('tp-'+[guid]::NewGuid().ToString('N'))
    $missing=[pscustomobject]@{Name='Not installed fixture';ProcessName='does-not-exist';TitleContains='';ExecutablePath='';AppId='Fixture.NotInstalled!App';FolderPath='';StartKind='AppId';StartTarget='Fixture.NotInstalled!App';LaunchAlways=$false}
    $result=Worker Apply @{Answer=(Answer @('f1','f2'));Context=(Context @($partial,$missing))}
    Assert ($result.Ok-and$result.Started-eq1-and$result.Mutated-eq0-and$result.Warnings-ge1) 'Partial launch result not truthful'
    $opened=Wait-OwnWindow $partial.Name;$raw=Get-TaskPloppLayoutRect $opened.Handle -Raw
    Assert ($raw.Width-eq500-and$raw.Height-eq360) 'Geometry mutated after preparation failure'
    $missing.StartKind='Path';$missing.StartTarget=Join-Path $root 'missing.lnk'
    $neverStarted=Favorite ('tp-'+[guid]::NewGuid().ToString('N'))
    $result=Worker Apply @{Answer=(Answer @('f1','f2'));Context=(Context @($neverStarted,$missing))}
    Assert ($result.Started-eq0-and@(Matching $neverStarted.Name).Count-eq0) 'Invalid start target did not prevalidate whole plan'

    $slow=Favorite ('tp-'+[guid]::NewGuid().ToString('N')) NoWindow
    $resolution=Resolve-TaskPloppLayoutTargets (Answer) (Context @($slow)) 700
    Assert ($resolution.Started-eq1-and$resolution.Issues.Count-ge1-and$null-eq$resolution.Entries[0].Window) 'No-window wait budget not reported'
    function AmbiguityProbe($Forms,$Favorite){
        $phase=@{Started=$false;Weak=$false;Calls=0}
        function Get-AppWindows {param([switch]$Raw) if($phase.Started-or$phase.Weak){foreach($item in $Forms){[pscustomobject]@{Handle=$item.Handle;Title=$Favorite.Name;ProcessId=$PID;ProcessName='powershell';ExecutablePath='';AppId='';FolderPath=''}}}}
        function Start-FavoriteApplication {param($Favorite,[switch]$Preview) if(-not$Preview){$phase.Started=$true;$phase.Calls++}}
        $ctx=Context @($Favorite);$resolution=Resolve-TaskPloppLayoutTargets (Answer) $ctx 1000
        Assert ($resolution.Issues.Count-ge1-and$phase.Calls-eq1-and$null-eq$resolution.Entries[0].Window) 'Multiple new windows guessed'
        $phase.Started=$false;$phase.Weak=$true;$phase.Calls=0;$Favorite.TitleContains=''
        $resolution=Resolve-TaskPloppLayoutTargets (Answer) (Context @($Favorite)) 1000
        Assert ($resolution.Issues.Count-ge1-and$phase.Calls-eq0) 'Ambiguous weak old matches guessed/launched'
    }
    $extra=[Windows.Forms.Form]::new()
    try{$form.WindowState='Normal';$extra.Show();[Windows.Forms.Application]::DoEvents();AmbiguityProbe @($form,$extra) $neverStarted}finally{$extra.Dispose()}
    Write-Host 'OK: Failed second launch leaves first app open without geometry; missing target prevalidated; bounded no-window polling.'
}finally{
    $form.Dispose();[void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    # Only fixture processes whose command line contains this exact unique temporary root.
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine-and$_.CommandLine.Contains($fixture)-and$_.CommandLine.Contains($root)}|ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-layout-favorites-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
