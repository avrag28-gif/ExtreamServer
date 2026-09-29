# Run in an elevated PowerShell on the Windows GPU machine.
# Register the machine as a GitHub Actions self-hosted runner, then apply
# reversible performance settings for Roblox Studio.

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$RepoUrl,
  [Parameter(Mandatory=$true)][string]$RunnerToken,
  [string]$RunnerName = $env:COMPUTERNAME,
  [string[]]$Labels = @("gpu","roblox-studio")
)

$ErrorActionPreference = "Stop"
$RunnerDir = "C:\actions-runner"

New-Item -ItemType Directory -Force -Path $RunnerDir | Out-Null
Set-Location $RunnerDir

$latest = Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner/releases/latest" -Headers @{ "User-Agent" = "ExtreamServer" }
$asset = $latest.assets | Where-Object { $_.name -match "actions-runner-win-x64-.*\.zip$" } | Select-Object -First 1
if (-not $asset) { throw "Could not find the current Windows x64 Actions Runner package." }

$zip = Join-Path $RunnerDir "actions-runner.zip"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $RunnerDir -Force
Remove-Item $zip -Force

$labelArg = ($Labels -join ",")
.config.cmd --unattended --url $RepoUrl --token $RunnerToken --name $RunnerName --labels $labelArg --replace

# Reversible Windows performance settings.
powercfg /setactive SCHEME_MIN
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name VisualFXSetting -Type DWord -Value 2 -Force

# Hardware verification.
Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
  nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv
} else {
  Write-Warning "nvidia-smi was not found. Install the correct NVIDIA driver before using this runner for GPU workloads."
}

# Install runner as a Windows service.
.\svc.cmd install
.\svc.cmd start

Write-Host ""
Write-Host "Self-hosted GPU runner configured."
Write-Host "Labels: $labelArg"
Write-Host "Runner directory: $RunnerDir"
