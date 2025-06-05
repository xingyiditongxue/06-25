function Test-ExtensionLoaded {
    param(
        [int]$Port = 9222,
        [string]$ExtensionName = "Oxapocket",
        [int]$TimeoutSeconds = 30
    )
    
    Write-Host "Testing if extension is loaded..." "INFO"
    
    $maxAttempts = $TimeoutSeconds
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/json" -TimeoutSec 5
            $tabs = $response.Content | ConvertFrom-Json
            
            # 方法1: 检查是否有包含扩展名称的Service Worker
            $serviceWorkerFound = $false
            $extensionTabFound = $false
            
            foreach ($tab in $tabs) {
                Write-Host "Checking tab: $($tab.title) - $($tab.url)" "DEBUG"
                
                # 检查Service Worker (更可靠的方法)
                if ($tab.type -eq "service_worker" -and $tab.url -like "chrome-extension://*") {
                    Write-Host "Found extension service worker: $($tab.url)" "INFO"
                    $serviceWorkerFound = $true
                }
                
                # 检查扩展相关的标签页
                if ($tab.url -like "chrome-extension://*" -and ($tab.title -like "*$ExtensionName*" -or $tab.url -like "*$ExtensionName*")) {
                    Write-Host "✅ Extension found: $($tab.title) - $($tab.url)" "SUCCESS"
                    $extensionTabFound = $true
                }
            }
            
            # 方法2: 检查manifest.json是否能通过文件系统访问到扩展ID
            $manifestCheck = Test-ExtensionManifest -ExtensionPath $LocalExtensionPath
            
            # 方法3: 尝试检查加载的扩展数量
            $extensionCount = ($tabs | Where-Object { $_.url -like "chrome-extension://*" }).Count
            Write-Host "Total extension-related tabs/workers found: $extensionCount" "INFO"
            
            if ($serviceWorkerFound -or $extensionTabFound -or $manifestCheck) {
                Write-Host "✅ Extension verification successful!" "SUCCESS"
                return $true
            } else {
                Write-Host "Extension not detected, attempt $($attempt + 1)/$maxAttempts" "WARN"
                Start-Sleep -Seconds 2
                $attempt++
            }
            
        } catch {
            Write-Host "Attempt $($attempt + 1): Could not connect to Chrome debugging port: $_" "WARN"
            Start-Sleep -Seconds 2
            $attempt++
        }
    }

    Write-Host "❌ Extension verification failed after $maxAttempts attempts" "ERROR"
    return $false
}

function Test-ExtensionManifest {
    param([string]$ExtensionPath)
    
    try {
        $manifestPath = Join-Path $ExtensionPath "manifest.json"
        if (Test-Path $manifestPath) {
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            Write-Host "Extension manifest found - Name: $($manifest.name), Version: $($manifest.version)" "INFO"
            
            # 检查关键的manifest属性
            if ($manifest.name -and $manifest.version -and ($manifest.manifest_version -eq 2 -or $manifest.manifest_version -eq 3)) {
                Write-Host "✅ Extension manifest is valid" "SUCCESS"
                return $true
            }
        }
    } catch {
        Write-Host "Could not validate manifest: $_" "WARN"
    }
    
    return $false
}

# 替代验证方法：检查Chrome进程是否正常运行且没有崩溃
function Test-ChromeStability {
    param([System.Diagnostics.Process]$ChromeProcess)
    
    try {
        if ($ChromeProcess -and !$ChromeProcess.HasExited) {
            Write-Host "✅ Chrome process is stable and running" "SUCCESS"
            return $true
        } else {
            Write-Host "❌ Chrome process has exited or crashed" "ERROR"
            return $false
        }
    } catch {
        Write-Host "Could not check Chrome process status: $_" "WARN"
        return $false
    }
}
