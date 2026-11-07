#requires -Version 5.1
[CmdletBinding()]
param([switch]$Engines)
$ErrorActionPreference='Stop'
function Assert([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Preview($Form,[string]$Name){
    $bmp=[Drawing.Bitmap]::new($Form.Width,$Form.Height)
    try{$Form.DrawToBitmap($bmp,[Drawing.Rectangle]::new(0,0,$Form.Width,$Form.Height));$bmp.Save((Join-Path $env:TEMP $Name))}finally{$bmp.Dispose()}
}
$testConfig=Join-Path $env:TEMP ('TaskPlopp-dictation-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($testConfig,'{"ShowOpenWindows":false,"AutoLockEnabled":false,"AutoLockMinutes":30,"Programs":[],"HiddenWindows":[]}',[Text.UTF8Encoding]::new($true))
$global:DictationUiFailure=$null
if($Engines){
    Add-Type -AssemblyName System.Speech
    $s=[System.Speech.Synthesis.SpeechSynthesizer]::new();$memory=[IO.MemoryStream]::new()
    try {
        $s.SelectVoice('Microsoft Hedda Desktop')
        $s.SetOutputToAudioStream($memory,[System.Speech.AudioFormat.SpeechAudioFormatInfo]::new(16000,[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono))
        $s.Speak('Das ist ein Test für die Zwischenablage. Der zweite Satz muss ebenfalls erscheinen.')
        $global:DictationFixturePcm=$memory.ToArray()
    } finally {$s.Dispose();$memory.Dispose()}
}
try {
    . (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -SmokeTest -ConfigFile $testConfig -OnShown {
        param($sender,$args)
        try {
            $smokeTimer.Stop()
            $mic=$sender.Controls.Find('DictationToggle',$true)[0]
            Assert ($mic.Enabled -and $script:Settings.DictationEngine -eq 'Whisper') 'Standard/Startbutton falsch'
            $sender.Size=[Drawing.Size]::new(420,350)
            [Windows.Forms.Application]::DoEvents()
            $toolbar=$sender.Controls.Find('Toolbar',$true)[0]
            Assert (@($toolbar.Controls | ForEach-Object Top | Select-Object -Unique).Count -eq 1) 'Mikrofon erzeugt Umbruch'
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $tab=$dialog.Controls.Find('DictationTab',$true)[0];$tab.Parent.SelectedTab=$tab
                $dialog.Controls.Find('DictationEngine',$true)[0].SelectedIndex=1
                Preview $dialog 'TaskPlopp-dictation-config.png'
                $dialog.Controls.Find('SaveSettings',$true)[0].PerformClick()
            }
            Assert ((Get-Settings -Path $testConfig).DictationEngine -eq 'Vosk') 'Engine nicht gespeichert'
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                $dialog.Controls.Find('DictationEngine',$true)[0].SelectedIndex=0
                $dialog.Controls.Find('CancelSettings',$true)[0].PerformClick()
            }
            Assert ($script:Settings.DictationEngine -eq 'Vosk') 'Abbrechen hat Engine geaendert'
            $script:DictationPhase='Transcribing';Update-TaskPloppDictationButton
            Assert (-not $mic.Enabled) 'Parallelaufnahme moeglich'
            $script:DictationPhase='Ready';$script:DictationInstaller=[pscustomobject]@{Done=$false;LastLine='Test'}
            Update-TaskPloppDictationButton
            Assert (-not $mic.Enabled) 'Aufnahme waehrend Einrichtung moeglich'
            $script:DictationInstaller=$null;Update-TaskPloppDictationButton
            Set-TaskPloppActivity Recording
            for($n=0;$n -lt 64;$n++){Update-TaskPloppActivity (($n%10)/10.0) $n}
            Preview $sender 'TaskPlopp-dictation-recording.png'
            $sender.Hide();Assert (-not $sender.Visible) 'Ausblenden fehlgeschlagen'
            $sender.Show();$sender.Font=[Drawing.Font]::new('Segoe UI',15)
            Preview $sender 'TaskPlopp-dictation-large-font.png'
            Set-TaskPloppActivity Transcribing Vosk
            Update-TaskPloppActivity 0 0
            $script:DictationPendingText='Zwischenergebnis'
            function Set-TaskPloppDictationClipboard([string]$Text){throw 'Simulierte belegte Zwischenablage'}
            Copy-TaskPloppDictationResult
            Assert ($script:DictationPendingText -eq 'Zwischenergebnis') 'Text bei Clipboardfehler verloren'
            Assert ($script:MessageBar.BackColor.R -eq 255) 'Clipboardfehler nicht rot'
            function Set-TaskPloppDictationClipboard([string]$Text){$script:TestCopiedText=$Text}
            Copy-TaskPloppDictationResult
            Assert ($script:TestCopiedText -eq 'Zwischenergebnis' -and -not $script:DictationPendingText) 'Kopierversuch fehlgeschlagen'
            $fake=[pscustomobject]@{Done=$true;Error='';Text=''}
            $fake | Add-Member NoteProperty Disposed $true
            $script:DictationJob=$fake;$script:DictationPhase='Transcribing'
            Invoke-TaskPloppDictationTick
            Assert ($script:DictationPhase -eq 'Ready' -and -not $script:DictationPendingText) 'Leeres Ergebnis als Erfolg behandelt'
            $fake=[pscustomobject]@{Done=$true;Error='Testfehler';Text='Nicht kopieren'}
            $fake | Add-Member NoteProperty Disposed $true
            $script:DictationJob=$fake;$script:DictationPhase='Transcribing'
            Invoke-TaskPloppDictationTick
            Assert ($script:TestCopiedText -eq 'Zwischenergebnis') 'Fehlerergebnis kopiert'
            $fake=[pscustomobject]@{Disposed=$true;Async=[pscustomobject]@{IsCompleted=$true};StopWatch=$null;Shared=@{Stop=$false;Discard=$false;Closed=$true;Error='';Pcm=$null;MaxPeak=0.0}}
            $script:DictationRecorder=$fake;$script:DictationPhase='Recording'
            Stop-TaskPloppRecording -Discard;Invoke-TaskPloppDictationTick
            Assert ($fake.Shared.Discard-and$script:DictationPhase-eq'Ready'-and$null-eq$script:DictationRecorder) 'Verwerfen gibt Aufnahme nicht frei'
            $hang=[pscustomobject]@{Disposed=$false;Async=[pscustomobject]@{IsCompleted=$false};StopWatch=[pscustomobject]@{Elapsed=[TimeSpan]::FromSeconds(3)};Shared=@{Stop=$true;Discard=$false;Error='';Peak=0.0;MaxPeak=0.0}}
            $script:DictationRecorder=$hang;$script:DictationPhase='Recording'
            Invoke-TaskPloppDictationTick
            Assert (-not$hang.Disposed-and$script:DictationPhase-eq'Recording') 'Unfertigen Worker freigegeben oder neue Aufnahme erlaubt'
            Assert ($script:MessageBar.BackColor.R-eq255) 'Ausbleibende Freigabe nicht gemeldet'
            $failedClose=[pscustomobject]@{Disposed=$true;Async=[pscustomobject]@{IsCompleted=$true};StopWatch=$null;Shared=@{Stop=$true;Discard=$false;Closed=$false;Error='Treiber schliesst nicht';Pcm=$null;MaxPeak=0.0}}
            $script:DictationRecorder=$failedClose;$script:DictationPhase='Recording'
            Invoke-TaskPloppDictationTick
            Assert (-not$mic.Enabled-and$script:DictationPhase-eq'Recording') 'Nicht freigegebenes Mikrofon erlaubt neue Aufnahme'
            $script:DictationRecorder=$null;$script:DictationPhase='Ready';Update-TaskPloppDictationButton
            $oldRoot=$script:DictationRoot;$script:DictationRoot=Join-Path $env:TEMP 'TaskPlopp-missing-dictation-fixture'
            Invoke-TaskPloppDictation
            Assert ($script:DictationPhase -eq 'Ready' -and $null -eq $script:DictationRecorder) 'Fehlende Engine startet Aufnahme'
            $script:DictationRoot=$oldRoot
            if($Engines){
                Initialize-TaskPloppDictation
                $heartbeat=New-Object Windows.Forms.Timer;$heartbeat.Interval=50
                $global:DictationHeartbeats=0
                $heartbeat.Add_Tick({$global:DictationHeartbeats++});$heartbeat.Start()
                try {
                    foreach($engine in 'Whisper','Vosk'){
                        $fake=[pscustomobject]@{Disposed=$true;Async=[pscustomobject]@{IsCompleted=$true};StopWatch=$null;Shared=@{Stop=$false;Discard=$false;Closed=$true;Error='';Pcm=$global:DictationFixturePcm;MaxPeak=1.0}}
                        $script:DictationRecorder=$fake;$script:DictationPhase='Recording'
                        $script:DictationEngine=$engine;$script:DictationMaxPeak=1
                        Stop-TaskPloppRecording;Invoke-TaskPloppDictationTick
                        Assert ($script:DictationPhase-eq'Transcribing') 'Echte Engine nicht gestartet'
                        $watch=[Diagnostics.Stopwatch]::StartNew()
                        while($script:DictationPhase -eq 'Transcribing'){
                            if($watch.Elapsed.TotalSeconds -gt 30){throw 'GUI-Engine-Timeout'}
                            [Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 20
                        }
                        Assert ($script:TestCopiedText -match 'zweite|zweiter' -and $script:TestCopiedText -match 'erscheinen') 'Zweiter Satz fehlt im GUI-Ergebnis'
                    }
                    Assert ($global:DictationHeartbeats -gt 5) 'GUI wurde durch Transkription blockiert'
                    Write-Host 'OK: Beide echten Engines durch GUI-Ablauf, zweiter Satz erhalten, UI-Heartbeat laeuft weiter. Clipboard-Schreibgrenze simuliert.'
                } finally {$heartbeat.Dispose();$global:DictationFixturePcm=$null}
            }
            'OK: Engine speichern/abbrechen, kompakte GUI, Pegel, Sperre paralleler Aktionen, Clipboardfehler, leeres/fehlerhaftes Ergebnis, Verwerfen, fehlende Einrichtung.' | Write-Host
        } catch {$global:DictationUiFailure=$_;Write-Host $_.ToString()}
        finally {$sender.Close()}
    }
    if($global:DictationUiFailure){throw $global:DictationUiFailure}
} finally {if(Test-Path $testConfig){Remove-Item -LiteralPath $testConfig}}
