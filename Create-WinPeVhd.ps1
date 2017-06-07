. $PSScriptRoot\PepsiUtilities.ps1



<# == 1. Create Environment ====================================================================  #>

# Create my environment for WADK utilities
$WADK = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit"
$env:WADK = $WADK
$winPE = "${WADK}\Windows Preinstallation Environment"
$winPepsi = "C:\WinPE_amd64\mount"
$winPepsiVhd = "${PSScriptRoot}\dist\WinPEpsi.vhdx"
$_winPepsiMicrosoftOnly = "${PSScriptRoot}\dist\boot-microsoft-only.wim"

$DEBUG = $False
if ($env:WinPepsiDebug) { 
  $DEBUG = $True 
}

# Create "official" environment for running WADK utilities
$env:WinPERoot = $winPE
$env:OSCDImgRoot = "${WADK}\Deployment Tools\AMD64\Oscdimg"


<# ====== 1.1. Clean Environment ===============================================================  #>

# Clean working folders
$_itemsToDelete = @(
  Get-AbsolutePath "$winPepsi\..",
  $_winPepsiMicrosoftOnly,
  $winPepsiVhd
)
$_itemsToDelete | % {
  Remove-Item $_ -Recurse -Force -confirm:$True
}








<# == 2. Create WinPEpsi image  ================================================================  #>

# Create working copy of WinPE from reference WinPE/amd64 image in WADK
& "$WinPE\copype" amd64 (Get-AbsolutePath "$winPepsi\..")

# Mount WinPE image for customization
$_winPepsiWim = Get-AbsolutePath "$winPepsi\..\media\sources\boot.wim"
Dism /Mount-Image /ImageFile:$_winPepsiWim /index:1 /MountDir:$winPepsi



<# ====== 2.1 Add optional Windows features ===================================================== #>

# Add optional components (Powershell etc.) to WinPE
$_components = "WMI", "NetFX", "Scripting", "PowerShell", "DismCmdlets", "StorageWMI"
$_components | % { 
    Dism /Add-Package /Image:$winPepsi /PackagePath:"$WinPE\amd64\WinPE_OCs\WinPE-${_}.cab" 
    Dism /Add-Package /Image:$winPepsi /PackagePath:"$WinPE\amd64\WinPE_OCs\en-us\WinPE-${_}_en-us.cab"
}


# Check resulting set of components in WinPE image
Dism /Get-Packages /Image:$winPepsi

<#
if (Test-Path $_winPepsiMicrosoftOnly) {
  Write-Host "$_winPepsiMicrosoftOnly exists: skipping new copy" -foreground yellow
} else {
  Write-Host "Copy intermediary image to $_winPepsiMicrosoftOnly" -foreground green
  Dism /Unmount-Image /MountDir:$winPepsi /commit
  Copy-Item $_winPepsiWim $_winPepsiMicrosoftOnly
  Dism /Mount-Image /ImageFile:$_winPepsiWim /index:1 /MountDir:$winPepsi
}
#>


<# ====== 2.2 Add 3rd party assets to WinPEpsi ================================================== #>

# Download some assets for injection to WinPE
$_remoteAssets = @{ 
  "7-zip" = '7z1604-x64.zip', '7-zip', 'http://www.7-zip.org/a/7z1604-x64.exe';
  "Double Commander" = 'doublecmd-0.7.8.x86_64-win64.zip', 'oneleveldown\..', 'https://freefr.dl.sourceforge.net/project/doublecmd/DC%20for%20Windows%2064%20bit/Double%20Commander%200.7.8%20beta/doublecmd-0.7.8.x86_64-win64.zip'; 
  "RapidEE" = 'RapidEEx64.zip', 'RapidEE', 'https://www.rapidee.com/download/archive/936/RapidEEx64.zip'; 
  "OEM Info Updater" = 'OEM_Info_Updater_8.0.zip', 'OEMinfoUpdater', 'http://oemsky.net/oeminfoupdater/OEM_Info_Updater_8.0.zip'
}
$_assetDestRoot = "$winPepsi\Tools"
$_filesToSkip = "Wallpapers.zip"
$_tmp_dir = "${PSScriptRoot}\RemoteAssetsCache"

$_remoteAssets.keys | % {
  $_currentAsset = Join-Path $_tmp_dir $_remoteAssets[$_].item(0)

  if( Test-Path $_currentAsset ) {
    Write-Host "$_currentAsset exists:  skipping new download" -foreground yellow
  } else {
    Invoke-WebRequest -Uri $_remoteAssets[$_].item(2) -Outfile $_currentAsset
  }

  $_destDir = Join-Path "${_assetDestRoot}" $_remoteAssets[$_].item(1)
  if($_currentAsset -match ".zip$") {
    $_params = 'x', $_currentAsset, '-aoa', "-xr!${_filesToSkip}", "-o${_destDir}"
    & 7z $_params
  } else {
    Move-Item -Path $_currentAsset -Destination $_destDir -Force
  }
}


# Copy local Windows files to WinPE image
$_localSources = @(
  "$env:WADK\Deployment Tools\amd64\DISM\imagex.exe"
)
$_localSources | % { 
  copy-item  $_  $_assetDestRoot\  -Recurse -Force
}


# Copy additional utilities to WinPE image
$_localAssets = "${PSScriptRoot}\LocalAssets\*"
Copy-Item $_localAssets -Destination $_assetDestRoot -Recurse -Force



# Place startup commands to %SystemRoot%\System32\Startnet.cmd
$_winPEstartScript = "${winPepsi}\Windows\System32\Startnet.cmd"
$_customStartup = "${PSScriptRoot}\startnet.cmd"
Copy-Item $_customStartup $_winPEstartScript -Force
#Get-Content $_customStartup | Set-Content -Path $_winPEstartScript -Encoding ASCII -Force



Copy-Item "${PSScriptRoot}\Unattend-PE.xml" -Destination $winPepsi


& $replaceWinPEwallpaper



# Unmount the WinPE image 
Dism /Unmount-Image /MountDir:$winPepsi /commit






<# == 3. Create VHDx disk with WinPEpsi ========================================================= #>

if (Test-Path $winPepsiVhd) {
  Remove-Item $winPepsiVhd -Force
}


# Initialize VHDx
$Partition = New-VHD -Path $winPepsiVhd -SizeBytes 3GB -Dynamic | Mount-VHD -Passthru | 
             Initialize-Disk -PartitionStyle MBR -Passthru | 
             New-Partition -AssignDriveLetter -UseMaximumSize 
$Drive = $Partition.DriveLetter.Tostring()
Format-Volume -DriveLetter $Drive -FileSystem FAT32 -NewFileSystemLabel "Win10 PE" -Confirm:$false -Force
Set-Partition -DriveLetter $Drive -IsActive $True


# Apply WinPE image to our VHDx and make it bootable
Dism /Apply-Image /ImageFile:$_winPepsiWim /Index:1 /ApplyDir:"${Drive}:\"
BCDboot "${Drive}:\Windows" /s "${Drive}:" /f ALL

Dismount-VHD -Path $winPepsiVhd

