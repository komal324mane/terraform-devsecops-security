param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('secure', 'insecure')]
    [string]$Sample
)

$ErrorActionPreference = 'Stop'
$samplePath = Join-Path $PSScriptRoot "..\samples\$Sample"
$samplePath = [System.IO.Path]::GetFullPath($samplePath)
$tfsecPath = Join-Path $PSScriptRoot '..\.tools\tfsec\tfsec.exe'
$checkovPath = Join-Path $PSScriptRoot '..\.venv\Scripts\checkov.cmd'

if (-not (Test-Path $tfsecPath)) {
    throw "tfsec is not installed at $tfsecPath. Run scripts\Install-Tools.ps1 first."
}
if (-not (Test-Path $checkovPath)) {
    throw "Checkov is not installed at $checkovPath. Run scripts\Install-Tools.ps1 first."
}

function Invoke-Scanner {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$StdoutPath,
        [string]$StderrPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments 1> $StdoutPath 2> $StderrPath
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

$tfsecStdout = [System.IO.Path]::GetTempFileName()
$tfsecStderr = [System.IO.Path]::GetTempFileName()
$checkovStdout = [System.IO.Path]::GetTempFileName()
$checkovStderr = [System.IO.Path]::GetTempFileName()

try {
    Write-Output "Scanning $samplePath with tfsec..."
    $tfsecExitCode = Invoke-Scanner -Executable $tfsecPath -Arguments @($samplePath, '--no-color') -StdoutPath $tfsecStdout -StderrPath $tfsecStderr
    $tfsecText = (Get-Content $tfsecStdout -Raw) + "`n" + (Get-Content $tfsecStderr -Raw)
    Write-Output $tfsecText

    Write-Output "Scanning $samplePath with Checkov..."
    $checkovExitCode = Invoke-Scanner -Executable $checkovPath -Arguments @('-d', $samplePath, '--framework', 'terraform') -StdoutPath $checkovStdout -StderrPath $checkovStderr
    $checkovText = (Get-Content $checkovStdout -Raw) + "`n" + (Get-Content $checkovStderr -Raw)
    Write-Output $checkovText

    if ($Sample -eq 'secure' -and ($tfsecExitCode -ne 0 -or $checkovExitCode -ne 0)) {
        throw "Secure sample scan failed (tfsec=$tfsecExitCode, Checkov=$checkovExitCode). Review and remediate findings."
    }

    if ($Sample -eq 'insecure') {
        if ($tfsecText -notmatch 'ingress to SSH port') {
            throw "tfsec did not report the expected public SSH finding (exit code $tfsecExitCode). Review scanner output and tool health."
        }
        if ($checkovText -notmatch 'CKV_AZURE_10:.*SSH access is restricted') {
            throw "Checkov did not report CKV_AZURE_10 for public SSH (exit code $checkovExitCode). Review scanner output and tool health."
        }

        Write-Warning "Both scanners reported the expected public SSH finding; their nonzero scan results are expected for this insecure sample."
    }
}
finally {
    Remove-Item $tfsecStdout, $tfsecStderr, $checkovStdout, $checkovStderr -Force
}
