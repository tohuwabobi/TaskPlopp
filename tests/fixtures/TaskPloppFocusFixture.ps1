#requires -Version 5.1
param([string]$Token,[int]$OwnerPid)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
. (Join-Path $PSScriptRoot '..\..\src\TaskPlopp.Native.ps1')
$null=New-TaskPloppNativeType 'TaskPloppFocusFixture.Foreground' 'user32.dll' @(@{Name='AllowSetForegroundWindow';Return=[bool];Args=@([int])})
$form=[Windows.Forms.Form]::new();$timeout=[Windows.Forms.Timer]::new();$timeout.Interval=90000
try{
    $form.Text='TaskPlopp external focus fixture '+$Token;$form.Size=[Drawing.Size]::new(440,260)
    $form.Add_Activated({$null=[TaskPloppFocusFixture.Foreground]::AllowSetForegroundWindow($OwnerPid)})
    $form.Add_Shown({[Console]::WriteLine($form.Handle.ToInt64())})
    $timeout.Add_Tick({$form.Close()});$timeout.Start()
    [Windows.Forms.Application]::Run($form)
}finally{$timeout.Dispose();$form.Dispose()}
