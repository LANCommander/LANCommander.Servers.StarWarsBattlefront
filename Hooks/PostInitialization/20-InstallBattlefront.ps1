#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Star Wars: Battlefront is retail software with no public download. Use an existing install (the
# folder that holds GameData/Battlefront.exe) in /config/Server, or set SWBF_ARCHIVE_URL to a zip of
# it (GameData/ at the zip root, or inside one top-level folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallBattlefront"

$exe = Join-Path $Env:SERVER_DIR 'GameData/Battlefront.exe'

if (Test-Path -Path $exe) {
    Write-Log "Star Wars: Battlefront found in $Env:SERVER_DIR"
} elseif ($Env:SWBF_ARCHIVE_URL) {
    Write-Log "Downloading Star Wars: Battlefront from $Env:SWBF_ARCHIVE_URL"

    # The archive is about 2 GB, so download and extract under /config rather than the container's
    # root filesystem.
    $zip     = '/config/.swbf-download.zip'
    $extract = '/config/.swbf-extract'

    curl -fL --retry 3 --output $zip "$Env:SWBF_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:SWBF_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    # The server only needs GameData/, and not its cutscenes. unzip's * also matches /, so one
    # pattern covers GameData/ at the root and inside a top-level folder (a pattern that matches
    # nothing makes unzip fail).
    unzip -q -o $zip '*GameData/*' -x '*/Movies/*' -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept GameData/ at the zip root or inside one top-level folder
    $gameData = Get-ChildItem -Path $extract -Filter 'Battlefront.exe' -Recurse -File -Depth 2 |
        Where-Object { $_.Directory.Name -ieq 'GameData' } |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $gameData) { throw "GameData/Battlefront.exe not found in $Env:SWBF_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Remove-Item -Recurse -Force -Path (Join-Path $Env:SERVER_DIR 'GameData') -ErrorAction SilentlyContinue
    Move-Item -Force -Path $gameData.FullName -Destination (Join-Path $Env:SERVER_DIR 'GameData')
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    Remove-Item -Recurse -Force -Path $zip, $extract

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "Star Wars: Battlefront installed"
} else {
    Write-Log -Level Error "GameData/Battlefront.exe not found in $Env:SERVER_DIR. Copy a Star Wars: Battlefront install there or set SWBF_ARCHIVE_URL."
}

Invoke-Hook "PostInstallBattlefront"

Set-Location $Env:SERVER_ROOT
