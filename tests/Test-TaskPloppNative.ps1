#requires -Version 5.1
param([switch]$Microphone)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
# Source audit includes tests and fixtures, not just application modules.
foreach($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..') -Filter '*.ps1' -Recurse){
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert ($errors.Count-eq0) ('Syntaxfehler: '+$file.Name)
    $commands=$ast.FindAll({param($node)$node-is[Management.Automation.Language.CommandAst]-and$node.GetCommandName()-eq'Add-Type'},$true)
    foreach($command in $commands){$parameters=@($command.CommandElements|Where-Object{$_-is[Management.Automation.Language.CommandParameterAst]}|ForEach-Object ParameterName);Assert ($parameters-contains'AssemblyName'-and@($parameters|Where-Object{$_-in@('TypeDefinition','MemberDefinition','Path','OutputAssembly')}).Count-eq0) ('Compilerquelle: '+$file.Name)}
}
Assert (@(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..') -Filter '*.cs' -Recurse).Count-eq0) 'C#-Dateien uebrig'
Assert ($null-eq('TaskPlopp.Native'-as[type])-and$null-eq('TaskPlopp.Dictation.Job'-as[type])) 'Alte Hilfstypen geladen'
$assemblies=[AppDomain]::CurrentDomain.GetAssemblies().Count
. (Join-Path $PSScriptRoot '..\src\TaskPlopp.Native.ps1')
Assert ([AppDomain]::CurrentDomain.GetAssemblies().Count-eq$assemblies) 'Native Metadaten werden wiederholt erzeugt'
$first=[Windows.Forms.Form]::new();$second=[Windows.Forms.Form]::new()
try{
    $first.Text='TaskPlopp Unicode: Äpfel, Öl und Grüße';$second.Text='TaskPlopp zweites Fenster desselben Prozesses'
    $first.Show();$second.Show();[Windows.Forms.Application]::DoEvents()
    $windows=@(Get-TaskPloppNativeWindows)
    $actual=@($windows|Where-Object Handle -eq $first.Handle)
    Assert ($actual.Count-eq1-and$actual[0].Title-ceq$first.Text) 'Unicode-Fenstertitel abgeschnitten oder falsch dekodiert'
    Assert (@($windows|Where-Object {$_.ProcessId-eq$PID-and$_.Handle-in@($first.Handle,$second.Handle)}).Count-eq2) 'Mehrere Fenster eines Prozesses verloren'
}finally{$first.Dispose();$second.Dispose()}
$pinvoke=[TaskPloppInterop.User].GetMethod('GetWindowTextW').GetCustomAttributes([Runtime.InteropServices.DllImportAttribute],$false)[0]
Assert ($pinvoke.CharSet-eq[Runtime.InteropServices.CharSet]::Unicode) 'Unicode-Marshalling fehlt'
$hotkey=[TaskPloppInterop.User].GetMethod('RegisterHotKey').GetCustomAttributes([Runtime.InteropServices.DllImportAttribute],$false)[0]
Assert $hotkey.SetLastError 'Hotkey-Fehlernummer geht verloren'
Initialize-TaskPloppDictation
$sample=Get-TaskPloppInput
Assert ($sample.Available-is[bool]-and$sample.InputTick-is[uint32]) 'Input-ABI falsch'
$endpoint=Get-TaskPloppAudioDefaultId 1 0
$device=Get-TaskPloppWaveDevice $endpoint
Assert ($device-ge0) 'Endpoint-ID nicht auf WinMM abgebildet'
# Synthetic native headers prove FIFO including the final partial buffer.
$headers=New-Object 'Collections.Generic.List[IntPtr]';$memory=[IO.MemoryStream]::new()
$shared=@{Peak=0.0;MaxPeak=0.0}
try{
    foreach($samples in @(@(100,200),@(300))){
        $bytes=[byte[]]::new($samples.Count*2)
        for($i=0;$i-lt$samples.Count;$i++){[Buffer]::BlockCopy([BitConverter]::GetBytes([int16]$samples[$i]),0,$bytes,2*$i,2)}
        $header=[Runtime.InteropServices.Marshal]::AllocHGlobal(48);$data=[Runtime.InteropServices.Marshal]::AllocHGlobal($bytes.Length)
        [Runtime.InteropServices.Marshal]::Copy([byte[]]::new(48),0,$header,48);[Runtime.InteropServices.Marshal]::Copy($bytes,0,$data,$bytes.Length)
        [Runtime.InteropServices.Marshal]::WriteIntPtr($header,$data);[Runtime.InteropServices.Marshal]::WriteInt32($header,12,$bytes.Length);[Runtime.InteropServices.Marshal]::WriteInt32($header,24,1);$headers.Add($header)
    }
    $pump=@{Next=0;Headers=$headers;Memory=$memory;Handle=[IntPtr]::Zero;Shared=$shared}
    Read-TaskPloppCaptureBuffers $pump $false
    $bytes=$memory.ToArray()
    Assert ($bytes.Length-eq6-and[BitConverter]::ToInt16($bytes,0)-eq100-and[BitConverter]::ToInt16($bytes,2)-eq200-and[BitConverter]::ToInt16($bytes,4)-eq300) 'FIFO/Teilpuffer verloren'
    Assert ($shared.MaxPeak-gt0) 'Pegel fehlt'
}finally{foreach($header in $headers){[Runtime.InteropServices.Marshal]::FreeHGlobal([Runtime.InteropServices.Marshal]::ReadIntPtr($header));[Runtime.InteropServices.Marshal]::FreeHGlobal($header)};$memory.Dispose()}
# Mark every buffer done; overflow must be reported before any requeue.
$headers=New-Object 'Collections.Generic.List[IntPtr]';$memory=[IO.MemoryStream]::new()
try{
    for($i=0;$i-lt8;$i++){$header=[Runtime.InteropServices.Marshal]::AllocHGlobal(48);[Runtime.InteropServices.Marshal]::Copy([byte[]]::new(48),0,$header,48);[Runtime.InteropServices.Marshal]::WriteInt32($header,24,1);$headers.Add($header)}
    $caught=$false;try{Read-TaskPloppCaptureBuffers @{Next=0;Headers=$headers;Memory=$memory;Shared=$shared;Handle=[IntPtr]::Zero} $true}catch{$caught=$_.Exception.Message-like'*uebergelaufen*'}
    Assert $caught 'Pufferueberlauf blieb unbemerkt'
}finally{foreach($header in $headers){[Runtime.InteropServices.Marshal]::FreeHGlobal($header)};$memory.Dispose()}
$failedOpen=[hashtable]::Synchronized(@{Ready=$false;Stop=$true;Discard=$true;Closed=$true;Error='';Peak=0.0;MaxPeak=0.0;Pcm=$null;Bytes=[long]0;DriverBytes=[uint32]0})
Invoke-TaskPloppCapture $failedOpen ([uint32]4294967294)
Assert ($failedOpen.Error-like'*WinMM*'-and$failedOpen.Closed-and$null-eq$failedOpen.Pcm) 'Fehlgeschlagener Start blockiert Wiederholung oder behaelt Audio'
'OK: PS5.1-Quellcodeaudit, keine C#-Dateien/Compiler, gecachte ABI-Metadaten, Input, exakte Mikrofon-ID-Zuordnung, FIFO/Teilpuffer/Pegel und Ueberlauf.'
if($Microphone){
    $recorder=New-TaskPloppRecorder $endpoint;$watch=[Diagnostics.Stopwatch]::StartNew();$ticks=0
    try{
        while(-not$recorder.Shared.Ready-and-not$recorder.Async.IsCompleted){if($watch.Elapsed.TotalSeconds-gt3){throw 'Mikrofonstart dauert zu lange'};[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 5}
        $watch.Restart()
        while($watch.ElapsedMilliseconds-lt1500-and-not$recorder.Async.IsCompleted){$ticks++;[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 10}
        $recorder.Shared.Stop=$true;$watch.Restart()
        while(-not$recorder.Async.IsCompleted){if($watch.Elapsed.TotalSeconds-gt2){throw 'Mikrofonstop dauert zu lange'};[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 5}
        Assert (Close-TaskPloppRecorder $recorder) 'Worker nicht abgeschlossen'
        Assert (-not$recorder.Shared.Error-and$recorder.Shared.Closed) ('Aufnahmefehler: '+$recorder.Shared.Error)
        Assert ($recorder.Shared.Bytes-gt16000-and$recorder.Shared.Bytes-eq$recorder.Shared.DriverBytes-and$recorder.Shared.Pcm-is[byte[]]) 'Treiberbytes fehlen oder PCM-Typ verloren'
        "OK: Kurze Hardwareprobe nur im RAM: $($recorder.Shared.Bytes) Bytes = Treiberposition, Stop $($watch.ElapsedMilliseconds) ms, $ticks UI-Pumpen, Mikrofon geschlossen. Keine Transkription/Audiodatei."
    }finally{$recorder.Shared.Discard=$true;$recorder.Shared.Stop=$true;$null=Close-TaskPloppRecorder $recorder;$recorder.Shared.Pcm=$null}
}
