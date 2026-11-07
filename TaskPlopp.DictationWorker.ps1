#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$Executable,[Parameter(Mandatory=$true)][string]$Model)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot 'TaskPlopp.Native.ps1')
function Read-VoskUtf8([IntPtr]$Pointer) {
    if($Pointer-eq[IntPtr]::Zero){throw 'Leere Vosk-Antwort.'}
    $length=0;while([Runtime.InteropServices.Marshal]::ReadByte($Pointer,$length)-ne0){$length++}
    $bytes=[byte[]]::new($length);[Runtime.InteropServices.Marshal]::Copy($Pointer,$bytes,0,$length)
    return [Text.Encoding]::UTF8.GetString($bytes)
}
$loaded=[IntPtr]::Zero;$modelHandle=[IntPtr]::Zero;$recognizer=[IntPtr]::Zero
try {
    if(-not[Environment]::Is64BitProcess){throw 'Vosk benoetigt 64 Bit.'}
    $loaded=[TaskPloppInterop.Kernel]::LoadLibraryExW($Executable,[IntPtr]::Zero,8)
    if($loaded-eq[IntPtr]::Zero){throw 'Vosk-DLL konnte nicht geladen werden.'}
    $null=New-TaskPloppNativeType 'TaskPloppInterop.Vosk' $Executable @(
        @{Name='vosk_model_new';Return=[IntPtr];Args=@([byte[]])},@{Name='vosk_model_free';Return=[void];Args=@([IntPtr])},
        @{Name='vosk_recognizer_new';Return=[IntPtr];Args=@([IntPtr],[single])},@{Name='vosk_recognizer_free';Return=[void];Args=@([IntPtr])},
        @{Name='vosk_recognizer_accept_waveform';Return=[int];Args=@([IntPtr],[byte[]],[int])},
        @{Name='vosk_recognizer_result';Return=[IntPtr];Args=@([IntPtr])},@{Name='vosk_recognizer_final_result';Return=[IntPtr];Args=@([IntPtr])},
        @{Name='vosk_set_log_level';Return=[void];Args=@([int])}) -Convention Cdecl
    [TaskPloppInterop.Vosk]::vosk_set_log_level(-1)
    $modelHandle=[TaskPloppInterop.Vosk]::vosk_model_new([Text.Encoding]::UTF8.GetBytes($Model+[char]0))
    if($modelHandle-eq[IntPtr]::Zero){throw 'Vosk-Modell konnte nicht geladen werden.'}
    $recognizer=[TaskPloppInterop.Vosk]::vosk_recognizer_new($modelHandle,16000)
    if($recognizer-eq[IntPtr]::Zero){throw 'Vosk-Erkennung konnte nicht gestartet werden.'}
    $inputStream=[Console]::OpenStandardInput();$buffer=[byte[]]::new(8000);$parts=New-Object 'Collections.Generic.List[string]'
    while($true){
        $length=0
        while($length-lt$buffer.Length){$count=$inputStream.Read($buffer,$length,$buffer.Length-$length);if($count-eq0){break};$length+=$count}
        if($length-eq0){break};if($length%2){throw 'Ungueltige PCM-Daten.'}
        $code=[TaskPloppInterop.Vosk]::vosk_recognizer_accept_waveform($recognizer,$buffer,$length)
        if($code-lt0){throw 'Vosk-Verarbeitung fehlgeschlagen.'}
        if($code-eq1){$text=(Read-VoskUtf8 ([TaskPloppInterop.Vosk]::vosk_recognizer_result($recognizer))|ConvertFrom-Json).text;if($text){$parts.Add($text)}}
    }
    $text=(Read-VoskUtf8 ([TaskPloppInterop.Vosk]::vosk_recognizer_final_result($recognizer))|ConvertFrom-Json).text
    if($text){$parts.Add($text)}
    [Console]::WriteLine(($parts.ToArray()-join' '))
}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 1}
finally{
    if($recognizer-ne[IntPtr]::Zero){[TaskPloppInterop.Vosk]::vosk_recognizer_free($recognizer)}
    if($modelHandle-ne[IntPtr]::Zero){[TaskPloppInterop.Vosk]::vosk_model_free($modelHandle)}
    if($loaded-ne[IntPtr]::Zero){$null=[TaskPloppInterop.Kernel]::FreeLibrary($loaded)}
}
