# Fixed project paths; no dependence on the caller's current directory.
$script:ProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:DataRoot=Join-Path $script:ProjectRoot 'data'
function Initialize-TaskPloppData([string]$Root=$script:ProjectRoot) {
    $Root=[IO.Path]::GetFullPath($Root).TrimEnd('\')
    $legacy=Join-Path $Root 'config.json';$data=Join-Path $Root 'data';$target=Join-Path $data 'config.json'
    $notice=''
    try{
        $null=[IO.Directory]::CreateDirectory($data)
        if(([IO.File]::GetAttributes($data)-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'Data directory is a link'}
        if([IO.File]::Exists($legacy)){
            if([IO.File]::Exists($target)){
                $archive=Join-Path $data 'legacy';$null=[IO.Directory]::CreateDirectory($archive)
                $destination=Join-Path $archive ('config-'+[guid]::NewGuid().ToString('N')+'.json')
                Move-TaskPloppDataFile $legacy $destination $Root
                $notice='Vorhandene data/config.json bleibt aktiv. Zusaetzliche Altkonfiguration unveraendert unter data/legacy aufbewahrt.'
            }else{Move-TaskPloppDataFile $legacy $target $Root}
        }
        foreach($backup in Get-ChildItem -LiteralPath $Root -Filter 'config.before-*.json' -File){
            if($backup.Name-like'*.sync-conflict-*'){continue}
            $directory=Join-Path $data 'backups';$null=[IO.Directory]::CreateDirectory($directory)
            $destination=Join-Path $directory $backup.Name
            if([IO.File]::Exists($destination)){$destination=Join-Path $directory ($backup.BaseName+'-'+[guid]::NewGuid().ToString('N')+'.json')}
            Move-TaskPloppDataFile $backup.FullName $destination $Root
        }
    }catch{
        if(-not[IO.File]::Exists($target)-and[IO.File]::Exists($legacy)){$target=$legacy}
        $notice='Ordnerumzug unvollstaendig. Vorhandene Daten bleiben erhalten; alter Configpfad wird bei Bedarf weiter verwendet. Schreibrechte pruefen.'
    }
    [pscustomobject]@{ConfigPath=$target;Notice=$notice}
}
function Move-TaskPloppDataFile([string]$Source,[string]$Destination,[string]$Root) {
    $prefix=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    foreach($path in @($Source,$Destination)){
        if(-not[IO.Path]::GetFullPath($path).StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Path outside project'}
    }
    # Never overwrite. File.Move preserves original bytes and fails without losing the source.
    [IO.File]::Move($Source,$Destination)
}
