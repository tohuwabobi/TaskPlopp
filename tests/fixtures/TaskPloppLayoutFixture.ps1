#requires -Version 5.1
param([string]$Token,[string]$Signal,[ValidateSet('Window','Launcher','NoWindow','Double')][string]$Mode='Window',[switch]$Minimized,[switch]$InitiallyMaximized)
$ErrorActionPreference='Stop'
if($Mode-eq'Launcher'){[IO.File]::WriteAllText($Signal+'.launcherPid',[string]$PID);[IO.File]::WriteAllText($Signal,[string]$PID);return}
if($Mode-eq'NoWindow'){Start-Sleep -Seconds 3;return}
. (Join-Path $PSScriptRoot '..\..\src\TaskPlopp.Native.ps1')
$null=[TaskPloppInterop.Geometry]::SetThreadDpiAwarenessContext([IntPtr](-4))
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$form=[Windows.Forms.Form]::new();$other=$null;$timer=[Windows.Forms.Timer]::new();$timer.Interval=50
try{
    $form.Text=$Token;$form.StartPosition='Manual';$form.Bounds=[Drawing.Rectangle]::new(100,100,500,360)
    $form.Add_Shown({
        if($InitiallyMaximized){$form.WindowState='Maximized';[Windows.Forms.Application]::DoEvents()}
        if($Minimized){$form.WindowState='Minimized'}
    })
    $timer.Add_Tick({
        if($Signal-and[IO.File]::Exists($Signal)){
            [IO.File]::Delete($Signal);$form.WindowState='Maximized'
        }
    });$timer.Start()
    if($Mode-eq'Double'){$other=[Windows.Forms.Form]::new();$other.Text=$Token+' second';$other.Show()}
    [Windows.Forms.Application]::Run($form)
}finally{$timer.Dispose();if($other){$other.Dispose()};$form.Dispose()}
