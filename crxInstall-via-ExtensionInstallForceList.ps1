$extensionId = "ekegclanhfggoeglkgjifbbfhpjoccnn"
$crxPath = "file:///C:/Users/yidif/Oxyl-oxapocket/Oxapocket-pret-a-charger/latest/latest.crx"

$regPath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"

# Create key if missing
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Add extension to force-install list
Set-ItemProperty -Path $regPath -Name "1" -Value "$extensionId;$crxPath"

Write-Host "✅ Extension force-install rule applied." -ForegroundColor Green
