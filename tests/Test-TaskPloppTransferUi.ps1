#requires -Version 5.1
$ErrorActionPreference='Stop'
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
$config=Join-Path $env:TEMP ('TaskPlopp-transfer-ui-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($config,'{"ShowOpenWindows":false,"Programs":[]}',[Text.UTF8Encoding]::new($true))
$global:TransferUiFailure=$null
$global:TransferTestRoot=Join-Path $env:TEMP ('TaskPlopp-transfer-inline-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($global:TransferTestRoot)
try{
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -SmokeTest -ConfigFile $config -OnShown {
        param($sender,$args)
        try{
            $gear=$sender.Controls.Find('ConfigurationButton',$true)[0]
            Assert ($gear.ContextMenuStrip.Items.Count-eq1) 'Kontextmenue am Zahnrad fehlt'
            $script:TransferOpened=0
            Show-TaskPloppTransfer -OnShown {
                param($dialog,$args)
                $script:TransferOpened++
                Assert ($dialog.Controls.Find('ExportSettings',$true).Count-eq1-and$dialog.Controls.Find('ImportSettings',$true).Count-eq1) 'Export/Import fehlen'
                $same=$script:TransferDialog;Show-TaskPloppTransfer
                Assert ([object]::ReferenceEquals($same,$script:TransferDialog)) 'Doppelter Dialog'
                $bitmap=[Drawing.Bitmap]::new($dialog.Width,$dialog.Height)
                try{$dialog.DrawToBitmap($bitmap,$dialog.ClientRectangle);$bitmap.Save((Join-Path $env:TEMP 'TaskPlopp-transfer.png'))}finally{$bitmap.Dispose()}
                $dialog.Controls.Find('CloseTransfer',$true)[0].PerformClick()
            }
            Assert ($script:TransferOpened-eq1-and$null-eq$script:TransferDialog) 'Schliessen gibt Dialog nicht frei'
            function Get-TaskPloppOpenAIKeyPath {Join-Path $env:TEMP ('TaskPlopp-unconfigured-key-test-'+$PID+'.dpapi')}
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                Show-TaskPloppTransfer -OnShown {$script:TransferOpened++}
                Assert ($script:TransferOpened-eq1) 'Transferdialog ueber Konfigurationsentwurf geoeffnet'
                $dialog.Controls.Find('CloseSettings',$true)[0].PerformClick()
            }
            # Invoke the real context-menu handler, closing its modal dialog with a timer.
            $closer=[Windows.Forms.Timer]::new();$closer.Interval=50
            $closer.Add_Tick({
                $opened=Get-Variable TransferDialog -Scope Script -ValueOnly -ErrorAction SilentlyContinue
                if($opened-and-not$opened.IsDisposed){$closer.Stop();$script:TransferOpened++;$opened.Controls.Find('CloseTransfer',$true)[0].PerformClick()}
            })
            try{$closer.Start();$gear.ContextMenuStrip.Items[0].PerformClick()}finally{$closer.Dispose()}
            Assert ($script:TransferOpened-eq2) 'Rechtsklick-Menuehandler oeffnet nicht denselben Dialog'
            $sender.Hide()
            Show-TaskPloppTransfer -OnShown {param($dialog,$args)Assert $dialog.Visible 'Dialog bei verstecktem Hauptfenster unsichtbar';$dialog.Controls.Find('CloseTransfer',$true)[0].PerformClick()}
            Assert (-not$sender.Visible) 'Transfer erzwingt Hauptfenster'
            $sender.Show()
            foreach($save in $true,$false){$picker=New-TaskPloppTransferPicker -Save:$save;try{Assert (-not$picker.CheckFileExists-and-not$picker.CheckPathExists-and-not$picker.ValidateNames) 'Native Dateipicker-Rueckfrage aktiv';if($save){Assert (-not$picker.OverwritePrompt-and-not$picker.CreatePrompt) 'Native Export-Rueckfrage aktiv'}}finally{$picker.Dispose()}}
            $caught=$false;try{$null=Resolve-TaskPloppTransferFile (Join-Path $global:TransferTestRoot 'missing.zip')}catch{$caught=$true};Assert $caught 'Fehlende Importdatei akzeptiert'
            $caught=$false;try{$null=Resolve-TaskPloppProgramFile (Join-Path $global:TransferTestRoot 'missing.exe')}catch{$caught=$true};Assert $caught 'Fehlende Programmdatei akzeptiert'
            $package=Join-Path $global:TransferTestRoot 'Original.zip'
            $null=Write-TaskPloppTransferZip (Get-TaskPloppTransferData) $package
            $global:TransferChoice=$package
            function Select-TaskPloppTransferFile {param([switch]$Save) return $global:TransferChoice}
            $global:TransferImportCalls=0
            function Import-TaskPloppTransfer($Data){$global:TransferImportCalls++;return 'Fixture-Sicherung.zip'}
            Show-TaskPloppTransfer -OnShown {
                param($dialog,$args)
                try{
                    $load=$dialog.Controls.Find('ImportSettings',$true)[0];$export=$dialog.Controls.Find('ExportSettings',$true)[0];$apply=$dialog.Controls.Find('ApplyTransfer',$true)[0]
                    $load.PerformClick();Assert ($apply.Enabled-and$global:TransferImportCalls-eq0) 'Vorschau hat importiert'
                    $global:TransferChoice='';$load.PerformClick();Assert (-not$apply.Enabled-and$null-eq$dialog.Tag.Pending) 'Abbruch behaelt alte Aktion'
                    $global:TransferChoice=$package;$load.PerformClick();$apply.PerformClick();$apply.PerformClick()
                    Assert ($global:TransferImportCalls-eq1-and-not$apply.Enabled-and$null-eq$dialog.Tag.Pending) 'Import doppelt oder Vorbereitung nicht konsumiert'
                    $hash=(Get-FileHash -LiteralPath $package).Hash
                    $export.PerformClick();Assert ($apply.Enabled-and(Get-FileHash -LiteralPath $package).Hash-eq$hash) 'Export vor Anwenden ueberschrieben'
                    $apply.PerformClick();Assert (-not$apply.Enabled) 'Exportvorbereitung bleibt aktiv'
                    $global:TransferChoice=Join-Path $global:TransferTestRoot 'Neu.zip';$export.PerformClick()
                    Assert ((Test-Path -LiteralPath $global:TransferChoice)-and-not$apply.Enabled) 'Neue ZIP benoetigt unerwartet Bestaetigung'
                    $global:TransferChoice=$package;$load.PerformClick()
                    $global:TransferChoice=Join-Path $global:TransferTestRoot 'Fehlt.zip';$load.PerformClick()
                    Assert (-not$apply.Enabled-and$null-eq$dialog.Tag.Pending) 'Fehler behaelt alte Aktion'
                    $global:TransferChoice=$package;$load.PerformClick()
                    function Import-TaskPloppTransfer($Data){$global:TransferImportCalls++;throw 'Fixture nach Schreibpunkt'}
                    $apply.PerformClick();$apply.PerformClick()
                    Assert (-not$apply.Enabled-and$null-eq$dialog.Tag.Pending-and$global:TransferImportCalls-eq2) 'Fehlgeschlagenes Anwenden wiederholt alte Aktion'
                    $bitmap=[Drawing.Bitmap]::new($dialog.Width,$dialog.Height)
                    try{$dialog.DrawToBitmap($bitmap,$dialog.ClientRectangle);$bitmap.Save((Join-Path $env:TEMP 'TaskPlopp-transfer-inline.png'))}finally{$bitmap.Dispose()}
                    Write-Host 'OK: Native Picker ohne Rueckfragen, eigene Pfadvalidierung, Vorschau/Abbruch ohne Import, einmaliges Anwenden, explizites ZIP-Ersetzen und keine veralteten Aktionen nach Fehler.'
                }catch{$global:TransferUiFailure=$_;Write-Host $_.ToString()}
                finally{$dialog.Controls.Find('CloseTransfer',$true)[0].PerformClick()}
            }
            Write-Host 'OK: Zahnrad-Kontextmenue, Export/Import-Dialog, doppelte Oeffnung, Schliessen, Schutz des Konfigurationsentwurfs und verstecktes Hauptfenster.'
        }catch{$global:TransferUiFailure=$_;Write-Host $_.ToString();$sender.Close()}
    }
    if($global:TransferUiFailure){throw $global:TransferUiFailure}
}finally{
    if(Test-Path -LiteralPath $config){Remove-Item -LiteralPath $config}
    $resolved=[IO.Path]::GetFullPath($global:TransferTestRoot)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-transfer-inline-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
