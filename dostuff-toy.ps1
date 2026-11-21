# dostuff-toy.ps1 [name] [-Rebuild] [-Sync] [-- dostuff args...]
# One command for a dostuff toy run. The toy lives in Downloads\<name> (next to this repo; a full path works too).
#   .\dostuff-toy.ps1 toy-8              builds the toy if it is missing, then starts the dostuff TUI in it
#   .\dostuff-toy.ps1 toy-8              (again) just starts dostuff in the existing toy
#   .\dostuff-toy.ps1 toy-8 -Sync        refreshes the toy's .dostuff from this repo's .claude, then starts
#   .\dostuff-toy.ps1 toy-8 -Rebuild     deletes the toy and builds a fresh one, then starts
#   .\dostuff-toy.ps1 toy-8 -- -p "hi"   anything after -- goes to dostuff
# dostuff runs from the ..\agent-1 checkout (PYTHONPATH), like hooks-sandbox\run-toy.ps1. agent-1's commit and
# dirty files at start are appended to <toy>\.git\agent-1-runs.log (inside .git, so the pipeline never sees it).
param([string]$Name = "dostuff-toy", [switch]$Rebuild, [switch]$Sync)
$ErrorActionPreference = "Stop"

$Repo = $PSScriptRoot
$Agent = Join-Path $Repo "..\agent-1" | Resolve-Path
$Toy = if ([IO.Path]::IsPathRooted($Name)) { $Name } else { Join-Path (Split-Path $Repo -Parent) $Name }

# Git Bash, not WSL's bash (make-toy.sh and install-dostuff.sh need Git Bash on Windows).
$Bash = Join-Path $env:ProgramFiles "Git\bin\bash.exe"
if (-not (Test-Path $Bash)) { $Bash = "bash" }
function Invoke-MakeToy([string[]]$Flags) {
  & $Bash "$($Repo -replace '\\', '/')/tests/pipeline/make-toy.sh" @Flags ($Toy -replace '\\', '/')
  if ($LASTEXITCODE -ne 0) { throw "make-toy.sh failed ($LASTEXITCODE)" }
}

$IsToy = Test-Path (Join-Path $Toy ".dostuff\pipeline.conf")
if ((Test-Path $Toy) -and -not $IsToy) { throw "$Toy exists but is not a dostuff toy (no .dostuff\pipeline.conf); pick another name" }

if ($Rebuild -and $IsToy) { Remove-Item -Recurse -Force $Toy; $IsToy = $false }
if (-not $IsToy) { Invoke-MakeToy @("--dostuff") }
elseif ($Sync) { Invoke-MakeToy @("--dostuff", "--sync") }
else {
  # An existing toy: say when its pipeline is older than .claude\ (the run would test stale files).
  & $Bash "$($Repo -replace '\\', '/')/install-dostuff.sh" --check ($Toy -replace '\\', '/') *> $null
  if ($LASTEXITCODE -ne 0) { Write-Warning "the toy's .dostuff differs from .claude\ (stale pipeline). Rerun with -Sync or -Rebuild to test the latest." }
}

$Head = git -C $Agent rev-parse --short HEAD
$Branch = git -C $Agent branch --show-current
$Dirty = @(git -C $Agent status --short)
$Line = "$(Get-Date -Format s)  agent-1 $Branch@$Head  dirty: $(if ($Dirty.Count) { $Dirty.Count } else { 'none' })"
Add-Content (Join-Path $Toy ".git\agent-1-runs.log") (@($Line) + ($Dirty | ForEach-Object { "    $_" }))
Write-Host $Line

# Restore the caller's PYTHONPATH and folder afterwards, so the shell is unchanged when dostuff exits.
$OldPath = $env:PYTHONPATH
$env:PYTHONPATH = "$Agent"
Push-Location $Toy
try { python -m dostuff @args } finally { Pop-Location; $env:PYTHONPATH = $OldPath }
