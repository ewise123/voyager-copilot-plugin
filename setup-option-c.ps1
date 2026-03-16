# setup-option-c.ps1
# Run this once to set up the Voyager Copilot Plugin (Option C)

$RepoPath = "$env:USERPROFILE\projects\voyager-copilot-plugin"
$AdoUrl = "https://dev.azure.com/protectivetfsprod/DataHub/_git/voyager-copilot-plugin"

# Clone if not already present
if (-not (Test-Path $RepoPath)) {
    Write-Host "Cloning voyager-copilot-plugin..." -ForegroundColor Yellow
    git clone $AdoUrl $RepoPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Clone failed. Check your ADO access." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Repo already exists at $RepoPath - pulling latest..." -ForegroundColor Yellow
    git -C $RepoPath pull
}

# Show the developer what to add to VS Code settings
$pluginPath = "$RepoPath\plugins\voyager" -replace '\\', '\\\\'
Write-Host ""
Write-Host "SUCCESS! Now add this to your VS Code user settings" -ForegroundColor Green
Write-Host "(Ctrl+Shift+P -> 'Preferences: Open User Settings (JSON)'):" -ForegroundColor Yellow
Write-Host ""
Write-Host "  `"chat.plugins.enabled`": true," -ForegroundColor Cyan
Write-Host "  `"chat.plugins.paths`": {" -ForegroundColor Cyan
Write-Host "      `"$pluginPath`": true" -ForegroundColor Cyan
Write-Host "  }" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then reload VS Code (Ctrl+Shift+P -> 'Developer: Reload Window')" -ForegroundColor Yellow
Write-Host "Verify: type /skills in Copilot Chat - voyager-dlt should appear" -ForegroundColor Yellow
