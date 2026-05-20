#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$MsixPath = "C:\Temp\Claude.msix"
)

$ErrorActionPreference = 'Continue'

function Write-Section($text) {
    Write-Host ""
    Write-Host "=== $text ===" -ForegroundColor Cyan
}

Write-Section "1. VirtualMachinePlatform state"
$vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
$vmp | Select-Object FeatureName, State | Format-Table | Out-Host

if ($vmp.State -ne 'Enabled') {
    Write-Host "Enabling VirtualMachinePlatform..." -ForegroundColor Yellow
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Host
    Write-Host "REBOOT REQUIRED. Reboot, then re-run this script." -ForegroundColor Red
    exit 1
}

Write-Section "2. Existing Claude installs"
$existing = Get-AppxPackage -Name *Claude* -AllUsers -ErrorAction SilentlyContinue
if ($existing) {
    $existing | Select-Object Name, PackageFullName, PackageUserInformation | Format-List | Out-Host
    Write-Host "Removing per-user Claude packages..." -ForegroundColor Yellow
    $existing | ForEach-Object {
        try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop }
        catch { Write-Host "  Could not remove $($_.PackageFullName): $_" -ForegroundColor DarkYellow }
    }
} else {
    Write-Host "(none installed)"
}

Write-Section "3. MSIX package check"
if (-not (Test-Path $MsixPath)) {
    Write-Host "MSIX not found at $MsixPath" -ForegroundColor Red
    Write-Host "Download the .msix (not ClaudeSetup.exe) from https://claude.ai/download" -ForegroundColor Yellow
    Write-Host "Save it to $MsixPath, then re-run this script." -ForegroundColor Yellow
    exit 1
}
Write-Host "Found: $MsixPath"

Write-Section "4. Provisioning machine-wide"
try {
    Add-AppxProvisionedPackage -Online -PackagePath $MsixPath -SkipLicense -Regions "all" | Out-Host
    Write-Host "Provisioned OK." -ForegroundColor Green
} catch {
    Write-Host "Add-AppxProvisionedPackage failed: $_" -ForegroundColor Red
    exit 1
}

Write-Section "5. Verify"
Get-AppxPackage -Name *Claude* -AllUsers | Select-Object Name, PackageFullName | Format-Table | Out-Host

Write-Section "Done"
Write-Host "Sign out of Windows (or reboot), sign back in, launch Claude Desktop," -ForegroundColor Green
Write-Host "sign in to your Max account, and check the Cowork toggle." -ForegroundColor Green
