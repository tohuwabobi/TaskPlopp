# Core Audio ABI metadata; no compiled helper or second message loop.
function Initialize-TaskPloppAudio {
    if('TaskPloppInterop.AudioEnumerator'-as[type]){return}
    $ipref=[IntPtr].MakeByRefType();$uref=[uint32].MakeByRefType()
    $null=New-TaskPloppComType 'TaskPloppInterop.AudioEnumerator' 'A95664D2-9614-4F35-A746-DE8DB63617E6' @(
        @{Name='EnumAudioEndpoints';Args=@([int],[uint32],$ipref)},@{Name='GetDefaultAudioEndpoint';Args=@([int],[int],$ipref)})
    $null=New-TaskPloppComType 'TaskPloppInterop.AudioCollection' '0BD7A1BE-7A1A-44DB-8397-CC5392387B5E' @(
        @{Name='GetCount';Args=@($uref)},@{Name='Item';Args=@([uint32],$ipref)})
    $null=New-TaskPloppComType 'TaskPloppInterop.AudioEndpoint' 'D666063F-1587-4E43-81F1-B948E807363F' @(
        @{Name='Activate';Args=@([IntPtr],[uint32],[IntPtr],$ipref)},@{Name='OpenPropertyStore';Args=@([uint32],$ipref)},@{Name='GetId';Args=@($ipref)},@{Name='GetState';Args=@($uref)})
    $null=New-TaskPloppComType 'TaskPloppInterop.AudioProperties' '886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99' @(
        @{Name='GetCount';Args=@($uref)},@{Name='GetAt';Args=@([uint32],[IntPtr])},@{Name='GetValue';Args=@([IntPtr],[IntPtr])})
    $methods=@();foreach($name in 'GetMixFormat','GetDeviceFormat','ResetDeviceFormat','SetDeviceFormat','GetProcessingPeriod','SetProcessingPeriod','GetShareMode','SetShareMode','GetPropertyValue','SetPropertyValue'){$methods+=@{Name=$name;Args=@()}}
    $methods+=@{Name='SetDefaultEndpoint';Args=@([IntPtr],[int])}
    $null=New-TaskPloppComType 'TaskPloppInterop.AudioPolicy' 'F8679F50-850A-41CF-9C72-430F290290C8' $methods
    $null=New-TaskPloppNativeType 'TaskPloppInterop.Ole' 'ole32.dll' @(@{Name='PropVariantClear';Return=[int];Args=@([IntPtr])})
}
function ConvertTo-TaskPloppComObject([IntPtr]$Pointer,[type]$Type) {
    try{return [Runtime.InteropServices.Marshal]::GetTypedObjectForIUnknown($Pointer,$Type)}
    finally{$null=[Runtime.InteropServices.Marshal]::Release($Pointer)}
}
function New-TaskPloppAudioEnumerator {
    Initialize-TaskPloppAudio
    $obj=[Activator]::CreateInstance([type]::GetTypeFromCLSID([guid]'BCDE0395-E52F-467C-8E3D-C4579291692E'))
    $pointer=[Runtime.InteropServices.Marshal]::GetIUnknownForObject($obj)
    try{ConvertTo-TaskPloppComObject $pointer ([TaskPloppInterop.AudioEnumerator])}finally{$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($obj)}
}
function Invoke-TaskPloppAudioCom($Object,[type]$Type,[string]$Method,[object[]]$Arguments) {
    $hr=$Type.GetMethod($Method).Invoke($Object,$Arguments)
    [Runtime.InteropServices.Marshal]::ThrowExceptionForHR($hr)
}
function Get-TaskPloppAudioProperty($Store,[guid]$Format,[uint32]$Id) {
    $key=[Runtime.InteropServices.Marshal]::AllocHGlobal(20);$size=if([IntPtr]::Size-eq8){24}else{16}
    $value=[Runtime.InteropServices.Marshal]::AllocHGlobal($size)
    try{
        [Runtime.InteropServices.Marshal]::Copy($Format.ToByteArray(),0,$key,16)
        [Runtime.InteropServices.Marshal]::WriteInt32($key,16,[int]$Id)
        for($i=0;$i-lt$size;$i++){[Runtime.InteropServices.Marshal]::WriteByte($value,$i,0)}
        try{
            Invoke-TaskPloppAudioCom $Store ([TaskPloppInterop.AudioProperties]) GetValue ([object[]]@($key,$value))
            $kind=[Runtime.InteropServices.Marshal]::ReadInt16($value)
            $pointer=[Runtime.InteropServices.Marshal]::ReadIntPtr($value,8)
            if($pointer-eq[IntPtr]::Zero){return ''}
            if($kind-eq31){return [Runtime.InteropServices.Marshal]::PtrToStringUni($pointer)}
            if($kind-eq72){return ([guid][Runtime.InteropServices.Marshal]::PtrToStructure($pointer,[guid])).ToString('D')}
            return ''
        }finally{$null=[TaskPloppInterop.Ole]::PropVariantClear($value)}
    }finally{[Runtime.InteropServices.Marshal]::FreeHGlobal($key);[Runtime.InteropServices.Marshal]::FreeHGlobal($value)}
}
function Get-TaskPloppAudioEndpointId($Endpoint) {
    $argsList=[object[]]@([IntPtr]::Zero)
    Invoke-TaskPloppAudioCom $Endpoint ([TaskPloppInterop.AudioEndpoint]) GetId $argsList
    try{[Runtime.InteropServices.Marshal]::PtrToStringUni($argsList[0])}finally{[Runtime.InteropServices.Marshal]::FreeCoTaskMem($argsList[0])}
}
function Get-TaskPloppAudioDevices([ValidateRange(0,1)][int]$Flow) {
    $enumerator=New-TaskPloppAudioEnumerator;$collection=$null
    try{
        $argsList=[object[]]@($Flow,[uint32]1,[IntPtr]::Zero)
        Invoke-TaskPloppAudioCom $enumerator ([TaskPloppInterop.AudioEnumerator]) EnumAudioEndpoints $argsList
        $collection=ConvertTo-TaskPloppComObject $argsList[2] ([TaskPloppInterop.AudioCollection])
        $count=[object[]]@([uint32]0);Invoke-TaskPloppAudioCom $collection ([TaskPloppInterop.AudioCollection]) GetCount $count
        for($i=0;$i-lt$count[0];$i++){
            $endpoint=$null;$store=$null
            try{
                $item=[object[]]@([uint32]$i,[IntPtr]::Zero);Invoke-TaskPloppAudioCom $collection ([TaskPloppInterop.AudioCollection]) Item $item
                $endpoint=ConvertTo-TaskPloppComObject $item[1] ([TaskPloppInterop.AudioEndpoint])
                $id=Get-TaskPloppAudioEndpointId $endpoint
                $props=[object[]]@([uint32]0,[IntPtr]::Zero);Invoke-TaskPloppAudioCom $endpoint ([TaskPloppInterop.AudioEndpoint]) OpenPropertyStore $props
                $store=ConvertTo-TaskPloppComObject $props[1] ([TaskPloppInterop.AudioProperties])
                $name=Get-TaskPloppAudioProperty $store 'A45C254E-DF1C-4EFD-8020-67D146A850E0' 14
                $container='';try{$container=Get-TaskPloppAudioProperty $store '8C7ED206-3F8A-4827-B3AB-AE9E1FAEFC6C' 2}catch{}
                [pscustomobject]@{Id=$id;Name=$(if($name){$name}else{$id});ContainerId=$container}
            }finally{if($null-ne$store){$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($store)};if($null-ne$endpoint){$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($endpoint)}}
        }
    }finally{if($null-ne$collection){$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($collection)};$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($enumerator)}
}
function Get-TaskPloppAudioDefaultId([ValidateRange(0,1)][int]$Flow,[ValidateRange(0,2)][int]$Role) {
    $enumerator=New-TaskPloppAudioEnumerator;$endpoint=$null
    try{
        $argsList=[object[]]@($Flow,$Role,[IntPtr]::Zero)
        $hr=[TaskPloppInterop.AudioEnumerator].GetMethod('GetDefaultAudioEndpoint').Invoke($enumerator,$argsList)
        if($hr-eq-2147023728){return ''};[Runtime.InteropServices.Marshal]::ThrowExceptionForHR($hr)
        $endpoint=ConvertTo-TaskPloppComObject $argsList[2] ([TaskPloppInterop.AudioEndpoint])
        Get-TaskPloppAudioEndpointId $endpoint
    }finally{if($null-ne$endpoint){$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($endpoint)};$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($enumerator)}
}
function Set-TaskPloppAudioRole([string]$Id,[ValidateRange(0,2)][int]$Role) {
    if([string]::IsNullOrWhiteSpace($Id)){throw 'Leere Audiogeraete-ID.'}
    Initialize-TaskPloppAudio
    $obj=[Activator]::CreateInstance([type]::GetTypeFromCLSID([guid]'870AF99C-171D-4F9E-AF0D-E63DF40C2BC9'))
    try{$policy=ConvertTo-TaskPloppComObject ([Runtime.InteropServices.Marshal]::GetIUnknownForObject($obj)) ([TaskPloppInterop.AudioPolicy])}finally{$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($obj)}
    $wide=[Runtime.InteropServices.Marshal]::StringToCoTaskMemUni($Id)
    try{Invoke-TaskPloppAudioCom $policy ([TaskPloppInterop.AudioPolicy]) SetDefaultEndpoint ([object[]]@($wide,$Role))}
    finally{[Runtime.InteropServices.Marshal]::FreeCoTaskMem($wide);$null=[Runtime.InteropServices.Marshal]::ReleaseComObject($policy)}
}
function Get-TaskPloppAudioDefaults([int]$Flow) {
    Initialize-TaskPloppAudio
    for ($role=0; $role -lt 3; $role++) {
        try {
            $id = (Get-TaskPloppAudioDefaultId $Flow $role)
            [pscustomobject]@{ Role=$role; Id=$id; Error='' }
        } catch { [pscustomobject]@{ Role=$role; Id=''; Error='Standardgeraet nicht lesbar' } }
    }
}
function Set-TaskPloppAudioDefault([string]$Id) {
    Initialize-TaskPloppAudio
    for ($role=0; $role -lt 3; $role++) { Set-TaskPloppAudioRole $Id $role }
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
function Show-TaskPloppView([ValidateSet('Tasks','Audio','Help')][string]$View = $script:CurrentView) {
    $wasHelp=$script:CurrentView-eq'Help'
    if($View-eq'Help'-and-not$wasHelp){$script:HelpReturnView=$script:CurrentView}
    $script:CurrentView=$View
    $script:Main.AudioView=$View-eq'Audio';$script:Main.HelpView=$View-eq'Help'
    $script:Main.SuspendLayout()
    try{
        $statusRow=$script:MessageBar.Parent.RowStyles[1]
        $statusRow.SizeType=if($View-eq'Help'){'Absolute'}else{'AutoSize'};$statusRow.Height=0
        if($wasHelp-and$View-ne'Help'){$null=Update-TaskPloppMessageTimeout $script:MessageBar}
        $script:MessageBar.Visible=$View-ne'Help'
        $script:ListPanel.AutoScroll=$View-eq'Tasks'
        $script:HelpButton.Text=if($View-eq'Help'){[string][char]0xE72B}else{'?'}
        $script:HelpButton.Font=if($View-eq'Help'){$script:ToolbarIconFont}else{$script:Main.Font}
        $helpHint=if($View-eq'Help'){'Zurueck (Escape)'}else{'Hilfe: Programmbeschreibung und Bedienung'}
        $script:HelpButton.AccessibleName=$helpHint;$script:ToolbarToolTip.SetToolTip($script:HelpButton,$helpHint)
        $script:AudioButton.Text=if($View-eq'Audio'){[string][char]0xE72B}else{'Audio'}
        $script:AudioButton.Font=if($View-eq'Audio'){$script:ToolbarIconFont}else{$script:Main.Font}
        $hint=if($View-eq'Audio'){'Zurueck zu Tasks (Escape)'}else{'Lautsprecher und Mikrofone auswaehlen'}
        $script:AudioButton.AccessibleName=$hint;$script:ToolbarToolTip.SetToolTip($script:AudioButton,$hint)
        switch($View){
            Help {Show-TaskPloppHelp}
            Audio {Update-TaskPloppAudioView -KeepMessage:$wasHelp}
            Tasks {Update-WindowList}
        }
    }finally{$script:Main.ResumeLayout($true)}
}
function Show-TaskPloppHelp {
    Clear-TaskPloppContent
    $help=[Windows.Forms.RichTextBox]::new();$help.Name='HelpText';$help.ReadOnly=$true
    $help.Margin=[Windows.Forms.Padding]::new(0);$help.BorderStyle='None';$help.BackColor=$script:Main.BackColor;$help.ForeColor=$script:Main.ForeColor
    $help.DetectUrls=$false;$help.WordWrap=$true;$help.ScrollBars='Vertical'
    $help.Text=@'
TaskPlopp – deine lokalen Programme griffbereit

TaskPlopp hilft dir, aus Citrix heraus zu lokalen Fenstern und Werkzeugen zu wechseln.

TaskPlopp öffnen
Nutze die Tastenkombination Strg+NumPad0. In der Konfiguration kann eine andere Kombination eingestellt werden.

Minimieren und Schließen
Drücke Leertaste - TaskPlopp verschwindet in die Taskleiste. X blendet es neben der Uhr aus; dort kannst du es ganz beenden. Beim Programmwechsel verhält es sich wie ein normales Fenster; der Hotkey holt es wieder nach vorne.

Favoriten und Fenster
Einen Button anklicken oder 1–9, 0, A–Z drücken. Favoriten starten bei Bedarf ihr Programm. Weitere Fenster zeigt laufende lokale Anwendungen. Citrix minimiert das Citrix-Fenster.

Audio und PC-Sperre
Unter Audio kannst du Mikrofon und Lautsprecher wählen. Das Schloss schaltet die automatische PC-Sperre um.

Diktat
Mikrofon anklicken, sprechen, erneut klicken. Die ausgewählte lokale Engine transkribiert; der Text landet in der Zwischenablage. Mit Strg+V einfügen. Die Engine wählst du in der Konfiguration.

KI-Fensterordner
Fenster-Symbol neben dem Mikrofon anklicken. Diktiere ins Mikro, wie die Fenster auf dem Desktop angeordnet werden sollen. Fenster-Symbol erneut klicken. OpenAI plant die Anordnung aus Auftrag, Fenstertiteln und Bildschirmbildern. Benenne Favoriten und Chrome-Profile eindeutig. Rechtsklick auf das Symbol: letzte Anordnung rückgängig. Neu gestartete Programme bleiben offen.

Konfiguration
Das Zahnrad öffnet Einstellungen und sortierbare Favoriten. Änderungen werden sofort gespeichert. Unter Tastenkombination auf Aufnahme klicken und die gewünschte Kombination drücken. Rechtsklick aufs Zahnrad: Konfiguration sichern oder übertragen. API-Keys werden pro PC eingerichtet.
'@
    $script:ListPanel.Controls.Add($help)
    $bold=[Drawing.Font]::new($help.Font,[Drawing.FontStyle]::Bold)
    try{
        foreach($heading in @('TaskPlopp – deine lokalen Programme griffbereit','TaskPlopp öffnen','Minimieren und Schließen','Favoriten und Fenster','Audio und PC-Sperre','Diktat','KI-Fensterordner','Konfiguration')){
            $index=[regex]::Match($help.Text,('(?m)^'+[regex]::Escape($heading)+'\r?$')).Index
            $help.Select($index,$heading.Length);$help.SelectionFont=$bold
        }
        $shortcut='Strg+NumPad0';$index=$help.Text.IndexOf($shortcut,[StringComparison]::Ordinal)
        $help.Select($index,$shortcut.Length);$help.SelectionFont=$bold
        $help.Select(0,0)
    }finally{$bold.Dispose()}
    Update-TaskPloppContentLayout
}
function Update-TaskPloppAudioView {
    param([switch]$KeepMessage)
    if($script:CurrentView-eq'Help'){return}
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
