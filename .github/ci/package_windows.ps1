$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$dist = Join-Path $root "dist/nextpnr-windows-x64"
$envRoot = $env:CONDA_PREFIX

if (-not $envRoot) {
    throw "CONDA_PREFIX is not set; run this script through 'pixi run'."
}

Remove-Item $dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item $dist -ItemType Directory | Out-Null

Copy-Item (Join-Path $root "build/pixi-fpga/nextpnr-ice40.exe") $dist
Copy-Item (Join-Path $root "build/pixi-fpga/nextpnr-himbaechel.exe") $dist
Copy-Item (Join-Path $root "build/pixi-fpga/share") (Join-Path $dist "share") -Recurse

# Deploy Qt plugins and libraries for the GUI-enabled Himbaechel/Gowin binary.
$libraryBin = Join-Path $envRoot "Library/bin"
$windeployqt = Join-Path $libraryBin "windeployqt6.exe"
$qtpathsAlias = Join-Path $dist "qtpaths.exe"
Copy-Item (Join-Path $libraryBin "qtpaths6.exe") $qtpathsAlias
$originalPath = $env:PATH
$env:PATH = "$dist;$libraryBin;$originalPath"
& $windeployqt --release --compiler-runtime --no-translations (Join-Path $dist "nextpnr-himbaechel.exe")
$deployExitCode = $LASTEXITCODE
$env:PATH = $originalPath
Remove-Item $qtpathsAlias -Force
if ($deployExitCode -ne 0) {
    throw "windeployqt failed with exit code $deployExitCode."
}

# Dependencies not handled by windeployqt.
$runtimeDlls = @(
    "boost_program_options.dll",
    "boost_iostreams.dll",
    "boost_thread.dll",
    "zlib.dll",
    "libbz2.dll",
    "liblzma.dll",
    "zstd.dll",
    "libpng16.dll",
    "freetype.dll",
    "double-conversion.dll",
    "pcre2-16.dll"
)
foreach ($name in $runtimeDlls) {
    $source = @(
        (Join-Path $libraryBin $name),
        (Join-Path $envRoot $name)
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $source) {
        throw "Required runtime DLL not found: $name"
    }
    Copy-Item $source $dist -Force
}
Get-ChildItem $envRoot -File | Where-Object {
    $_.Name -like "msvcp140*.dll" -or
    $_.Name -like "vcruntime140*.dll" -or
    $_.Name -eq "concrt140.dll" -or
    $_.Name -eq "ucrtbase.dll"
} | Copy-Item -Destination $dist -Force

# Bundle the embedded Python runtime without third-party site-packages.
Get-ChildItem $envRoot -Filter "python*.dll" | Copy-Item -Destination $dist -Force
Copy-Item (Join-Path $envRoot "DLLs") (Join-Path $dist "DLLs") -Recurse
New-Item (Join-Path $dist "Lib") -ItemType Directory | Out-Null
Get-ChildItem (Join-Path $envRoot "Lib") |
    Where-Object { $_.Name -ne "site-packages" } |
    Copy-Item -Destination (Join-Path $dist "Lib") -Recurse

$versionedPython = Get-ChildItem $dist -Filter "python3*.dll" |
    Where-Object { $_.Name -ne "python3.dll" } |
    Select-Object -First 1
if (-not $versionedPython) {
    throw "Versioned Python runtime DLL was not packaged."
}
@(".", "Lib", "DLLs") | Set-Content (Join-Path $dist ($versionedPython.BaseName + "._pth")) -Encoding ascii

# Verify the artifact without falling back to DLLs from the Pixi environment.
$env:PATH = "$dist;$env:SystemRoot\System32;$env:SystemRoot"
Set-Location $root
& (Join-Path $dist "nextpnr-ice40.exe") --lp384 --package qn32 --run python/graphics_smoke.py
if ($LASTEXITCODE -ne 0) {
    throw "Packaged iCE40 graphics smoke test failed with exit code $LASTEXITCODE."
}
& (Join-Path $dist "nextpnr-himbaechel.exe") --device GW1N-LV1QN48C6/I5 --run python/graphics_smoke.py
if ($LASTEXITCODE -ne 0) {
    throw "Packaged Gowin graphics smoke test failed with exit code $LASTEXITCODE."
}
