#requires -Version 5.1
$ErrorActionPreference='Stop'
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
$config=Join-Path $env:TEMP ('TaskPlopp-transfer-ui-'+[guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($config,'{"ShowOpenWindows":false,"Programs":[]}',[Text.UTF8Encoding]::new($true))
$global:TransferUiFailure=$null
try{
    . (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -SmokeTest -ConfigFile $config -OnShown {
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
            Show-TaskPloppConfiguration -OnShown {
                param($dialog,$args)
                Show-TaskPloppTransfer -OnShown {$script:TransferOpened++}
                Assert ($script:TransferOpened-eq1) 'Transferdialog ueber Konfigurationsentwurf geoeffnet'
                $dialog.Controls.Find('CancelSettings',$true)[0].PerformClick()
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
            Write-Host 'OK: Zahnrad-Kontextmenue, Export/Import-Dialog, doppelte Oeffnung, Schliessen, Schutz des Konfigurationsentwurfs und verstecktes Hauptfenster.'
        }catch{$global:TransferUiFailure=$_;Write-Host $_.ToString();$sender.Close()}
    }
    if($global:TransferUiFailure){throw $global:TransferUiFailure}
}finally{if(Test-Path -LiteralPath $config){Remove-Item -LiteralPath $config}}
