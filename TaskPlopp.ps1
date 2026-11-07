#requires -Version 5.1
[CmdletBinding()]
param([switch]$LibraryOnly, [switch]$SmokeTest, [switch]$ResidentTest, [scriptblock]$OnShown, [string]$ConfigFile)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

if (-not ('TaskPlopp.Native' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace TaskPlopp {
    public class Window {
        public IntPtr Handle;
        public int ProcessId;
        public string Title;
    }
    public static class Native {
        private delegate bool EnumProc(IntPtr h, IntPtr p);
        [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr p);
        [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr h);
        [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr h, out int id);
        [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int command);
        [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr h, int command);
        [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr h);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] private static extern IntPtr GetAncestor(IntPtr h, uint flag);
        [DllImport("user32.dll")] private static extern IntPtr GetLastActivePopup(IntPtr h);
        [DllImport("user32.dll", EntryPoint="GetWindowLong")] private static extern int GetWindowLong32(IntPtr h, int index);
        [DllImport("user32.dll", EntryPoint="GetWindowLongPtr")] private static extern IntPtr GetWindowLong64(IntPtr h, int index);
        [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr h, int attribute, out int value, int size);
        [DllImport("kernel32.dll")] private static extern IntPtr OpenProcess(uint access, bool inherit, int id);
        [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] private static extern int GetApplicationUserModelId(IntPtr process, ref uint length, StringBuilder appId);
        [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr p);
        [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int height, uint flags);
        public static bool IsSwitchable(IntPtr h) {
            if (!IsWindow(h) || !IsWindowVisible(h)) return false;
            long style = IntPtr.Size == 8 ? GetWindowLong64(h, -20).ToInt64() : GetWindowLong32(h, -20);
            if ((style & 0x08000000L) != 0) return false;
            if ((style & 0x00000080L) != 0 && (style & 0x00040000L) == 0) return false;
            int cloaked;
            if (DwmGetWindowAttribute(h, 14, out cloaked, 4) == 0 && cloaked != 0) return false;
            if ((style & 0x00040000L) != 0) return true;
            IntPtr walk = GetAncestor(h, 3);
            for (int i=0; i<100; i++) {
                IntPtr popup = GetLastActivePopup(walk);
                if (popup == IntPtr.Zero || popup == walk) break;
                if (IsWindowVisible(popup)) { walk = popup; break; }
                walk = popup;
            }
            return walk == h;
        }
        public static string AppId(int processId) {
            IntPtr process = OpenProcess(0x1000, false, processId);
            if (process == IntPtr.Zero) return "";
            try {
                uint length = 0;
                if (GetApplicationUserModelId(process, ref length, null) != 122 || length == 0) return "";
                var value = new StringBuilder((int)length);
                return GetApplicationUserModelId(process, ref length, value) == 0 ? value.ToString() : "";
            } finally { CloseHandle(process); }
        }
        public static int HostedAppProcessId(IntPtr window, int hostProcessId) {
            int result = hostProcessId;
            EnumChildWindows(window, delegate(IntPtr child, IntPtr p) {
                int id; GetWindowThreadProcessId(child, out id);
                if (id != hostProcessId && AppId(id).Length > 0) { result=id; return false; }
                return true;
            }, IntPtr.Zero);
            return result;
        }
        public static Window[] List() {
            var list = new List<Window>();
            EnumWindows(delegate(IntPtr h, IntPtr p) {
                if (!IsWindowVisible(h)) return true;
                var title = new StringBuilder(2048);
                if (GetWindowText(h, title, title.Capacity) == 0) return true;
                int id; GetWindowThreadProcessId(h, out id);
                list.Add(new Window { Handle=h, ProcessId=id, Title=title.ToString() });
                return true;
            }, IntPtr.Zero);
            return list.ToArray();
        }
        public static bool Activate(IntPtr h) {
            if (!IsWindow(h)) return false;
            if (IsIconic(h)) {
                ShowWindowAsync(h, 9);
                for (int i=0; i<20 && IsIconic(h); i++) System.Threading.Thread.Sleep(10);
            }
            SetForegroundWindow(h);
            for (int i=0; i<20; i++) {
                if (GetForegroundWindow() == h) return true;
                System.Threading.Thread.Sleep(10);
            }
            return false;
        }
        public static bool Minimize(IntPtr h) {
            if (!IsWindow(h)) return false;
            int processId;
            if (GetWindowThreadProcessId(h, out processId) == GetCurrentThreadId()) ShowWindow(h, 6);
            else ShowWindowAsync(h, 6);
            for (int i=0; i<30; i++) {
                if (!IsWindow(h) || IsIconic(h)) return true;
                System.Threading.Thread.Sleep(10);
            }
            return false;
        }
        public static bool ActivateWithCoverWindows(IntPtr target, IntPtr[] covers) {
            if (!IsWindow(target)) return false;
            foreach (IntPtr cover in covers) {
                if (cover != target && IsWindow(cover) && !Minimize(cover)) return false;
            }
            return Activate(target);
        }
        public static void Raise(IntPtr h) {
            ShowWindowAsync(h, 9);
            SetWindowPos(h, new IntPtr(-1), 0, 0, 0, 0, 0x43);
            SetForegroundWindow(h);
        }
    }
}
'@
}

$script:ConfigPath = if($ConfigFile) { [IO.Path]::GetFullPath($ConfigFile) } else { Join-Path $PSScriptRoot 'config.json' }
$script:CitrixProcesses = @('wfica32', 'CDViewer', 'Citrix.DesktopViewer.App', 'SelfService', 'Receiver', 'CitrixWorkspaceApp')

function Get-Settings {
    param([string]$Path = $script:ConfigPath)
    if (-not (Test-Path -LiteralPath $Path)) {
        return ConvertTo-TaskPloppSettings ([pscustomobject]@{ ShowOpenWindows = $true; Programs = @() })
    }
    $data = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not ($data.PSObject.Properties.Name -contains 'Programs') -or
        -not ($data.PSObject.Properties.Name -contains 'ShowOpenWindows') -or
        $data.ShowOpenWindows -isnot [bool]) { throw 'Ungueltige Konfiguration.' }
    foreach ($entry in @($data.Programs)) {
        foreach ($key in @('Name', 'ProcessName', 'TitleContains')) {
            if (-not ($entry.PSObject.Properties.Name -contains $key) -or $entry.$key -isnot [string]) {
                throw "Ungueltiger Programmeintrag: $key fehlt oder ist kein Text."
            }
        }
        if ([string]::IsNullOrWhiteSpace($entry.Name) -or [string]::IsNullOrWhiteSpace($entry.ProcessName)) {
            throw 'Name und Prozessname duerfen nicht leer sein.'
        }
    }
    return ConvertTo-TaskPloppSettings $data
}

function Save-Settings {
    param($Settings, [string]$Path = $script:ConfigPath)
    # First validate a temporary file, then atomically replace the configuration.
    $temp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $json = ($Settings | ConvertTo-Json -Depth 5) -replace "`r?`n", "`r`n"
        [IO.File]::WriteAllText($temp, $json + "`r`n", [Text.UTF8Encoding]::new($true))
        $null = Get-Settings -Path $temp
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp, $Path, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temp, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
    }
}

function Get-AppWindows {
    param([switch]$Raw)
    $cache = @{}
    $folderPaths = $null
    foreach ($window in [TaskPlopp.Native]::List()) {
        if ($window.ProcessId -eq $PID) { continue }
        if (-not $Raw -and -not [TaskPlopp.Native]::IsSwitchable($window.Handle)) { continue }
        $processId = $window.ProcessId
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            if ($process.ProcessName -eq 'ApplicationFrameHost') {
                $processId = [TaskPlopp.Native]::HostedAppProcessId($window.Handle, $processId)
                $process = Get-Process -Id $processId -ErrorAction Stop
            }
            if (-not $cache.ContainsKey($processId)) {
                $path = ''; try { $path = [string]$process.Path } catch { }
                $cache[$processId] = @{ Path = $path; AppId = [TaskPlopp.Native]::AppId($processId) }
            }
        } catch { continue }
        if ($window.Title -eq 'Program Manager') { continue }
        $folderPath = ''
        if (-not $Raw -and $process.ProcessName -eq 'explorer') {
            if ($null -eq $folderPaths) { try { $folderPaths = Get-ExplorerFolderPaths } catch { $folderPaths = @{} } }
            if ($folderPaths.ContainsKey($window.Handle.ToInt64())) { $folderPath = $folderPaths[$window.Handle.ToInt64()] }
        }
        [pscustomobject]@{
            Handle = $window.Handle; Title = $window.Title
            ProcessName = $process.ProcessName; ProcessId = $processId
            ExecutablePath = $cache[$processId].Path; AppId = $cache[$processId].AppId
            FolderPath = $folderPath
        }
    }
}

function Show-Notice([string]$Message) {
    [void][Windows.Forms.MessageBox]::Show($Message, 'TaskPlopp', 'OK', 'Information')
}

. (Join-Path $PSScriptRoot 'TaskPlopp.Apps.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Configuration.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Keyboard.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Status.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Audio.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.IdleLock.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Dictation.ps1')

if ($LibraryOnly) { return }
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Bitte mit powershell.exe -STA -File TaskPlopp.ps1 starten.'
}

$created = $false
$eventName = if ($SmokeTest -or $ResidentTest) { "Local\TaskPlopp-Test-$PID" } else { 'Local\TaskPlopp-Wake' }
$script:WakeEvent = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::AutoReset,
    $eventName, [ref]$created)
if (-not $created -and -not $SmokeTest) {
    [void]$script:WakeEvent.Set()
    $script:WakeEvent.Dispose()
    return
}

try {
    try { $script:Settings = Get-Settings } catch {
        Show-Notice "Die Konfiguration konnte nicht gelesen werden. Sie bleibt erhalten.`r`n$($_.Exception.Message)"
        $script:Settings = ConvertTo-TaskPloppSettings ([pscustomobject]@{ ShowOpenWindows = $true; Programs = @() })
    }
    $script:AppIcon = [Drawing.Icon]::new((Join-Path $PSScriptRoot 'assets\TaskPlopp.ico'))
    $script:Main = New-Object TaskPlopp.KeyboardForm
    $script:Main.Icon = $script:AppIcon
    $script:Main.Text = 'TaskPlopp'
    $script:Main.Size = [Drawing.Size]::new(580, 650)
    $script:Main.MinimumSize = [Drawing.Size]::new(420, 350)
    $script:Main.StartPosition = 'CenterScreen'
    $script:Main.TopMost = $true
    $script:Main.Font = [Drawing.Font]::new('Segoe UI', 10)
    $script:Main.BackColor = [Drawing.Color]::FromArgb(245, 247, 250)
    $script:ExitRequested = $false
    $script:CurrentView = 'Tasks'
    $script:IdleState=New-TaskPloppIdleState $script:Settings.AutoLockEnabled $script:Settings.AutoLockMinutes
    $script:Main.Add_FormClosing({ param($sender, $eventArgs)
        if (-not $SmokeTest -and -not $script:ExitRequested -and
            $eventArgs.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) {
            $eventArgs.Cancel = $true
            $script:Main.Hide()
        }
    })

    function Show-TaskPlopp {
        $script:Main.Show()
        [TaskPlopp.Native]::Raise($script:Main.Handle)
        Show-TaskPloppView 'Tasks'
        Show-TaskPloppDictationStatus
    }

    $top = New-Object Windows.Forms.TableLayoutPanel
    $top.Name='TopArea'; $top.Dock='Top'; $top.AutoSize=$true; $top.AutoSizeMode='GrowAndShrink'
    $top.ColumnCount=1; $top.RowCount=2; $top.Margin=[Windows.Forms.Padding]::new(0)
    [void]$top.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize))
    [void]$top.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize))
    $toolbar = New-Object Windows.Forms.FlowLayoutPanel
    $toolbar.Name='Toolbar'; $toolbar.Dock='Fill'; $toolbar.AutoSize=$true; $toolbar.AutoSizeMode='GrowAndShrink'
    $toolbar.MinimumSize=[Drawing.Size]::new(0,52); $toolbar.Padding=[Windows.Forms.Padding]::new(8)
    $toolbar.Margin=[Windows.Forms.Padding]::new(0)
    $script:ToolbarToolTip=New-Object Windows.Forms.ToolTip
    $script:ToolbarToolTip.ShowAlways=$true
    $script:ToolbarIconFont=[Drawing.Font]::new('Segoe MDL2 Assets',14)
    $script:MessageBar = New-Object TaskPlopp.MessageBar
    $script:MessageBar.Name='Messages'; $script:MessageBar.Dock='Fill'; $script:MessageBar.Margin=[Windows.Forms.Padding]::new(0)
    $script:Main.Add_VisibleChanged({ $script:MessageBar.SetHostVisible($script:Main.Visible) })
    $top.Controls.Add($toolbar,0,0); $top.Controls.Add($script:MessageBar,0,1)
    $script:ListPanel = New-Object Windows.Forms.FlowLayoutPanel
    $script:ListPanel.Name='TaskContent'
    $script:ListPanel.Dock = 'Fill'; $script:ListPanel.AutoScroll = $true
    $script:ListPanel.FlowDirection = 'TopDown'; $script:ListPanel.WrapContents = $false
    $script:ListPanel.Padding = [Windows.Forms.Padding]::new(10)
    $script:Main.Controls.Add($script:ListPanel)
    $script:Main.Controls.Add($top)

    function Add-ToolbarButton([string]$Text, [scriptblock]$Action, [string]$Hint, [switch]$Icon) {
        $button = New-Object Windows.Forms.Button
        $button.Text=$Text; $button.AutoSize=$false; $button.Height=34
        $button.Width=if($Icon) { 42 } else { 64 }
        if($Icon) { $button.Font=$script:ToolbarIconFont }
        $button.AccessibleName=$Hint
        $script:ToolbarToolTip.SetToolTip($button,$Hint)
        $button.Add_Click($Action); $toolbar.Controls.Add($button)
        return $button
    }

    function Open-Window($Window) {
        if (-not [TaskPlopp.Native]::IsWindow($Window.Handle)) {
            Show-Notice 'Dieses Fenster wurde inzwischen geschlossen.'
            Update-WindowList
            return
        }
        # Keep the clicked GUI in the foreground until requesting the focus change.
        # A fullscreen/topmost Citrix viewer can otherwise keep covering local apps.
        $covers = [IntPtr[]]@()
        if ($Window.ProcessName -notin $script:CitrixProcesses) {
            $covers = [IntPtr[]]@(Get-AppWindows -Raw | Where-Object {
                $_.ProcessName -in $script:CitrixProcesses
            } | ForEach-Object { $_.Handle })
        }
        if ([TaskPlopp.Native]::ActivateWithCoverWindows($Window.Handle, $covers)) {
            $script:Main.Hide()
        } else {
            Show-Notice 'Das Fenster konnte nicht sichtbar aktiviert werden. Eventuell blockiert ein erhoehtes Programm den Wechsel. Bitte Fensterliste aktualisieren und erneut versuchen.'
        }
    }

    function Open-Favorite($Favorite) {
        $matches = @()
        if (-not $Favorite.LaunchAlways) { $matches = @(Get-AppWindows | Where-Object { Test-WindowMatch $_ $Favorite }) }
        if ($matches.Count -gt 0) { Open-Window $matches[0]; return }
        $target = Resolve-FavoriteStart $Favorite
        if (-not $target.Kind) {
            Show-Notice 'Fuer diesen Favoriten fehlt das Startziel. Bitte in der Konfiguration eine Startdatei oder installierte App auswaehlen.'
            Show-TaskPloppConfiguration
            return
        }
        # Validate before minimizing Citrix; missing files should leave the desktop untouched.
        $null = Start-FavoriteApplication $Favorite -Preview
        foreach ($citrix in @(Get-AppWindows -Raw | Where-Object { $_.ProcessName -in $script:CitrixProcesses })) {
            if (-not [TaskPlopp.Native]::Minimize($citrix.Handle)) { throw 'Citrix konnte nicht minimiert werden.' }
        }
        Start-FavoriteApplication $Favorite
        $script:Main.Hide()
    }

    function Add-WindowButton([string]$Text, $Target, [switch]$Favorite, [object[]]$MatchingWindows = @()) {
        $button = New-Object Windows.Forms.Button
        $button.Text = $Text; $button.Tag = [pscustomobject]@{ Target = $Target; IsFavorite = [bool]$Favorite }
        $script:Main.RegisterSelectionButton($button)
        $button.Size = [Drawing.Size]::new([Math]::Max(340, $script:ListPanel.ClientSize.Width - 42), 48)
        $button.TextAlign = 'MiddleLeft'; $button.AutoEllipsis = $true
        $button.FlatStyle = 'Flat'; $button.BackColor = [Drawing.Color]::White
        $button.Add_Click({ param($sender, $eventArgs)
            try {
                if ($sender.Tag.IsFavorite) { Open-Favorite $sender.Tag.Target }
                else { Open-Window $sender.Tag.Target }
            } catch { Show-Notice $_.Exception.Message }
        })
        if ($Favorite -and $MatchingWindows.Count -gt 1) {
            $menu = New-Object Windows.Forms.ContextMenuStrip
            foreach ($window in $MatchingWindows) {
                $item = $menu.Items.Add($window.Title); $item.Tag = $window
                $item.Add_Click({ param($sender,$eventArgs)
                    try { Open-Window $sender.Tag } catch { Show-Notice $_.Exception.Message }
                })
            }
            $button.ContextMenuStrip = $menu
        }
        if (-not $Favorite) {
            $menu = New-Object Windows.Forms.ContextMenuStrip
            $add = $menu.Items.Add('Als Favorit hinzufuegen'); $add.Tag = $Target
            $add.Add_Click({ param($sender, $eventArgs)
                try {
                    $copy = ConvertTo-TaskPloppSettings ($script:Settings | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
                    $copy.Programs = @($copy.Programs) + @(New-FavoriteFromWindow $sender.Tag)
                    Save-Settings $copy; $script:Settings = $copy; Update-WindowList
                } catch { Show-Notice $_.Exception.Message }
            })
            $hide = $menu.Items.Add('Dieses Programm ausblenden'); $hide.Tag = $Target
            $hide.Add_Click({ param($sender, $eventArgs)
                try {
                    $window = $sender.Tag
                    $copy = ConvertTo-TaskPloppSettings ($script:Settings | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
                    $copy.HiddenWindows = @($copy.HiddenWindows) + @([pscustomobject]@{
                        Name = Get-AppDisplayName $window.ProcessName $window.AppId; ProcessName = $window.ProcessName
                        ExecutablePath = $window.ExecutablePath; AppId = $window.AppId; TitleContains = ''
                    })
                    Save-Settings $copy; $script:Settings = $copy; Update-WindowList
                } catch { Show-Notice $_.Exception.Message }
            })
            $button.ContextMenuStrip = $menu
        }
        $button.Add_Disposed({ param($sender, $eventArgs)
            if ($sender.ContextMenuStrip) { $sender.ContextMenuStrip.Dispose() }
        })
        $script:ListPanel.Controls.Add($button)
    }

    function Add-Heading([string]$Text) {
        $label = New-Object Windows.Forms.Label
        $label.Text = $Text; $label.AutoSize = $true
        $label.Margin = [Windows.Forms.Padding]::new(3, 12, 3, 8)
        $script:ListPanel.Controls.Add($label)
    }

    function Update-WindowList {
        $script:ListPanel.SuspendLayout()
        try {
            $script:Main.ClearSelectionButtons()
            while ($script:ListPanel.Controls.Count -gt 0) { $script:ListPanel.Controls[0].Dispose() }
            $windows = @(Get-AppWindows | Sort-Object ProcessName, Title)
            Add-Heading 'Favoriten'
            foreach ($spec in @(Get-FavoriteButtonSpecs $windows $script:Settings)) {
                Add-WindowButton $spec.Text $spec.Favorite -Favorite -MatchingWindows $spec.Windows
            }
            if (@($script:Settings.Programs).Count -eq 0) { Add-Heading 'Favoriten ueber "Konfiguration" hinzufuegen.' }
            if ($script:Settings.ShowOpenWindows) {
                Add-Heading 'Weitere Fenster (Rechtsklick: Favorit / ausblenden)'
                $otherWindows = @(Get-OtherWindows $windows $script:Settings)
                foreach ($item in $otherWindows) { Add-WindowButton "$(Get-AppDisplayName $item.ProcessName $item.AppId) | $($item.Title)" $item }
                if ($otherWindows.Count -eq 0) { Add-Heading 'Keine weiteren Fenster.' }
            }
        } finally { $script:ListPanel.ResumeLayout() }
    }

    $null = Add-ToolbarButton ([string][char]0xE72C) { Show-TaskPloppView } -Hint 'Aktuelle Ansicht aktualisieren' -Icon
    $null = Add-ToolbarButton ([string][char]0xE713) { Show-TaskPloppConfiguration } -Hint 'Konfiguration oeffnen' -Icon
    $null = Add-ToolbarButton 'Citrix' {
        $citrix = @(Get-AppWindows -Raw | Where-Object { $_.ProcessName -in $script:CitrixProcesses })
        if ($citrix.Count -eq 0) { Show-Notice 'Kein sichtbares Citrix-Fenster gefunden.'; return }
        foreach ($window in $citrix) { [void][TaskPlopp.Native]::Minimize($window.Handle) }
        $script:Main.Close()
    } -Hint 'Citrix-Fenster minimieren'
    $script:AudioButton = Add-ToolbarButton 'Audio' {
        if ($script:CurrentView -eq 'Audio') { Show-TaskPloppView 'Tasks' }
        else { Show-TaskPloppView 'Audio' }
    } -Hint 'Lautsprecher und Mikrofone auswaehlen'
    $script:AudioButton.Name='AudioToggle'
    $script:LockButton=Add-ToolbarButton ([string][char]0xE72E) {
        try {
            $copy=ConvertTo-TaskPloppSettings ($script:Settings | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
            $copy.AutoLockEnabled=-not $copy.AutoLockEnabled
            Save-Settings $copy
            $script:Settings=$copy
            Apply-TaskPloppIdleSettings -Notify
        } catch { Set-TaskPloppMessage 'Error' 'Sperreinstellung konnte nicht gespeichert werden' $_.Exception.Message }
    } -Hint 'Automatische PC-Sperre' -Icon
    $script:LockButton.Name='AutoLockToggle'
    Apply-TaskPloppIdleSettings
    $script:DictationButton=Add-ToolbarButton ([string][char]0xE720) { Invoke-TaskPloppDictation } -Hint 'Diktat starten' -Icon
    $script:DictationButton.Name='DictationToggle'
    $dictationMenu=New-Object Windows.Forms.ContextMenuStrip
    $discardItem=$dictationMenu.Items.Add('Aufnahme verwerfen')
    $discardItem.Add_Click({Stop-TaskPloppRecording -Discard})
    $copyItem=$dictationMenu.Items.Add('Erneut in Zwischenablage kopieren')
    $copyItem.Add_Click({Copy-TaskPloppDictationResult})
    $dictationMenu.Add_Opening({
        $discardItem.Enabled=$script:DictationPhase -eq 'Recording'
        $copyItem.Enabled=[bool]$script:DictationPendingText
    })
    $script:DictationButton.ContextMenuStrip=$dictationMenu
    Update-TaskPloppDictationButton
    $script:Main.add_BackRequested({ Show-TaskPloppView 'Tasks' })
    $script:ListPanel.Add_SizeChanged({
        foreach ($control in $script:ListPanel.Controls) {
            if ($script:CurrentView -eq 'Tasks' -and $control -is [Windows.Forms.Button]) {
                $control.Width = [Math]::Max(340, $script:ListPanel.ClientSize.Width - 42)
            } elseif ($script:CurrentView -eq 'Audio' -and $control.Name -eq 'AudioColumns') {
                $control.Size=[Drawing.Size]::new([Math]::Max(200,$script:ListPanel.ClientSize.Width-20),[Math]::Max(60,$script:ListPanel.ClientSize.Height-20))
            }
        }
    })
    if (-not $SmokeTest -and -not $ResidentTest) {
        . (Join-Path $PSScriptRoot 'Start-TaskPlopp.ps1') -LibraryOnly
        $script:Tray = New-Object Windows.Forms.NotifyIcon
        $script:Tray.Icon = $script:AppIcon
        $script:Tray.Text = 'TaskPlopp'
        $menu = New-Object Windows.Forms.ContextMenuStrip
        $openItem = $menu.Items.Add('TaskPlopp oeffnen')
        $openItem.Add_Click({ Show-TaskPlopp })
        $exitItem = $menu.Items.Add('TaskPlopp beenden')
        $exitItem.Add_Click({ $script:ExitRequested = $true; $script:Main.Close() })
        $script:Tray.ContextMenuStrip = $menu
        $script:Tray.Add_DoubleClick({ Show-TaskPlopp })
        $script:Tray.Visible = $true
        try {
            $script:HotkeyListener = [TaskPloppHotkey.Listener]::new(0x4003, 0x79)
            $script:HotkeyListener.add_Pressed({ Show-TaskPlopp })
            $script:Tray.Text = 'TaskPlopp: Strg+Alt+F10'
        } catch {
            $script:Tray.Text = 'TaskPlopp: Hotkey belegt'
            $script:Tray.ShowBalloonTip(5000, 'TaskPlopp', 'Strg+Alt+F10 ist belegt. Bitte TaskPlopp ueber dieses Symbol oeffnen.', [Windows.Forms.ToolTipIcon]::Warning)
        }
    }
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 150
    $timer.Add_Tick({
        if ($script:WakeEvent.WaitOne(0)) {
            Show-TaskPlopp
        }
    })
    $script:Main.Add_Shown({ [TaskPlopp.Native]::Raise($script:Main.Handle) })
    if($OnShown) { $script:Main.Add_Shown($OnShown) }
    Update-WindowList
    $timer.Start()
    $dictationTimer=New-Object Windows.Forms.Timer
    $dictationTimer.Interval=100
    $dictationTimer.Add_Tick({Invoke-TaskPloppDictationTick})
    $dictationTimer.Start()
    $idleTimer=New-Object Windows.Forms.Timer
    $idleTimer.Interval=500
    $idleTimer.Add_Tick({ Invoke-TaskPloppIdleCheck })
    # UI smoke tests must never lock the user's desktop.
    if(-not $SmokeTest -and -not $ResidentTest) { $idleTimer.Start() }
    if ($SmokeTest -or $ResidentTest) {
        $smokeTimer = New-Object Windows.Forms.Timer
        $smokeTimer.Interval = 1200
        $smokeTimer.Add_Tick({
            $smokeTimer.Stop()
            if ($ResidentTest) {
                $script:Main.Close()
                if ($script:Main.IsDisposed -or $script:Main.Visible) { throw 'GUI wurde nicht ausgeblendet.' }
                $watch = [Diagnostics.Stopwatch]::StartNew()
                Show-TaskPlopp
                $watch.Stop()
                if (-not $script:Main.Visible) { throw 'GUI wurde nicht erneut eingeblendet.' }
                [Console]::WriteLine("OK: Schliessen blendet GUI aus; erneutes Einblenden inkl. Fensterliste in $($watch.ElapsedMilliseconds) ms, gleicher Prozess $PID.")
                $script:ExitRequested = $true
                $script:Main.Close()
                return
            }
            $bitmap = [Drawing.Bitmap]::new($script:Main.Width, $script:Main.Height)
            try {
                $script:Main.DrawToBitmap($bitmap, $script:Main.ClientRectangle)
                $bitmap.Save((Join-Path $env:TEMP 'TaskPlopp-smoke.png'))
            } finally { $bitmap.Dispose() }
            $script:Main.Close()
        })
        $smokeTimer.Start()
    }
    [Windows.Forms.Application]::Run($script:Main)
} finally {
    if(Get-Variable dictationTimer -ErrorAction SilentlyContinue){$dictationTimer.Dispose()}
    Close-TaskPloppDictation
    if(Get-Variable dictationMenu -ErrorAction SilentlyContinue){$dictationMenu.Dispose()}
    if (Get-Variable idleTimer -ErrorAction SilentlyContinue) { $idleTimer.Dispose() }
    if (Get-Variable HotkeyListener -Scope Script -ErrorAction SilentlyContinue) { $script:HotkeyListener.Dispose() }
    if (Get-Variable Tray -Scope Script -ErrorAction SilentlyContinue) {
        $script:Tray.Visible = $false
        $script:Tray.ContextMenuStrip.Dispose()
        $script:Tray.Dispose()
    }
    if (Get-Variable timer -ErrorAction SilentlyContinue) { $timer.Dispose() }
    if (Get-Variable smokeTimer -ErrorAction SilentlyContinue) { $smokeTimer.Dispose() }
    if (Get-Variable Main -Scope Script -ErrorAction SilentlyContinue) { $script:Main.Dispose() }
    if (Get-Variable ToolbarToolTip -Scope Script -ErrorAction SilentlyContinue) { $script:ToolbarToolTip.Dispose() }
    if (Get-Variable ToolbarIconFont -Scope Script -ErrorAction SilentlyContinue) { $script:ToolbarIconFont.Dispose() }
    if (Get-Variable AppIcon -Scope Script -ErrorAction SilentlyContinue) { $script:AppIcon.Dispose() }
    $script:WakeEvent.Dispose()
}
