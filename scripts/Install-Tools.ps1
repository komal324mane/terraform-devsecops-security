$ErrorActionPreference = 'Stop'

$version = '1.28.14'
$archiveName = "tfsec_${version}_windows_amd64.tar.gz"
$archiveUri = "https://github.com/aquasecurity/tfsec/releases/download/v$version/$archiveName"
$expectedSha256 = 'a53c4d7c6c85029378c8895ffbf9b23ea04a887d20136dc1d24d1307cf1a0491'
$toolsDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\.tools\tfsec'))
$archivePath = Join-Path ([System.IO.Path]::GetTempPath()) $archiveName

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw 'Python was not found in PATH. Install Python 3.12 or newer, then rerun this script.'
}
if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
    throw 'tar.exe was not found in PATH. Use a supported Windows version with tar.exe available.'
}

$venvDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\.venv'))
$venvPython = Join-Path $venvDirectory 'Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    python -m venv $venvDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Python virtual environment creation failed with exit code $LASTEXITCODE"
    }
}

& $venvPython -m pip install --disable-pip-version-check 'checkov==3.2.495'
if ($LASTEXITCODE -ne 0) {
    throw "Pinned Checkov installation failed with exit code $LASTEXITCODE"
}

New-Item -ItemType Directory -Path $toolsDirectory -Force | Out-Null
Invoke-WebRequest -Uri $archiveUri -OutFile $archivePath
$actualSha256 = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
    throw "tfsec archive checksum mismatch: expected $expectedSha256, got $actualSha256"
}

& tar.exe -xzf $archivePath -C $toolsDirectory
if ($LASTEXITCODE -ne 0) {
    throw "tfsec archive extraction failed with exit code $LASTEXITCODE"
}

$tfsecPath = Join-Path $toolsDirectory 'tfsec.exe'
if (-not (Test-Path $tfsecPath)) {
    throw "tfsec.exe was not found after extracting $archiveName"
}

& $tfsecPath --version
if ($LASTEXITCODE -ne 0) {
    throw "tfsec version check failed with exit code $LASTEXITCODE"
}
& (Join-Path $venvDirectory 'Scripts\checkov.cmd') --version
if ($LASTEXITCODE -ne 0) {
    throw "Checkov version check failed with exit code $LASTEXITCODE"
}
