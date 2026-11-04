#requires -Version 5.1
[CmdletBinding()]
param([switch]$CheckHotkey, [switch]$LibraryOnly, [uint32]$Modifiers = 0x4003, [uint32]$Key = 0x79)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not ('TaskPloppHotkey.Listener' -as [type])) {
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Diagnostics;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Drawing;
namespace TaskPloppHotkey {
    public sealed class Listener : NativeWindow, IDisposable {
        [DllImport("user32.dll", SetLastError=true)]
        static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);
        [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr window, int id);
        public event EventHandler Pressed;
        public Listener(uint modifiers, uint key) {
            CreateHandle(new CreateParams { Caption="TaskPlopp Hotkey", Parent=new IntPtr(-3) });
            // MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, virtual key F10.
            if (!RegisterHotKey(Handle, 1, modifiers, key)) {
                int error = Marshal.GetLastWin32Error();
                DestroyHandle();
                throw new Win32Exception(error, "Hotkey konnte nicht registriert werden (Windows-Fehler " + error + ").");
            }
        }
        protected override void WndProc(ref Message m) {
            if (m.Msg == 0x0312 && m.WParam.ToInt32() == 1) {
                if (Pressed != null) Pressed(this, EventArgs.Empty);
            }
            base.WndProc(ref m);
        }
        public void Dispose() {
            if (Handle != IntPtr.Zero) { UnregisterHotKey(Handle, 1); DestroyHandle(); }
        }
    }
}
'@
}
if ($LibraryOnly) { return }
if ($CheckHotkey) {
    $listener = [TaskPloppHotkey.Listener]::new($Modifiers, $Key)
    $listener.Dispose()
    Write-Output "OK: Hotkey registriert und wieder freigegeben (Modifiers=$Modifiers, Key=$Key)."
    return
}
& (Join-Path $PSScriptRoot 'TaskPlopp.ps1')
