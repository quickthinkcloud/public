# URL
# START http://boxstarter.org/package/url?https://dl.dropboxusercontent.com/u/16074172/Automation/Boxstarter/Base_SQL2014SP1STD.ps1

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

#Create SQL Server folders (assumes the drives are there)
$path = "F:\Data" 
md $path -Force
$path = "G:\Logs" 
md $path -Force
#$path = "H:\Backups" 
#md $path -Force

# Download SQL Server 2014 Standard Edition
Write-Host "Download SQL Server 2014 Standard Edition"
if (Test-Path C:\Repository\SW_DVD9_SQL_Svr_Standard_Edtn_2014w_SP1_64Bit_English_-2_MLF_X20-29010.ISO)
    { 
    Write-Host "Folder exists already"
    } 
    else 
    {
    $url = "https://s3-eu-west-1.amazonaws.com/softwarerepoqtc/Agresso/SW_DVD9_SQL_Svr_Standard_Edtn_2014w_SP1_64Bit_English_-2_MLF_X20-29010.ISO"
    $output = "C:\Repository\SW_DVD9_SQL_Svr_Standard_Edtn_2014w_SP1_64Bit_English_-2_MLF_X20-29010.ISO"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output) 
    }

# Mount ISO to Z:\
Write-Host "Mounting ISO"
$ImagePath = 'c:\Repository\SW_DVD9_SQL_Svr_Standard_Edtn_2014w_SP1_64Bit_English_-2_MLF_X20-29010.ISO'
$Volume = Mount-DiskImage -ImagePath $ImagePath -NoDriveLetter -PassThru | 
Get-Volume;
$Filter = "DeviceID = '$($Volume.Path.Replace('\','\\'))'"
Get-WmiObject -Class Win32_Volume -Filter $Filter |% { $_.DriveLetter = 'Z:'; 
$_.Put() }

# Install SQL Server Standard Configuration
Write-Host "Downloading Standard Config File"
if (Test-Path C:\Repository\ConfigurationFile.ini)
    { 
    Write-Host "Folder exists already"
    } 
    else 
    {
    $url = "https://s3-eu-west-1.amazonaws.com/softwarerepoqtc/Agresso/SQL_2014_Install_No_Backup_Drive.txt"
    $output = "C:\Repository\ConfigurationFile.ini"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output) 
    }
Write-Host "Installing SQL Server with QTC Defaults"
start-process Z:\Setup.exe /ConfigurationFile=C:\Repository\ConfigurationFile.ini -wait

if (Test-PendingReboot) { Invoke-Reboot }

# Configure SQL Server
Import-Module sqlps
Invoke-Sqlcmd -QueryTimeout 3600 -Query "
EXEC sp_configure 'backup compression default', 0 ;
GO
RECONFIGURE WITH OVERRIDE ;
GO
sp_configure 'show advanced options', 1;
GO
reconfigure;
GO
sp_configure 'cost threshold for parallelism', 50;
GO
reconfigure;
GO"


##### Base_Server Footer #####
# Set Regional Settings
# Set Regional Settings and Apply to New User Accounts
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