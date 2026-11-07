# Local dictation only. No audio files, cloud calls or automatic text insertion.
$script:DictationPhase='Ready'
$script:DictationRecorder=$null
$script:DictationJob=$null
$script:DictationInstaller=$null
$script:DictationPendingText=''
$script:DictationInstallError=''
$script:DictationRoot=Join-Path $env:LOCALAPPDATA 'TaskPlopp\Dictation'
function Initialize-TaskPloppDictation {
    if(-not ('TaskPlopp.Dictation.Job' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'TaskPlopp.Dictation.cs') -ReferencedAssemblies System.Web.Extensions,System.Core
    }
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
    $script:DictationButton.Enabled=$script:DictationPhase -ne 'Transcribing' -and $null -eq $script:DictationInstaller
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
    if($script:DictationPhase -eq 'Recording'){$script:MessageBar.SetActivity('Recording','')}
    elseif($script:DictationPhase -eq 'Transcribing'){$script:MessageBar.SetActivity('Transcribing',$script:DictationEngine)}
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
    if($script:DictationPhase -ne 'Recording'){return}
    try {
        if($Discard){Set-TaskPloppMessage 'Notice' 'Aufnahme verworfen' '';return}
        $pcm=$script:DictationRecorder.Stop()
        if($pcm.Length -lt 3200 -or $script:DictationMaxPeak -lt 0.003){
            Set-TaskPloppMessage 'Notice' 'Keine verwertbare Aufnahme' 'Mikrofon und Eingangspegel pruefen. Zwischenablage bleibt erhalten.';return
        }
        $paths=Get-TaskPloppDictationPaths $script:DictationEngine
        $script:DictationJob=[TaskPlopp.Dictation.Job]::new($script:DictationEngine,$paths.Executable,$paths.Model,$pcm)
        $script:DictationPhase='Transcribing'
        Show-TaskPloppDictationStatus
    } catch {Set-TaskPloppMessage 'Error' 'Diktat konnte nicht verarbeitet werden' $_.Exception.Message}
    finally {
        $script:DictationRecorder.Dispose();$script:DictationRecorder=$null
        if($script:DictationPhase -eq 'Recording'){$script:DictationPhase='Ready'}
        Update-TaskPloppDictationButton
    }
}
function Invoke-TaskPloppDictation {
    if($script:DictationPhase -eq 'Recording'){Stop-TaskPloppRecording;return}
    if($script:DictationPhase -ne 'Ready' -or $null -ne $script:DictationInstaller){return}
    try {
        $engine=$script:Settings.DictationEngine
        $paths=Get-TaskPloppDictationPaths $engine
        if(-not $paths.Ready){throw 'Bitte unter Konfiguration > Diktat die Komponenten installieren.'}
        Initialize-TaskPloppDictation;Initialize-TaskPloppAudio
        $endpoint=[TaskPloppAudio.Audio]::GetDefaultId(1,0)
        [TaskPlopp.Dictation.Recorder]::CheckFormat($endpoint)
        $script:DictationRecorder=[TaskPlopp.Dictation.Recorder]::new($endpoint)
        $script:DictationPendingText='';$script:DictationEngine=$engine
        $script:DictationEndpoint=$endpoint
        $script:DictationMaxPeak=0.0;$script:DictationDeviceCheck=0
        $script:DictationWatch=[Diagnostics.Stopwatch]::StartNew()
        $script:DictationPhase='Recording';Show-TaskPloppDictationStatus
    } catch {Set-TaskPloppMessage 'Error' 'Aufnahme konnte nicht gestartet werden' $_.Exception.Message}
    Update-TaskPloppDictationButton
}
function Start-TaskPloppDictationInstall {
    if($script:DictationPhase -ne 'Ready' -or $null -ne $script:DictationInstaller){return}
    try {
        Initialize-TaskPloppDictation
        $script:DictationInstallError=''
        $script:DictationInstaller=[TaskPlopp.Dictation.Installer]::new((Join-Path $PSScriptRoot 'Install-TaskPloppDictation.ps1'),$script:DictationRoot)
        Set-TaskPloppMessage 'Notice' 'Diktat-Komponenten werden eingerichtet' 'Download, Entpacken und Pruefung laufen im Hintergrund.'
    } catch {$script:DictationInstallError=$_.Exception.Message;Set-TaskPloppMessage 'Error' 'Einrichtung konnte nicht gestartet werden' $_.Exception.Message}
    Update-TaskPloppDictationButton
}
function Invoke-TaskPloppDictationTick {
    if($null -ne $script:DictationInstaller){
        if($script:DictationInstaller.Done){
            $code=$script:DictationInstaller.ExitCode;$detail=$script:DictationInstaller.Error
            $script:DictationInstallError=if($code -eq 0){''}else{$detail}
            $script:DictationInstaller.Dispose();$script:DictationInstaller=$null
            if($code -eq 0){Set-TaskPloppMessage 'Success' 'Beide Diktat-Engines sind bereit' 'In der Konfiguration die Engine fuer das naechste Diktat waehlen.'}
            else {Set-TaskPloppMessage 'Error' 'Diktat-Einrichtung fehlgeschlagen' $detail}
            Update-TaskPloppDictationButton
        } else {Set-TaskPloppMessage 'Notice' 'Diktat-Komponenten werden eingerichtet' $script:DictationInstaller.LastLine}
    }
    if($script:DictationPhase -eq 'Recording'){
        try {
            $script:DictationRecorder.Poll()
            $peak=$script:DictationRecorder.Peak
            $script:DictationMaxPeak=[Math]::Max($script:DictationMaxPeak,$peak)
            $seconds=$script:DictationWatch.Elapsed.TotalSeconds
            if($seconds - $script:DictationDeviceCheck -ge 1){
                $null=[TaskPlopp.Dictation.Recorder]::DeviceId($script:DictationEndpoint)
                $script:DictationDeviceCheck=$seconds
            }
            $script:MessageBar.UpdateActivity($peak,$seconds)
        } catch {
            Stop-TaskPloppRecording -Discard
            Set-TaskPloppMessage 'Error' 'Mikrofonaufnahme abgebrochen' $_.Exception.Message
        }
    } elseif($script:DictationPhase -eq 'Transcribing'){
        $script:MessageBar.UpdateActivity(0,0)
        if($script:DictationJob.Done){
            $errorText=$script:DictationJob.Error;$text=$script:DictationJob.Text
            $script:DictationJob.Dispose();$script:DictationJob=$null;$script:DictationPhase='Ready'
            if($errorText){Set-TaskPloppMessage 'Error' 'Transkription fehlgeschlagen' $errorText}
            elseif([string]::IsNullOrWhiteSpace($text)){Set-TaskPloppMessage 'Notice' 'Kein Text erkannt' 'Zwischenablage bleibt erhalten. Mikrofon und Aufnahme pruefen.'}
            else {$script:DictationPendingText=$text;Copy-TaskPloppDictationResult}
            Update-TaskPloppDictationButton
        }
    }
}
function Close-TaskPloppDictation {
    foreach($name in 'DictationRecorder','DictationJob','DictationInstaller'){
        $value=Get-Variable $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if($null -ne $value){$value.Dispose();Set-Variable $name -Scope Script -Value $null}
    }
    $script:DictationPendingText='';$script:DictationPhase='Ready'
}
