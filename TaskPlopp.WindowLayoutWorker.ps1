#requires -Version 5.1
param([ValidateSet('Plan','Apply','Undo')][string]$Mode)
$ErrorActionPreference='Stop'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
try {
    . (Join-Path $PSScriptRoot 'TaskPlopp.Native.ps1')
    if([TaskPloppInterop.Geometry]::SetThreadDpiAwarenessContext([IntPtr](-4))-eq[IntPtr]::Zero){throw 'DPI_UNAVAILABLE'}
    . (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
    $request=[Console]::In.ReadToEnd()|ConvertFrom-Json
    switch($Mode){
        Plan {
            $context=Get-TaskPloppLayoutContext $request.ParentProcessId
            if(-not$context.Windows.Count){throw 'NO_WINDOWS'}
            $pictures=@(Get-TaskPloppLayoutPictures $context.Monitors)
            [Console]::WriteLine('CaptureDone')
            $answer=Get-TaskPloppLayoutAnswer $request.Intent $context $pictures $request.Model
            Assert-TaskPloppLayout $answer $context
            $result=[pscustomobject]@{Ok=$true;Context=$context;Answer=$answer}
        }
        Apply { $result=Set-TaskPloppLayout $request.Answer $request.Context }
        Undo { $result=Restore-TaskPloppLayout @($request.Snapshots) }
    }
    [Console]::WriteLine(($result|ConvertTo-Json -Depth 12 -Compress))
} catch {
    # Never forward request bodies, response bodies, headers or exception text.
    $code=[string]$_.Exception.Message
    if($code-cnotmatch'^(?:DPI_UNAVAILABLE|NO_WINDOWS|CAPTURE_FAILED|KEY_UNAVAILABLE|HTTP_[0-9]{3}|API_TIMEOUT|API_FAILED|API_RESPONSE|INVALID_LAYOUT|STALE_WINDOWS|MONITORS_CHANGED)$'){$code='LAYOUT_FAILED'}
    [Console]::WriteLine((@{Ok=$false;Code=$code}|ConvertTo-Json -Compress))
    exit 1
}
