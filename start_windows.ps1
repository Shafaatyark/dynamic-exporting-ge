[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8000,
    [switch]$CheckOnly,
    [switch]$SmokeTest,
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $repoRoot

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    Write-Error "Python 3.10 or newer was not found. Install Python, then run this launcher again."
    exit 1
}
$systemPython = $pythonCommand.Source

$reportText = & $systemPython scripts\check_installation.py --engine matlab --json
$report = $reportText | ConvertFrom-Json
& $systemPython scripts\check_installation.py --engine matlab

if ($CheckOnly) {
    exit $(if ($report.ready) { 0 } else { 1 })
}
if (-not $report.ready) {
    $problems = @()
    if (-not $report.matlab.available) {
        $problems += "MATLAB was not found. If it is installed in a custom location, set `$env:DEGE_MATLAB_EXE to the full path to matlab.exe."
    }
    if (-not $report.dynare.available) {
        $problems += "Dynare was not found. Set `$env:DEGE_DYNARE_PATH to Dynare's matlab folder (the folder containing dynare.m), then run this launcher again."
    } elseif (-not $report.dynare.certified) {
        $dynareVersion = if ($report.dynare.version) { $report.dynare.version } else { "version unknown" }
        $problems += "Dynare $dynareVersion was found, but Dynare 7.1 or newer is required."
    }
    if (-not $report.python.available) {
        $problems += "Python 3.10 or newer is required."
    }
    Write-Error ($problems -join [Environment]::NewLine)
    exit 1
}

$env:DEGE_ENGINE = "matlab"
$env:DEGE_MATLAB_EXE = $report.matlab.path
$env:DEGE_DYNARE_PATH = $report.dynare.path
$env:DEGE_CORS_ORIGINS = "http://127.0.0.1:$Port,http://localhost:$Port"

$venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $venvPython)) {
    if ($SkipInstall) {
        Write-Error "The local Python environment is missing. Run again without -SkipInstall to create it."
        exit 1
    }
    Write-Host "Creating the local Python environment..."
    & $systemPython -m venv .venv
}

& $venvPython -c "import fastapi, uvicorn" 2>$null
if ($LASTEXITCODE -ne 0) {
    if ($SkipInstall) {
        Write-Error "FastAPI dependencies are missing. Run again without -SkipInstall to install them."
        exit 1
    }
    Write-Host "Installing the local web interface dependencies..."
    & $venvPython -m pip install -r api\requirements.txt
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($SmokeTest) {
    & $venvPython scripts\run_example.py
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$localUrl = "http://127.0.0.1:$Port"
$opener = Start-Job -ScriptBlock {
    param($Url)
    for ($attempt = 0; $attempt -lt 60; $attempt += 1) {
        try {
            Invoke-WebRequest -Uri "$Url/api/health" -UseBasicParsing -TimeoutSec 2 | Out-Null
            Start-Process $Url
            return
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
} -ArgumentList $localUrl

Write-Host "Starting the simulator at $localUrl"
Write-Host "MATLAB and Dynare will run only on this computer. Press Ctrl+C to stop."
try {
    & $venvPython -m uvicorn api.app:app --host 127.0.0.1 --port $Port
} finally {
    Stop-Job -Job $opener -ErrorAction SilentlyContinue
    Remove-Job -Job $opener -Force -ErrorAction SilentlyContinue
}
