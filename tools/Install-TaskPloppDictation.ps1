#requires -Version 5.1
[CmdletBinding()]
param([string]$Root=(Join-Path $env:LOCALAPPDATA 'TaskPlopp\Dictation'))
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
if($PSVersionTable.PSEdition -ne 'Desktop' -or -not [Environment]::Is64BitProcess){throw 'Windows PowerShell 5.1, 64 Bit erforderlich.'}
function Progress-Line([string]$Text){[Console]::WriteLine($Text)}
function Download([string]$Url,[string]$Name,[string]$Hash='') {
    $path=Join-Path $Root $Name
    if(Test-Path $path){
        if(-not $Hash -or (Get-FileHash $path -Algorithm SHA256).Hash -eq $Hash){return $path}
        Remove-Item -LiteralPath $path
    }
    Progress-Line "Download: $Name"
    $part="$path.part"
    try {
        & curl.exe --fail --location --silent --show-error --connect-timeout 30 $Url -o $part
        if($LASTEXITCODE -ne 0){throw "Download fehlgeschlagen: $Name. Internetverbindung pruefen und erneut versuchen."}
        if($Hash -and (Get-FileHash $part -Algorithm SHA256).Hash -ne $Hash){throw "Pruefsumme stimmt nicht: $Name"}
        Move-Item -LiteralPath $part -Destination $path -Force
    } finally {if(Test-Path $part){Remove-Item -LiteralPath $part}}
    return $path
}
try {
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $whisper=Download 'https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-bin-x64.zip' 'whisper.zip' '6BA69E3482D7826214F90A6A9C84CA07782AEC1E1D0C6A7C30C994FD5D816CCB'
    $vosk=Download 'https://github.com/alphacep/vosk-api/releases/download/v0.3.45/vosk-win64-0.3.45.zip' 'vosk.zip'
    $model=Download 'https://alphacephei.com/vosk/models/vosk-model-small-de-0.15.zip' 'vosk-model.zip'
    $base=Download 'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin' 'ggml-base.bin' '60ED5BC3DD14EEA856493D334349B405782DDCAF0028D4B5DF4088345FBA2EFE'
    foreach($engine in 'Whisper','Vosk') {
        $marker=Join-Path $Root "$engine.ready"
        if(Test-Path $marker){Remove-Item -LiteralPath $marker}
    }
    Progress-Line 'Entpacken: whisper.cpp und Vosk'
    Expand-Archive -LiteralPath $whisper -DestinationPath (Join-Path $Root 'whisper-b5454') -Force
    Expand-Archive -LiteralPath $vosk -DestinationPath (Join-Path $Root 'vosk-0.3.45') -Force
    Expand-Archive -LiteralPath $model -DestinationPath $Root -Force
    Progress-Line 'Pruefung: beide Engines und Modelle (nur synthetische Stille)'
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.Native.ps1')
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.Dictation.ps1')
    foreach($engine in 'Whisper','Vosk') {
        $exe=if($engine -eq 'Whisper'){Join-Path $Root 'whisper-b5454\Release\whisper-cli.exe'}else{Join-Path $Root 'vosk-0.3.45\vosk-win64-0.3.45\libvosk.dll'}
        $target=if($engine -eq 'Whisper'){$base}else{Join-Path $Root 'vosk-model-small-de-0.15'}
        $job=New-TaskPloppDictationJob $engine $exe $target ([byte[]]::new(32000))
        $watch=[Diagnostics.Stopwatch]::StartNew()
        try {
            while(-not $job.Done){Update-TaskPloppProcess $job;if($watch.Elapsed.TotalSeconds -gt 120){throw "$engine : Pruefung dauert zu lange."};Start-Sleep -Milliseconds 100}
            if($job.Error){throw "$engine : $($job.Error)"}
        } finally {Close-TaskPloppProcess $job}
        [IO.File]::WriteAllText((Join-Path $Root "$engine.ready"),'Version 1: lokale Laufzeit und Modell geprueft.')
        Progress-Line "$engine bereit"
    }
    Progress-Line 'Beide Diktat-Engines sind bereit.'
} catch {[Console]::Error.WriteLine($_.Exception.Message);exit 1}
