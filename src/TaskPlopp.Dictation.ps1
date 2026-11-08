# Local transcription; optional result dispatch to the separate window arranger.
$script:DictationPurpose='Dictation'
$script:DictationPhase='Ready'
$script:DictationRecorder=$null
$script:DictationJob=$null
$script:DictationInstaller=$null
$script:DictationPendingText=''
$script:DictationInstallError=''
$script:DictationRoot=Join-Path $env:LOCALAPPDATA 'TaskPlopp\Dictation'
function Initialize-TaskPloppDictation {
    if(-not[Environment]::Is64BitProcess){throw 'Diktat benoetigt 64-Bit Windows PowerShell.'}
    $null=New-TaskPloppNativeType 'TaskPloppInterop.Wave' 'winmm.dll' @(
        @{Name='waveInGetNumDevs';Return=[uint32];Args=@()},
        @{Name='waveInMessage';Return=[uint32];Args=@([IntPtr],[uint32],[IntPtr],[IntPtr])},
        @{Name='waveInOpen';Return=[uint32];Args=@([IntPtr].MakeByRefType(),[uint32],[IntPtr],[IntPtr],[IntPtr],[uint32])},
        @{Name='waveInPrepareHeader';Return=[uint32];Args=@([IntPtr],[IntPtr],[uint32])},
        @{Name='waveInUnprepareHeader';Return=[uint32];Args=@([IntPtr],[IntPtr],[uint32])},
        @{Name='waveInAddBuffer';Return=[uint32];Args=@([IntPtr],[IntPtr],[uint32])},
        @{Name='waveInStart';Return=[uint32];Args=@([IntPtr])},@{Name='waveInStop';Return=[uint32];Args=@([IntPtr])},
        @{Name='waveInReset';Return=[uint32];Args=@([IntPtr])},@{Name='waveInClose';Return=[uint32];Args=@([IntPtr])},
        @{Name='waveInGetPosition';Return=[uint32];Args=@([IntPtr],[IntPtr],[uint32])})
}
function Get-TaskPloppWaveDevice([string]$Endpoint) {
    Initialize-TaskPloppDictation
    $size=[Runtime.InteropServices.Marshal]::AllocHGlobal(4)
    try{
        for($id=[uint32]0;$id-lt[TaskPloppInterop.Wave]::waveInGetNumDevs();$id++){
            [Runtime.InteropServices.Marshal]::WriteInt32($size,0)
            if([TaskPloppInterop.Wave]::waveInMessage([IntPtr]$id,0x812,$size,[IntPtr]::Zero)-ne0){continue}
            $bytes=[Runtime.InteropServices.Marshal]::ReadInt32($size);if($bytes-le0-or$bytes-gt65536){continue}
            $name=[Runtime.InteropServices.Marshal]::AllocHGlobal($bytes)
            try{if([TaskPloppInterop.Wave]::waveInMessage([IntPtr]$id,0x811,$name,[IntPtr]$bytes)-eq0-and[Runtime.InteropServices.Marshal]::PtrToStringUni($name)-eq$Endpoint){return $id}}finally{[Runtime.InteropServices.Marshal]::FreeHGlobal($name)}
        }
    }finally{[Runtime.InteropServices.Marshal]::FreeHGlobal($size)}
    throw 'Das Standardmikrofon ist nicht als Aufnahmegeraet verfuegbar.'
}
function Assert-TaskPloppWave([uint32]$Code) {if($Code-ne0){throw "Mikrofonfehler (WinMM $Code). Audiogeraet und Berechtigung pruefen."}}
function Read-TaskPloppCaptureBuffers($Pump,[bool]$Again) {
        if($Again-and$pump.Headers.Count-eq8-and([Runtime.InteropServices.Marshal]::ReadInt32($pump.Headers[($pump.Next+7)%8],24)-band1)){throw 'Aufnahmepuffer uebergelaufen. Aufnahme bitte wiederholen.'}
        for($n=0;$n-lt$pump.Headers.Count;$n++){
            $header=$pump.Headers[$pump.Next]
            if(([Runtime.InteropServices.Marshal]::ReadInt32($header,24)-band1)-eq0){break}
            $pump.Next=($pump.Next+1)%$pump.Headers.Count
            $length=[Runtime.InteropServices.Marshal]::ReadInt32($header,12)
            if($length-lt0-or$length-gt3200-or($length%2)-ne0){throw 'Ungueltiger Aufnahmepuffer.'}
            if($length){
                $bytes=[byte[]]::new($length);[Runtime.InteropServices.Marshal]::Copy([Runtime.InteropServices.Marshal]::ReadIntPtr($header),$bytes,0,$length)
                $pump.Memory.Write($bytes,0,$length);$peak=0.0
                for($offset=0;$offset-lt$length;$offset+=2){$peak=[Math]::Max($peak,[Math]::Abs([int][BitConverter]::ToInt16($bytes,$offset))/32768.0)}
                $pump.Shared.Peak=$peak;$pump.Shared.MaxPeak=[Math]::Max($pump.Shared.MaxPeak,$peak)
            }
            if($Again){Assert-TaskPloppWave ([TaskPloppInterop.Wave]::waveInAddBuffer($pump.Handle,$header,48))}
        }
    }

function Invoke-TaskPloppCapture($Shared,[uint32]$Device) {
    Initialize-TaskPloppDictation
    $handle=[IntPtr]::Zero;$format=[IntPtr]::Zero;$headers=New-Object 'Collections.Generic.List[IntPtr]';$memory=[IO.MemoryStream]::new()
    $pump=@{Next=0;Headers=$headers;Memory=$memory;Handle=[IntPtr]::Zero;Shared=$Shared}
    try{
        $format=[Runtime.InteropServices.Marshal]::AllocHGlobal(18);[Runtime.InteropServices.Marshal]::Copy([byte[]]::new(18),0,$format,18)
        [Runtime.InteropServices.Marshal]::WriteInt16($format,0,1);[Runtime.InteropServices.Marshal]::WriteInt16($format,2,1);[Runtime.InteropServices.Marshal]::WriteInt32($format,4,16000);[Runtime.InteropServices.Marshal]::WriteInt32($format,8,32000);[Runtime.InteropServices.Marshal]::WriteInt16($format,12,2);[Runtime.InteropServices.Marshal]::WriteInt16($format,14,16)
        Assert-TaskPloppWave ([TaskPloppInterop.Wave]::waveInOpen([ref]$handle,$Device,$format,[IntPtr]::Zero,[IntPtr]::Zero,0));$pump.Handle=$handle;$Shared.Closed=$false
        for($i=0;$i-lt8;$i++){
            $header=[Runtime.InteropServices.Marshal]::AllocHGlobal(48);[Runtime.InteropServices.Marshal]::Copy([byte[]]::new(48),0,$header,48);$headers.Add($header)
            $data=[Runtime.InteropServices.Marshal]::AllocHGlobal(3200);[Runtime.InteropServices.Marshal]::WriteIntPtr($header,$data);[Runtime.InteropServices.Marshal]::WriteInt32($header,8,3200)
            Assert-TaskPloppWave ([TaskPloppInterop.Wave]::waveInPrepareHeader($handle,$header,48))
            Assert-TaskPloppWave ([TaskPloppInterop.Wave]::waveInAddBuffer($handle,$header,48))
        }
        Assert-TaskPloppWave ([TaskPloppInterop.Wave]::waveInStart($handle));$Shared.Ready=$true
        while(-not$Shared.Stop){Read-TaskPloppCaptureBuffers $pump $true;Start-Sleep -Milliseconds 5}
        Assert-TaskPloppWave ([TaskPloppInterop.Wave]::waveInStop($handle))
        $time=[Runtime.InteropServices.Marshal]::AllocHGlobal(12)
        try{
            [Runtime.InteropServices.Marshal]::WriteInt32($time,4)
            Assert-TaskPloppWave ([TaskPloppInterop.Wave]::waveInGetPosition($handle,$time,12))
            if([Runtime.InteropServices.Marshal]::ReadInt32($time)-eq4){$Shared.DriverBytes=[BitConverter]::ToUInt32([BitConverter]::GetBytes([Runtime.InteropServices.Marshal]::ReadInt32($time,4)),0)}
        }finally{[Runtime.InteropServices.Marshal]::FreeHGlobal($time)}
        Assert-TaskPloppWave ([TaskPloppInterop.Wave]::waveInReset($handle));Read-TaskPloppCaptureBuffers $pump $false
        $Shared.Bytes=$memory.Length
        if(($memory.Length%4294967296)-ne$Shared.DriverBytes){throw 'Aufnahmedaten unvollstaendig. Bitte wiederholen.'}
        if(-not$Shared.Discard){$Shared.Pcm=$memory.ToArray()}
    }catch{$Shared.Error=$_.Exception.Message}
    finally{
        if($handle-ne[IntPtr]::Zero){$null=[TaskPloppInterop.Wave]::waveInReset($handle)}
        foreach($header in $headers){
            $unprepared=$true
            if($handle-ne[IntPtr]::Zero){$unprepared=([TaskPloppInterop.Wave]::waveInUnprepareHeader($handle,$header,48)-eq0)}
            # Never free a header still owned by the driver.
            if($unprepared){[Runtime.InteropServices.Marshal]::FreeHGlobal([Runtime.InteropServices.Marshal]::ReadIntPtr($header));[Runtime.InteropServices.Marshal]::FreeHGlobal($header)}
            else{$Shared.Error='Aufnahmepuffer konnte nicht freigegeben werden.'}
        }
        if($handle-ne[IntPtr]::Zero){$Shared.Closed=([TaskPloppInterop.Wave]::waveInClose($handle)-eq0);if(-not$Shared.Closed){$Shared.Error='Mikrofon konnte nicht geschlossen werden.'}}
        if($format-ne[IntPtr]::Zero){[Runtime.InteropServices.Marshal]::FreeHGlobal($format)}
        $memory.Dispose();$Shared.Ready=$true
    }
}
function New-TaskPloppRecorder([string]$Endpoint) {
    $device=Get-TaskPloppWaveDevice $Endpoint
    $shared=[hashtable]::Synchronized(@{Ready=$false;Stop=$false;Discard=$false;Closed=$true;Error='';Peak=0.0;MaxPeak=0.0;Pcm=$null;Bytes=[long]0;DriverBytes=[uint32]0})
    $space=[RunspaceFactory]::CreateRunspace();$space.ApartmentState='STA';$space.ThreadOptions='ReuseThread';$space.Open()
    $ps=[PowerShell]::Create();$ps.Runspace=$space
    $null=$ps.AddScript('param($root,$shared,$device);$ErrorActionPreference="Stop";. (Join-Path $root "TaskPlopp.Native.ps1");. (Join-Path $root "TaskPlopp.Dictation.ps1");Invoke-TaskPloppCapture $shared $device').AddArgument($PSScriptRoot).AddArgument($shared).AddArgument($device)
    [pscustomobject]@{Shared=$shared;PowerShell=$ps;Runspace=$space;Async=$ps.BeginInvoke();StopWatch=$null;Disposed=$false}
}
function Close-TaskPloppRecorder($Recorder) {
    if($Recorder.Disposed){return $true}
    $Recorder.Shared.Stop=$true
    if(-not$Recorder.Async.IsCompleted){return $false}
    try{$null=$Recorder.PowerShell.EndInvoke($Recorder.Async);if($Recorder.PowerShell.HadErrors){$Recorder.Shared.Error=($Recorder.PowerShell.Streams.Error|Out-String)}}finally{$Recorder.PowerShell.Dispose();$Recorder.Runspace.Dispose();$Recorder.Disposed=$true}
    return $true
}
function ConvertTo-TaskPloppWav([byte[]]$Pcm) {
    $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream)
    try{
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'));$writer.Write([int]($Pcm.Length+36));$writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([int]16);$writer.Write([int16]1);$writer.Write([int16]1);$writer.Write([int]16000);$writer.Write([int]32000);$writer.Write([int16]2);$writer.Write([int16]16)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data'));$writer.Write([int]$Pcm.Length);$writer.Write($Pcm);$writer.Flush()
        return ,$stream.ToArray()
    }finally{$writer.Dispose();$stream.Dispose()}
}
function New-TaskPloppProcess($Info,[byte[]]$InputBytes,[switch]$Installer) {
    $Info.UseShellExecute=$false;$Info.CreateNoWindow=$true;$Info.RedirectStandardOutput=$true;$Info.RedirectStandardError=$true
    $Info.StandardOutputEncoding=[Text.Encoding]::UTF8;$Info.StandardErrorEncoding=[Text.Encoding]::UTF8
    $Info.RedirectStandardInput=-not$Installer
    $process=[Diagnostics.Process]::Start($Info)
    $job=[pscustomobject]@{Process=$process;Output=$null;Errors=$process.StandardError.ReadToEndAsync();Write=$null;InputClosed=[bool]$Installer;Installer=[bool]$Installer;LastLine='Einrichtung wird gestartet';Text='';Error='';Done=$false;ExitCode=$null;Disposed=$false}
    if($Installer){$job.Output=$process.StandardOutput.ReadLineAsync()}else{$job.Output=$process.StandardOutput.ReadToEndAsync();$job.Write=$process.StandardInput.BaseStream.WriteAsync($InputBytes,0,$InputBytes.Length)}
    return $job
}
function New-TaskPloppDictationJob([string]$Engine,[string]$Executable,[string]$Model,[byte[]]$Pcm) {
    if($Engine-eq'Whisper'){
        $info=[Diagnostics.ProcessStartInfo]::new($Executable,('-m "'+$Model+'" -f - -of taskplopp-stdout -l de -nt -np -ng'));$inputBytes=ConvertTo-TaskPloppWav $Pcm
    }elseif($Engine-eq'Vosk'){
        $shell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $info=[Diagnostics.ProcessStartInfo]::new($shell,('-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'TaskPlopp.DictationWorker.ps1')+'" -Executable "'+$Executable+'" -Model "'+$Model+'"'));$inputBytes=$Pcm
    }else{throw 'Unbekannte Diktat-Engine.'}
    return New-TaskPloppProcess $info $inputBytes
}
function Update-TaskPloppProcess($Job) {
    if($Job.Done-or$Job.Disposed){return}
    if(-not$Job.InputClosed-and$Job.Write.IsCompleted){
        try{$null=$Job.Write.GetAwaiter().GetResult()}catch{$Job.Error=$_.Exception.Message}
        try{$Job.Process.StandardInput.Close()}catch{$Job.Error=$_.Exception.Message};$Job.InputClosed=$true
    }
    if($Job.Installer){
        while($null-ne$Job.Output-and$Job.Output.IsCompleted){
            $line=$Job.Output.GetAwaiter().GetResult()
            if($null-eq$line){$Job.Output=$null;break}
            if($line){$Job.LastLine=$line}
            $Job.Output=$Job.Process.StandardOutput.ReadLineAsync()
        }
    }
    if(-not$Job.Process.HasExited){return}
    if(-not$Job.InputClosed-or-not$Job.Errors.IsCompleted-or($null-ne$Job.Output-and-not$Job.Output.IsCompleted)){return}
    if(-not$Job.Installer){$Job.Text=$Job.Output.GetAwaiter().GetResult().Trim()}
    $diagnostic=$Job.Errors.GetAwaiter().GetResult();$Job.ExitCode=$Job.Process.ExitCode
    if($Job.ExitCode-ne0){$Job.Error="Prozessfehler $($Job.ExitCode): $diagnostic"}
    $Job.Done=$true
}
function Close-TaskPloppProcess($Job) {
    if($Job.Disposed){return}
    if(-not$Job.Process.HasExited){
        if($Job.Installer){
            $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\taskkill.exe'),("/PID "+$Job.Process.Id+" /T /F"));$info.UseShellExecute=$false;$info.CreateNoWindow=$true
            $killer=[Diagnostics.Process]::Start($info);$killer.Dispose()
        }else{$Job.Process.Kill()}
    }
    # No UI-thread waits on unfinished I/O or on a native worker.
    if($Job.Write-and$Job.Write.IsFaulted){$null=$Job.Write.Exception}
    $Job.Process.Dispose();$Job.Disposed=$true
}
function Get-TaskPloppDictationPaths([ValidateSet('Whisper','Vosk')][string]$Engine) {
    $exe=if($Engine -eq 'Whisper'){'whisper-b5454\Release\whisper-cli.exe'}else{'vosk-0.3.45\vosk-win64-0.3.45\libvosk.dll'}
    $model=if($Engine -eq 'Whisper'){'ggml-base.bin'}else{'vosk-model-small-de-0.15\am\final.mdl'}
    [pscustomobject]@{
        Executable=Join-Path $script:DictationRoot $exe
        Model=if($Engine -eq 'Whisper'){Join-Path $script:DictationRoot $model}else{Join-Path $script:DictationRoot 'vosk-model-small-de-0.15'}
        Ready=(Test-Path (Join-Path $script:DictationRoot "$Engine.ready")) -and (Test-Path (Join-Path $script:DictationRoot $exe)) -and (Test-Path (Join-Path $script:DictationRoot $model))
    }
}
function Update-TaskPloppDictationButton {
    if(-not(Get-Variable DictationButton -Scope Script -ErrorAction SilentlyContinue)){return}
    $recording=$script:DictationPhase -eq 'Recording'
    Update-TaskPloppLayoutButton
    $script:DictationButton.Enabled=($null-eq$script:LayoutJob)-and-not($script:DictationPurpose-eq'Layout'-and$script:DictationPhase-ne'Ready')-and$script:DictationPhase -ne 'Transcribing' -and $null -eq $script:DictationInstaller -and ($null -eq $script:DictationRecorder -or -not $script:DictationRecorder.Disposed -or $script:DictationRecorder.Shared.Closed)
    $script:DictationButton.UseVisualStyleBackColor=$false
    $script:DictationButton.BackColor=if($recording){[Drawing.Color]::FromArgb(205,239,211)}else{[Drawing.Color]::FromArgb(240,240,240)}
    $hint=if($recording){'Aufnahme beenden und transkribieren (Rechtsklick: verwerfen)'}else{'Diktat starten'}
    $script:DictationButton.AccessibleName=$hint
    $script:ToolbarToolTip.SetToolTip($script:DictationButton,$hint)
    if(Get-Variable Tray -Scope Script -ErrorAction SilentlyContinue){
        Update-TaskPloppTrayText
        if($recording){$script:Tray.Icon=[Drawing.SystemIcons]::Information}else{$script:Tray.Icon=$script:AppIcon}
    }
}
function Show-TaskPloppDictationStatus {
    if($script:DictationPhase -eq 'Recording'){$caption=if($script:DictationPurpose-eq'Layout'){'Sag mir, woran du arbeitest'}else{'Diktat laeuft'};Set-TaskPloppActivity Recording '' $caption}
    elseif($script:DictationPhase -eq 'Transcribing'){Set-TaskPloppActivity Transcribing $script:DictationEngine}
}
function Copy-TaskPloppDictationResult {
    if(-not $script:DictationPendingText){return}
    try {
        Set-TaskPloppDictationClipboard $script:DictationPendingText
        $script:DictationPendingText=''
        Set-TaskPloppMessage 'Success' 'Diktat in Zwischenablage' 'Mit Strg+V einfuegen.'
    } catch {
        Set-TaskPloppMessage 'Error' 'Zwischenablage ist gerade nicht verfuegbar' 'Rechtsklick auf das Mikrofon: Erneut kopieren. Neues Diktat verwirft das bisherige Ergebnis.'
    }
}
function Set-TaskPloppDictationClipboard([string]$Text) {
    [Windows.Forms.Clipboard]::SetText($Text)
}
function Stop-TaskPloppRecording([switch]$Discard) {
    if($script:DictationPhase-ne'Recording'-or$null-eq$script:DictationRecorder){return}
    $recorder=$script:DictationRecorder
    if($Discard){$recorder.Shared.Discard=$true}
    if(-not$recorder.Shared.Stop){$recorder.StopWatch=[Diagnostics.Stopwatch]::StartNew();$recorder.Shared.Stop=$true}
}
function Complete-TaskPloppRecording {
    $recorder=$script:DictationRecorder
    if(-not(Close-TaskPloppRecorder $recorder)){return}
    $shared=$recorder.Shared
    if(-not$shared.Closed){$shared.Pcm=$null;Set-TaskPloppMessage Error 'Mikrofonfreigabe nicht bestaetigt' 'Weitere Aufnahme gesperrt. TaskPlopp bitte neu starten.';Update-TaskPloppDictationButton;return}
    $script:DictationRecorder=$null;$script:DictationPhase='Ready'
    try {
        if($shared.Error){throw $shared.Error}
        if($shared.Discard){Set-TaskPloppMessage Notice 'Aufnahme verworfen' '';return}
        if($null-eq$shared.Pcm-or$shared.Pcm.Length-lt3200-or$shared.MaxPeak-lt0.003){Set-TaskPloppMessage Notice 'Keine verwertbare Aufnahme' 'Mikrofon und Eingangspegel pruefen. Zwischenablage bleibt erhalten.';return}
        $paths=Get-TaskPloppDictationPaths $script:DictationEngine
        $script:DictationJob=New-TaskPloppDictationJob $script:DictationEngine $paths.Executable $paths.Model $shared.Pcm
        $script:DictationPhase='Transcribing';Show-TaskPloppDictationStatus
    }catch{Set-TaskPloppMessage Error 'Diktat konnte nicht verarbeitet werden' $_.Exception.Message}
    finally{$shared.Pcm=$null;Update-TaskPloppDictationButton}
}
function Invoke-TaskPloppDictation {
    param([ValidateSet('Dictation','Layout')][string]$Purpose='Dictation')
    if($null-ne$script:LayoutJob-or($script:DictationPhase-ne'Ready'-and$script:DictationPurpose-ne$Purpose)){Set-TaskPloppMessage Notice 'TaskPlopp ist beschaeftigt' 'Bitte zuerst den laufenden Auftrag beenden.';return}
    if($script:DictationPhase -eq 'Recording'){Stop-TaskPloppRecording;return}
    if($script:DictationPhase -ne 'Ready' -or $null -ne $script:DictationInstaller){return}
    try {
        $engine=$script:Settings.DictationEngine
        $paths=Get-TaskPloppDictationPaths $engine
        if(-not $paths.Ready){throw 'Bitte unter Konfiguration > Diktat die Komponenten installieren.'}
        Initialize-TaskPloppDictation;Initialize-TaskPloppAudio
        $endpoint=Get-TaskPloppAudioDefaultId 1 0
        $script:DictationRecorder=New-TaskPloppRecorder $endpoint
        $script:DictationPurpose=$Purpose
        if($Purpose-eq'Dictation'){$script:DictationPendingText=''};$script:DictationEngine=$engine
        $script:DictationEndpoint=$endpoint
        $script:DictationMaxPeak=0.0;$script:DictationDeviceCheck=0
        $script:DictationWatch=[Diagnostics.Stopwatch]::StartNew()
        $script:DictationPhase='Recording';Show-TaskPloppDictationStatus
    } catch {Set-TaskPloppMessage 'Error' 'Aufnahme konnte nicht gestartet werden' $_.Exception.Message}
    Update-TaskPloppDictationButton
}
function Start-TaskPloppDictationInstall {
    if($null-ne$script:LayoutJob){Set-TaskPloppMessage Notice 'Fensterordner arbeitet' 'Einrichtung bitte danach starten.';return}
    if($script:DictationPhase -ne 'Ready' -or $null -ne $script:DictationInstaller){return}
    try {
        Initialize-TaskPloppDictation
        $script:DictationInstallError=''
        $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),('-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $script:ProjectRoot 'tools\Install-TaskPloppDictation.ps1')+'" -Root "'+$script:DictationRoot+'"'))
        $script:DictationInstaller=New-TaskPloppProcess $info -Installer
        Set-TaskPloppMessage 'Notice' 'Diktat-Komponenten werden eingerichtet' 'Download, Entpacken und Pruefung laufen im Hintergrund.'
    } catch {$script:DictationInstallError=$_.Exception.Message;Set-TaskPloppMessage 'Error' 'Einrichtung konnte nicht gestartet werden' $_.Exception.Message}
    Update-TaskPloppDictationButton
}
function Invoke-TaskPloppDictationTick {
    if($null -ne $script:DictationInstaller){
        Update-TaskPloppProcess $script:DictationInstaller
        if($script:DictationInstaller.Done){
            $code=$script:DictationInstaller.ExitCode;$detail=$script:DictationInstaller.Error
            $script:DictationInstallError=if($code -eq 0){''}else{$detail}
            Close-TaskPloppProcess $script:DictationInstaller;$script:DictationInstaller=$null
            if($code -eq 0){Set-TaskPloppMessage 'Success' 'Beide Diktat-Engines sind bereit' 'In der Konfiguration die Engine fuer das naechste Diktat waehlen.'}
            else {Set-TaskPloppMessage 'Error' 'Diktat-Einrichtung fehlgeschlagen' $detail}
            Update-TaskPloppDictationButton
        } else {Set-TaskPloppMessage 'Notice' 'Diktat-Komponenten werden eingerichtet' $script:DictationInstaller.LastLine}
    }
    if($script:DictationPhase -eq 'Recording'){
        $recorder=$script:DictationRecorder
        if($recorder.Async.IsCompleted){Complete-TaskPloppRecording;return}
        try {
            $script:DictationMaxPeak=[Math]::Max($script:DictationMaxPeak,$recorder.Shared.MaxPeak)
            $seconds=$script:DictationWatch.Elapsed.TotalSeconds
            if(-not$recorder.Shared.Stop-and$seconds-$script:DictationDeviceCheck-ge1){$null=Get-TaskPloppWaveDevice $script:DictationEndpoint;$script:DictationDeviceCheck=$seconds}
            if($recorder.StopWatch-and$recorder.StopWatch.Elapsed.TotalSeconds-gt2){Set-TaskPloppMessage Error 'Mikrofon antwortet noch nicht' 'Freigabe laeuft; eine neue Aufnahme ist erst danach moeglich.'}
            else{Update-TaskPloppActivity $recorder.Shared.Peak $seconds}
        }catch{$recorder.Shared.Error=$_.Exception.Message;Stop-TaskPloppRecording -Discard}
    } elseif($script:DictationPhase -eq 'Transcribing'){
        Update-TaskPloppActivity 0 0
        Update-TaskPloppProcess $script:DictationJob
        if($script:DictationJob.Done){
            $errorText=$script:DictationJob.Error;$text=$script:DictationJob.Text
            Close-TaskPloppProcess $script:DictationJob;$script:DictationJob=$null;$script:DictationPhase='Ready'
            if($errorText){Set-TaskPloppMessage 'Error' 'Transkription fehlgeschlagen' $errorText}
            elseif([string]::IsNullOrWhiteSpace($text)){Set-TaskPloppMessage 'Notice' 'Kein Text erkannt' 'Zwischenablage bleibt erhalten. Mikrofon und Aufnahme pruefen.'}
            elseif($script:DictationPurpose-eq'Layout'){Start-TaskPloppLayoutPlan $text}
            else {$script:DictationPendingText=$text;Copy-TaskPloppDictationResult}
            Update-TaskPloppDictationButton
        }
    }
}
function Close-TaskPloppDictation {
    if($null-ne$script:DictationRecorder){$script:DictationRecorder.Shared.Discard=$true;$null=Close-TaskPloppRecorder $script:DictationRecorder}
    foreach($job in @($script:DictationJob,$script:DictationInstaller)){if($null-ne$job){Close-TaskPloppProcess $job}}
    $script:DictationPendingText='';$script:DictationPhase='Ready'
}
