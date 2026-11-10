# Selection belongs only to the active main form; dialogs and context menus win.
function Initialize-TaskPloppKeyboard($Form) {
    $Form.KeyPreview=$true
    $Form | Add-Member NoteProperty SelectionButtons (New-Object 'Collections.Generic.List[Windows.Forms.Button]')
    $Form | Add-Member NoteProperty AudioView $false
    $Form | Add-Member NoteProperty HelpView $false
    $Form | Add-Member ScriptMethod ClearSelectionButtons {$this.SelectionButtons.Clear()}
    $Form | Add-Member ScriptMethod RegisterSelectionButton {
        param($button)
        $index=$this.SelectionButtons.Count;$this.SelectionButtons.Add($button)
        if($index-lt36){$button.Text='['+'1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ'[$index]+']  '+$button.Text}
    }
    $Form | Add-Member ScriptMethod TrySelectKey {param($keyData) Invoke-TaskPloppSelection $this $keyData}
    $Form.Add_KeyDown({param($sender,$eventArgs)
        if(Invoke-TaskPloppSelection $sender $eventArgs.KeyData){$eventArgs.Handled=$true;$eventArgs.SuppressKeyPress=$true}
    })
}
function Test-TaskPloppOpenMenu($Control) {
    if($Control.ContextMenuStrip-and$Control.ContextMenuStrip.Visible){return $true}
    foreach($child in $Control.Controls){if(Test-TaskPloppOpenMenu $child){return $true}}
    return $false
}
function Invoke-TaskPloppSelection($Form,[Windows.Forms.Keys]$KeyData) {
    if(-not$Form.Visible-or-not$Form.Enabled-or[Windows.Forms.Form]::ActiveForm-ne$Form){return $false}
    if(($KeyData-band([Windows.Forms.Keys]::Control-bor[Windows.Forms.Keys]::Alt))-ne0-or(Test-TaskPloppOpenMenu $Form)){return $false}
    if($Form.HelpView){
        if($KeyData-eq[Windows.Forms.Keys]::Escape){Show-TaskPloppView $script:HelpReturnView;return $true}
        return $false
    }
    if($KeyData-eq[Windows.Forms.Keys]::Space){
        if((Get-Variable ConfigurationOpen -Scope Script -ValueOnly -ErrorAction SilentlyContinue)-eq$true){return $false}
        $control=$Form.ActiveControl
        while($null-ne$control){
            if($control-is[Windows.Forms.TextBoxBase]-or$control-is[Windows.Forms.ListControl]-or$control-is[Windows.Forms.UpDownBase]-or($control-is[Windows.Forms.DataGridView]-and$control.IsCurrentCellInEditMode)){return $false}
            if($control-is[Windows.Forms.ContainerControl]){$control=$control.ActiveControl}else{break}
        }
        Minimize-TaskPlopp
        return $true
    }
    if($KeyData-eq[Windows.Forms.Keys]::Escape-and$Form.AudioView){Show-TaskPloppView 'Tasks';return $true}
    $code=[int]($KeyData-band[Windows.Forms.Keys]::KeyCode)
    $key=if($code-ge48-and$code-le57){[char]$code}elseif($code-ge96-and$code-le105){[char]($code-48)}elseif($code-ge65-and$code-le90){[char]$code}else{return $false}
    $index='1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ'.IndexOf($key)
    if($index-lt0-or$index-ge$Form.SelectionButtons.Count){return $false}
    $button=$Form.SelectionButtons[$index]
    if($button.IsDisposed-or-not$button.Visible-or-not$button.Enabled){return $false}
    $button.PerformClick();return $true
}
