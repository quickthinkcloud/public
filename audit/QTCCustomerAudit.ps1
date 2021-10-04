### PARAMETERS (must be the first section of the script!)### 
param (
    $ConfigFile = $(throw "You must specify a config file")
    #Working parameters
    #[parameter(Mandatory=$true,HelpMessage="You must enter a string")]$aString
)
### END OF PARAMETERS ###

$scriptVersion = 20211004.4
$LogPath = "$($workingDir)QTCAuditScript.log"
Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):QTCAuditScript Started (scriptVersion: $($scriptVersion))"

### GLOBAL VARIABLES ###
# None

## USER CONFIGURED VARIABLES ##
$customerName = "CustomerName"
#$workingDir = "C:\Users\$($env:USERNAME)\"


### FUNCTIONS ###
Function Update-File {
  param
  (
    [Parameter(Mandatory = $true, Position=0)]
    [string]$filepath,
    [Parameter(Mandatory = $true, Position=1)]
    [string]$filesourceURL
  )
    #$filepath = "C:\QTCScripts\Scheduled\LicenseAudit\aaa\bbb.ps1"
    #$filesourceURL = "https://raw.githubusercontent.com/quickthinkcloud/public/master/licensing/RDSLicensingAudit.ps1"

    $item = Get-Item $filepath

    $item.VersionInfo.FileName
    $item.DirectoryName
    $item.Name

    $filenameTempArr = $Item.Name.Split(".")
    $filenameNew = "$($filenameTempArr[0])_latest.$($filenameTempArr[-1])"


    #check that the destination directory exists
    if (!(Test-Path $item.DirectoryName)) {  
        #CreateDirectory
        New-Item -Path "$($item.DirectoryName)" -ItemType "directory" 
    }

   
    #check the latest update file exists
    if (!(Test-Path "$($item.VersionInfo.FileName)")) {
        
        #download the latest
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $filesourceURL -OutFile "$($item.VersionInfo.FileName)"
    } Else {

        #download the latest
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $filesourceURL -OutFile "$($item.DirectoryName)\$($filenamenew)"
    }

    
    #Compare Checksums
    #Check for new file
    If (Test-Path "$($item.DirectoryName)\$($filenamenew)") {
        $newHash = Get-FileHash "$($item.DirectoryName)\$($filenameNew)"

        #Check existing file
        If (Test-Path "$($item.VersionInfo.FileName)") {
            $existingHash = Get-FileHash "$($item.VersionInfo.FileName)"
            
            #Compare hashes and overwrite if required
            If ($existingHash -ne $newHash) {
                Move-Item "$($item.DirectoryName)\$($filenameNew)" -Destination "$($item.VersionInfo.FileName)" -Force
            } # End If
        } # End If
    } # End If
        
    

} # End Function
#Update-File -filepath "C:\QTCScripts\Scheduled\LicenseAudit\aaa.ps1" -filesourceURL "https://raw.githubusercontent.com/quickthinkcloud/public/master/licensing/RDSLicensingAudit.ps1"


### SCRIPT BODY ###
#Run the config .ps1 to set the variables
write-host "Current Script Version: $($scriptVersion)"
Start-Sleep -Seconds 3
. .\$ConfigFile
cd $workingDir

#Additional Functions
. .\sftp_function.ps1

#SCRIPT ADMIN VARIABLES!
$date = get-date -Format yyyyMMdd
#$datetime = get-date -Format yyyyMMdd_HHmm
$outputfilename = "$($date)_$($customerName)_Audit_DomainAdmins.csv"

Get-ADGroupMember "Domain Admins" -Recursive | sort name | select name | Export-Csv $outputfilename -NoTypeInformation -Force


#Upload to SFTP
#Start-Sleep -Seconds 3
#Send-SFTPData -sourceFiles $outputfilename -credential $SFTPCreds -SFTProotDir "/licensing"