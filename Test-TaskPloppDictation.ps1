#requires -Version 5.1
[CmdletBinding()]
param([switch]$Engines)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'Test bitte mit Windows PowerShell 5.1 starten.'}
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
$wav=ConvertTo-TaskPloppWav ([byte[]]::new(3200))
if($wav-isnot[byte[]]-or$wav.Length-ne3244-or[Text.Encoding]::ASCII.GetString($wav,0,4)-ne'RIFF'-or[BitConverter]::ToInt32($wav,40)-ne3200){throw 'WAV-Format oder Bytearray-Typ'}
$caught=$false;try{$failed=New-TaskPloppDictationJob Whisper 'missing.exe' 'missing.bin' ([byte[]]::new(4000))}catch{$caught=$true}
if(-not$caught){Close-TaskPloppProcess $failed;throw 'Fehlender Prozess nicht abgewiesen'}
function New-InstallerFixture($Fixture,$Root) {
    $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),('-NoProfile -File "'+$Fixture+'" -Root "'+$Root+'"'))
    New-TaskPloppProcess $info -Installer
}
'OK: WAV-Header/Laenge, typstabiles Bytearray und fehlender Prozess.'
$Root=Join-Path $env:TEMP ('TaskPlopp-download-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root | Out-Null
try {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Install-TaskPloppDictation.ps1'),[ref]$tokens,[ref]$errors)
    foreach($name in 'Download','Progress-Line'){
        $definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
        . ([scriptblock]::Create($definition.Extent.Text))
    }
    $script:TestCurlExit=22;$script:TestCurlCalls=0
    function curl.exe {
        $script:TestCurlCalls++
        [IO.File]::WriteAllText($args[-1],'fixture')
        $global:LASTEXITCODE=$script:TestCurlExit
    }
    $caught=$false
    try{Download 'https://invalid.example/test' 'test.zip' | Out-Null}catch{$caught=$true}
    if(-not $caught -or (Test-Path (Join-Path $Root 'test.zip')) -or (Test-Path (Join-Path $Root 'test.zip.part'))){throw 'Teil-Download als fertig behandelt'}
    $script:TestCurlExit=0;$caught=$false
    try{Download 'https://invalid.example/test' 'test.zip' ('0'*64) | Out-Null}catch{$caught=$true}
    if(-not $caught -or (Test-Path (Join-Path $Root 'test.zip'))){throw 'Falsche Pruefsumme akzeptiert'}
    $result=Download 'https://invalid.example/test' 'test.zip'
    $calls=$script:TestCurlCalls
    $again=Download 'https://invalid.example/test' 'test.zip'
    if($again -ne $result -or $script:TestCurlCalls -ne $calls){throw 'Vollstaendiges Paket nicht wiederverwendet'}
    $fixture=Join-Path $Root 'fixture.ps1'
    [IO.File]::WriteAllText($fixture,'param($Root); [Console]::WriteLine("Fixture bereit"); [Console]::Error.WriteLine("Testfehler"); exit 3')
    $install=(New-InstallerFixture $fixture $Root)
    try {
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while(-not $install.Done){Update-TaskPloppProcess $install;if($watch.Elapsed.TotalSeconds -gt 10){throw 'Installer-Timeout'};Start-Sleep -Milliseconds 20}
        if($install.ExitCode -ne 3 -or $install.LastLine -ne 'Fixture bereit' -or $install.Error -notmatch 'Testfehler'){throw 'Installerstatus oder Fehler ging verloren'}
    } finally {Close-TaskPloppProcess $install}
    [IO.File]::WriteAllText($fixture,'param($Root); Start-Sleep -Seconds 30')
    $install=(New-InstallerFixture $fixture $Root)
    $process=$install.Process
    $childId=$process.Id
    Close-TaskPloppProcess $install
    $deadline=[DateTime]::UtcNow.AddSeconds(3)
    while((Get-Process -Id $childId -ErrorAction SilentlyContinue)-and[DateTime]::UtcNow-lt$deadline){Start-Sleep -Milliseconds 20}
    if(Get-Process -Id $childId -ErrorAction SilentlyContinue){throw 'Eigener Installerprozess laeuft nach Beenden weiter'}
    'OK: Downloadfehler, Teil-Datei-Cleanup, Pruefsummenfehler und Cache mit lokalen Ersatzdaten; kein Netzwerkzugriff.'
    'OK: Versteckter Installer uebergibt Fortschritt/Fehler/Exitcode und beendet eigenen Prozess.'
    foreach($mode in 'BlockedInput','BlockedCall') {
        $body=if($mode-eq'BlockedInput'){'Start-Sleep -Seconds 30'}else{'$memory=[IO.MemoryStream]::new();[Console]::OpenStandardInput().CopyTo($memory);$memory.Dispose();[Console]::WriteLine("READY");Start-Sleep -Seconds 30'}
        [IO.File]::WriteAllText($fixture,$body,[Text.UTF8Encoding]::new($true))
        $info=[Diagnostics.ProcessStartInfo]::new((Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'),('-NoProfile -File "'+$fixture+'"'))
        $payload=if($mode-eq'BlockedInput'){[byte[]]::new(4194304)}else{[byte[]]::new(32000)}
        $job=New-TaskPloppProcess $info $payload;$childId=$job.Process.Id
        try {
            $watch=[Diagnostics.Stopwatch]::StartNew();$pumps=0
            while($watch.ElapsedMilliseconds-lt1000){Update-TaskPloppProcess $job;[Windows.Forms.Application]::DoEvents();$pumps++;Start-Sleep -Milliseconds 10}
            if($job.Done){throw 'Blockierende Fixture war schon beendet'}
            $watch.Restart();Close-TaskPloppProcess $job
            $closeMilliseconds=$watch.ElapsedMilliseconds
            while(-not($job.Output.IsCompleted-and$job.Errors.IsCompleted-and$job.Write.IsCompleted)) {if($watch.Elapsed.TotalSeconds-gt2){throw 'Pipes nach Abbruch offen'};Start-Sleep -Milliseconds 10}
            foreach($task in @($job.Output,$job.Errors,$job.Write)){if($task.IsFaulted){$null=$task.Exception}}
            if($mode-eq'BlockedCall'-and$job.Output.GetAwaiter().GetResult()-notmatch'READY'){throw 'Fixture erreichte blockierenden Aufruf nicht'}
            if($closeMilliseconds-gt500-or(Get-Process -Id $childId -ErrorAction SilentlyContinue)){throw 'Abbruch blockiert GUI oder Prozess bleibt uebrig'}
            "OK: $mode gezielt beendet; Close $closeMilliseconds ms, $pumps UI-Pumpen, alle I/O-Tasks abgeschlossen."
        }finally{Close-TaskPloppProcess $job}
    }
} finally {
    Remove-Item Function:\curl.exe -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath $Root -File | ForEach-Object {Remove-Item -LiteralPath $_.FullName}
    Remove-Item -LiteralPath $Root
}
if(-not $Engines){return}
Add-Type -AssemblyName System.Speech
$s=[System.Speech.Synthesis.SpeechSynthesizer]::new()
$audio=[IO.MemoryStream]::new()
try {
    $s.SelectVoice('Microsoft Hedda Desktop')
    $format=[System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(16000,[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono)
    $s.SetOutputToAudioStream($audio,$format)
    $s.Speak('Dies ist ein kurzer Test. Heute prüfen wir die lokale Spracherkennung. Der Text bleibt auf diesem Computer.')
    $pcm=$audio.ToArray()
} finally {$s.Dispose();$audio.Dispose()}
$root=Join-Path $env:LOCALAPPDATA 'TaskPlopp\Dictation'
foreach($engine in 'Whisper','Vosk'){
    $exe=if($engine -eq 'Whisper'){Join-Path $root 'whisper-b5454\Release\whisper-cli.exe'}else{Join-Path $root 'vosk-0.3.45\vosk-win64-0.3.45\libvosk.dll'}
    $model=if($engine -eq 'Whisper'){Join-Path $root 'ggml-base.bin'}else{Join-Path $root 'vosk-model-small-de-0.15'}
    $job=(New-TaskPloppDictationJob $engine $exe $model $pcm)
    try {
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while(-not $job.Done){Update-TaskPloppProcess $job;if($watch.Elapsed.TotalSeconds -gt 90){throw 'Engine-Timeout im Test'};Start-Sleep -Milliseconds 100}
        if($job.Error){throw $job.Error}
        $normalized=([regex]::Replace($job.Text.ToLowerInvariant(),'[^\p{L} ]','') -replace '\s+',' ').Trim()
        if($normalized -ne 'dies ist ein kurzer test heute prüfen wir die lokale spracherkennung der text bleibt auf diesem computer'){throw "Unerwartetes Testtranskript: $($job.Text)"}
        "$engine : $($watch.ElapsedMilliseconds) ms; $($job.Text)"
    } finally {Close-TaskPloppProcess $job}
}
