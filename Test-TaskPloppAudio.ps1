#requires -Version 5.1
[CmdletBinding()]
param([switch]$Hardware)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'TaskPlopp.ps1') -LibraryOnly
function Assert([bool]$Condition,[string]$Message) { if(-not $Condition) { throw $Message } }
Initialize-TaskPloppAudio
foreach($type in @([TaskPloppInterop.AudioEnumerator],[TaskPloppInterop.AudioEndpoint],[TaskPloppInterop.AudioProperties],[TaskPloppInterop.AudioPolicy])) {
    foreach($method in $type.GetMethods()) {Assert (($method.MethodImplementationFlags -band [Reflection.MethodImplAttributes]::PreserveSig) -ne 0) 'PreserveSig fehlt.'}
}
$enumerator=New-TaskPloppAudioEnumerator
Assert ([Runtime.InteropServices.Marshal]::ReleaseComObject($enumerator)-eq0) 'Zusaetzliche COM-Referenz des Erzeugers bleibt uebrig.'
$device=[pscustomobject]@{Id='A';Name='Testmikrofon';ContainerId='group-1'}
$all=@(0..2 | ForEach-Object { [pscustomobject]@{Role=$_;Id='A';Error=''} })
Assert ((Get-TaskPloppAudioLabel $device $all) -like '[[]Aktiv[]]*') 'Einheitlicher Standard nicht markiert.'
$all[2].Id='B'
$label=Get-TaskPloppAudioLabel $device $all
Assert ($label -like '*Console*Multimedia*' -and $label -notlike '*Aktiv*') 'Unterschiedliche Rollen falsch dargestellt.'
$color1=Get-TaskPloppAudioColor -Name 'Lautsprecher (Test)' -ContainerId 'same'
$color2=Get-TaskPloppAudioColor -Name 'Mikrofon (Test)' -ContainerId 'same'
Assert ($color1.ToArgb() -eq $color2.ToArgb()) 'Geraetepaare haben unterschiedliche Farben.'
Write-Output 'OK: COM-Signaturen, PROPVARIANT, Rollenanzeige und Geraetefarben.'

# Inspect live hardware without changing it by default.
foreach($flow in 0,1) {
    $devices=@(Get-TaskPloppAudioDevices $flow)
    $defaults=@(Get-TaskPloppAudioDefaults $flow)
    Assert ($defaults.Count -eq 3) 'Nicht alle drei Rollen gelesen.'
    Write-Output "OK: Flow $flow, $($devices.Count) aktive Geraete, drei Rollen abgefragt."
    if(-not $Hardware -or $devices.Count -eq 0 -or @($defaults | Where-Object {-not $_.Id -or $_.Error}).Count -gt 0) { continue }
    $target=$devices | Where-Object Id -ne $defaults[0].Id | Select-Object -First 1
    if(-not $target) { $target=$devices[0] }
    try {
        Set-TaskPloppAudioDefault $target.Id
        $actual=@(Get-TaskPloppAudioDefaults $flow)
        Assert (@($actual | Where-Object {$_.Id -ne $target.Id -or $_.Error}).Count -eq 0) 'Realer Wechsel nicht fuer alle Rollen bestaetigt.'
        Write-Output "OK: Flow $flow real umgeschaltet und alle drei Rollen bestaetigt."
    } finally {
        foreach($old in $defaults) { Set-TaskPloppAudioRole $old.Id $old.Role }
        $restored=@(Get-TaskPloppAudioDefaults $flow)
        foreach($old in $defaults) { Assert ($restored[$old.Role].Id -eq $old.Id) 'Urspruenglicher Standard nicht wiederhergestellt.' }
        Write-Output "OK: Flow $flow auf urspruengliche Standards zurueckgestellt."
    }
}

# Deterministic failures without touching audio hardware.
$realView=${function:Update-TaskPloppAudioView}
function Set-TaskPloppMessage($Kind,$Summary,$Detail) { $script:MessageKind=$Kind }
function Update-TaskPloppAudioView { $script:RefreshCount++ }
$script:RefreshCount=0
function Set-TaskPloppAudioDefault($Id) { }
function Get-TaskPloppAudioDefaults($Flow) { $all }
$all[2].Id='A'
Invoke-TaskPloppAudioSelection $device 1
Assert ($script:MessageKind -eq 'Success') 'Bestaetigter Wechsel nicht als Erfolg gemeldet.'
$all[2].Id='B'
Invoke-TaskPloppAudioSelection $device 1
Assert ($script:MessageKind -eq 'Error') 'Teilweiser Wechsel als Erfolg gemeldet.'
function Set-TaskPloppAudioDefault($Id) { throw 'Test: Geraet inzwischen entfernt' }
Invoke-TaskPloppAudioSelection $device 1
Assert ($script:MessageKind -eq 'Error' -and $script:RefreshCount -eq 3) 'Fehler nicht gemeldet oder Ansicht nicht erneuert.'
function Get-TaskPloppAudioDevices($Flow) { @() }
$script:Main=New-Object Windows.Forms.Form
Initialize-TaskPloppKeyboard $script:Main
$script:ListPanel=New-Object Windows.Forms.FlowLayoutPanel
$script:ListPanel.Size=[Drawing.Size]::new(500,300)
$script:Main.Controls.Add($script:ListPanel)
# Restore only the real view function for rendering the empty-device case.
Set-Item Function:\Update-TaskPloppAudioView -Value $realView
try {
    Update-TaskPloppAudioView
    Assert ($script:ListPanel.Controls[0].Controls.Count -eq 2) 'Leere Geraeteliste zerstoert Audioansicht.'
} finally { $script:Main.Dispose() }
Write-Output 'OK: Erfolg, Teilfehler, entferntes Geraet und leere Geraeteliste ohne Absturz.'
