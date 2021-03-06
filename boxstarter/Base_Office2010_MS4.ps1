# URL
# START http://boxstarter.org/package/url?https://dl.dropboxusercontent.com/u/16074172/Automation/Boxstarter/Base_Office2010_MS4.ps1

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

#Download Agresso Media

Write-Host "Downloading Agresso MS4 Media"

if (Test-Path C:\Repository\ABW56M4U1-Basic.zip)
    { 
    Write-Host "Folder exists already"
    } 
    else 
    {
    $url = "https://s3-eu-west-1.amazonaws.com/softwarerepoqtc/Agresso/ABW56M4U1-Basic.zip"
    $output = "C:\Repository\ABW56M4U1-Basic.zip"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output) 
    }

if (Test-Path C:\Repository\ABW56M4U1-Basic)
    { 
    Write-Host "Folder exists already"
    } 
    else 
    {
    & "C:\Program Files\7-Zip\7z.exe" x "C:\Repository\ABW56M4U1-Basic.zip" -o"C:\Repository\"
    }

# Install Agresso
Write-Host "Installing Agresso"
dism.exe /Online /Enable-Feature /FeatureName:IIS-WebServerRole /FeatureName:IIS-WebServer /FeatureName:IIS-CommonHttpFeatures /FeatureName:IIS-StaticContent /FeatureName:IIS-DefaultDocument /FeatureName:IIS-DirectoryBrowsing /FeatureName:IIS-HttpErrors /FeatureName:IIS-ApplicationDevelopment /FeatureName:IIS-ASPNET45 /FeatureName:IIS-NetFxExtensibility45 /FeatureName:IIS-NetFxExtensibility45 /FeatureName:IIS-ISAPIExtensions /FeatureName:IIS-ISAPIFilter /FeatureName:IIS-HealthAndDiagnostics /FeatureName:IIS-HttpLogging /FeatureName:IIS-LoggingLibraries /FeatureName:IIS-RequestMonitor /FeatureName:IIS-HttpTracing /FeatureName:IIS-CustomLogging /FeatureName:IIS-Security /FeatureName:IIS-BasicAuthentication /FeatureName:IIS-WindowsAuthentication /FeatureName:IIS-RequestFiltering /FeatureName:IIS-Performance /FeatureName:IIS-HttpCompressionStatic /FeatureName:IIS-WebServerManagementTools /FeatureName:IIS-ManagementConsole /FeatureName:IIS-ManagementScriptingTools /FeatureName:IIS-HttpCompressionDynamic /FeatureName:IIS-Metabase /FeatureName:WAS-WindowsActivationService /FeatureName:WAS-ProcessModel /FeatureName:WAS-ConfigurationAPI /FeatureName:NetFx4Extended-ASPNET45 /FeatureName:WCF-HTTP-Activation45 /FeatureName:IIS-WebSockets /NoRestart
cinst urlrewrite
if (Test-Path "C:\Program Files (x86)\Agresso 5.7.1")
    { 
    Write-Host "Agresso Already Installed"
    } 
    else 
    {
    msiexec /qb /i "C:\Repository\ABW56M4U1-Basic\UNIT4 Agresso\UNIT4 Agresso (64-bit).msi" ADDLOCAL="images,styles,rootx64,agresso_web,agresso_web_classic,web_services,agressowshost,rootx86,agrmanagementtools,agrmanagementtoolsx64,server,alertservice,aspx_scripts,bin_web,centralconfig,chartfx,client,client_chm,client_client,client_server,devexpress,docarchivews,scripts,server_client,server_convert,server_dbupgrade,server_reports,server_serverqueue,server_services,serverx64,services,techguide,web_root"
    }
	
# Configure Agresso Folders

Write-Host "Configure Agresso Folders"

$path = "C:\UNIT4\Maintenance\Patches" 
md $path -Force
$path = "C:\UNIT4\Maintenance\UK Products" 
md $path -Force
$path = "C:\UNIT4\Maintenance\Licenses" 
md $path -Force
$path = "C:\UNIT4\Maintenance\Report Engine" 
md $path -Force
$path = "C:\UNIT4\Maintenance\Bespoke" 
md $path -Force
$path = "C:\UNIT4\Maintenance\Experience Packs" 
md $path -Force

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


#Configure URL Rewrite

Write-Host "Configuring URLRewrite"

if (Test-Path C:\inetpub\wwwroot\web.config)
    { 
    Write-Host "File exists already"
    } 
    else 
    {
    $url = "https://s3-eu-west-1.amazonaws.com/softwarerepoqtc/Agresso/web.config"
    $output = "C:\inetpub\wwwroot\web.config"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output) 
    }

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