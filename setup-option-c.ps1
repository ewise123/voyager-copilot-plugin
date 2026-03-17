# setup-option-c.ps1
# Run this once to set up the Voyager Copilot Plugin (Option C)
#
# Usage:
#   .\setup-option-c.ps1                                           # Uses defaults
#   .\setup-option-c.ps1 -AdoUrl "https://dev.azure.com/myorg/..." # Custom ADO URL
#   .\setup-option-c.ps1 -RepoPath "D:\my\custom\path"            # Custom clone path
#   .\setup-option-c.ps1 -AdoOrg "protectivetfsprod"              # Custom ADO org for MCP

param(
    [string]$RepoPath = "$env:USERPROFILE\projects\voyager-copilot-plugin",
    [string]$AdoUrl = "",
    [string]$AdoOrg = ""
)

# If no ADO URL provided, prompt for it
if (-not $AdoUrl) {
    Write-Host "Enter the ADO clone URL for the voyager-copilot-plugin repo:" -ForegroundColor Yellow
    Write-Host "  Example: https://dev.azure.com/SSAAIAccelerator/VoyagerCopilot/_git/voyager-copilot-plugin" -ForegroundColor Gray
    $AdoUrl = Read-Host "ADO URL"
    if (-not $AdoUrl) {
        Write-Host "ERROR: ADO URL is required." -ForegroundColor Red
        exit 1
    }
}

# If no ADO org provided, try to extract from URL
if (-not $AdoOrg) {
    if ($AdoUrl -match "dev\.azure\.com/([^/]+)/") {
        $AdoOrg = $Matches[1]
        Write-Host "Detected ADO org: $AdoOrg" -ForegroundColor Gray
    } else {
        Write-Host "Enter your ADO organization name (e.g., SSAAIAccelerator, protectivetfsprod):" -ForegroundColor Yellow
        $AdoOrg = Read-Host "ADO Org"
    }
}

# Clone if not already present
if (-not (Test-Path $RepoPath)) {
    Write-Host "Cloning voyager-copilot-plugin to $RepoPath..." -ForegroundColor Yellow
    git clone $AdoUrl $RepoPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Clone failed. Check your ADO access and VPN." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Repo already exists at $RepoPath - pulling latest..." -ForegroundColor Yellow
    git -C $RepoPath pull
}

# Show the developer what to add to VS Code settings
$pluginPath = "$RepoPath\plugins\voyager" -replace '\\', '\\\\'
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Step 1: Add the plugin to VS Code" -ForegroundColor Green
Write-Host "(Ctrl+Shift+P -> 'Preferences: Open User Settings (JSON)')" -ForegroundColor Yellow
Write-Host ""
Write-Host "  `"chat.plugins.enabled`": true," -ForegroundColor Cyan
Write-Host "  `"chat.plugins.paths`": {" -ForegroundColor Cyan
Write-Host "      `"$pluginPath`": true" -ForegroundColor Cyan
Write-Host "  }" -ForegroundColor Cyan
Write-Host ""
Write-Host "Step 2: Add the ADO MCP server (optional, enables 'work on task #NNN')" -ForegroundColor Green
Write-Host "(Ctrl+Shift+P -> 'MCP: Open User Configuration')" -ForegroundColor Yellow
Write-Host "Add this inside the 'servers' object:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  `"ado`": {" -ForegroundColor Cyan
Write-Host "      `"type`": `"stdio`"," -ForegroundColor Cyan
Write-Host "      `"command`": `"npx`"," -ForegroundColor Cyan
Write-Host "      `"args`": [`"-y`", `"@azure-devops/mcp`", `"$AdoOrg`", `"-d`", `"core`", `"work`", `"work-items`"]" -ForegroundColor Cyan
Write-Host "  }" -ForegroundColor Cyan
Write-Host ""
Write-Host "Step 3: Reload VS Code" -ForegroundColor Green
Write-Host "  Ctrl+Shift+P -> 'Developer: Reload Window'" -ForegroundColor Yellow
Write-Host ""
Write-Host "Step 4: Verify" -ForegroundColor Green
Write-Host "  Type /skills in Copilot Chat - you should see 8 voyager skills" -ForegroundColor Yellow
