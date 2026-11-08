#requires -Version 5.1
param([switch]$Api)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TaskPlopp.Native.ps1')
$null=[TaskPloppInterop.Geometry]::SetThreadDpiAwarenessContext([IntPtr](-4))
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Reject($Action,[string]$Expected){try{&$Action;throw 'NOT_REJECTED'}catch{Assert ($_.Exception.Message-eq$Expected) ('Expected '+$Expected+', got '+$_.Exception.Message)}}
$virtual=[pscustomobject]@{Monitors=@([pscustomobject]@{id='left';work=[pscustomobject]@{x=-1920;y=0;width=1920;height=1040}});Windows=@([pscustomobject]@{id='w1'})}
$answer='{"reason":"Test","windows":[{"id":"w1","monitorId":"left","x":-1800,"y":20,"width":900,"height":900}]}'|ConvertFrom-Json
Assert-TaskPloppLayout $answer $virtual
$answer.windows[0].x=-2000;Reject {Assert-TaskPloppLayout $answer $virtual} INVALID_LAYOUT
$answer.windows[0].x=-1800;$answer.windows+=@($answer.windows[0]);Reject {Assert-TaskPloppLayout $answer $virtual} INVALID_LAYOUT
$answer.windows=@();Assert-TaskPloppLayout $answer $virtual
foreach($bad in @(
    '{"reason":"Test","windows":[{"id":"unknown","monitorId":"left","x":-1800,"y":20,"width":900,"height":900}]}',
    '{"reason":"Test","windows":[{"id":"w1","monitorId":"missing","x":-1800,"y":20,"width":900,"height":900}]}',
    '{"reason":"Test","windows":[{"id":"w1","monitorId":"left","x":-1800,"y":20,"width":0,"height":900}]}',
    '{"reason":"Test","windows":[{"id":"w1","monitorId":"left","x":-1800,"y":20,"width":900.5,"height":900}]}',
    '{"reason":"Test","windows":[{"id":"w1","monitorId":"left","x":-1800,"y":20,"width":900,"height":900,"extra":"reject"}]}')){Reject {Assert-TaskPloppLayout ($bad|ConvertFrom-Json) $virtual} INVALID_LAYOUT}
foreach($response in @('{"status":"incomplete","output":[]}','{"status":"completed","output":[{"type":"message","content":[{"type":"refusal"}]}]}','{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"broken"}]}]}')){Reject {ConvertFrom-TaskPloppLayoutResponse ($response|ConvertFrom-Json)} API_RESPONSE}
Write-Host 'OK: Negative coordinates, bounds, duplicate IDs, empty layout, incomplete/refused/malformed responses.'
function Run-Worker([string]$Mode,$Request){
    $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),('-NoProfile -STA -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'TaskPlopp.WindowLayoutWorker.ps1')+'" -Mode '+$Mode))
    $bytes=[Text.Encoding]::UTF8.GetBytes(($Request|ConvertTo-Json -Depth 12 -Compress));$job=New-TaskPloppProcess $info $bytes
    try{
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while(-not$job.Done){[Windows.Forms.Application]::DoEvents();Update-TaskPloppProcess $job;Start-Sleep -Milliseconds 15;if($watch.Elapsed.TotalSeconds-gt20){throw 'TEST_WORKER_TIMEOUT'}}
        if(-not$job.Text){throw $job.Error};$job.Text|ConvertFrom-Json
    }finally{Close-TaskPloppProcess $job}
}
$form=[Windows.Forms.Form]::new();$control=[Windows.Forms.Form]::new()
try{
    $form.Text='TaskPlopp owned editor fixture';$form.StartPosition='Manual';$form.Bounds=[Drawing.Rectangle]::new(100,100,600,400);$form.MinimumSize=[Drawing.Size]::new(300,200);$form.Show()
    $control.Text='TaskPlopp untouched fixture';$control.StartPosition='Manual';$control.Bounds=[Drawing.Rectangle]::new(800,100,500,400);$control.Show();[Windows.Forms.Application]::DoEvents()
    $original=Get-TaskPloppLayoutRect $form.Handle -Raw;$untouched=Get-TaskPloppLayoutRect $control.Handle -Raw
    $identity=Get-TaskPloppLayoutIdentity $form.Handle;$identity|Add-Member NoteProperty id 'w1'
    $context=[pscustomobject]@{Monitors=@(Get-TaskPloppLayoutMonitors);Windows=@($identity)};$monitor=$context.Monitors[0]
    $answer=[pscustomobject]@{reason='Fixture';windows=@([pscustomobject]@{id='w1';monitorId=$monitor.id;x=($monitor.work.x+50);y=($monitor.work.y+60);width=700;height=500})}
    $result=Run-Worker Apply @{Answer=$answer;Context=$context}
    Assert $result.Ok ('Apply failed: '+($result|ConvertTo-Json -Compress));Assert ($result.Mutated-eq1-and$result.Applied-eq1) 'Wrong apply counts'
    $rect=Get-TaskPloppLayoutRect $form.Handle;Assert ($rect.X-eq$answer.windows[0].x-and$rect.Width-eq700-and$rect.Height-eq500) 'Visible bounds mismatch'
    Assert ((Get-TaskPloppLayoutRect $control.Handle -Raw)-eq$untouched) 'Unrelated window moved'
    $undo=Run-Worker Undo @{Snapshots=@($result.Snapshots)};Assert ($undo.Restored-eq1) 'Normal undo failed'
    Assert ((Get-TaskPloppLayoutRect $form.Handle -Raw)-eq$original) 'Original normal bounds not restored'
    $form.WindowState='Maximized';[Windows.Forms.Application]::DoEvents()
    $result=Run-Worker Apply @{Answer=$answer;Context=$context};Assert ($result.Applied-eq1) 'Maximized apply failed'
    $undo=Run-Worker Undo @{Snapshots=@($result.Snapshots)};Assert ($undo.Restored-eq1-and[TaskPloppInterop.Geometry]::IsZoomed($form.Handle)) 'Maximized undo failed'
    $form.WindowState='Normal';$form.MinimumSize=[Drawing.Size]::new(900,600);[Windows.Forms.Application]::DoEvents()
    $result=Run-Worker Apply @{Answer=$answer;Context=$context};Assert ($result.Mutated-eq1-and$result.Warnings-ge1-and$result.Applied-eq0) 'Native minimum not reported'
    $undo=Run-Worker Undo @{Snapshots=@($result.Snapshots)};Assert ($undo.Restored-eq1) 'Partial apply undo failed'
    $stale=$context|ConvertTo-Json -Depth 8|ConvertFrom-Json;$stale.Windows[0].Started='wrong'
    $before=Get-TaskPloppLayoutRect $form.Handle -Raw
    $failure=Run-Worker Apply @{Answer=$answer;Context=$stale}
    Assert (-not$failure.Ok-and$failure.Code-eq'STALE_WINDOWS'-and(Get-TaskPloppLayoutRect $form.Handle -Raw)-eq$before) 'Stale window mutated'
    $changed=$context|ConvertTo-Json -Depth 8|ConvertFrom-Json;$changed.Monitors[0].width++
    $failure=Run-Worker Apply @{Answer=$answer;Context=$changed}
    Assert (-not$failure.Ok-and$failure.Code-eq'MONITORS_CHANGED'-and(Get-TaskPloppLayoutRect $form.Handle -Raw)-eq$before) 'Changed monitor mutated windows'
    # Capture only an owned white client region, never the desktop surrounding it.
    $form.BackColor=[Drawing.Color]::White;$form.TopMost=$true;$form.BringToFront();[Windows.Forms.Application]::DoEvents()
    $point=$form.PointToScreen([Drawing.Point]::new(20,20))
    try{
        $pictures=@(Get-TaskPloppLayoutPictures @([pscustomobject]@{id='fixture';x=$point.X;y=$point.Y;width=160;height=80}))
        $bytes=[Convert]::FromBase64String($pictures[0].url.Substring('data:image/png;base64,'.Length));$memory=[IO.MemoryStream]::new($bytes);$image=[Drawing.Bitmap]::new($memory)
        try{Assert ($image.Width-eq160-and$image.Height-eq80-and$image.GetPixel(80,40).ToArgb()-eq[Drawing.Color]::White.ToArgb()) 'Owned screenshot pixels not proven'}finally{$image.Dispose();$memory.Dispose()}
        Write-Host 'OK: Owned white fixture screenshot encoded in RAM; no surrounding desktop capture or image file.'
    }catch{if($_.Exception.Message-notin@('CAPTURE_FAILED','Owned screenshot pixels not proven')){throw};Write-Host ('SKIP: Owned fixture screenshot not verifiable on this desktop ('+$_.Exception.Message+'); real capture remains a manual check.')}
    Write-Host 'OK: Real PS5.1 worker, physical visible bounds, untouched control, normal/maximized undo, minimum-size partial result, stale identity.'
}finally{$form.Dispose();$control.Dispose()}
$config=Join-Path $env:TEMP ('TaskPlopp-layout-ui-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($config,'{"Programs":[],"ShowOpenWindows":false,"AutoLockEnabled":false}',[Text.UTF8Encoding]::new($true))
$global:LayoutUiFailure=$null
try{
    . (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -SmokeTest -ConfigFile $config -OnShown {
        param($sender,$args)
        $smokeTimer.Stop()
        try{
            function Get-AppWindows {param([switch]$Raw) @()}
            $script:DictationPurpose='Layout';$script:DictationPhase='Recording';Show-TaskPloppDictationStatus
            Update-TaskPloppActivity 0.5 2
            Assert ($script:MessageBar.Tag.Lines[0]-like'Sag mir*') 'Recording caption overwritten'
            function Start-TaskPloppLayoutPlan([string]$Intent){$script:TestLayoutIntent=$Intent}
            function Set-TaskPloppDictationClipboard([string]$Text){throw 'LAYOUT_MUST_NOT_COPY'}
            $script:DictationPendingText='Existing clipboard retry';$script:DictationPhase='Transcribing'
            $script:DictationJob=[pscustomobject]@{Done=$true;Disposed=$true;Text='Editor und Browser nebeneinander';Error=''}
            Invoke-TaskPloppDictationTick
            Assert ($script:TestLayoutIntent-eq'Editor und Browser nebeneinander'-and$script:DictationPendingText-eq'Existing clipboard retry') 'Layout result routed to clipboard'
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $dialog.Controls.Find('WindowLayoutModel',$true)[0].Text='gpt-4.1-mini'
                $dialog.Controls.Find('SaveSettings',$true)[0].PerformClick()
            }
            Assert ((Get-Settings -Path $config).WindowLayoutModel-eq'gpt-4.1-mini') 'Model not persisted'
            $sender.Hide();$script:LayoutCapturing=$true;Show-TaskPlopp
            Assert (-not$sender.Visible) 'Hotkey reopens GUI before capture completes'
            $script:LayoutCapturing=$false;$sender.Show()
            foreach($code in @('HTTP_401','HTTP_429','HTTP_500','API_TIMEOUT','KEY_UNAVAILABLE','CAPTURE_FAILED','MONITORS_CHANGED')){
                $text='CaptureDone'+"`n"+(@{Ok=$false;Code=$code}|ConvertTo-Json -Compress)+"`n"
                $reader=[IO.StringReader]::new($text);$errors=[IO.StringReader]::new('')
                $process=[pscustomobject]@{HasExited=$true;StandardOutput=$reader};$process|Add-Member ScriptMethod Dispose {}
                $script:LayoutMode='Plan';$sender.Hide()
                $script:LayoutJob=[pscustomobject]@{Process=$process;Output=$reader.ReadLineAsync();Errors=$errors.ReadToEndAsync();Write=[Threading.Tasks.Task]::Delay(0);InputClosed=$true;Result=$null;Watch=[Diagnostics.Stopwatch]::StartNew()}
                Invoke-TaskPloppLayoutTick
                Assert ($null-eq$script:LayoutJob-and$sender.Visible-and$script:MessageBar.Tag.Lines[0]-like'*nicht abschliessen*') ('Bad status or stuck job '+$code)
                $reader.Dispose();$errors.Dispose()
            }
            # A real harmless worker proves cancellation kills the process and cannot apply later.
            $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),'-NoProfile -Command "Start-Sleep -Seconds 30"')
            $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$process=[Diagnostics.Process]::Start($info);$workerId=$process.Id
            $script:LayoutJob=[pscustomobject]@{Process=$process;Write=[Threading.Tasks.Task]::Delay(0)};$script:LayoutMode='Plan'
            Cancel-TaskPloppWindowLayout
            Assert ($null-eq$script:LayoutJob) 'Cancelled worker retained'
            for($i=0;$i-lt40-and(Get-Process -Id $workerId -ErrorAction SilentlyContinue);$i++){Start-Sleep -Milliseconds 25}
            Assert ($null-eq(Get-Process -Id $workerId -ErrorAction SilentlyContinue)) 'Cancelled worker still alive'
            $script:LayoutJob=[pscustomobject]@{CommitFixture=$true};$script:LayoutMode='Apply'
            Cancel-TaskPloppWindowLayout;Assert ($null-ne$script:LayoutJob) 'Apply killed by Escape'
            $sender.Close();Assert ($script:LayoutClosePending-and-not$sender.IsDisposed) 'Close not deferred during Apply'
            $script:LayoutJob=$null;$script:LayoutMode='';$script:LayoutClosePending=$false
            Write-Host 'OK: GUI capture marker/errors, local transcript dispatch without clipboard, caption, model setting, real cancellation, deferred Apply close.'
        }catch{$global:LayoutUiFailure=$_}
        finally{$script:LayoutJob=$null;$script:LayoutMode='';$script:DictationPhase='Ready';$script:DictationRecorder=$null;$sender.Close()}
    }
    if($global:LayoutUiFailure){throw $global:LayoutUiFailure}
}finally{[IO.File]::Delete($config)}
if($Api){
    # Synthetic data only: no desktop capture, real titles, microphone or clipboard.
    $context=[pscustomobject]@{Monitors=@([pscustomobject]@{id='m1';x=0;y=0;width=1920;height=1080;work=[pscustomobject]@{x=0;y=0;width=1920;height=1040}});Windows=@(
        [pscustomobject]@{id='w1';Title='Report editor';ProcessName='editor';monitorId='m1';maximized=$false;x=10;y=10;width=800;height=600},
        [pscustomobject]@{id='w2';Title='Reference browser';ProcessName='browser';monitorId='m1';maximized=$false;x=50;y=50;width=800;height=600},
        [pscustomobject]@{id='w3';Title='Music player';ProcessName='music';monitorId='m1';maximized=$false;x=80;y=80;width=600;height=400})}
    $bitmap=[Drawing.Bitmap]::new(960,540);$graphics=[Drawing.Graphics]::FromImage($bitmap);$stream=[IO.MemoryStream]::new()
    try{
        $graphics.Clear([Drawing.Color]::White);$graphics.DrawString('Report editor | Reference browser | Music player',[Drawing.SystemFonts]::DefaultFont,[Drawing.Brushes]::Black,20,20)
        $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
        $picture=[pscustomobject]@{id='m1';width=960;height=540;url='data:image/png;base64,'+[Convert]::ToBase64String($stream.ToArray())}
        foreach($images in @($false,$true)){
            $watch=[Diagnostics.Stopwatch]::StartNew();$pictures=if($images){@($picture)}else{@()}
            $answer=Get-TaskPloppLayoutAnswer 'Ich schreibe einen Bericht und brauche den Editor und Browser mit Quellen nebeneinander. Musik ist unwichtig.' $context $pictures 'gpt-4.1-mini'
            Assert-TaskPloppLayout $answer $context
            Assert ($answer.windows.Count-eq2-and$answer.windows.id-contains'w1'-and$answer.windows.id-contains'w2'-and$answer.windows.id-notcontains'w3') 'AI selected wrong fixtures'
            $a=$answer.windows[0];$b=$answer.windows[1]
            Assert (($a.x+$a.width)-le$b.x-or($b.x+$b.width)-le$a.x) 'AI did not place fixtures side by side'
            Write-Host ('OK: Live API synthetic only, image='+$images+', seconds='+[Math]::Round($watch.Elapsed.TotalSeconds,2)+', selected='+($answer.windows.id-join','))
        }
    }finally{$graphics.Dispose();$bitmap.Dispose();$stream.Dispose()}
}
