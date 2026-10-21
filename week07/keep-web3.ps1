# Run in the guestbook directory. Stop with Ctrl+C before shutting down Compose.
while ($true) {
    $webIds = @(docker compose ps --status running -q web)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Cannot read Compose state. Retrying in 5 seconds.'
    } elseif ($webIds.Count -ne 3) {
        Write-Host "$(Get-Date -Format s) web=$($webIds.Count): restoring to 3"
        docker compose up -d --scale web=3 web
        if ($LASTEXITCODE -ne 0) {
            Write-Warning 'Recovery failed. Retrying in 5 seconds.'
        }
    } else {
        Write-Host "$(Get-Date -Format s) web=3"
    }
    Start-Sleep -Seconds 5
}
