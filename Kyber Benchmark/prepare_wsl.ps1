# Requires: Windows PowerShell running as Administrator

Write-Host "=== WSL + Ubuntu preparation (Windows only) ==="

# Ensure Admin
$currUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
  Write-Error "Run this in an elevated PowerShell (Right-click → Run as Administrator)."
  exit 1
}

# 1) Enable WSL features (no auto-restart)
Write-Host "`n[1/4] Enabling Windows features for WSL2..."
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null

# 2) Set WSL2 as default
Write-Host "[2/4] Setting WSL default version to 2..."
wsl --set-default-version 2 | Out-Null

# 3) Install Ubuntu if missing
Write-Host "[3/4] Checking for Ubuntu..."
$distros = (wsl -l -q) 2>$null
$hasUbuntu = $distros -contains "Ubuntu"

if (-not $hasUbuntu) {
  Write-Host "Ubuntu not found. Installing..."
  wsl --install -d Ubuntu
  Write-Host "`nIf prompted to reboot, do so. Then open the 'Ubuntu' app once to create your UNIX username/password, and re-run this script to verify."
  exit 0
} else {
  Write-Host "Ubuntu already installed."
}

# 4) Verify Ubuntu initialized (user created)
Write-Host "[4/4] Verifying Ubuntu initialization..."
$probe = & wsl -d Ubuntu -- bash -lc "echo READY" 2>$null
if ($probe -notmatch "READY") {
  Write-Host "Ubuntu is installed but not initialized."
  Write-Host "Open the 'Ubuntu' app once to create your UNIX user, then run this script again."
  exit 0
}

Write-Host "`n✅ Windows prep complete. You can now open Ubuntu and run your Linux steps."
Write-Host "Tip: Start Ubuntu via Start menu or:  wsl -d Ubuntu"