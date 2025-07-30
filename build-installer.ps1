# ===============================
# Hire HQ Connector Build Script
# ===============================

# CONFIGURATION
$installerScript = "HireHQConnectorForSyrinx.iss"
$outputDir = "Output"
$innoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"  # Update path if needed

# DOWNLOAD LATEST INSTALLERS
Write-Host "`nDownloading latest installers..." -ForegroundColor Cyan

$gcloudUrl = "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe"
$tailscaleUrl = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe"

Invoke-WebRequest -Uri $gcloudUrl -OutFile "GoogleCloudSDKInstaller.exe" -UseBasicParsing
Invoke-WebRequest -Uri $tailscaleUrl -OutFile "tailscale-setup-latest.exe" -UseBasicParsing

# REQUIRED FILES
$requiredFiles = @(
    "GoogleCloudSDKInstaller.exe",
    "tailscale-setup-latest.exe",
    "HireHQTrayApp.exe",
    $installerScript
)

Write-Host "`nChecking files..." -ForegroundColor Cyan
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "Missing: $file" -ForegroundColor Red
        exit 1
    }
}
Write-Host "All files present.`n" -ForegroundColor Green

# RUN INNO SETUP COMPILER
Write-Host "Building installer..." -ForegroundColor Cyan
& "$innoPath" $installerScript

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild successful!" -ForegroundColor Green
    Write-Host "Output: $outputDir\\HireHQConnectorForSyrinxSetup.exe`n"
} else {
    Write-Host "`nBuild failed. Check script for errors." -ForegroundColor Red
}
