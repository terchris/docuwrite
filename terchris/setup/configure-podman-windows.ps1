# File: configure-podman-windows.ps1
# Purpose: Configure Podman and VSCode Docker extension on Windows
#
# This script verifies and configures Podman for use with VSCode's Docker extension.
# It performs the following tasks:
# - Checks/installs Podman (using Chocolatey if available, or guides manual installation)
# - Verifies Podman machine status and starts if needed
# - Configures VSCode Docker extension to use Podman socket
# - Sets up Windows environment variables
#
# Usage:
#   1. Open PowerShell
#   2. If needed: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   3. Run: .\configure-podman-windows.ps1
#
# Requirements:
#   - Windows 10/11
#   - VSCode with Docker extension installed
#   - Optional: Chocolatey for automatic Podman installation
#
# Note: Run as administrator if using Chocolatey for installation

function Test-PodmanInstallation {
    if (Get-Command -Name podman -ErrorAction SilentlyContinue) {
        $version = podman version --format "{{.Client.Version}}"
        Write-Host "✅ Podman is installed (version $version)"
        return $true
    }

    Write-Host "❌ Podman is not installed"
    if (Get-Command -Name choco -ErrorAction SilentlyContinue) {
        Write-Host "📦 Installing Podman using Chocolatey..."

        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
            Write-Host "❌ Please run PowerShell as Administrator to install Podman using Chocolatey"
            return $false
        }

        try {
            choco install podman -y
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            if (Get-Command -Name podman -ErrorAction SilentlyContinue) {
                Write-Host "✅ Podman installed successfully"
                return $true
            }
        }
        catch {
            Write-Host "❌ Failed to install using Chocolatey"
        }
    }

    Write-Host "Podman needs to be installed manually:"
    Write-Host "1. Download the Windows installer from https://podman.io/getting-started/installation#windows"
    Write-Host "2. Run the downloaded installer and follow installation instructions"
    Write-Host "3. Run this script again"
    return $false
}

function Check-PodmanMachine {
    $machineStatus = podman machine list | Select-String "Currently running"
    if ($machineStatus) {
        Write-Host "✅ Podman machine is running"
        return $true
    }

    Write-Host "⚙️ Podman machine needs setup..."
    if (!(podman machine list | Select-String ".*")) {
        Write-Host "🔧 Initializing Podman machine..."
        podman machine init
    }
    Write-Host "🚀 Starting Podman machine..."
    podman machine start
    return $true
}

function Get-SocketPath {
    $machineName = (podman machine list | Select-String "Currently running").ToString().Split()[0]
    if (!$machineName) {
        Write-Host "❌ No running Podman machine found"
        return $null
    }

    try {
        $machineInfo = podman machine inspect $machineName | ConvertFrom-Json
        $socketPath = $machineInfo.ConnectionInfo.PodmanSocket.Path

        if (!$socketPath) {
            Write-Host "❌ Could not determine Podman socket path"
            return $null
        }

        return $socketPath
    }
    catch {
        Write-Host "❌ Error getting Podman socket path: $_"
        return $null
    }
}

function Configure-VSCode {
    param (
        [string]$SocketPath
    )

    $vscodePath = "$env:APPDATA\Code\User"
    $settingsPath = "$vscodePath\settings.json"

    if (!(Test-Path $vscodePath)) {
        Write-Host "❌ VSCode doesn't appear to be installed"
        return $false
    }

    $unixSocketPath = $SocketPath.Replace('\', '/')

    if (Test-Path $settingsPath) {
        try {
            $currentSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
            if ($currentSettings.'docker.environment'.DOCKER_HOST -eq "unix://$unixSocketPath") {
                Write-Host "✅ VSCode Docker extension already configured"
                return $true
            }
        }
        catch {
            Write-Host "⚠️ Could not parse existing VSCode settings, will create new ones"
        }
    }

    Write-Host "⚙️ Configuring VSCode Docker extension..."

    if (!(Test-Path $settingsPath)) {
        Set-Content -Path $settingsPath -Value "{}"
    }

    Copy-Item $settingsPath "$settingsPath.backup" -ErrorAction SilentlyContinue

    $settingsContent = Get-Content $settingsPath -Raw
    if (!$settingsContent -or $settingsContent.Trim() -eq "") {
        $settingsContent = "{}"
    }

    $dockerSettings = @"
"docker.environment": {"DOCKER_HOST": "unix://$unixSocketPath"}
"@

    if ($settingsContent -match '"docker\.environment"\s*:') {
        $settingsContent = $settingsContent -replace '"docker\.environment"\s*:\s*{[^}]*}', $dockerSettings
    }
    else {
        $settingsContent = $settingsContent.Trim().TrimEnd('}')
        if ($settingsContent.Length -gt 1) {
            $settingsContent += ','
        }
        $settingsContent += "`n  $dockerSettings`n}"
    }

    try {
        Set-Content -Path $settingsPath -Value $settingsContent
        Write-Host "✅ VSCode Docker extension configured"
        return $true
    }
    catch {
        Write-Host "❌ Failed to update VSCode settings: $_"
        return $false
    }
}

function Configure-Environment {
    param (
        [string]$SocketPath
    )

    $unixSocketPath = $SocketPath.Replace('\', '/')
    $currentValue = [Environment]::GetEnvironmentVariable("DOCKER_HOST", "User")

    if ($currentValue -eq "unix://$unixSocketPath") {
        Write-Host "✅ DOCKER_HOST environment variable already configured"
        return $true
    }

    Write-Host "⚙️ Configuring DOCKER_HOST environment variable..."
    try {
        [Environment]::SetEnvironmentVariable(
            "DOCKER_HOST",
            "unix://$unixSocketPath",
            "User"
        )
        Write-Host "✅ Environment variable configured"
        Write-Host "ℹ️  Please restart your terminal for the changes to take effect"
        return $true
    }
    catch {
        Write-Host "❌ Failed to set environment variable: $_"
        return $false
    }
}

# Main execution flow
function Main {
    Write-Host "🔍 Checking Podman configuration..."

    if (!(Test-PodmanInstallation)) {
        exit 1
    }

    if (!(Check-PodmanMachine)) {
        exit 1
    }

    $SocketPath = Get-SocketPath
    if (!$SocketPath) {
        exit 1
    }

    $success = $true
    if (!(Configure-VSCode $SocketPath)) {
        $success = $false
    }
    if (!(Configure-Environment $SocketPath)) {
        $success = $false
    }

    if ($success) {
        Write-Host "🎉 Podman configuration verified and updated where needed!"
    }
    else {
        Write-Host "⚠️ Some configurations could not be completed. Please check the messages above."
        exit 1
    }
}

# Run the script
Main
