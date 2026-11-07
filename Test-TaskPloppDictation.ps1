#requires -Version 5.1
[CmdletBinding()]
param([switch]$Engines)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'Test bitte mit Windows PowerShell 5.1 starten.'}
Add-Type -Path (Join-Path $PSScriptRoot 'TaskPlopp.Dictation.cs') -ReferencedAssemblies System.Web.Extensions,System.Core
$result=[TaskPlopp.Dictation.Job]::JoinResults([string[]]@('{"text":"Erster Satz"}','{"text":"Zweiter Satz"}','{"text":"Übriger Text"}'))
if($result -ne 'Erster Satz Zweiter Satz Übriger Text'){throw 'Segmentverlust'}
$wav=[TaskPlopp.Dictation.Job]::Wav([byte[]]::new(3200))
if($wav.Length -ne 3244 -or [Text.Encoding]::ASCII.GetString($wav,0,4) -ne 'RIFF'){throw 'WAV-Format'}
$failed=[TaskPlopp.Dictation.Job]::new('Whisper','missing.exe','missing.bin',[byte[]]::new(4000))
while(-not $failed.Done){Start-Sleep -Milliseconds 20}
if(-not $failed.Error -or $failed.Text){throw 'Fehler als Erfolg behandelt'}
$failed.Dispose()
'OK: WAV, UTF-8-Segmente, Prozessfehler.'
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
    $install=[TaskPlopp.Dictation.Installer]::new($fixture,$Root)
    try {
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while(-not $install.Done){if($watch.Elapsed.TotalSeconds -gt 10){throw 'Installer-Timeout'};Start-Sleep -Milliseconds 20}
        if($install.ExitCode -ne 3 -or $install.LastLine -ne 'Fixture bereit' -or $install.Error -notmatch 'Testfehler'){throw 'Installerstatus oder Fehler ging verloren'}
    } finally {$install.Dispose()}
    [IO.File]::WriteAllText($fixture,'param($Root); Start-Sleep -Seconds 30')
    $install=[TaskPlopp.Dictation.Installer]::new($fixture,$Root)
    $process=$install.GetType().GetField('process',[Reflection.BindingFlags]'Instance,NonPublic').GetValue($install)
    $childId=$process.Id
    $install.Dispose()
    if(Get-Process -Id $childId -ErrorAction SilentlyContinue){throw 'Eigener Installerprozess laeuft nach Beenden weiter'}
    'OK: Downloadfehler, Teil-Datei-Cleanup, Pruefsummenfehler und Cache mit lokalen Ersatzdaten; kein Netzwerkzugriff.'
    'OK: Versteckter Installer uebergibt Fortschritt/Fehler/Exitcode und beendet eigenen Prozess.'
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
    $job=[TaskPlopp.Dictation.Job]::new($engine,$exe,$model,$pcm)
    try {
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while(-not $job.Done){if($watch.Elapsed.TotalSeconds -gt 90){throw 'Engine-Timeout im Test'};Start-Sleep -Milliseconds 100}
        if($job.Error){throw $job.Error}
        $normalized=([regex]::Replace($job.Text.ToLowerInvariant(),'[^\p{L} ]','') -replace '\s+',' ').Trim()
        if($normalized -ne 'dies ist ein kurzer test heute prüfen wir die lokale spracherkennung der text bleibt auf diesem computer'){throw "Unerwartetes Testtranskript: $($job.Text)"}
        "$engine : $($job.Milliseconds) ms; $($job.Text)"
    } finally {$job.Dispose()}
}
