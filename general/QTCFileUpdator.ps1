$scriptVersion = 20211005
$LogPath = "$($workingDir)QTCFileUpdator.log"
Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):QTCFileUpdator Started (scriptVersion: $($scriptVersion))"


### FUNCTIONS ###
Function Get-QTCFile {
  param
  (
    [Parameter(Mandatory = $true, Position=0)]
    [string]$filepath,
    [Parameter(Mandatory = $true, Position=1)]
    [string]$filesourceURL
  )
    #$filepath = "C:\QTCScripts\Scheduled\Audit\QTCCustomerAudit.ps1"
    #$filesourceURL = "https://raw.githubusercontent.com/quickthinkcloud/public/master/licensing/RDSLicensingAudit.ps1"

    $arr = $filepath.Split("\")

    $count = 0
#    if (Get-Variable newPath) {
#        Remove-Variable -Name newPath
#    }
    while ($count -lt ($arr.Count -1)) {
        $newPath += "$($arr[$count])\"
        $count++
    }

    #check that the destination directory exists
    if (!(Test-Path $newPath)) {  
        #CreateDirectory
        New-Item -Path "$($newPath)" -ItemType "directory" 
    }

    #get QTC file
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest $filesourceURL -OutFile "$($filepath)"



} # End Function
Function Update-QTCFile {
  param
  (
    [Parameter(Mandatory = $true, Position=0)]
    [string]$filepath,
    [Parameter(Mandatory = $true, Position=1)]
    [string]$filesourceURL
  )
    #$filepath = "C:\QTCScripts\Scheduled\Audit\QTCCustomerAudit.ps1"
    #$filesourceURL = "https://raw.githubusercontent.com/quickthinkcloud/public/master/audit/QTCCustomerAudit.ps1"

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

#Get-QTCFile -filepath "C:\QTCScripts\Scheduled\Audit\QTCCustomerAudit.ps1" -filesourceURL "https://raw.githubusercontent.com/quickthinkcloud/public/master/audit/QTCCustomerAudit.ps1"
Update-QTCFile -filepath "C:\QTCScripts\Scheduled\Audit\QTCCustomerAudit.ps1" -filesourceURL "https://raw.githubusercontent.com/quickthinkcloud/public/master/audit/QTCCustomerAudit.ps1"