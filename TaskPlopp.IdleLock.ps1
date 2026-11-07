# The old IdleLock observation, extended by the Windows input timestamp for brief key presses.
# No keys, coordinates or input history are logged or persisted.
if(-not ('TaskPloppIdle.Input' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace TaskPloppIdle {
    public sealed class Snapshot {
        public bool Available;
        public int X, Y;
        public bool KeyDown;
        public uint InputTick;
    }
    public static class Input {
        [StructLayout(LayoutKind.Sequential)] private struct Point { public int X,Y; }
        [StructLayout(LayoutKind.Sequential)] private struct LastInput { public uint Size,Tick; }
        [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
        [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll")] private static extern bool GetLastInputInfo(ref LastInput input);
        [DllImport("user32.dll")] public static extern bool LockWorkStation();
        public static Snapshot Read() {
            Point point;
            var result = new Snapshot();
            result.Available = GetCursorPos(out point);
            if (!result.Available) return result; // E.g. locked/input desktop unavailable.
            result.X=point.X; result.Y=point.Y;
            var last = new LastInput { Size=(uint)Marshal.SizeOf(typeof(LastInput)) };
            if (GetLastInputInfo(ref last)) result.InputTick=last.Tick;
            for (int key=1; key<255; key++) {
                if ((GetAsyncKeyState(key) & 0x8000) != 0) { result.KeyDown=true; break; }
            }
            return result;
        }
    }
}
'@
}

function Get-TaskPloppIdleClock { return [double][Diagnostics.Stopwatch]::GetTimestamp() / [Diagnostics.Stopwatch]::Frequency }
function New-TaskPloppIdleState([bool]$Enabled,[int]$Minutes) {
    [pscustomobject]@{ Enabled=$Enabled; Minutes=$Minutes; LastActivity=(Get-TaskPloppIdleClock); LastSample=$null }
}
function Test-TaskPloppIdleTimeout($State,$Sample,[double]$Now) {
    if(-not $State.Enabled -or -not $Sample.Available) {
        $State.LastActivity=$Now; $State.LastSample=$null; return $false
    }
    $previous=$State.LastSample
    $State.LastSample=$Sample
    if($null -eq $previous -or $Sample.KeyDown -or $Sample.X -ne $previous.X -or
        $Sample.Y -ne $previous.Y -or $Sample.InputTick -ne $previous.InputTick) {
        $State.LastActivity=$Now; return $false
    }
    if($Now - $State.LastActivity -ge $State.Minutes*60) {
        $State.LastActivity=$Now
        return $true
    }
    return $false
}
function Apply-TaskPloppIdleSettings([switch]$Notify) {
    # Library-only/configuration tests have no running monitor.
    if(-not (Get-Variable IdleState -Scope Script -ErrorAction SilentlyContinue)) { return }
    $enabled=[bool]$script:Settings.AutoLockEnabled
    $minutes=[int]$script:Settings.AutoLockMinutes
    $changed=$script:IdleState.Enabled -ne $enabled -or $script:IdleState.Minutes -ne $minutes
    if($changed) { $script:IdleState=New-TaskPloppIdleState $enabled $minutes }
    $script:LockButton.Text=if($enabled) { [string][char]0xE72E } else { [string][char]0xE785 }
    $script:LockButton.UseVisualStyleBackColor=$false
    $script:LockButton.BackColor=if($enabled) { [Drawing.Color]::FromArgb(205,239,211) } else { [Drawing.Color]::FromArgb(230,230,230) }
    $script:LockButton.FlatStyle='Flat'
    $script:LockButton.FlatAppearance.BorderSize=if($enabled) { 2 } else { 1 }
    $hint=if($enabled) { "PC-Sperre aktiv: nach $minutes Minuten ohne Eingabe. Klicken zum Deaktivieren." }
        else { 'Automatische PC-Sperre aus. Klicken zum Aktivieren.' }
    $script:LockButton.AccessibleName=$hint
    $script:ToolbarToolTip.SetToolTip($script:LockButton,$hint)
    if($Notify -and $changed) {
        if($enabled) { Set-TaskPloppMessage 'Success' 'Automatische PC-Sperre aktiviert' "Nach $minutes Minuten ohne Maus-/Tastaturaktivitaet. Die Frist beginnt jetzt neu." }
        else { Set-TaskPloppMessage 'Notice' 'Automatische PC-Sperre deaktiviert' 'Die TaskPlopp-Sperre ist aus. Windows-eigene Sperrvorgaben bleiben unveraendert.' }
    }
}
function Invoke-TaskPloppIdleCheck {
    if(-not $script:IdleState.Enabled) { return }
    $sample=[TaskPloppIdle.Input]::Read()
    if(Test-TaskPloppIdleTimeout $script:IdleState $sample (Get-TaskPloppIdleClock)) {
        if([TaskPloppIdle.Input]::LockWorkStation()) {
            Set-TaskPloppMessage 'Notice' 'Automatische PC-Sperre angefordert' "Seit $($script:IdleState.Minutes) Minuten keine erkannte Maus-/Tastaturaktivitaet."
        } else {
            Set-TaskPloppMessage 'Error' 'PC-Sperre konnte nicht angefordert werden' 'Windows hat den Sperraufruf nicht angenommen.'
        }
    }
}
