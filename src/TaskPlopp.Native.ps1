# Windows ABI declarations only. Executable application logic stays in PowerShell.
function New-TaskPloppNativeType($Name,$Dll,$Methods,[Runtime.InteropServices.CallingConvention]$Convention='Winapi') {
    $existing=$Name -as [type]; if($existing){return $existing}
    $assembly=[AppDomain]::CurrentDomain.DefineDynamicAssembly([Reflection.AssemblyName]::new($Name),[Reflection.Emit.AssemblyBuilderAccess]::Run)
    $builder=$assembly.DefineDynamicModule($Name).DefineType($Name,[Reflection.TypeAttributes]'Public,Abstract,Sealed')
    foreach($spec in $Methods){
        $entry=if($spec.ContainsKey('Entry')){$spec.Entry}else{$spec.Name}
        $method=$builder.DefinePInvokeMethod($spec.Name,$Dll,$entry,[Reflection.MethodAttributes]'Public,Static,PinvokeImpl',[Reflection.CallingConventions]::Standard,$spec.Return,[type[]]$spec.Args,$Convention,[Runtime.InteropServices.CharSet]::Unicode)
        $method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
        $attr=[Runtime.InteropServices.DllImportAttribute]
        $method.SetCustomAttribute([Reflection.Emit.CustomAttributeBuilder]::new($attr.GetConstructor([type[]]@([string])),[object[]]@($Dll),[Reflection.FieldInfo[]]@($attr.GetField('SetLastError'),$attr.GetField('CharSet'),$attr.GetField('CallingConvention'),$attr.GetField('ExactSpelling'),$attr.GetField('EntryPoint')),[object[]]@($true,[Runtime.InteropServices.CharSet]::Unicode,$Convention,$true,$entry)))
    }
    $builder.CreateType()
}
function New-TaskPloppComType($Name,$Guid,$Methods) {
    $existing=$Name -as [type];if($existing){return $existing}
    $assembly=[AppDomain]::CurrentDomain.DefineDynamicAssembly([Reflection.AssemblyName]::new($Name),[Reflection.Emit.AssemblyBuilderAccess]::Run)
    $builder=$assembly.DefineDynamicModule($Name).DefineType($Name,[Reflection.TypeAttributes]'Public,Interface,Abstract,Import')
    $builder.SetCustomAttribute([Reflection.Emit.CustomAttributeBuilder]::new([Runtime.InteropServices.GuidAttribute].GetConstructor([type[]]@([string])),[object[]]@($Guid)))
    $builder.SetCustomAttribute([Reflection.Emit.CustomAttributeBuilder]::new([Runtime.InteropServices.InterfaceTypeAttribute].GetConstructor([type[]]@([Runtime.InteropServices.ComInterfaceType])),[object[]]@([Runtime.InteropServices.ComInterfaceType]::InterfaceIsIUnknown)))
    foreach($spec in $Methods){$method=$builder.DefineMethod($spec.Name,[Reflection.MethodAttributes]'Public,Abstract,Virtual,NewSlot,HideBySig',[int],[type[]]$spec.Args);$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)}
    $builder.CreateType()
}
$null=New-TaskPloppNativeType 'TaskPloppInterop.User' 'user32.dll' @(
    @{Name='GetTopWindow';Return=[IntPtr];Args=@([IntPtr])},@{Name='GetWindow';Return=[IntPtr];Args=@([IntPtr],[uint32])},
    @{Name='IsWindow';Return=[bool];Args=@([IntPtr])},@{Name='IsWindowVisible';Return=[bool];Args=@([IntPtr])},
    @{Name='GetWindowTextW';Return=[int];Args=@([IntPtr],[Text.StringBuilder],[int])},
    @{Name='GetWindowThreadProcessId';Return=[uint32];Args=@([IntPtr],[int].MakeByRefType())},
    @{Name='GetWindowLongPtrW';Return=[IntPtr];Args=@([IntPtr],[int])},@{Name='GetWindowLongW';Return=[int];Args=@([IntPtr],[int])},
    @{Name='GetAncestor';Return=[IntPtr];Args=@([IntPtr],[uint32])},@{Name='GetLastActivePopup';Return=[IntPtr];Args=@([IntPtr])},
    @{Name='ShowWindow';Return=[bool];Args=@([IntPtr],[int])},@{Name='ShowWindowAsync';Return=[bool];Args=@([IntPtr],[int])},
    @{Name='IsIconic';Return=[bool];Args=@([IntPtr])},@{Name='GetForegroundWindow';Return=[IntPtr];Args=@()},
    @{Name='SetForegroundWindow';Return=[bool];Args=@([IntPtr])},
    @{Name='SetWindowPos';Return=[bool];Args=@([IntPtr],[IntPtr],[int],[int],[int],[int],[uint32])},
    @{Name='GetCursorPos';Return=[bool];Args=@([IntPtr])},@{Name='GetLastInputInfo';Return=[bool];Args=@([IntPtr])},
    @{Name='GetAsyncKeyState';Return=[int16];Args=@([int])},@{Name='LockWorkStation';Return=[bool];Args=@()},
    @{Name='RegisterHotKey';Return=[bool];Args=@([IntPtr],[int],[uint32],[uint32])},@{Name='UnregisterHotKey';Return=[bool];Args=@([IntPtr],[int])},
    @{Name='PeekMessageW';Return=[bool];Args=@([IntPtr],[IntPtr],[uint32],[uint32],[uint32])},
    @{Name='PostThreadMessageW';Return=[bool];Args=@([uint32],[uint32],[IntPtr],[IntPtr])},
    @{Name='PostMessageW';Return=[bool];Args=@([IntPtr],[uint32],[IntPtr],[IntPtr])},
    @{Name='SendMessageW';Return=[IntPtr];Args=@([IntPtr],[uint32],[IntPtr],[IntPtr])}
)
$null=New-TaskPloppNativeType 'TaskPloppInterop.Kernel' 'kernel32.dll' @(
    @{Name='GetCurrentThreadId';Return=[uint32];Args=@()},@{Name='OpenProcess';Return=[IntPtr];Args=@([uint32],[bool],[int])},
    @{Name='CloseHandle';Return=[bool];Args=@([IntPtr])},
    @{Name='GetApplicationUserModelId';Return=[int];Args=@([IntPtr],[uint32].MakeByRefType(),[Text.StringBuilder])},
    @{Name='LoadLibraryExW';Return=[IntPtr];Args=@([string],[IntPtr],[uint32])},@{Name='FreeLibrary';Return=[bool];Args=@([IntPtr])}
)
$null=New-TaskPloppNativeType 'TaskPloppInterop.Dwm' 'dwmapi.dll' @(@{Name='DwmGetWindowAttribute';Return=[int];Args=@([IntPtr],[int],[int].MakeByRefType(),[int])})
$null=New-TaskPloppNativeType 'TaskPloppInterop.Geometry' 'user32.dll' @(
    @{Name='GetWindowRect';Return=[bool];Args=@([IntPtr],[IntPtr])},
    @{Name='GetWindowPlacement';Return=[bool];Args=@([IntPtr],[IntPtr])},
    @{Name='SetWindowPlacement';Return=[bool];Args=@([IntPtr],[IntPtr])},
    @{Name='SetThreadDpiAwarenessContext';Return=[IntPtr];Args=@([IntPtr])},
    @{Name='IsZoomed';Return=[bool];Args=@([IntPtr])})
$null=New-TaskPloppNativeType 'TaskPloppInterop.Frame' 'dwmapi.dll' @(
    @{Name='DwmGetWindowAttribute';Return=[int];Args=@([IntPtr],[int],[IntPtr],[int])})
function Test-TaskPloppSwitchable([IntPtr]$Handle) {
    if(-not[TaskPloppInterop.User]::IsWindow($Handle)-or-not[TaskPloppInterop.User]::IsWindowVisible($Handle)){return $false}
    $style=if([IntPtr]::Size-eq8){[TaskPloppInterop.User]::GetWindowLongPtrW($Handle,-20).ToInt64()}else{[long][TaskPloppInterop.User]::GetWindowLongW($Handle,-20)}
    if(($style-band0x08000000)-ne0-or(($style-band0x80)-ne0-and($style-band0x40000)-eq0)){return $false}
    $cloaked=0;if([TaskPloppInterop.Dwm]::DwmGetWindowAttribute($Handle,14,[ref]$cloaked,4)-eq0-and$cloaked-ne0){return $false}
    if($style-band0x40000){return $true}
    $walk=[TaskPloppInterop.User]::GetAncestor($Handle,3)
    for($i=0;$i-lt100;$i++){$popup=[TaskPloppInterop.User]::GetLastActivePopup($walk);if($popup-eq[IntPtr]::Zero-or$popup-eq$walk){break};$walk=$popup;if([TaskPloppInterop.User]::IsWindowVisible($popup)){break}}
    return $walk-eq$Handle
}
function Get-TaskPloppAppId([int]$ProcessId) {
    $process=[TaskPloppInterop.Kernel]::OpenProcess(0x1000,$false,$ProcessId);if($process-eq[IntPtr]::Zero){return ''}
    try{$length=[uint32]0;if([TaskPloppInterop.Kernel]::GetApplicationUserModelId($process,[ref]$length,$null)-ne122-or$length-eq0){return ''};$value=[Text.StringBuilder]::new([int]$length);if([TaskPloppInterop.Kernel]::GetApplicationUserModelId($process,[ref]$length,$value)-eq0){return $value.ToString()};return ''}finally{$null=[TaskPloppInterop.Kernel]::CloseHandle($process)}
}
function Get-TaskPloppHostedProcess([IntPtr]$Handle,[int]$HostProcessId) {
    $pending=New-Object 'Collections.Generic.Stack[IntPtr]';$pending.Push($Handle)
    while($pending.Count){$parent=$pending.Pop();$child=[TaskPloppInterop.User]::GetWindow($parent,5);$seen=@{};while($child-ne[IntPtr]::Zero-and-not$seen.ContainsKey($child)){$seen[$child]=$true;$processId=0;$null=[TaskPloppInterop.User]::GetWindowThreadProcessId($child,[ref]$processId);if($processId-ne$HostProcessId-and(Get-TaskPloppAppId $processId)){return $processId};$pending.Push($child);$child=[TaskPloppInterop.User]::GetWindow($child,2)}}
    return $HostProcessId
}
function Get-TaskPloppNativeWindows {
    $handle=[TaskPloppInterop.User]::GetTopWindow([IntPtr]::Zero);$seen=@{}
    while($handle-ne[IntPtr]::Zero-and-not$seen.ContainsKey($handle)){
        $seen[$handle]=$true
        if([TaskPloppInterop.User]::IsWindowVisible($handle)){$title=[Text.StringBuilder]::new(2048);if([TaskPloppInterop.User]::GetWindowTextW($handle,$title,2048)){$processId=0;$null=[TaskPloppInterop.User]::GetWindowThreadProcessId($handle,[ref]$processId);[pscustomobject]@{Handle=$handle;ProcessId=$processId;Title=$title.ToString()}}}
        $handle=[TaskPloppInterop.User]::GetWindow($handle,2)
    }
}
function Activate-TaskPloppWindow([IntPtr]$Handle) {
    if(-not[TaskPloppInterop.User]::IsWindow($Handle)){return $false}
    if([TaskPloppInterop.User]::IsIconic($Handle)){$null=[TaskPloppInterop.User]::ShowWindowAsync($Handle,9);for($i=0;$i-lt20-and[TaskPloppInterop.User]::IsIconic($Handle);$i++){Start-Sleep -Milliseconds 10}}
    $null=[TaskPloppInterop.User]::SetForegroundWindow($Handle)
    for($i=0;$i-lt20;$i++){if([TaskPloppInterop.User]::GetForegroundWindow()-eq$Handle){return $true};Start-Sleep -Milliseconds 10};return $false
}
function Minimize-TaskPloppWindow([IntPtr]$Handle) {
    if(-not[TaskPloppInterop.User]::IsWindow($Handle)){return $false}
    $processId=0;$thread=[TaskPloppInterop.User]::GetWindowThreadProcessId($Handle,[ref]$processId)
    if($thread-eq[TaskPloppInterop.Kernel]::GetCurrentThreadId()){$null=[TaskPloppInterop.User]::ShowWindow($Handle,6)}else{$null=[TaskPloppInterop.User]::ShowWindowAsync($Handle,6)}
    for($i=0;$i-lt30;$i++){if(-not[TaskPloppInterop.User]::IsWindow($Handle)-or[TaskPloppInterop.User]::IsIconic($Handle)){return $true};Start-Sleep -Milliseconds 10};return $false
}
function Activate-TaskPloppCoveredWindow([IntPtr]$Target,[IntPtr[]]$Covers) {
    if(-not[TaskPloppInterop.User]::IsWindow($Target)){return $false};foreach($cover in $Covers){if($cover-ne$Target-and[TaskPloppInterop.User]::IsWindow($cover)-and-not(Minimize-TaskPloppWindow $cover)){return $false}};return Activate-TaskPloppWindow $Target
}
function Raise-TaskPloppWindow([IntPtr]$Handle) {$null=[TaskPloppInterop.User]::ShowWindowAsync($Handle,9);$null=[TaskPloppInterop.User]::SetWindowPos($Handle,[IntPtr](-1),0,0,0,0,0x43);$null=[TaskPloppInterop.User]::SetForegroundWindow($Handle)}
function Get-TaskPloppInput {
    $memory=[Runtime.InteropServices.Marshal]::AllocHGlobal(8)
    try{
        $available=[TaskPloppInterop.User]::GetCursorPos($memory);$x=0;$y=0;$tick=[uint32]0;$down=$false
        if($available){$x=[Runtime.InteropServices.Marshal]::ReadInt32($memory);$y=[Runtime.InteropServices.Marshal]::ReadInt32($memory,4);[Runtime.InteropServices.Marshal]::WriteInt32($memory,8);if([TaskPloppInterop.User]::GetLastInputInfo($memory)){$tick=[BitConverter]::ToUInt32([BitConverter]::GetBytes([Runtime.InteropServices.Marshal]::ReadInt32($memory,4)),0)};for($key=1;$key-lt255;$key++){if([TaskPloppInterop.User]::GetAsyncKeyState($key)-band0x8000){$down=$true;break}}}
        [pscustomobject]@{Available=$available;X=$x;Y=$y;InputTick=$tick;KeyDown=$down}
    }finally{[Runtime.InteropServices.Marshal]::FreeHGlobal($memory)}
}
