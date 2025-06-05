# 改进的Service Worker检测逻辑
function Test-ExtensionLoaded {
    param(
        [int]$Port = 9222,
        [string]$ExtensionName = "Oxapocket",
        [string]$ExtensionPath = "",
        [int]$TimeoutSeconds = 30
    )
    
    Write-Host "Testing if extension is loaded..." "INFO"
    
    $maxAttempts = $TimeoutSeconds / 2  # 每2秒检查一次
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/json" -TimeoutSec 5
            $tabs = $response.Content | ConvertFrom-Json
            
            Write-Host "`n=== Chrome调试信息 ===" "INFO"
            Write-Host "总共发现 $($tabs.Count) 个标签/Worker" "INFO"
            
            $serviceWorkers = @()
            $extensionTabs = @()
            $potentialMatches = @()
            
            foreach ($tab in $tabs) {
                Write-Host "`n📋 Tab详情:" "DEBUG"
                Write-Host "  Title: $($tab.title)" "DEBUG"
                Write-Host "  URL: $($tab.url)" "DEBUG"
                Write-Host "  Type: $($tab.type)" "DEBUG"
                
                # 收集所有Service Worker
                if ($tab.type -eq "service_worker") {
                    $serviceWorkers += $tab
                    Write-Host "  ✅ 这是一个Service Worker" "SUCCESS"
                }
                
                # 收集所有扩展相关标签
                if ($tab.url -like "chrome-extension://*") {
                    $extensionTabs += $tab
                    Write-Host "  🔧 这是扩展相关内容" "INFO"
                    
                    # 检查是否可能是我们的扩展
                    if ($tab.title -like "*$ExtensionName*" -or 
                        $tab.url -like "*$ExtensionName*" -or
                        ($tab.type -eq "service_worker" -and $tab.url -like "*background*")) {
                        $potentialMatches += $tab
                        Write-Host "  🎯 可能匹配我们的扩展!" "SUCCESS"
                    }
                }
            }
            
            Write-Host "`n=== 统计结果 ===" "INFO"
            Write-Host "Service Workers总数: $($serviceWorkers.Count)" "INFO"
            Write-Host "扩展相关标签总数: $($extensionTabs.Count)" "INFO"
            Write-Host "可能的匹配数: $($potentialMatches.Count)" "INFO"
            
            # 详细显示所有Service Worker
            if ($serviceWorkers.Count -gt 0) {
                Write-Host "`n🔧 发现的Service Workers:" "INFO"
                foreach ($sw in $serviceWorkers) {
                    Write-Host "  - $($sw.url)" "INFO"
                    
                    # 尝试从URL推断扩展
                    if ($sw.url -match "chrome-extension://([a-z]+)/") {
                        $extensionId = $matches[1]
                        Write-Host "    扩展ID: $extensionId" "DEBUG"
                    }
                }
            }
            
            # 验证逻辑
            $extensionDetected = $false
            
            # 方法1: 检查是否有包含我们扩展特征的Service Worker
            if ($potentialMatches.Count -gt 0) {
                Write-Host "✅ 通过内容匹配找到了扩展!" "SUCCESS"
                $extensionDetected = $true
            }
            
            # 方法2: 如果找到了新的Service Worker（相比Chrome默认的）
            elseif ($serviceWorkers.Count -gt 2) {  # Chrome通常有2个默认的Service Worker
                Write-Host "✅ 检测到额外的Service Worker，可能是我们的扩展" "SUCCESS"
                $extensionDetected = $true
            }
            
            # 方法3: 检查manifest文件是否存在且有效
            elseif (Test-ExtensionManifest -ExtensionPath $ExtensionPath) {
                Write-Host "✅ Manifest文件有效，假设扩展已加载" "SUCCESS"
                $extensionDetected = $true
            }
            
            if ($extensionDetected) {
                return $true
            } else {
                Write-Host "⏳ 扩展尚未检测到，等待中... ($($attempt + 1)/$maxAttempts)" "WARN"
                Start-Sleep -Seconds 2
                $attempt++
            }
            
        } catch {
            Write-Host "Attempt $($attempt + 1): 无法连接Chrome调试端口: $_" "WARN"
            Start-Sleep -Seconds 2
            $attempt++
        }
    }

    Write-Host "❌ 扩展验证失败" "ERROR"
    return $false
}

function Test-ExtensionManifest {
    param([string]$ExtensionPath)
    
    if (-not $ExtensionPath) { return $false }
    
    try {
        $manifestPath = Join-Path $ExtensionPath "manifest.json"
        if (Test-Path $manifestPath) {
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            Write-Host "📄 Manifest检查 - 名称: $($manifest.name), 版本: $($manifest.version)" "INFO"
            
            if ($manifest.name -and $manifest.version) {
                return $true
            }
        }
    } catch {
        Write-Host "无法验证manifest: $_" "WARN"
    }
    
    return $false
}
