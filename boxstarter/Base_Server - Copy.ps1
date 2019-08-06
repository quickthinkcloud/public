# URL
# START http://boxstarter.org/package/url?https://bitbucket.org/quickthinkcloud/boxstarter/raw/1ca181317c095a26ece70f76a09d588300aa74bc/Base_Server.ps1

##### Base_Server Header #####
# Boxstarter options
$Boxstarter.RebootOk=$true # Allow reboots?
$Boxstarter.NoPassword=$false # Is this a machine with no login password?
$Boxstarter.AutoLogin=$true # Save my password securely and auto-login after a reboot

# Basic setup
Update-ExecutionPolicy Unrestricted
# Set-ExplorerOptions -showHidenFilesFoldersDrives -showFileExtensions #Chris found this line in Base_SQL2014SP1STD.ps1. It looks self-explanitory and useful but wants to discuss with David before adding/enabling it here.
# Enable-RemoteDesktop # Disabled because in the Interoute Template
# Disable-InternetExplorerESC # Disabled because in the Interoute Template
# Disable-UAC # Disabled because in the Interoute Template
# Enable-MicrosoftUpdate # Disabled because in the Interoute Template

# TO SCRIPT
# CENTRASTAGE INSTALL
# ERA AGENT
# ESET FILE SECURITY 6

#Essential Software
cinst 7zip.install
 
# Install DotNet3.5
cinst DotNet3.5
if (Test-PendingReboot) { Invoke-Reboot }

# Update Windows and reboot if necessary
# Install-WindowsUpdate -AcceptEula
# if (Test-PendingReboot) { Invoke-Reboot }

#Basic Software
cinst adobereader
cinst treesizefree
cinst notepadplusplus

if (Test-PendingReboot) { Invoke-Reboot }

$path = "C:\Repository"
md $path -Force
$path = "C:\QTCScripts"
md $path -Force
$path = "C:\QTCScripts\Scheduled"
md $path -Force
$path = "C:\QTCScripts\Triggered"
md $path -Force

#Set Ciphers to QTC Best Practice
Write-Host "Downloading Nartac"

if (Test-Path C:\Repository\IISCryptoCli.exe)
    { 
    Write-Host "File exists already"
    } 
    else 
    {
    $url = "https://s3-eu-west-1.amazonaws.com/softwarerepoqtc/Agresso/IISCryptoCli.exe"
    $output = "C:\Repository\IISCryptoCli.exe"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output) 
    }
C:\Repository\IISCryptoCli.exe /template best

##### END Base_Server Header #####


#
#


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