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

$venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"
$packageRoot = Join-Path $repoRoot ".python-packages"
$runtimePython = $null
$usingSystemFallback = $false

function Test-PythonExecutable {
    param([Parameter(Mandatory = $true)][string]$Executable)
    try {
        & $Executable -c "import sys; print(sys.executable)" 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Enable-SystemPythonFallback {
    $script:runtimePython = $systemPython
    $script:usingSystemFallback = $true
    if ([string]::IsNullOrWhiteSpace($env:PYTHONPATH)) {
        $env:PYTHONPATH = $packageRoot
    } elseif (($env:PYTHONPATH -split [IO.Path]::PathSeparator) -notcontains $packageRoot) {
        $env:PYTHONPATH = "$packageRoot$([IO.Path]::PathSeparator)$env:PYTHONPATH"
    }
    Write-Host "Using the managed-Windows Python fallback with packages in .python-packages."
}

function Test-ApiDependencies {
    if ($script:usingSystemFallback -and
        (-not (Test-Path -LiteralPath (Join-Path $packageRoot "fastapi")) -or
         -not (Test-Path -LiteralPath (Join-Path $packageRoot "uvicorn")))) {
        return $false
    }
    try {
        & $script:runtimePython -c "import fastapi, uvicorn" 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

if (Test-Path -LiteralPath $venvPython) {
    if (Test-PythonExecutable -Executable $venvPython) {
        $runtimePython = $venvPython
    } else {
        Write-Warning "The existing .venv Python cannot run under the current Windows policy."
        Enable-SystemPythonFallback
    }
} elseif (-not $CheckOnly -and -not $SkipInstall) {
    Write-Host "Creating the local Python environment..."
    try {
        & $systemPython -m venv .venv
        if ($LASTEXITCODE -ne 0 -or -not (Test-PythonExecutable -Executable $venvPython)) {
            throw "The virtual environment could not be created or executed."
        }
        $runtimePython = $venvPython
    } catch {
        Write-Warning "The local virtual environment is unavailable: $($_.Exception.Message)"
        Enable-SystemPythonFallback
    }
} else {
    Enable-SystemPythonFallback
}

$reportText = & $runtimePython scripts\check_installation.py --engine matlab --json
$report = $reportText | ConvertFrom-Json
& $runtimePython scripts\check_installation.py --engine matlab

if ($CheckOnly) {
    exit $(if ($report.ready) { 0 } else { 1 })
}
if (-not $report.ready) {
    Write-Error "MATLAB and Dynare must be installed before the local simulator can start."
    exit 1
}

$env:DEGE_ENGINE = "matlab"
$env:DEGE_MATLAB_EXE = $report.matlab.path
$env:DEGE_DYNARE_PATH = $report.dynare.path
$env:DEGE_CORS_ORIGINS = "http://127.0.0.1:$Port,http://localhost:$Port"

if (-not (Test-ApiDependencies)) {
    if ($SkipInstall) {
        Write-Error "FastAPI dependencies are missing. Run again without -SkipInstall to install them."
        exit 1
    }
    Write-Host "Installing the local web interface dependencies..."
    if ($usingSystemFallback) {
        New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
        & $systemPython -m pip install --target $packageRoot -r api\requirements.txt
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
        try {
            & $runtimePython -m pip install -r api\requirements.txt
            if ($LASTEXITCODE -ne 0) { throw "Virtual-environment dependency installation failed." }
        } catch {
            Write-Warning "The virtual environment cannot install or run the API dependencies."
            Enable-SystemPythonFallback
            if (-not (Test-ApiDependencies)) {
                New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
                & $systemPython -m pip install --target $packageRoot -r api\requirements.txt
                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            }
        }
    }
    if (-not (Test-ApiDependencies)) {
        Write-Error "FastAPI dependencies could not be loaded by the selected Python runtime."
        exit 1
    }
}

if ($SmokeTest) {
    & $runtimePython scripts\run_example.py
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
    & $runtimePython -m uvicorn api.app:app --host 127.0.0.1 --port $Port
} finally {
    Stop-Job -Job $opener -ErrorAction SilentlyContinue
    Remove-Job -Job $opener -Force -ErrorAction SilentlyContinue
}
