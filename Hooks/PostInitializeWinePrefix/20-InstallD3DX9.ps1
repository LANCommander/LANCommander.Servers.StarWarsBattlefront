#Requires -Modules Logging

# Battlefront's /norender mode gives D3DX a stub device. Wine's builtin d3dx9_43 crashes on it in
# D3DXCheckTextureRequirements (page fault reading 0), so install Microsoft's d3dx9_43.dll (cached in
# the image at /opt/d3dx9) into the prefix and prefer it over the builtin.

$prefix = $Env:WINEPREFIX
$runAs  = "$($Env:UID):$($Env:GID)"
$source = '/opt/d3dx9/d3dx9_43.dll'

# 32-bit DLLs live in syswow64 in a 64-bit prefix, system32 in a 32-bit one
$sysDir = Join-Path $prefix 'drive_c/windows/syswow64'
if (-not (Test-Path -Path $sysDir)) {
    $sysDir = Join-Path $prefix 'drive_c/windows/system32'
}

$target = Join-Path $sysDir 'd3dx9_43.dll'
$marker = Join-Path $prefix '.lancommander-d3dx9_43'

$installed = (Test-Path -Path $target) -and (Test-Path -Path $marker) -and
    ((Get-FileHash -Path $target).Hash -eq (Get-FileHash -Path $source).Hash)

if (-not $installed) {
    Write-Log "Installing native d3dx9_43.dll into the Wine prefix"

    Copy-Item -Force -Path $source -Destination $target
    chown $runAs $target

    & gosu $runAs wine reg add 'HKCU\Software\Wine\DllOverrides' /v d3dx9_43 /t REG_SZ /d native /f
    $exitCode = $LASTEXITCODE
    & gosu $runAs wineserver --wait

    if ($exitCode -ne 0) {
        throw "Could not set the d3dx9_43 DLL override (exit code $exitCode)"
    }

    New-Item -ItemType File -Path $marker -Force | Out-Null
    chown $runAs $marker

    Write-Log "Native d3dx9_43.dll installed"
} else {
    Write-Log "Native d3dx9_43.dll already installed"
}
