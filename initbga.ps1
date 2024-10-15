# Check the existence of the source directory
function CheckSourceDirectory {
	param (
		[string]$sourcePath
	)

	# Test if source directory exists, if not create it
	if (!(Test-Path $sourcePath)) {
		New-Item -ItemType Directory -Path $sourcePath -Force | Out-Null
	}
}

# Function to download and unpack the necessary dependencies
function DownloadAndUnpackDependencies {
	param (
		[string]$sourcePath
	)
	
	Write-Output "Downloading dependency Microsoft.VCLibs.x64.14.00.Desktop.appx..."
 	wget.exe "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -O "$sourcePath\Microsoft.VCLibs.x64.14.00.Desktop.appx" --show-progress
	
	Write-Output "Downloading dependency microsoft.ui.xaml.2.8.6.nupkg..."
	wget.exe "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6" -O "$sourcePath\microsoft.ui.xaml.2.8.6.nupkg" --show-progress

	# Rename the .nupkg to .zip
 	Move-Item "$sourcePath\microsoft.ui.xaml.2.8.6.nupkg" "$sourcePath\microsoft.ui.xaml.2.8.6.zip"

	# Expand the .nupkg file
	Expand-Archive "$sourcePath\microsoft.ui.xaml.2.8.6.zip" -DestinationPath "$sourcePath\microsoft.ui.xaml.2.8.6"
	
	# Move .appx to source directory and cleanup
	Write-Output "Cleanup source folder..."
	Move-Item "$sourcePath\microsoft.ui.xaml.2.8.6\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx" "$sourcePath\Microsoft.UI.Xaml.2.8.appx"
	Remove-Item -Force -Recurse "$sourcePath\microsoft.ui.xaml.2.8.6"
}

# Function to install dependencies
function InstallDependency {
	param (
		[string]$sourcePath
	)

	$name = Split-Path $sourcePath -Leaf
	Write-Output "Installing $name dependency..."
	Add-AppxPackage -Path $sourcePath
}

# Function to download and install the provided packages from GitHub
function DownloadAndInstall {
	param (
		[string]$uri,
		[switch]$provisioned = $false
	)

	# Make the REST request to get release info
	try {
		$object = Invoke-RestMethod -Uri $uri
	} catch {
		Write-Error "Failed to retrieve release data from $uri"
		return
	}

	Write-Output "Downloading latest $($object.name) bundle..."

	# Find the download source and filename for the msixbundle
	$downloadSource = $object.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1 -ExpandProperty browser_download_url
	$downloadFilename = $object.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1 -ExpandProperty name

	if (-not $downloadSource) {
		Write-Error "No .msixbundle found in the release assets for $($object.name)"
		return
	}

	# Download the file
	$destinationPath = "$PSScriptRoot\sources\$downloadFilename"
	wget.exe $downloadSource -O $destinationPath --show-progress

	Write-Output "Installing $($object.name) bundle..."

	# Check if it should be installed as provisioned (system-wide) or just added
	if ($provisioned) {
		# Optional: Download the license file if applicable
		$downloadSourceLic = $object.assets | Where-Object { $_.name -like "*.xml" } | Select-Object -First 1 -ExpandProperty browser_download_url
		$downloadFilenameLic = $object.assets | Where-Object { $_.name -like "*.xml" } | Select-Object -First 1 -ExpandProperty name

		if ($downloadSourceLic) {
			wget.exe $downloadSourceLic -O "${PSScriptRoot}\sources\$downloadFilenameLic" --show-progress
		}

		Add-AppxProvisionedPackage -Online -PackagePath $destinationPath -LicensePath "${PSScriptRoot}\sources\$downloadFilenameLic"
	} else {
		Add-AppxPackage -Path $destinationPath
	}
}

# Function to install packages using winget
function WinGetInstall {
	param (
		[string]$id
	)
	Write-Output "Installing $id with winget..."
	winget install --id $id --silent --accept-source-agreements --accept-package-agreements
}

# Get and add wget
Write-Output "Downloading and adding wget"
Invoke-WebRequest -UseBasicParsing -Uri "https://eternallybored.org/misc/wget/1.21.4/64/wget.exe" -OutFile "C:\Windows\System32\wget.exe"

# Disable ProgressBars for faster loading times
$ProgressPreference = 'SilentlyContinue'

# Local package paths
$sourcePath = "${PSScriptRoot}\sources"
CheckSourceDirectory -sourcePath $sourcePath
DownloadAndUnpackDependencies -sourcePath $sourcePath
$xamlPackage = "$sourcePath\Microsoft.UI.Xaml.2.8.appx"
$uwpPackage = "$sourcePath\Microsoft.VCLibs.x64.14.00.Desktop.appx"

# GitHub API URIs for bundles
$bundleUri = @('https://api.github.com/repos/microsoft/winget-cli/releases/latest')

# Winget software IDs to install
$winGetInstallSoftware = @('Notepad++.Notepad++', '7zip.7zip', 'Microsoft.MouseWithoutBorders')

# Install local packages
Write-Output "Installing XAML Package..."
InstallDependency -sourcePath $xamlPackage

Write-Output "Installing UWP Package..."
InstallDependency -sourcePath $uwpPackage

# Download and install bundles
foreach ($uri in $bundleUri) {
	# Check if the current URI is for winget-cli, and use provisioned installation
	if ($uri -like '*winget-cli*') {
		DownloadAndInstall -uri $uri -provisioned
	} else {
		DownloadAndInstall -uri $uri
	}
}

WinGetInstall "cmdlettest"

foreach ($id in $winGetInstallSoftware) {
		WinGetInstall $id
}

Remove-Item -Recurse -Force $sourcePath

# Re-enable ProgressBars
$ProgressPreference = 'Continue'
