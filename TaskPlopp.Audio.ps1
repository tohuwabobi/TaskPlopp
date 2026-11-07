# Adapted from local TDAudioSwitch; only the reusable audio operations, no second GUI loop.
function Initialize-TaskPloppAudio {
    if (-not ('TaskPloppAudio.Audio' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'TaskPlopp.Audio.cs') }
}
function Get-TaskPloppAudioDevices([int]$Flow) {
    Initialize-TaskPloppAudio
    return [TaskPloppAudio.Audio]::GetDevices($Flow)
}
function Get-TaskPloppAudioDefaults([int]$Flow) {
    Initialize-TaskPloppAudio
    for ($role=0; $role -lt 3; $role++) {
        try {
            $id = [TaskPloppAudio.Audio]::GetDefaultId($Flow,$role)
            [pscustomobject]@{ Role=$role; Id=$id; Error='' }
        } catch { [pscustomobject]@{ Role=$role; Id=''; Error='Standardgeraet nicht lesbar' } }
    }
}
function Set-TaskPloppAudioDefault([string]$Id) {
    Initialize-TaskPloppAudio
    for ($role=0; $role -lt 3; $role++) { [TaskPloppAudio.Audio]::SetDefaultId($Id,$role) }
}
function Get-TaskPloppAudioLabel($Device, [object[]]$Defaults) {
    $roles = @('Console','Multimedia','Kommunikation')
    $active = @($Defaults | Where-Object { $_.Id -eq $Device.Id -and -not $_.Error })
    if ($active.Count -eq 3) { return "[Aktiv] $($Device.Name)" }
    if ($active.Count -gt 0) { return "[$(($active | ForEach-Object { $roles[$_.Role] }) -join ', ')] $($Device.Name)" }
    return $Device.Name
}
function Invoke-TaskPloppAudioSelection($Device, [int]$Flow) {
    try {
        Set-TaskPloppAudioDefault $Device.Id
        $defaults = @(Get-TaskPloppAudioDefaults $Flow)
        if (@($defaults | Where-Object { $_.Id -eq $Device.Id -and -not $_.Error }).Count -ne 3) {
            throw 'Nicht alle drei Standardrollen wurden bestaetigt.'
        }
        Set-TaskPloppMessage 'Success' 'Standardgeraet umgeschaltet' $Device.Name
    } catch {
        Set-TaskPloppMessage 'Error' 'Audiowechsel nicht vollstaendig bestaetigt' "$($Device.Name). Bitte aktualisieren oder erneut versuchen. $($_.Exception.Message)"
    }
    Update-TaskPloppAudioView -KeepMessage
}

function Clear-TaskPloppContent {
    $script:Main.ClearSelectionButtons()
    while ($script:ListPanel.Controls.Count -gt 0) { $script:ListPanel.Controls[0].Dispose() }
}
function Show-TaskPloppView([ValidateSet('Tasks','Audio')][string]$View = $script:CurrentView) {
    $script:CurrentView = $View
    $script:Main.AudioView = ($View -eq 'Audio')
    $script:ListPanel.AutoScroll = ($View -eq 'Tasks')
    $script:AudioButton.Text = if ($View -eq 'Audio') { 'Zurueck zu Tasks' } else { 'Audio' }
    if ($View -eq 'Audio') { Update-TaskPloppAudioView } else { Update-WindowList }
}
function Update-TaskPloppAudioView {
    param([switch]$KeepMessage)
    $script:ListPanel.SuspendLayout()
    try {
        $hints=@(); $readError=$false
        Clear-TaskPloppContent
        $grid = New-Object Windows.Forms.TableLayoutPanel
        $grid.Name='AudioColumns'; $grid.ColumnCount=2; $grid.RowCount=1
        $grid.Margin=[Windows.Forms.Padding]::new(0)
        [void]$grid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,50))
        [void]$grid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,50))
        $grid.Size=[Drawing.Size]::new([Math]::Max(200,$script:ListPanel.ClientSize.Width-20),[Math]::Max(60,$script:ListPanel.ClientSize.Height-20))
        $script:ListPanel.Controls.Add($grid)
        $grid.Tag=New-Object Windows.Forms.ToolTip
        $grid.Add_Disposed({ param($sender,$eventArgs) $sender.Tag.Dispose() })
        for ($flow=0; $flow -lt 2; $flow++) {
            $column=New-Object Windows.Forms.TableLayoutPanel
            $column.Dock='Fill'; $column.ColumnCount=1; $column.AutoScroll=$true
            [void]$column.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent,100))
            $column.Margin=[Windows.Forms.Padding]::new(0,0,8,0)
            $grid.Controls.Add($column,$flow,0)
            $heading=New-Object Windows.Forms.Label
            $heading.Text=if($flow -eq 0) { 'Lautsprecher' } else { 'Mikrofone' }
            $heading.AutoSize=$true; $heading.Margin=[Windows.Forms.Padding]::new(3,0,3,10)
            $column.Controls.Add($heading)
            try {
                $devices=@(Get-TaskPloppAudioDevices $flow | Sort-Object Name,Id)
                $defaults=@(Get-TaskPloppAudioDefaults $flow)
                $missing=@($defaults | Where-Object { -not $_.Id -or $_.Error })
                if ($missing.Count -gt 0) {
                    $hints += "$($heading.Text): fehlende/unbekannte Standardrollen"
                    $notice=New-Object Windows.Forms.Label
                    $notice.Text='Standard fehlt/unbekannt: ' + (($missing | ForEach-Object { @('Console','Multimedia','Kommunikation')[$_.Role] }) -join ', ')
                    $notice.AutoSize=$true; $notice.MaximumSize=[Drawing.Size]::new(220,0)
                    $column.Controls.Add($notice)
                }
                if($devices.Count -eq 0) {
                    $hints += "$($heading.Text): keine aktiven Geraete"
                    $notice=New-Object Windows.Forms.Label
                    $notice.Text='Keine aktiven Geraete. Anschliessen und Aktualisieren waehlen.'
                    $notice.AutoSize=$true; $notice.MaximumSize=[Drawing.Size]::new(220,0)
                    $column.Controls.Add($notice)
                }
                foreach($device in $devices) {
                    $button=New-Object Windows.Forms.Button
                    $button.Dock='Top'
                    $button.Text=Get-TaskPloppAudioLabel $device $defaults
                    $button.Height=76; $button.Width=[Math]::Max(100,$column.ClientSize.Width-25)
                    $button.FlatStyle='Flat'; $button.AutoEllipsis=$true
                    $button.BackColor=Get-TaskPloppAudioColor -Name $device.Name -ContainerId $device.ContainerId
                    $button.Tag=[pscustomobject]@{Device=$device;Flow=$flow}
                    $grid.Tag.SetToolTip($button,$button.Text)
                    if(@($defaults | Where-Object Id -eq $device.Id).Count -gt 0) { $button.FlatAppearance.BorderSize=3 }
                    # Set complete label first. Register once so [1]...[Z] survive refreshes.
                    $script:Main.RegisterSelectionButton($button)
                    $button.Add_Click({ param($sender,$eventArgs) Invoke-TaskPloppAudioSelection $sender.Tag.Device $sender.Tag.Flow })
                    $column.Controls.Add($button)
                }
            } catch {
                $readError=$true
                $notice=New-Object Windows.Forms.Label
                $notice.Text='Geraete nicht lesbar. Bitte Aktualisieren waehlen.'; $notice.AutoSize=$true
                $notice.MaximumSize=[Drawing.Size]::new(220,0); $column.Controls.Add($notice)
                Set-TaskPloppMessage 'Error' 'Audiogeraete konnten nicht gelesen werden' $_.Exception.Message
            }
            $column.Add_SizeChanged({ param($sender,$eventArgs) Resize-TaskPloppAudioColumn $sender })
            Resize-TaskPloppAudioColumn $column
        }
        if(-not $KeepMessage -and -not $readError) {
            if($hints.Count -gt 0) { Set-TaskPloppMessage 'Notice' 'Audiohinweis' (($hints -join '. ') + '. Anschliessen und Aktualisieren waehlen.') }
            else { Set-TaskPloppMessage 'Notice' 'Audiogeraete bereit' 'Lautsprecher oder Mikrofon anklicken; alternativ die beschriftete Taste druecken.' }
        }
    } finally { $script:ListPanel.ResumeLayout() }
}

function Resize-TaskPloppAudioColumn($Column) {
    foreach($control in $Column.Controls) {
        if($control -is [Windows.Forms.Button]) { $control.Width=[Math]::Max(70,$Column.ClientSize.Width-12) }
        elseif($control -is [Windows.Forms.Label]) { $control.MaximumSize=[Drawing.Size]::new([Math]::Max(60,$Column.ClientSize.Width-12),0) }
    }
}

function Get-TaskPloppAudioColorKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [AllowNull()]
        [string] $ContainerId
    )

    if (-not [string]::IsNullOrWhiteSpace($ContainerId)) {
        return 'container:{0}' -f $ContainerId.Trim().ToLowerInvariant()
    }

    $openingParenthesis = $Name.IndexOf('(')
    $closingParenthesis = $Name.LastIndexOf(')')

    if ($openingParenthesis -ge 0 -and $closingParenthesis -gt $openingParenthesis) {
        $key = $Name.Substring(
            $openingParenthesis + 1,
            $closingParenthesis - $openingParenthesis - 1
        )
        $key = $key -replace '^\d+\s*-\s*', ''
        return $key.Trim().ToLowerInvariant()
    }

    return $Name.Trim().ToLowerInvariant()
}

function Convert-TaskPloppHsvToColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double] $Hue,

        [Parameter(Mandatory = $true)]
        [double] $Saturation,

        [Parameter(Mandatory = $true)]
        [double] $Value
    )

    $chroma = $Value * $Saturation
    $hueSector = ($Hue % 360.0) / 60.0
    $secondary = $chroma * (1.0 - [Math]::Abs(($hueSector % 2.0) - 1.0))

    $red = 0.0
    $green = 0.0
    $blue = 0.0

    switch ([Math]::Floor($hueSector)) {
        0 { $red = $chroma; $green = $secondary; break }
        1 { $red = $secondary; $green = $chroma; break }
        2 { $green = $chroma; $blue = $secondary; break }
        3 { $green = $secondary; $blue = $chroma; break }
        4 { $red = $secondary; $blue = $chroma; break }
        default { $red = $chroma; $blue = $secondary; break }
    }

    $matchValue = $Value - $chroma
    return [System.Drawing.Color]::FromArgb(
        [int][Math]::Round(($red + $matchValue) * 255.0),
        [int][Math]::Round(($green + $matchValue) * 255.0),
        [int][Math]::Round(($blue + $matchValue) * 255.0)
    )
}

function Get-TaskPloppAudioColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [AllowNull()]
        [string] $ContainerId
    )

    $key = Get-TaskPloppAudioColorKey -Name $Name -ContainerId $ContainerId
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($key)
    $hashProvider = [System.Security.Cryptography.SHA256]::Create()

    try {
        $hash = $hashProvider.ComputeHash($bytes)
    }
    finally {
        $hashProvider.Dispose()
    }

    $palette = @(for ($index = 0; $index -lt 127; $index++) {
        $hue = ($index * 137.507764) % 360.0
        $saturation = @(0.38, 0.48, 0.58)[$index % 3]
        $value = @(0.90, 0.97)[$index % 2]
        Convert-TaskPloppHsvToColor -Hue $hue -Saturation $saturation -Value $value
    })

    $paletteIndex = [BitConverter]::ToUInt32($hash, 0) % $palette.Count
    return $palette[$paletteIndex]
}
