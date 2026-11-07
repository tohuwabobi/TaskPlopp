# Two lines, drawn by a normal Panel. All drawing stays on the GUI thread.
function New-TaskPloppMessageBar {
    $panel=[Windows.Forms.Panel]::new()
    [Windows.Forms.Control].GetProperty('DoubleBuffered',[Reflection.BindingFlags]'Instance,NonPublic').SetValue($panel,$true,$null)
    $timer=[Windows.Forms.Timer]::new();$timer.Interval=30
    $panel.Tag=@{Lines=@('','');Widths=@(0.0,0.0);Offsets=@(0.0,0.0);Activity='';Peaks=[single[]]::new(64);Frame=0;Timer=$timer;HostVisible=$true}
    $panel | Add-Member ScriptProperty IsScrolling {$this.Tag.Timer.Enabled}
    $panel.ForeColor=[Drawing.Color]::FromArgb(30,30,30)
    $timer.Tag=$panel
    $timer.Add_Tick({param($sender,$eventArgs)
        $p=$sender.Tag;$s=$p.Tag
        for($i=0;$i-lt2;$i++){if($s.Widths[$i]-gt$p.ClientSize.Width-16){$s.Offsets[$i]=($s.Offsets[$i]+1.5)%($s.Widths[$i]+48)}}
        $p.Invalidate()
    })
    $panel.Add_FontChanged({param($sender,$e) Measure-TaskPloppMessage $sender})
    $panel.Add_SizeChanged({param($sender,$e) Measure-TaskPloppMessage $sender})
    $panel.Add_VisibleChanged({param($sender,$e) Measure-TaskPloppMessage $sender})
    $panel.Add_Disposed({param($sender,$e) $sender.Tag.Timer.Dispose()})
    $panel.Add_Paint({param($p,$e)
        $s=$p.Tag;$brush=[Drawing.SolidBrush]::new($p.ForeColor)
        try{
            for($i=0;$i-lt2;$i++){
                $top=2+$i*($p.Font.Height+6)
                if($i-eq1-and$s.Activity-eq'Recording'){
                    $step=[Math]::Max(1,($p.ClientSize.Width-16.0)/64)
                    $pen=[Drawing.Pen]::new([Drawing.Color]::FromArgb(25,110,45),2)
                    try{for($n=0;$n-lt64;$n++){$size=[Math]::Max(1,$s.Peaks[$n]*($p.Font.Height+3));$e.Graphics.DrawLine($pen,[single](8+$n*$step),[single]($top+($p.Font.Height-$size)/2),[single](8+$n*$step),[single]($top+($p.Font.Height+$size)/2))}}finally{$pen.Dispose()}
                    continue
                }
                $saved=$e.Graphics.Save()
                try{
                    $e.Graphics.SetClip([Drawing.Rectangle]::new(8,$top,[Math]::Max(0,$p.ClientSize.Width-16),$p.Font.Height+6))
                    $e.Graphics.DrawString($s.Lines[$i],$p.Font,$brush,[single](8-$s.Offsets[$i]),[single]$top,[Drawing.StringFormat]::GenericTypographic)
                    if($s.Widths[$i]-gt$p.ClientSize.Width-16){$e.Graphics.DrawString($s.Lines[$i],$p.Font,$brush,[single](8-$s.Offsets[$i]+$s.Widths[$i]+48),[single]$top,[Drawing.StringFormat]::GenericTypographic)}
                }finally{$e.Graphics.Restore($saved)}
            }
            if($s.Activity-eq'Transcribing'){$width=[Math]::Max(1,$p.ClientSize.Width-16);$e.Graphics.FillRectangle([Drawing.Brushes]::DarkOrange,8+($s.Frame*5)%$width,$p.Height-3,[Math]::Min(24,$width),3)}
        }finally{$brush.Dispose()}
    })
    Measure-TaskPloppMessage $panel
    return $panel
}
function Measure-TaskPloppMessage($Panel) {
    if($Panel.IsDisposed){return}
    $s=$Panel.Tag
    $Panel.Height=2*($Panel.Font.Height+6)+4
    $g=$Panel.CreateGraphics()
    try{for($i=0;$i-lt2;$i++){$s.Widths[$i]=$g.MeasureString($s.Lines[$i],$Panel.Font,[int]::MaxValue,[Drawing.StringFormat]::GenericTypographic).Width;$s.Offsets[$i]=0}}finally{$g.Dispose()}
    $s.Timer.Enabled=$s.HostVisible-and$Panel.Visible-and$Panel.ClientSize.Width-gt16-and($s.Widths[0]-gt$Panel.ClientSize.Width-16-or$s.Widths[1]-gt$Panel.ClientSize.Width-16)
    $Panel.Invalidate()
}
function Set-TaskPloppStatusHostVisible([bool]$Visible) {
    $script:MessageBar.Tag.HostVisible=$Visible
    if($Visible){Measure-TaskPloppMessage $script:MessageBar}else{$script:MessageBar.Tag.Timer.Stop()}
}
function Set-TaskPloppMessage([string]$Kind,[string]$Summary,[string]$Detail='') {
    $panels=@()
    foreach($name in 'MessageBar','ConfigurationMessageBar'){
        $panel=Get-Variable $name -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if($null-ne$panel-and-not$panel.IsDisposed){$panels+=,$panel}
    }
    if($panels.Count-eq0){$script:StartupNotice=($Summary+' '+$Detail).Trim();return}
    foreach($p in $panels){
        $s=$p.Tag;$s.Activity=''
        switch($Kind){
            Success {$prefix='Erfolg';$p.BackColor=[Drawing.Color]::FromArgb(205,239,211)}
            Error {$prefix='Fehler';$p.BackColor=[Drawing.Color]::FromArgb(255,198,198)}
            Warning {$prefix='Warnung';$p.BackColor=[Drawing.Color]::FromArgb(255,198,198)}
            default {$prefix='Hinweis';$p.BackColor=[Drawing.Color]::FromArgb(255,226,163)}
        }
        $s.Lines[0]=$prefix+': '+($Summary-replace'[\r\n]',' ');$s.Lines[1]=$Detail-replace'[\r\n]',' '
        Measure-TaskPloppMessage $p
    }
}
function Set-TaskPloppActivity([string]$Mode,[string]$Detail='',[string]$Caption='Diktat laeuft') {
    if($Mode-eq'Recording'){Set-TaskPloppMessage Success $Caption $Detail}else{Set-TaskPloppMessage Notice 'Transkription laeuft' $Detail}
    $s=$script:MessageBar.Tag;$s.Activity=$Mode;$s.Caption=$Caption;[Array]::Clear($s.Peaks,0,64);$s.Frame=0
}
function Update-TaskPloppActivity([single]$Peak,[double]$Seconds) {
    $s=$script:MessageBar.Tag;if(-not$s.Activity){return};$s.Frame++
    if($s.Activity-eq'Recording'){$s.Lines[0]=$s.Caption+' - '+[TimeSpan]::FromSeconds($Seconds).ToString('hh\:mm\:ss');[Array]::Copy($s.Peaks,1,$s.Peaks,0,63);$s.Peaks[63]=$Peak}
    $script:MessageBar.Invalidate()
}
