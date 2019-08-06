# URL
# START http://boxstarter.org/package/url?https://dl.dropboxusercontent.com/u/16074172/Automation/Boxstarter/Base_Office2010.ps1

##### Base_Server Header #####
# Boxstarter options
$Boxstarter.RebootOk=$true # Allow reboots?
$Boxstarter.NoPassword=$false # Is this a machine with no login password?
$Boxstarter.AutoLogin=$true # Save my password securely and auto-login after a reboot

# Basic setup
Update-ExecutionPolicy Unrestricted
Set-ExplorerOptions -showHidenFilesFoldersDrives -showFileExtensions
Enable-RemoteDesktop
Disable-InternetExplorerESC
Disable-UAC
Enable-MicrosoftUpdate

#Essential Software
cinst 7zip.install
  
# Install DotNet3.5
cinst DotNet3.5
if (Test-PendingReboot) { Invoke-Reboot }

# Update Windows and reboot if necessary
Install-WindowsUpdate -AcceptEula
if (Test-PendingReboot) { Invoke-Reboot }

#Basic Software
cinst adobereader
cinst treesizefree
cinst notepadplusplus

if (Test-PendingReboot) { Invoke-Reboot }

$path = "C:\Repository"
md $path -Force
##### END Base_Server Header #####

#Set Ciphers to QTC Best Practice
Write-Host "Downloading Nartac"

if (Test-Path C:\Repository\IISCryptoCli40.exe)
    { 
    Write-Host "File exists already"
    } 
    else 
    {
    $url = "https://www.nartac.com/Downloads/IISCrypto/IISCryptoCli40.exe"
    $output = "C:\Repository\IISCryptoCli40.exe"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output) 
    }
C:\Repository\IISCryptoCli40.exe /template best

# Download Office Installer 2010
Write-Host "Downloading Office 2010 Media"
if (Test-Path C:\Repository\Office_2010_SP1.zip)
    { 
    Write-Host "Folder exists already"
    } 
    else 
    {
    $url = "https://s3-eu-west-1.amazonaws.com/softwarerepoqtc/Agresso/Office_2010_SP1.zip"
    $output = "C:\Repository\Office_2010_SP1.zip"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output) 
    }
Write-Host "Extracting Office Media"
if (Test-Path C:\Repository\Office_2010_SP1)
    { 
    Write-Host "Folder exists already"
    } 
    else 
    {
	$path = "C:\Repository\Office_2010_SP1"
	md $path -Force
    & "C:\Program Files\7-Zip\7z.exe" x "C:\Repository\Office_2010_SP1.zip" -o"C:\Repository\Office_2010_SP1"
    }

#Install Office 2010
Write-Host "Installing Office 2010"
if (Test-Path "C:\Program Files (x86)\Microsoft Office")
    { 
    Write-Host "Office Already Installed"
    } 
    else 
    {
    start-process "C:\Repository\Office_2010_SP1\setup.exe" -wait
    }



##### Base_Server Footer #####
# Set Regional Settings
#"Set Regional Settings and Apply to New User Accounts"
& control intl.cpl

# Clean up Boxstarter autologin
# Note: keep this last in the script
Write-Host "Tidying Up"
$winLogonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Remove-ItemProperty -Path $winLogonKey -Name "DefaultUserName" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $winLogonKey -Name "DefaultDomainName" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $winLogonKey -Name "DefaultPassword" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $winLogonKey -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
##### END Base_Server Footer #####