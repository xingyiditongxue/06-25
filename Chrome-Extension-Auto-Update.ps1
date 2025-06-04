# Scheduled Task Script for Chrome Extension Auto-Update
# This script checks for updates via WebDAV and handles the update process

param(
    [string]$WebDAVUrl = "https://your-webdav-server.com/extension/",
    [string]$LocalExtensionPath = "$env:LOCALAPPDATA\OxapocketExtension",
    [string]$TempPath = "$env:TEMP\OxapocketUpdate",
    [switch]$ForceUpdate = $false,
    [switch]$StartChrome = $false,
    [switch]$Silent = $true
)

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor White }
    }
    
    # Write to log file
    $logFile = "$env:LOCALAPPDATA\OxapocketExtension\update.log"
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

function Get-ExtensionVersion {
    param([string]$Path)
    try {
        if (Test-Path "$Path\manifest.json") {
            $manifest = Get-Content "$Path\manifest.json" | ConvertFrom-Json
            return $manifest.version
        }
    } catch {
        Write-Log "Error reading version from $Path`: $_" "ERROR"
    }
    return $null
}

function Test-ChromeRunning {
    $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    return ($chromeProcesses.Count -gt 0)
}

function Show-UserNotification {
    param([string]$Message, [string]$Title = "Oxapocket Extension")
    
    if (-not $Silent) {
        # Try to show a Windows notification
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $notification = New-Object System.Windows.Forms.NotifyIcon
            $notification.Icon = [System.Drawing.SystemIcons]::Information
            $notification.BalloonTipTitle = $Title
            $notification.BalloonTipText = $Message
            $notification.Visible = $true
            $notification.ShowBalloonTip(5000)
            
            # Clean up after 6 seconds
            Start-Sleep -Seconds 6
            $notification.Visible = $false
            $notification.Dispose()
        } catch {
            Write-Log "Could not show notification: $_" "WARN"
        }
    }
}

Write-Log "🚀 Starting Oxapocket Extension Auto-Update Check" "INFO"
Write-Log "WebDAV URL: $WebDAVUrl"
Write-Log "Local Path: $LocalExtensionPath"

try {
    # Create directories if they don't exist
    if (-not (Test-Path $LocalExtensionPath)) {
        New-Item -ItemType Directory -Path $LocalExtensionPath -Force | Out-Null
        Write-Log "Created local extension directory: $LocalExtensionPath" "INFO"
    }
    
    if (-not (Test-Path $TempPath)) {
        New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
    }

    # Step 1: Check for updates via WebDAV
    Write-Log "🔍 Checking for updates..." "INFO"
    
    # Download version info or latest manifest
    $remoteManifestUrl = "$WebDAVUrl/manifest.json"
    $tempManifestPath = "$TempPath\manifest.json"
    
    try {
        # Create WebDAV credentials if needed
        # $credentials = New-Object System.Management.Automation.PSCredential("username", (ConvertTo-SecureString "password" -AsPlainText -Force))
        
        # Download manifest to check version
        Invoke-WebRequest -Uri $remoteManifestUrl -OutFile $tempManifestPath -UseBasicParsing
        Write-Log "✅ Downloaded remote manifest" "SUCCESS"
    } catch {
        Write-Log "❌ Failed to download manifest from WebDAV: $_" "ERROR"
        exit 1
    }
    
    # Compare versions
    $currentVersion = Get-ExtensionVersion -Path $LocalExtensionPath
    $remoteVersion = Get-ExtensionVersion -Path $TempPath
    
    Write-Log "Current version: $currentVersion" "INFO"
    Write-Log "Remote version: $remoteVersion" "INFO"
    
    $needsUpdate = $false
    
    if ($ForceUpdate) {
        $needsUpdate = $true
        Write-Log "🔧 Force update requested" "INFO"
    } elseif (-not $currentVersion) {
        $needsUpdate = $true
        Write-Log "📦 No local installation found, will install" "INFO"
    } elseif ($remoteVersion -and ($remoteVersion -ne $currentVersion)) {
        $needsUpdate = $true
        Write-Log "🆙 New version available: $currentVersion → $remoteVersion" "INFO"
    } else {
        Write-Log "✅ Extension is up to date" "SUCCESS"
    }
    
    if (-not $needsUpdate) {
        Write-Log "No update needed, exiting" "INFO"
        exit 0
    }
    
    # Step 2: Download the complete extension
    Write-Log "📥 Downloading extension update..." "INFO"
    
    # Download extension ZIP or individual files
    $extensionZipUrl = "$WebDAVUrl/extension.zip"  # Adjust based on your WebDAV structure
    $tempZipPath = "$TempPath\extension.zip"
    
    try {
        Invoke-WebRequest -Uri $extensionZipUrl -OutFile $tempZipPath -UseBasicParsing
        Write-Log "✅ Downloaded extension package" "SUCCESS"
        
        # Extract to temp directory
        $extractPath = "$TempPath\extracted"
        if (Test-Path $extractPath) {
            Remove-Item $extractPath -Recurse -Force
        }
        Expand-Archive -Path $tempZipPath -DestinationPath $extractPath -Force
        Write-Log "✅ Extracted extension files" "SUCCESS"
        
    } catch {
        Write-Log "❌ Failed to download/extract extension: $_" "ERROR"
        exit 1
    }
    
    # Step 3: Check if Chrome is running
    $chromeRunning = Test-ChromeRunning
    if ($chromeRunning) {
        Write-Log "⚠️ Chrome is currently running" "WARN"
        
        if (-not $Silent) {
            Show-UserNotification "Extension update available. Please restart Chrome to apply the update."
        }
        
        # Option: Ask user to close Chrome
        if (-not $Silent) {
            $response = Read-Host "Chrome is running. Close it to apply update? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Write-Log "🔄 Attempting to close Chrome..." "INFO"
                Get-Process -Name "chrome" | Stop-Process -Force
                Start-Sleep -Seconds 3
            }
        }
    }
    
    # Step 4: Install the update
    Write-Log "📦 Installing extension update..." "INFO"
    
    # Backup current installation
    if (Test-Path $LocalExtensionPath) {
        $backupPath = "$LocalExtensionPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -Path $LocalExtensionPath -Destination $backupPath -Recurse -Force
        Write-Log "💾 Created backup at: $backupPath" "INFO"
    }
    
    # Install new version
    try {
        # Remove old installation
        if (Test-Path $LocalExtensionPath) {
            Remove-Item "$LocalExtensionPath\*" -Recurse -Force
        }
        
        # Copy new files
        Copy-Item -Path "$extractPath\*" -Destination $LocalExtensionPath -Recurse -Force
        Write-Log "✅ Extension updated successfully!" "SUCCESS"
        
        # Verify installation
        $newVersion = Get-ExtensionVersion -Path $LocalExtensionPath
        Write-Log "✅ Installed version: $newVersion" "SUCCESS"
        
    } catch {
        Write-Log "❌ Failed to install update: $_" "ERROR"
        
        # Restore backup if available
        $latestBackup = Get-ChildItem -Path (Split-Path $LocalExtensionPath) -Filter "*.backup.*" | 
                       Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($latestBackup) {
            Copy-Item -Path $latestBackup.FullName -Destination $LocalExtensionPath -Recurse -Force
            Write-Log "🔄 Restored from backup: $($latestBackup.Name)" "INFO"
        }
        
        exit 1
    }
    
    # Step 5: Handle Chrome restart (optional)
    if ($StartChrome -and -not $chromeRunning) {
        Write-Log "🌐 Starting Chrome with updated extension..." "INFO"
        
        # Find Chrome installation
        $chromePaths = @(
            "C:\Program Files\Google\Chrome\Application\chrome.exe",
            "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
        
        $chromePath = $null
        foreach ($path in $chromePaths) {
            if (Test-Path $path) {
                $chromePath = $path
                break
            }
        }
        
        if ($chromePath) {
            # Start Chrome with extension loaded
            $chromeArgs = @(
                "--load-extension=`"$LocalExtensionPath`"",
                "--no-first-run",
                "--no-default-browser-check"
            )
            
            Start-Process -FilePath $chromePath -ArgumentList $chromeArgs
            Write-Log "✅ Chrome started with updated extension" "SUCCESS"
        } else {
            Write-Log "❌ Chrome not found" "ERROR"
        }
    }
    
    # Step 6: User notification
    if (-not $Silent) {
        if ($chromeRunning) {
            Show-UserNotification "Extension updated! Please restart Chrome to use the new version."
        } else {
            Show-UserNotification "Extension updated successfully!"
        }
    }
    
    Write-Log "🎉 Update process completed successfully!" "SUCCESS"
    
} catch {
    Write-Log "❌ Unexpected error: $_" "ERROR"
    exit 1
} finally {
    # Cleanup temp files
    if (Test-Path $TempPath) {
        Remove-Item $TempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Log "📋 Update Summary:" "INFO"
Write-Log "  - Extension Path: $LocalExtensionPath" "INFO"
Write-Log "  - Chrome Running: $(if (Test-ChromeRunning) { 'Yes' } else { 'No' })" "INFO"
Write-Log "  - Version: $(Get-ExtensionVersion -Path $LocalExtensionPath)" "INFO"
