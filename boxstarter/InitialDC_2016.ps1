<# URL
# THIS:                                                      https://qtcloud.box.com/s/3cp9vgj8jowkbwfsap0gb5rwoq8l8thl                                                              
# BECOMES THIS:                                              https://qtcloud.box.com/shared/static/3cp9vgj8jowkbwfsap0gb5rwoq8l8thl.ps1
# SO START COMMAND:  START http://boxstarter.org/package/url?https://qtcloud.box.com/shared/static/3cp9vgj8jowkbwfsap0gb5rwoq8l8thl.ps1
inetcpl.cpl
$winLogonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Remove-ItemProperty -Path $winLogonKey -Name "AWSAccessKey" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $winLogonKey -Name "AWSSecretKey" -ErrorAction SilentlyContinue
New-ItemProperty -Path $winLogonKey -Name "AWSAccessKey" -Value "a" -ErrorAction SilentlyContinue 
New-ItemProperty -Path $winLogonKey -Name "AWSSecretKey" -Value "a/a" -ErrorAction SilentlyContinue 
# START http://boxstarter.org/package/url?https://raw.githubusercontent.com/quickthinkcloud/public/master/boxstarter/InitialDC_2016.ps1
START https://bit.ly/2TyggcW
#>

Start-Transcript c:\repository\bs_install.txt -Append
### FUNCTIONS ###
function Test-RegistryValue {
    # Syntax for this fucntion:
    # Test-RegistryValue -Path $winLogonKey -Value 'Valuename'

    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,
        
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Value
    ) # end param

    try {
        Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        return $true
     } catch {
        return $false
    } # end try catch
} # End Function

##### Base_Server Header #####
# Boxstarter options
$Boxstarter.RebootOk=$true # Allow reboots?
$Boxstarter.NoPassword=$false # Is this a machine with no login password?
$Boxstarter.AutoLogin=$true # Save my password securely and auto-login after a reboot
$useAWSRepository = $false

write-host "We're just getting started" -ForegroundColor DarkYellow

# Basic setup
Update-ExecutionPolicy Unrestricted
#Set-ExplorerOptions -showHidenFilesFoldersDrives -showFileExtensions #Chris found this line in Base_SQL2014SP1STD.ps1. It looks self-explanitory and useful but wants to discuss with David before adding/enabling it here.
#Enable-RemoteDesktop # Disabled because in the Interoute Template
#Disable-InternetExplorerESC # Disabled because in the Interoute Template
#Disable-UAC # Disabled because in the Interoute Template
#Enable-MicrosoftUpdate # Disabled because in the Interoute Template


If ($useAWSRepository -eq $true) {
    # AWS Install
    $softwareName = "AWSToolsAndSDKForNet"
    $softwareFilename = "AWSToolsAndSDKForNet.msi"
                                                                                                        if (!(Test-Path "C:\Repository\$($softwareName)InstallAttempted.txt")) {
    New-Item -path C:\Repository -name "$($softwareName)InstallAttempted.txt" -type "file" -value "$(Get-Date -format 'dd/MM/yyyy HH:mm:ss') - Attempting $($softwareName) installation."
    Write-Host "Created new file and text content added"

    #Download latest version of AWS PowerShell and call it to install
    $Uri = 'http://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi'
    #Invoke-WebRequest -Uri $Uri -OutFile "$env:HOMEPATH\downloads\$($Uri -replace '^.*/')"
    Invoke-WebRequest -Uri $Uri -OutFile "C:\repository\$($Uri -replace '^.*/')"
    Unblock-File -Path "C:\repository\$($Uri -replace '^.*/')"
    Write-Host "Install just the AWS Tools for Powershell..." -ForegroundColor Yellow
    

    New-Item -path C:\Repository -name AWSInstaller.bat -type "file" -value "C:\repository\$($Uri -replace '^.*/') /quiet"
    Start-Process "C:\Repository\AWSInstaller.bat" -Wait

    #download the file
    # invoke-webrequest https://qtcloud.box.com/shared/static/bl5cenkbw3y7lgyn2wtrw79sg22ny3k4.7z -OutFile $esetFile
    # or
    # download file from S3
    # Read-S3Object -BucketName qtcsoftwarerepo -Key "$($softwareFolderInQTCsoftwareREPO)/$($softwareFilename)" -File "C:\Repository\$($softwareFilename)" -Region eu-west-1

    #Extract Media
    #if (Test-Path C:\Repository\ESETInstaller.exe) { 
    #    Write-Host "Folder exists already"
    #} else {
    #    & "C:\Program Files\7-Zip\7z.exe" x "C:\Repository\$($softwareFilename)" -o"C:\Repository\"
    #}

    #Install
    # & "C:\repository\$($Uri -replace '^.*/') /quiet"
    # start-process "C:\repository\$($Uri -replace '^.*/') /quiet" -wait
                                                                } else {
    Add-Content -path "C:\Repository\$($softwareName)InstallAttempted.txt" -value "$(Get-Date -format 'dd/MM/yyyy HH:mm:ss') - Detected previous installation attempt - aborting."
    Write-Host "File already exists and new text content added"

    if (!(Test-Path "C:\Repository\$($softwareFilename)")) {
        Write-Host "$($myCounter) - All going ok..."
        $myCounter = $myCounter + 1
    } else {
        Remove-Item "C:\Repository\$($softwareFilename)" -Force
    
    } # end if
    if (!(Test-Path "C:\Repository\AWSInstaller.bat")) {
        Write-Host "$($myCounter) - All going ok..."
        $myCounter = $myCounter + 1
    } else {
        Remove-Item "C:\Repository\AWSInstaller.bat" -Force
    } # end if
    } # end if

    #AWS Parameters
    $winLogonKey="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                            If (!(Test-RegistryValue -Path $winLogonKey -Value 'AWSAccessKey')) {
    $awsAccessKey = Read-Host -Prompt "Input your AWS Access Key:" 
    New-ItemProperty -Path $winLogonKey -Name "AWSAccessKey" -Value "$($awsAccessKey)" -ErrorAction SilentlyContinue 
    $awsAccessKey = Get-ItemProperty -Path $winLogonKey -Name AWSAccessKey

    #Download latest version of AWS PowerShell and call it to install
    #$Uri = 'http://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi'
    ##Invoke-WebRequest -Uri $Uri -OutFile "$env:HOMEPATH\downloads\$($Uri -replace '^.*/')"
    #Invoke-WebRequest -Uri $Uri -OutFile "C:\repository\$($Uri -replace '^.*/')"
    #Unblock-File -Path "C:\repository\$($Uri -replace '^.*/')"
    #Write-Host "Install just the AWS Tools for Powershell..." -ForegroundColor Yellow
    #& "C:\repository\$($Uri -replace '^.*/')"
            } else {
    Write-Host "AWSAccessKey Retrieved"
    $awsAccessKey = Get-ItemProperty -Path $winLogonKey -Name AWSAccessKey
    } # end if else

                If (!(Test-RegistryValue -Path $winLogonKey -Value 'AWSSecretKey')) {
    $awsSecretKey = Read-Host -Prompt "Input your AWS Secret Key:"
    New-ItemProperty -Path $winLogonKey -Name "AWSSecretKey" -Value "$($awsSecretKey)" -ErrorAction SilentlyContinue 
    $awsSecretKey = Get-ItemProperty -Path $winLogonKey -Name AWSSecretKey
            } else {
    Write-Host "AWSSecretKey Retrieved"
    $awsSecretKey = Get-ItemProperty -Path $winLogonKey -Name AWSSecretKey
    } # end if else

    #AWS Configuration
    Initialize-AWSDefaultConfiguration -AccessKey $awsAccessKey.AWSAccessKey -SecretKey $awsSecretKey.AWSSecretKey -Region eu-west-1

    #Download Software from AWS
    # Read-S3Object -BucketName qtcsoftwarerepo -Key Microsoft/Office/Office_2013w_SP1.zip -File C:\Repository\Office_2013w_SP1.zip -Region eu-west-1
    # Read-S3Object -BucketName qtcsoftwarerepo -Key LibreOffice/LibreOffice_5.3.6_Win_x64.msi -File C:\Repository\LibreOffice_5.3.6_Win_x64.msi -Region eu-west-1
    
} # End If ($useAWSRepository -eq $true)


#Essential Software
#write-host "About to attempt Chocolaty install of 7zip"
#pause
cinst 7zip.install
 
# Install DotNet3.5
#cinst DotNet3.5
#if (Test-PendingReboot) { Invoke-Reboot }

# Update Windows and reboot if necessary
# Install-WindowsUpdate -AcceptEula
#if (Test-PendingReboot) { Invoke-Reboot }

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
if (!(Test-Path "C:\QTCScripts\Scheduled\readme.txt")) {
   New-Item -path C:\QTCScripts\Scheduled -name readme.txt -type "file" -value "This area is for QTC scripts that are run as per a schedule."
   Write-Host "Created new file and text content added"
} else {
  # Add-Content -path C:\QTCScripts\Scheduled\readme.txt -value "new text content"
  # Write-Host "File already exists and new text content added"
}
if (!(Test-Path "C:\QTCScripts\Triggered\readme.txt")) {
   New-Item -path C:\QTCScripts\Triggered -name readme.txt -type "file" -value "This area is for QTC scripts that are run as per a trigger."
   Write-Host "Created new file and text content added"
} else {
  # Add-Content -path C:\QTCScripts\Triggered\readme.txt -value "new text content"
  # Write-Host "File already exists and new text content added"
}


write-host "About to attempt CS install..."
#pause

# CentraStage
$centrastageFile = "$($Env:userprofile)\Downloads\CSAgent.exe"
if (!(Test-Path "C:\Repository\CentrastageInstallAttempted.txt")) {
    New-Item -path C:\Repository -name CentrastageInstallAttempted.txt -type "file" -value "$(Get-Date -format 'dd/MM/yyyy HH:mm:ss') - Attempting Centrastage installation."
    Write-Host "Created new file and text content added"
    invoke-webrequest https://merlot.centrastage.net/csm/profile/downloadAgent/d549c035-e426-41f4-95ea-59394a291daf -OutFile $centrastageFile
    & $centrastageFile
    Start-Sleep -s 60
} else {
    Add-Content -path C:\Repository\CentrastageInstallAttempted.txt -value "$(Get-Date -format 'dd/MM/yyyy HH:mm:ss') - Detected previous installation attempt - aborting."
    Write-Host "File already exists and new text content added"

    if (Test-Path $centrastageFile) {
        Remove-Item $centrastageFile -Force
    } # end if
} # end if 

# ESET AV
$esetFile = "C:\Repository\ESETInstaller.7z"
if (!(Test-Path "C:\Repository\ESETInstallAttempted.txt")) {
    New-Item -path C:\Repository -name ESETInstallAttempted.txt -type "file" -value "$(Get-Date -format 'dd/MM/yyyy HH:mm:ss') - Attempting ESET installation."
    Write-Host "Created new file and text content added"

    #download the file
    #invoke-webrequest https://qtcloud.box.com/shared/static/bl5cenkbw3y7lgyn2wtrw79sg22ny3k4.7z -OutFile $esetFile
    invoke-webrequest https://www.dropbox.com/s/n95bk0ivc4b5agz/ERA_Installer_x64_en_US.7z?dl=1 -OutFile $esetFile

    #Extract Media
    #if (Test-Path C:\Repository\ESETInstaller.exe) { 
    #    Write-Host "Folder exists already"
    #} else {
        & "C:\Program Files\7-Zip\7z.exe" x "$($esetFile)" -o"C:\Repository\"
    #}

    New-Item -path C:\Repository -name ESETInstaller.bat -type "file" -value "C:\Repository\ERA_Installer_x64_en_US.exe --silent --accepteula"
    & C:\Repository\ESETInstaller.bat
    # & $esetFile --silent --accepteula

    Start-Sleep -s 60
} else {
    Add-Content -path C:\Repository\ESETInstallAttempted.txt -value "$(Get-Date -format 'dd/MM/yyyy HH:mm:ss') - Detected previous installation attempt - aborting."
    Write-Host "File already exists and new text content added"

    if (Test-Path $esetFile) {
        Remove-Item $esetFile -Force
    } # end if
    if (Test-Path C:\Repository\ESETInstaller.bat) {
        Remove-Item C:\Repository\ESETInstaller.bat -Force
    } # end if
    if (Test-Path C:\Repository\ESETInstaller.bat) {
        Remove-Item C:\Repository\ERA_Installer_x64_en_US.exe -Force
    } # end if
} # end if

<#Set Ciphers to QTC Best Practice
Write-Host "Downloading Nartac"
if (Test-Path C:\Repository\IISCryptoCli.exe) { 
    Write-Host "File exists already"
    } else {
    $url = "https://s3-eu-west-1.amazonaws.com/softwarerepoqtc/Agresso/IISCryptoCli.exe"
    $output = "C:\Repository\IISCryptoCli.exe"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $output) 
    }
C:\Repository\IISCryptoCli.exe /template best
if (Test-PendingReboot) { Invoke-Reboot }
#>
##### END Base_Server Header #####


#
#


##### Base_Server Footer #####
# Set Language Settings
Set-Culture en-GB
Set-WinSystemLocale en-GB
Set-WinHomeLocation -GeoId 242
Set-WinUserLanguageList en-GB, en-US -force

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
Remove-ItemProperty -Path $winLogonKey -Name "AWSAccessKey" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $winLogonKey -Name "AWSSecretKey" -ErrorAction SilentlyContinue
Stop-Transcript
##### END Base_Server Footer #####