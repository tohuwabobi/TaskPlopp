#requires -Version 5.1
param([int]$Favorites=-1)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion.Major-ne5){throw 'Windows PowerShell 5.1 required'}
if($Favorites-lt0){
    foreach($count in @(0,2,20)){
        & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File $PSCommandPath -Favorites $count
        if($LASTEXITCODE-ne0){throw ('Startup child failed: '+$count)}
    }
    exit
}
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Pump {for($i=0;$i-lt8;$i++){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 15}}
$root=Join-Path $env:TEMP ('TaskPlopp-startup-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root);$config=Join-Path $root 'config.json'
$data=@{ShowOpenWindows=$false;AutoLockEnabled=$false;Programs=@(for($i=0;$i-lt$Favorites;$i++){[pscustomobject]@{Name=('Favorite '+$i);ProcessName=('taskplopp-startup-missing-'+$i);TitleContains=''}})}
[IO.File]::WriteAllText($config,($data|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($true))
$global:StartupFailure=$null
try{
    # Normal PS5.1 process context: no forced DPI awareness before startup.
    . (Join-Path $PSScriptRoot '..\src\TaskPlopp.ps1') -SmokeTest -ConfigFile $config -OnShown {
        param($sender,$args)
        $smokeTimer.Stop()
        try{
            $area=$workArea;$first=$sender.Bounds;Pump
            Assert ($sender.Bounds-eq$first) 'Bounds changed after first Shown'
            Assert ([Math]::Abs(($first.Left+$first.Width/2)-($area.Left+$area.Width/2))-le1-and[Math]::Abs(($first.Top+$first.Height/2)-($area.Top+$area.Height/2))-le1) 'Visible startup not centered on selected working area'
            Assert ($first.Height-le[Math]::Max($sender.MinimumSize.Height,[Math]::Floor($area.Height*0.85))) 'Startup exceeds height cap'
            $bar=$script:MessageBar;$top=$bar.Parent;$content=$script:ListPanel
            if($Favorites-eq2){
                $last=@($content.Controls|Where-Object {$_-is[Windows.Forms.Button]})[-1]
                Assert ($last.Bottom+$last.Margin.Bottom+$content.Padding.Bottom-le$content.ClientSize.Height) 'Last favorite clipped despite available room'
                Assert ($content.ClientSize.Height-($last.Bottom+$last.Margin.Bottom+$content.Padding.Bottom)-le3) 'Unnecessary blank space below initial favorites'
                $bitmap=[Drawing.Bitmap]::new($sender.Width,$sender.Height)
                try{$sender.DrawToBitmap($bitmap,[Drawing.Rectangle]::new(0,0,$sender.Width,$sender.Height));$bitmap.Save((Join-Path $env:TEMP 'TaskPlopp-startup-preview.png'))}finally{$bitmap.Dispose()}
            }
            if($Favorites-eq20){Assert ($content.VerticalScroll.Visible) 'Many favorites are not scrollable'}
            $sender.Bounds=[Drawing.Rectangle]::new(($area.Left+30),($area.Top+30),[Math]::Max(720,$sender.MinimumSize.Width),600)
            $manual=$sender.Bounds;$listTop=$content.Top;$barHeight=$bar.Height
            foreach($kind in @('Notice','Success','Error')){
                Set-TaskPloppMessage $kind 'Startup layout fixture' 'Two lines stay reserved'
                Pump;Assert ($sender.Bounds-eq$manual-and$content.Top-eq$listTop-and$bar.Height-eq$barHeight) 'Status changes outer bounds/list origin'
            }
            $script:RefreshButton.PerformClick();Pump;Assert ($sender.Bounds-eq$manual) 'Refresh reapplied startup bounds'
            $script:HelpButton.PerformClick();Pump;$script:HelpButton.PerformClick();Pump
            Assert ($sender.Bounds-eq$manual) 'Help changes outer bounds'
            function Get-TaskPloppAudioDevices {param($Flow) @()}
            function Get-TaskPloppAudioDefaults {param($Flow) @()}
            Show-TaskPloppView Audio;Pump;Show-TaskPloppView Tasks;Pump
            Assert ($sender.Bounds-eq$manual) 'Audio changes outer bounds'
            $sender.Hide();$sender.Show();Pump;Show-TaskPlopp;Pump
            Assert ($sender.Bounds-eq$manual) 'Hide/Show or explicit wake reapplies startup size'
            Minimize-TaskPlopp;Pump
            Show-TaskPlopp;Pump
            Assert ($sender.Bounds-eq$manual) ('Minimize/restore changes manual normal bounds: expected='+$manual+', actual='+$sender.Bounds+', state='+$sender.WindowState)
            # Synthetic monitor rectangles and control lists use the same real measurement helper.
            $script:Settings.ShowOpenWindows=$true
            foreach($count in @(0,1,3,5)){
                $script:StartupOthers=$count
                function Get-AppWindows {
                    param([switch]$Raw)
                    for($i=0;$i-lt$script:StartupOthers;$i++){[pscustomobject]@{Handle=[IntPtr]::Zero;ProcessId=$PID;ProcessName=('startup-other-'+$i);Title=('Other '+$i);ExecutablePath='';AppId='';FolderPath=''}}
                }
                Update-WindowList
                $actualOthers=@($content.Controls|Where-Object {$_-is[Windows.Forms.Button]-and-not$_.Tag.IsFavorite})
                Assert ($actualOthers.Count-eq$count) 'Synthetic other windows not rendered'
                $rect=[Drawing.Rectangle]::new(-1500,-100,1300,1000)
                Set-TaskPloppStartupBounds $rect;Pump
                Assert ([Math]::Abs(($sender.Left+$sender.Width/2)-($rect.Left+$rect.Width/2))-le1-and$sender.Height-le850) 'Synthetic negative-origin centering/cap wrong'
                if($count-eq3){$threeHeight=$sender.Height}
                if($count-eq5){Assert ($sender.Height-eq$threeHeight) 'More than three additional windows enlarged startup'}
            }
            if($Favorites-le2){
                $script:StartupOthers=0;Update-WindowList
                $heading=@($content.Controls|Where-Object {$_-is[Windows.Forms.Label]})[0]
                $heading.Text=('Long wrapping heading for the owned startup fixture '*7)
                Set-TaskPloppStartupBounds ([Drawing.Rectangle]::new(0,0,1000,1600));Pump
                $last=$content.Controls[$content.Controls.Count-1]
                Assert ($last.Bottom+$last.Margin.Bottom+$content.Padding.Bottom-le$content.ClientSize.Height) 'Wrapped heading clips available target content'
            }
            $sender.Font=[Drawing.Font]::new('Segoe UI',20);Update-WindowList
            Set-TaskPloppStartupBounds ([Drawing.Rectangle]::new(0,0,1000,700));Pump
            Assert ($sender.Height-le595-and$sender.Width-ge$sender.MinimumSize.Width) 'Large-font/small-area cap wrong'
            Write-Host ('OK: Normal PS5.1 startup favorites='+$Favorites+', initial='+$first.Width+'x'+$first.Height+', centered/capped; status/manual size stable; 0/1/3/5 other windows, negative origin, large font.')
        }catch{$global:StartupFailure=$_}
        finally{$sender.Close()}
    }
    if($global:StartupFailure){throw $global:StartupFailure}
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if($resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($resolved)-like'TaskPlopp-startup-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
