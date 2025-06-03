# Script d'installation d'extension Chrome
# À distribuer avec votre fichier .crx

param(
    [string]$CrxFile = $null
)

Write-Host "🚀 Installation d'extension Chrome" -ForegroundColor Blue
Write-Host "=================================" -ForegroundColor Blue

# Auto-détecter le fichier .crx dans le dossier courant
if (-not $CrxFile) {
    $crxFiles = Get-ChildItem -Path "." -Filter "*.crx"
    
    if ($crxFiles.Count -eq 0) {
        Write-Error "❌ Aucun fichier .crx trouvé dans le dossier courant"
        Write-Host "💡 Placez le fichier .crx dans le même dossier que ce script"
        exit 1
    } elseif ($crxFiles.Count -eq 1) {
        $CrxFile = $crxFiles[0].FullName
        Write-Host "📦 Fichier détecté : $($crxFiles[0].Name)" -ForegroundColor Green
    } else {
        Write-Host "📦 Plusieurs fichiers .crx trouvés :" -ForegroundColor Yellow
        for ($i = 0; $i -lt $crxFiles.Count; $i++) {
            Write-Host "  [$i] $($crxFiles[$i].Name)"
        }
        $choice = Read-Host "Choisissez le numéro du fichier à installer"
        $CrxFile = $crxFiles[$choice].FullName
    }
}

# Vérifier que le fichier existe
if (-not (Test-Path $CrxFile)) {
    Write-Error "❌ Fichier .crx introuvable : $CrxFile"
    exit 1
}

# Méthode 1: Installation via dossier temporaire (plus simple)
Write-Host "`n🔧 Méthode d'installation simple..." -ForegroundColor Cyan

# Créer un dossier temporaire
$tempDir = Join-Path $env:TEMP "ChromeExtension_$(Get-Random)"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

try {
    # Extraire le .crx dans le dossier temporaire
    Expand-Archive -Path $CrxFile -DestinationPath $tempDir -Force
    
    Write-Host "✅ Extension extraite dans : $tempDir" -ForegroundColor Green
    
    # Ouvrir Chrome avec l'extension
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
        Write-Host "🌐 Ouverture de Chrome avec l'extension..." -ForegroundColor Yellow
        
        # Ouvrir Chrome avec l'extension en mode développeur
        Start-Process -FilePath $chromePath -ArgumentList "--load-extension=`"$tempDir`"", "--new-window"
        
        Write-Host "`n✅ Installation terminée !" -ForegroundColor Green
        Write-Host "📋 Instructions manuelles complémentaires :" -ForegroundColor Magenta
        Write-Host "1. Dans Chrome, allez à chrome://extensions/"
        Write-Host "2. Activez le 'Mode développeur' (coin supérieur droit)"
        Write-Host "3. Votre extension devrait être visible et active"
        Write-Host "4. Pour une installation permanente, cliquez sur 'Épingler' dans la barre d'outils"
        
        Write-Host "`n⚠️  Note : L'extension sera dans le dossier temporaire :" -ForegroundColor Yellow
        Write-Host "   $tempDir"
        Write-Host "   Ne supprimez pas ce dossier si vous voulez garder l'extension"
        
    } else {
        Write-Error "❌ Chrome non trouvé. Installez Google Chrome d'abord."
    }
    
} catch {
    Write-Error "❌ Erreur lors de l'extraction : $_"
    
    # Nettoyer en cas d'erreur
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n🔄 Redémarrez Chrome pour finaliser l'installation" -ForegroundColor Blue
