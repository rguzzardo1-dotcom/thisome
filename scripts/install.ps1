#requires -Version 5.1
<#
One-shot installer for thisome on Windows.

  - Verifies Python is installed.
  - Creates a virtualenv next to this repo and installs dependencies.
  - Prompts for CLIENT_ID / TENANT_ID and writes .env (unless one already exists).
  - Runs daily_todo.py once so you can complete the device-code sign-in.
  - Registers two scheduled tasks under \thisome\:
      Daily To Do      -> daily 6:00 AM
      Weekly Cleanup   -> Monday 8:00 AM

Re-run any time; it's idempotent.
#>

[CmdletBinding()]
param(
    [string]$DailyTime  = '02:00',
    [string]$WeeklyTime = '16:00',
    [string]$WeeklyDay  = 'Friday'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

Write-Host "==> thisome installer" -ForegroundColor Cyan
Write-Host "Repo: $RepoRoot"

# --- Python check ----------------------------------------------------------
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Error "Python not found on PATH. Install from https://www.python.org/downloads/ (check 'Add to PATH'), then re-run."
}
$pyver = & python --version 2>&1
Write-Host "Found: $pyver"

# --- venv ------------------------------------------------------------------
$venv = Join-Path $RepoRoot '.venv'
if (-not (Test-Path $venv)) {
    Write-Host "==> Creating virtualenv (.venv)" -ForegroundColor Cyan
    & python -m venv $venv
}
$venvPython = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    Write-Error "venv creation failed; $venvPython not found."
}

Write-Host "==> Installing dependencies" -ForegroundColor Cyan
& $venvPython -m pip install --upgrade pip | Out-Null
& $venvPython -m pip install -r (Join-Path $RepoRoot 'requirements.txt')

# --- .env ------------------------------------------------------------------
$envPath = Join-Path $RepoRoot '.env'
if (-not (Test-Path $envPath)) {
    Write-Host "==> Configuring .env" -ForegroundColor Cyan
    Write-Host "If you haven't registered the Azure app yet, see README.md before continuing." -ForegroundColor Yellow
    $clientId = Read-Host "Enter CLIENT_ID (Application/client ID from Azure)"
    $tenantId = Read-Host "Enter TENANT_ID (Directory/tenant ID, or 'common' for personal accounts)"
    if (-not $tenantId) { $tenantId = 'common' }
    @(
        "CLIENT_ID=$clientId"
        "TENANT_ID=$tenantId"
    ) | Set-Content -Encoding UTF8 -Path $envPath
    Write-Host "Wrote $envPath"
} else {
    Write-Host "==> .env already exists -- leaving it alone" -ForegroundColor Cyan
}

# --- First-run sign-in -----------------------------------------------------
$cachePath = Join-Path $env:USERPROFILE '.thisome_cache.bin'
if (-not (Test-Path $cachePath)) {
    Write-Host "==> Running daily_todo.py once for sign-in" -ForegroundColor Cyan
    Write-Host "A device-code URL will print below. Open it in a browser, paste the code, and sign in." -ForegroundColor Yellow
    & $venvPython (Join-Path $RepoRoot 'daily_todo.py')
} else {
    Write-Host "==> Token cache already exists at $cachePath -- skipping sign-in" -ForegroundColor Cyan
}

# --- Scheduled tasks -------------------------------------------------------
# Daily task runs whether the user is signed in or not -- this needs the
# Windows password so Task Scheduler can launch the process as you. The
# weekly cleanup stays Interactive because it must show a Tk dialog.
Write-Host "==> Registering scheduled tasks" -ForegroundColor Cyan
Write-Host "The daily task needs your Windows password so it can run while you're signed out." -ForegroundColor Yellow
$securePwd = Read-Host "Windows password for $($env:USERNAME)" -AsSecureString
$plainPwd  = [System.Net.NetworkCredential]::new('', $securePwd).Password

function Register-ThisomeTask {
    param(
        [string]$Name,
        [string]$Script,
        [string]$Trigger,         # 'Daily' or 'Weekly'
        [string]$LogonMode        # 'Password' or 'Interactive'
    )

    $taskPath = '\thisome\'
    $fullName = "$taskPath$Name"

    if (Get-ScheduledTask -TaskName $Name -TaskPath $taskPath -ErrorAction SilentlyContinue) {
        Write-Host "    removing existing task $fullName"
        Unregister-ScheduledTask -TaskName $Name -TaskPath $taskPath -Confirm:$false
    }

    $action = New-ScheduledTaskAction `
        -Execute $venvPython `
        -Argument "`"$Script`"" `
        -WorkingDirectory $RepoRoot

    if ($Trigger -eq 'Daily') {
        $trig = New-ScheduledTaskTrigger -Daily -At $DailyTime
    } else {
        $trig = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $WeeklyDay -At $WeeklyTime
    }

    $wake = $Trigger -eq 'Daily'
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -WakeToRun:$wake `
        -MultipleInstances IgnoreNew

    if ($LogonMode -eq 'Password') {
        Register-ScheduledTask `
            -TaskName $Name `
            -TaskPath $taskPath `
            -Action $action `
            -Trigger $trig `
            -Settings $settings `
            -User $env:USERNAME `
            -Password $plainPwd `
            -RunLevel Limited `
            -Description "thisome -- $Name" | Out-Null
    } else {
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask `
            -TaskName $Name `
            -TaskPath $taskPath `
            -Action $action `
            -Trigger $trig `
            -Principal $principal `
            -Settings $settings `
            -Description "thisome -- $Name" | Out-Null
    }

    Write-Host "    registered $fullName"
}

Register-ThisomeTask -Name 'Daily To Do'    -Script (Join-Path $RepoRoot 'daily_todo.py')       -Trigger 'Daily'  -LogonMode 'Password'
Register-ThisomeTask -Name 'Weekly Cleanup' -Script (Join-Path $RepoRoot 'desktop_organize.py') -Trigger 'Weekly' -LogonMode 'Interactive'

# Best-effort scrub of the password from memory.
$plainPwd = $null
[System.GC]::Collect()

Write-Host ""
Write-Host "Done. Daily To Do runs at $DailyTime (whether signed in or not)." -ForegroundColor Green
Write-Host "Weekly Cleanup runs $WeeklyDay at $WeeklyTime (requires you to be signed in)." -ForegroundColor Green
Write-Host "Edit times anytime in Task Scheduler under \thisome\."
Write-Host ""
Write-Host "Note: a fully powered-off PC can't run the task -- StartWhenAvailable will catch it next boot." -ForegroundColor Yellow
Write-Host "If you change your Windows password, re-run this installer so the daily task can re-authenticate." -ForegroundColor Yellow
