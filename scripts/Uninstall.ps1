# Removes the thisome scheduled tasks. Leaves your files, .env, and venv alone.
$ErrorActionPreference = 'Continue'
foreach ($name in 'Daily To Do','Weekly Cleanup') {
    if (Get-ScheduledTask -TaskName $name -TaskPath '\thisome\' -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $name -TaskPath '\thisome\' -Confirm:$false
        Write-Host "Removed \thisome\$name"
    }
}
Write-Host "Done. Repo files are untouched. Delete the folder to remove the rest."
