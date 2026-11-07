#requires -Version 5.1
[CmdletBinding()]
param([switch]$LibraryOnly, [switch]$SmokeTest, [switch]$ResidentTest, [scriptblock]$OnShown, [string]$ConfigFile)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

. (Join-Path $PSScriptRoot 'TaskPlopp.Native.ps1')

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
    foreach ($window in (Get-TaskPloppNativeWindows)) {
        if ($window.ProcessId -eq $PID) { continue }
        if (-not $Raw -and -not (Test-TaskPloppSwitchable $window.Handle)) { continue }
        $processId = $window.ProcessId
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            if ($process.ProcessName -eq 'ApplicationFrameHost') {
                $processId = (Get-TaskPloppHostedProcess $window.Handle $processId)
                $process = Get-Process -Id $processId -ErrorAction Stop
            }
            if (-not $cache.ContainsKey($processId)) {
                $path = ''; try { $path = [string]$process.Path } catch { }
                $cache[$processId] = @{ Path = $path; AppId = (Get-TaskPloppAppId $processId) }
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

. (Join-Path $PSScriptRoot 'TaskPlopp.Apps.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Hotkey.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Configuration.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Keyboard.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Status.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Audio.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.IdleLock.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Dictation.ps1')
. (Join-Path $PSScriptRoot 'TaskPlopp.Transfer.ps1')

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

$script:StartupNotice=''
$uiExceptionHandler=[Threading.ThreadExceptionEventHandler]{param($sender,$eventArgs)
    try{Set-TaskPloppMessage Error 'Aktion konnte nicht abgeschlossen werden' $eventArgs.Exception.Message}
    catch{$script:StartupNotice=$eventArgs.Exception.Message}
}
[Windows.Forms.Application]::add_ThreadException($uiExceptionHandler)
try {
    try { $script:Settings = Get-Settings } catch {
        $script:StartupNotice="Die Konfiguration konnte nicht gelesen werden. Sie bleibt erhalten. $($_.Exception.Message)"
        $script:Settings = ConvertTo-TaskPloppSettings ([pscustomobject]@{ ShowOpenWindows = $true; Programs = @() })
    }
    $script:AppIcon = [Drawing.Icon]::new((Join-Path $PSScriptRoot 'assets\TaskPlopp.ico'))
    $script:Main = New-Object Windows.Forms.Form
    Initialize-TaskPloppKeyboard $script:Main
    $script:Main.Icon = $script:AppIcon
    $script:Main.Text = 'TaskPlopp'
    $workArea = [Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position).WorkingArea
    $script:Main.Size = [Drawing.Size]::new([Math]::Min(760, $workArea.Width - 80), [Math]::Min(1200, $workArea.Height - 80))
    $script:Main.MinimumSize = [Drawing.Size]::new(420, 350)
    $script:Main.StartPosition = 'CenterScreen'
    $script:Main.TopMost = $true
    $script:Main.Font = [Drawing.Font]::new('Segoe UI', 15)
    $script:Main.BackColor = [Drawing.Color]::FromArgb(245, 247, 250)
    $script:ExitRequested = $false
    $script:HotkeysEnabled=-not $SmokeTest -and -not $ResidentTest
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
        $transfer=Get-Variable TransferDialog -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if($transfer -and -not $transfer.IsDisposed){$transfer.Activate();return}
        $script:Main.Show()
        Raise-TaskPloppWindow $script:Main.Handle
        Show-TaskPloppView 'Tasks'
        Show-TaskPloppDictationStatus
    }

    $top = New-Object Windows.Forms.TableLayoutPanel
    $top.Name='TopArea'; $top.Dock='Top'; $top.AutoSize=$true; $top.AutoSizeMode='GrowAndShrink'
    $top.ColumnCount=1; $top.RowCount=2; $top.Margin=[Windows.Forms.Padding]::new(0)
    [void]$top.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize))
    [void]$top.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::AutoSize))
    $script:ContentInset=10
    $toolbar = New-Object Windows.Forms.TableLayoutPanel
    $toolbar.Name='Toolbar';$toolbar.Dock='Fill';$toolbar.AutoSize=$true;$toolbar.AutoSizeMode='GrowAndShrink'
    $toolbar.ColumnCount=2;$toolbar.RowCount=1;$toolbar.Padding=[Windows.Forms.Padding]::new(10,8,10,8)
    $toolbar.MinimumSize=[Drawing.Size]::new(0,52);$toolbar.Margin=[Windows.Forms.Padding]::new(0)
    [void]$toolbar.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,100))
    [void]$toolbar.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::AutoSize))
    $toolbarLeft=[Windows.Forms.FlowLayoutPanel]::new();$toolbarLeft.Name='ToolbarLeft'
    $toolbarLeft.Dock='Fill';$toolbarLeft.AutoSize=$true;$toolbarLeft.WrapContents=$false
    $toolbarLeft.Margin=[Windows.Forms.Padding]::new(0,0,12,0)
    $toolbarRight=[Windows.Forms.FlowLayoutPanel]::new();$toolbarRight.Name='ToolbarRight'
    $toolbarRight.Dock='Fill';$toolbarRight.AutoSize=$true;$toolbarRight.WrapContents=$false
    $toolbarRight.Margin=[Windows.Forms.Padding]::new(0)
    $toolbar.Controls.Add($toolbarLeft,0,0);$toolbar.Controls.Add($toolbarRight,1,0)
    $script:ToolbarToolTip=New-Object Windows.Forms.ToolTip
    $script:ToolbarToolTip.ShowAlways=$true
    $script:ToolbarIconFont=[Drawing.Font]::new('Segoe MDL2 Assets',14)
    $script:MessageBar = New-TaskPloppMessageBar
    $script:MessageBar.Name='Messages'; $script:MessageBar.Dock='Fill'; $script:MessageBar.Margin=[Windows.Forms.Padding]::new(10,3,10,3)
    $script:Main.Add_VisibleChanged({ Set-TaskPloppStatusHostVisible $script:Main.Visible })
    $top.Controls.Add($toolbar,0,0); $top.Controls.Add($script:MessageBar,0,1)
    $script:ListPanel = New-Object Windows.Forms.FlowLayoutPanel
    $script:ListPanel.Name='TaskContent'
    $script:ListPanel.Dock = 'Fill'; $script:ListPanel.AutoScroll = $true
    $script:ListPanel.FlowDirection = 'TopDown'; $script:ListPanel.WrapContents = $false
    $script:ListPanel.Padding = [Windows.Forms.Padding]::new(10)
    $script:Main.Controls.Add($script:ListPanel)
    $script:Main.Controls.Add($top)

    function Add-ToolbarButton([string]$Text, [scriptblock]$Action, [string]$Hint, [switch]$Icon, [switch]$Right) {
        $button = New-Object Windows.Forms.Button
        $button.Text=$Text; $button.AutoSize=$false; $button.Height=34
        $button.Width=if($Icon) { 42 } else { [Math]::Max(64,[Windows.Forms.TextRenderer]::MeasureText($Text,$script:Main.Font).Width+18) }
        if($Icon) { $button.Font=$script:ToolbarIconFont }
        $button.AccessibleName=$Hint
        $script:ToolbarToolTip.SetToolTip($button,$Hint)
        $group=if($Right){$toolbarRight}else{$toolbarLeft}
        $button.Margin=[Windows.Forms.Padding]::new(0)
        if($group.Controls.Count){$group.Controls[$group.Controls.Count-1].Margin=[Windows.Forms.Padding]::new(0,0,6,0)}
        $button.Add_Click($Action);$group.Controls.Add($button)
        return $button
    }

    function Open-Window($Window) {
        if (-not [TaskPloppInterop.User]::IsWindow($Window.Handle)) {
            Set-TaskPloppMessage Notice 'Fenster inzwischen geschlossen' 'Bitte einen anderen Eintrag auswaehlen.'
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
        if ((Activate-TaskPloppCoveredWindow $Window.Handle $covers)) {
            $script:Main.Hide()
        } else {
            Set-TaskPloppMessage Error 'Fenster konnte nicht aktiviert werden' 'Eventuell blockiert ein erhoehtes Programm den Wechsel. Bitte aktualisieren und erneut versuchen.'
        }
    }

    function Open-Favorite($Favorite) {
        $matches = @()
        if (-not $Favorite.LaunchAlways) { $matches = @(Get-AppWindows | Where-Object { Test-WindowMatch $_ $Favorite }) }
        if ($matches.Count -gt 0) { Open-Window $matches[0]; return }
        $target = Resolve-FavoriteStart $Favorite
        if (-not $target.Kind) {
            Set-TaskPloppMessage Notice 'Startziel fehlt' 'Bitte ueber das Zahnrad eine Startdatei oder installierte App auswaehlen.'
            return
        }
        # Validate before minimizing Citrix; missing files should leave the desktop untouched.
        $null = Start-FavoriteApplication $Favorite -Preview
        foreach ($citrix in @(Get-AppWindows -Raw | Where-Object { $_.ProcessName -in $script:CitrixProcesses })) {
            if (-not (Minimize-TaskPloppWindow $citrix.Handle)) { throw 'Citrix konnte nicht minimiert werden.' }
        }
        Start-FavoriteApplication $Favorite
        $script:Main.Hide()
    }

    function Add-WindowButton([string]$Text, $Target, [switch]$Favorite, [object[]]$MatchingWindows = @()) {
        $button = New-Object Windows.Forms.Button
        $button.Text = $Text; $button.Tag = [pscustomobject]@{ Target = $Target; IsFavorite = [bool]$Favorite }
        $script:Main.RegisterSelectionButton($button)
        $button.Size = [Drawing.Size]::new([Math]::Max(1, $script:ListPanel.ClientSize.Width - $script:ListPanel.Padding.Horizontal), [Math]::Max(48,2*$script:Main.Font.Height+8))
        $button.Margin=[Windows.Forms.Padding]::new(0,3,0,3)
        $button.TextAlign = 'MiddleLeft'; $button.AutoEllipsis = $true
        $button.FlatStyle = 'Flat'; $button.BackColor = [Drawing.Color]::White
        $button.Add_Click({ param($sender, $eventArgs)
            try {
                if ($sender.Tag.IsFavorite) { Open-Favorite $sender.Tag.Target }
                else { Open-Window $sender.Tag.Target }
            } catch { Set-TaskPloppMessage Error 'Aktion fehlgeschlagen' $_.Exception.Message }
        })
        if ($Favorite -and $MatchingWindows.Count -gt 1) {
            $menu = New-Object Windows.Forms.ContextMenuStrip
            foreach ($window in $MatchingWindows) {
                $item = $menu.Items.Add($window.Title); $item.Tag = $window
                $item.Add_Click({ param($sender,$eventArgs)
                    try { Open-Window $sender.Tag } catch { Set-TaskPloppMessage Error 'Aktion fehlgeschlagen' $_.Exception.Message }
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
                } catch { Set-TaskPloppMessage Error 'Aktion fehlgeschlagen' $_.Exception.Message }
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
                } catch { Set-TaskPloppMessage Error 'Aktion fehlgeschlagen' $_.Exception.Message }
            })
            $button.ContextMenuStrip = $menu
        }
        $button.Add_Disposed({ param($sender, $eventArgs)
            if ($sender.ContextMenuStrip) { $sender.ContextMenuStrip.Dispose() }
        })
        $script:ListPanel.Controls.Add($button)
    }

    function Add-Heading([string]$Text,[switch]$Bold) {
        $label = New-Object Windows.Forms.Label
        $label.Text = $Text; $label.AutoSize = $true
        if($Bold){
            $label.Font=[Drawing.Font]::new($script:Main.Font,[Drawing.FontStyle]::Bold)
            $label.Tag=$label.Font
            $label.Add_Disposed({param($sender,$args) $sender.Tag.Dispose()})
        }
        $label.Margin = [Windows.Forms.Padding]::new(0,12,0,8)
        $label.MaximumSize=[Drawing.Size]::new([Math]::Max(1,$script:ListPanel.ClientSize.Width-$script:ListPanel.Padding.Horizontal),0)
        $script:ListPanel.Controls.Add($label)
    }

    function Update-WindowList {
        $script:ListPanel.SuspendLayout()
        try {
            $script:Main.ClearSelectionButtons()
            while ($script:ListPanel.Controls.Count -gt 0) { $script:ListPanel.Controls[0].Dispose() }
            $windows = @(Get-AppWindows | Sort-Object ProcessName, Title)
            Add-Heading 'Favoriten' -Bold
            foreach ($spec in @(Get-FavoriteButtonSpecs $windows $script:Settings)) {
                Add-WindowButton $spec.Text $spec.Favorite -Favorite -MatchingWindows $spec.Windows
            }
            if (@($script:Settings.Programs).Count -eq 0) { Add-Heading 'Favoriten ueber "Konfiguration" hinzufuegen.' }
            if ($script:Settings.ShowOpenWindows) {
                Add-Heading 'Weitere Fenster (Rechtsklick: Favorit / ausblenden)' -Bold
                $otherWindows = @(Get-OtherWindows $windows $script:Settings)
                foreach ($item in $otherWindows) { Add-WindowButton "$(Get-AppDisplayName $item.ProcessName $item.AppId) | $($item.Title)" $item }
                if ($otherWindows.Count -eq 0) { Add-Heading 'Keine weiteren Fenster.' }
            }
        } finally { $script:ListPanel.ResumeLayout() }
    }

    $script:RefreshButton = Add-ToolbarButton ([string][char]0xE72C) { Show-TaskPloppView } -Hint 'Aktuelle Ansicht aktualisieren' -Icon -Right
    $script:RefreshButton.Name='RefreshButton'
    $script:ConfigurationButton = Add-ToolbarButton ([string][char]0xE713) { Show-TaskPloppConfiguration } -Hint 'Konfiguration oeffnen (Rechtsklick: sichern/uebertragen)' -Icon -Right
    $script:ConfigurationButton.Name='ConfigurationButton'
    $transferMenu=[Windows.Forms.ContextMenuStrip]::new()
    $transferItem=$transferMenu.Items.Add('Konfiguration sichern/uebertragen')
    $transferItem.Add_Click({Show-TaskPloppTransfer})
    $script:ConfigurationButton.ContextMenuStrip=$transferMenu
    $null = Add-ToolbarButton 'Citrix' {
        $citrix = @(Get-AppWindows -Raw | Where-Object { $_.ProcessName -in $script:CitrixProcesses })
        if ($citrix.Count -eq 0) { Set-TaskPloppMessage Notice 'Kein sichtbares Citrix-Fenster gefunden' ''; return }
        foreach ($window in $citrix) { $null=Minimize-TaskPloppWindow $window.Handle }
        $script:Main.Close()
    } -Hint 'Citrix-Fenster minimieren'
    $toolbarLeft.Controls[0].Name='CitrixButton'
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

    $script:UpdatingContentLayout=$false
    function Update-TaskPloppContentLayout {
        if($script:UpdatingContentLayout){return}
        $script:UpdatingContentLayout=$true
        try{
            $inset=$script:ContentInset
            $scroll=if($script:CurrentView-eq'Tasks'-and$script:ListPanel.VerticalScroll.Visible){[Windows.Forms.SystemInformation]::VerticalScrollBarWidth}else{0}
            $padding=[Windows.Forms.Padding]::new($inset+$scroll,10,$inset,10)
            if($script:ListPanel.Padding-ne$padding){$script:ListPanel.Padding=$padding}
            $margin=[Windows.Forms.Padding]::new($inset+$scroll,3,$inset+$scroll,3)
            if($script:MessageBar.Margin-ne$margin){$script:MessageBar.Margin=$margin}
            $width=[Math]::Max(1,$script:ListPanel.ClientSize.Width-$script:ListPanel.Padding.Horizontal)
            foreach($control in $script:ListPanel.Controls){
                if($script:CurrentView-eq'Tasks'){
                    if($control-is[Windows.Forms.Button]){
                        if($control.Width-ne$width){$control.Width=$width}
                        $height=[Math]::Max(48,2*$script:Main.Font.Height+8);if($control.Height-ne$height){$control.Height=$height}
                    }
                    elseif($control-is[Windows.Forms.Label]){$maximum=[Drawing.Size]::new($width,0);if($control.MaximumSize-ne$maximum){$control.MaximumSize=$maximum}}
                }elseif($control.Name-eq'AudioColumns'){
                    $size=[Drawing.Size]::new($width,[Math]::Max(1,$script:ListPanel.ClientSize.Height-$script:ListPanel.Padding.Vertical))
                    if($control.Size-ne$size){$control.Size=$size}
                }
            }
        }finally{$script:UpdatingContentLayout=$false}
    }
    $script:ListPanel.Add_Layout({Update-TaskPloppContentLayout})
    $script:ListPanel.Add_SizeChanged({Update-TaskPloppContentLayout})
    $script:Main.Add_FontChanged({Update-TaskPloppContentLayout})
    if (-not $SmokeTest -and -not $ResidentTest) {
        . (Join-Path $PSScriptRoot 'Start-TaskPlopp.ps1') -LibraryOnly
        $script:Tray = New-Object Windows.Forms.NotifyIcon
        $script:Tray.Icon = $script:AppIcon
        $script:Tray.Text = 'TaskPlopp'
        $menu = New-Object Windows.Forms.ContextMenuStrip
        $openItem = $menu.Items.Add('TaskPlopp oeffnen')
        $openItem.Add_Click({ Show-TaskPlopp })
        $transferTrayItem=$menu.Items.Add('Konfiguration sichern/uebertragen')
        $transferTrayItem.Add_Click({Show-TaskPloppTransfer})
        $exitItem = $menu.Items.Add('TaskPlopp beenden')
        $exitItem.Add_Click({ $script:ExitRequested = $true; $script:Main.Close() })
        $script:Tray.ContextMenuStrip = $menu
        $script:Tray.Add_DoubleClick({ Show-TaskPlopp })
        $script:Tray.Visible = $true
        try {
            Initialize-TaskPloppHotkey
        } catch {
            $script:Tray.Text = 'TaskPlopp: Hotkey belegt'
            $label=(Get-TaskPloppHotkeySpec $script:Settings).Label
            $script:StartupNotice+=" $label ist nicht verfuegbar. Bitte die Tastenkombination ueber das Zahnrad aendern."
        }
    }
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 150
    $timer.Add_Tick({
        if ($script:WakeEvent.WaitOne(0)) {
            Show-TaskPlopp
        }
    })
    $script:Main.Add_Shown({ Raise-TaskPloppWindow $script:Main.Handle })
    if($OnShown) { $script:Main.Add_Shown($OnShown) }
    Update-WindowList
    Update-TaskPloppContentLayout
    if($script:StartupNotice){Set-TaskPloppMessage Error 'Start nicht vollstaendig' $script:StartupNotice}
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
    [Windows.Forms.Application]::remove_ThreadException($uiExceptionHandler)
    if(Get-Variable dictationTimer -ErrorAction SilentlyContinue){$dictationTimer.Dispose()}
    Close-TaskPloppDictation
    if(Get-Variable transferMenu -ErrorAction SilentlyContinue){$transferMenu.Dispose()}
    if(Get-Variable dictationMenu -ErrorAction SilentlyContinue){$dictationMenu.Dispose()}
    if (Get-Variable idleTimer -ErrorAction SilentlyContinue) { $idleTimer.Dispose() }
    $registeredHotkey=Get-Variable HotkeyListener -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if($null -ne $registeredHotkey){$registeredHotkey.Dispose()}
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
