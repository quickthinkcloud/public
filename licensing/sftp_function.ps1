###########################################
#               Global Variables          #
###########################################
$tab = [char]9 #So I can tab outputs within the console.
$currentDirectory = Get-Location #Get's cd from where script is executed.


# Checks if a session exists.  If it does, bypasses the connection phase and utilises the existing session.
# If a session doesn't exist, then it creates one by parsing credentials from the send-sftpdata script, and calls Set-SFTPSession to achieve this
function Get-SFTPSessionStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SFTPserver,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$credential #Prompts for your SFTP credentials
    )
    Write-Host "Performing Session Checks"
    Write-Host "$($tab)Session detection status... " -NoNewline
    $SFTPsession = Get-SFTPSession | Where-Object -Property Host -eq $SFTPserver | Select-Object -First 1 -ErrorAction SilentlyContinue
    if ($SFTPsession) {
        Write-Host "Success" -ForegroundColor Green
        write-host "$($tab)Found session " -NoNewline 
        write-host "$($SFTPsession.SessionID)" -ForegroundColor Green -NoNewLine
        write-host " found for host " -NoNewLine
        write-host $SFTPServer -ForegroundColor Green
        write-host "--------------------------------------------"
        return $SFTPsession.SessionID
    }
    else {
        write-host "None" -ForegroundColor DarkYellow
        Write-Host "$($tab)Creating Session... " -NoNewline

        $SFTPsession = Set-SFTPSession -SFTPserver $SFTPserver -Credential $credential -InformationAction SilentlyContinue -ErrorAction SilentlyContinue

        if ($SFTPsession) {
            Write-Host " Success" -ForegroundColor Green
            Write-Host "$($tab)New session " -NoNewLine
            write-host $SFTPsession.SessionID -ForegroundColor Green -NoNewLine
            Write-Host " created on host " -NoNewLine
            Write-Host $SFTPserver -ForegroundColor Green
            write-host "--------------------------------------------"
            return $SFTPsession.SessionID
        }
        else {
            Write-Host " Failed! Aborting..." -ForegroundColor Red
            Write-Error "" -ErrorAction Stop
        }
        write-host "--------------------------------------------"
        
    }    
}

# Called via Get-SFTPSessionStatus.  Used to create a new SFTP session if one doesn't exist.
function Set-SFTPSession {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SFTPserver,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$credential #Prompts for your SFTP credentials
    )
    New-SFTPSession -ComputerName $SFTPserver -Credential $credential -InformationAction SilentlyContinue -ErrorAction SilentlyContinue
}

# Performs some basic network connectivity tests (DNS and port) before progressing on to attempt connection
# Attempts to speed up any issues (i.e. DNS) and give me a bit more visibility on where any fault exists
function Resolve-SFTPServer {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SFTPserver
    )
    Write-Host
    Write-Host "Performing initial connectivity checks for "  -NoNewline
    write-host "$SFTPServer..." -ForegroundColor DarkYellow
    Write-Host "$($tab)Testing DNS lookup" -NoNewline
    Write-Host "... " -NoNewline

    if (Resolve-DnsName $SFTPserver -Type "A" -ErrorAction SilentlyContinue) {
        Write-Host "Success" -ForegroundColor Green
        Write-Host "$($tab)Testing port connectivity" -NoNewline
        Write-Host "... " -NoNewline

        $portTest = Test-NetConnection -ComputerName $SFTPserver -Port 22 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        
        if ($portTest.TcpTestSucceeded -eq $true) {
            Write-Host "Success" -ForegroundColor Green
            write-host "--------------------------------------------"
        }
        else {
            write-host " Failed! Aborting..." -ForegroundColor Red
            write-host "--------------------------------------------"
            Write-Error "" -ErrorAction SilentlyContinue
        }
    }
    else {
        write-host " Failed! Aborting..." -ForegroundColor Red
        write-host "--------------------------------------------"
        Write-Error "" -ErrorAction Stop
    }
    
}

# Final part of the puzzle.  Tests that the remote path exists.  If it does, invoke the data transfer
# Note: Uploads using -overwrite as we don't currently do file comparison
function Start-SFTPTransfer {
    param (
        [Parameter(Mandatory=$true)]
        [string]$sessionID,
        [Parameter(Mandatory=$true)]
        [string]$SFTProotDir,
        [Parameter(Mandatory=$true)]
        [array]$sourceFiles,
        [Parameter(Mandatory=$true)]
        [string]$workingdir,
        [Parameter()]
        [string]$SFTPserver
    )

    Write-Host "Performing analysis of remote SFTP configuration on session ID: " -NoNewLine
    Write-Host "$sessionID" -ForegroundColor DarkYellow

    $remoteDirExists = Test-SFTPPath -SessionId $sessionID -Path $SFTProotDir
    Write-Host "$($tab)SFTP root folder verification status... " -NoNewLine
    if ($remoteDirExists) {
        Write-Host "Success!" -ForegroundColor Green
    }
    else {
        Write-Host " Failed! Aborting..." -ForegroundColor Red 
        Write-Error "" -ErrorAction stop
    }
    write-host "--------------------------------------------"
    #Write-Host "Performing file comparison analysis"    
    Write-Host "Uploading the following files to " -NoNewLine
    Write-Host $SFTPserver -ForegroundColor DarkYellow
    
    foreach ($file in $sourceFiles) {
        Write-Host "$($tab)$workingdir\$file... "
        #Set-SFTPFile -SessionId $sessionID -LocalFile "$($workingdir)\$file" -RemotePath $SFTProotDir -Overwrite -ErrorAction Stop
        Set-SFTPFile -SessionId $sessionID -LocalFile "$file" -RemotePath $SFTProotDir -Overwrite -ErrorAction Stop
    }
    write-host "--------------------------------------------"
}

# Superficial function so I can make the code a little neater to look through
function Write-ScriptHeader {
    Write-Host "########################################################################"
    Write-Host "########################################################################"
    Write-Host "$($tab)$($tab)$($tab)  QTC SFTP Script"
    Write-Host "########################################################################"
    Write-Host "########################################################################"
}

# If a text value (i.e. from existing variables) is used, then converts these into a PSCredential object
function Convert-Credential {
    param (
        [array]$sendCred
    )
    Write-Host "Performing Authentiation checks"
    Write-Host "$($tab)Authentication method used" -NoNewline
    write-host "... " -NoNewline
    Write-Host "Array" -ForegroundColor DarkYellow


    Write-Host "$($tab)Array validation status... " -NoNewline
    if ($sendCred.Count -ne 2) {
        Write-Host "Failed! Aborting..." -ForegroundColor Red
        write-host "--------------------------------------------"
    }
    else {
        Write-Host "Success" -ForegroundColor Green
        write-host "--------------------------------------------"
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sendCred[0], (ConvertTo-SecureString -String $sendCred[1] -AsPlainText -Force)
        return $credential
    }
}

# Superficial function so I can make the code a little neater to look through
function Write-CredentialSkip {
    Write-Host "Performing Authentication Checks"
    Write-Host "$($tab)Authentication method used" -NoNewline
    write-host "... " -NoNewline
    Write-Host "PSCredential" -ForegroundColor Green
    Write-Host "$($tab)No conversion needed... " -NoNewline
    Write-Host "Skipping" -ForegroundColor DarkYellow
    write-host "--------------------------------------------"
}

# Before attempting any upload.  This function runs through and tests the paths of the working directory
# and the array of source files to make sure they exist before transfer
function Test-FilesExist {
    param(
        [Parameter(Mandatory=$true)]
        [array]$sourceFiles,
        [Parameter(Mandatory=$true)]
        [string]$workingdir
    )

    Write-Host "Performing file validation checks for " -NoNewLine
    Write-Host $workingdir -ForegroundColor DarkYellow
    Write-Host "$($tab)Verifying working directory exists... " -NoNewLine
    $testPath = Test-Path -Path $workingdir
    if ($testPath) {
        Write-Host "Success" -ForegroundColor Green
    }
    else {
        Write-Host "Failed! Aborting..." -ForegroundColor Red
        Write-Error "" -ErrorAction Stop
    }

    Write-Host "Verifying files exist in working directory"
    
    foreach ($file in $sourceFiles) {
        $pathExists = Test-Path -Path "$($workingdir)\$file"
        Write-Host "$($tab)$workingdir\$file... " -NoNewLine

        if ($pathExists) {            
            Write-Host "Success" -ForegroundColor Green
        }
        else {
            Write-Host "Failed!" -ForegroundColor Red
            $fileTestError = $true        
        }
    }

    if ($fileTestError) {
        Write-Error "" -ErrorAction Stop
    }
    
    write-host "--------------------------------------------"
}

# Master function that takes all the parameters (i.e. you call this one from PowerShell)
# This function calls all/most of the other functions above, and is mainly used for the structure of the whole script
function Send-SFTPData {
    [CmdletBinding(DefaultParameterSetName="Secure")]
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline,ParameterSetName="Secure")]
        [System.Management.Automation.PSCredential]$credential, #Prompts for your SFTP credentials

        [Parameter(Mandatory=$true,ValueFromPipeline,ParameterSetName="Less_Secure")]
        [array]$sendCred,

        [Parameter()]
        [string]$SFTPserver="villefort.myqtcloud.com", #SFTP server DNS address or IP.  Can be overridden if required.

        [Parameter()]
        [string]$SFTProotDir="\", #SFTP server DNS address or IP.  Can be overridden if required.
        
        [Parameter()]
        [string] #Sets the working folder from which you can upload to the SFTP server.  Default is the LicenseAudit folder for QTCScripts
        $workingdir="$($currentDirectory.Path)",

        [Parameter(Mandatory=$true)]
        [array]
        $sourceFiles=@("file1.png","file2.png","file3.png") #Array of files to be uploaded from source.  Note you can simply put in one entry for a single file
    )

    Write-ScriptHeader #Placed the script header in a separate function to make this function a little tidier.
    $passedConnectivityCheck = Resolve-SFTPServer -SFTPserver $SFTPserver #Runs a custom function I've made for basic connectivity checks.  Script will bomb itself out if any failures.
    
    if (!$credential) { 
        $credential = Convert-Credential -sendCred $sendCred #if the -credential parameter isn't set, then runs a custom function and converts to PSCredential format.
    }
    else {
        Write-CredentialSkip #Already in secure format, so bypass the converstion.
    }

     $sessionCheck = Get-SFTPSessionStatus -SFTPserver $SFTPserver -credential $credential #Runs a custom function, and bypasses creating a new SFTP session if one already exists.  Script will bomb itself out if any failures.
     
     $localFilesCheck = Test-FilesExist -sourceFiles $sourceFiles -workingdir $workingdir

     Start-SFTPTransfer -sessionID $sessionCheck -SFTProotDir $SFTProotDir -workingdir $workingdir -sourceFiles $sourceFiles -SFTPserver $SFTPserver
}

#$steve = Get-Credential
#$steve | Send-SFTPData -sourceFiles "sftp_function.ps1","SelfService_IISReset.ps1"
#Send-SFTPData -sourceFiles "sftp_function.ps1","SelfService_IISReset.ps1" -sendCred "swilding","thisisinsecure"



<# Chris' installation notes/figuring things out...

#This may be required for initial installation of POSH

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Register-PSRepository -Default -Verbose
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

Install-Module posh-ssh


$sftpCreds = Get-Credential licensing
Send-SFTPData -sourceFiles "2021-05 - BI - Citrix Sessions.csv" -credential $sftpCreds -SFTProotDir "/licensing" #-workingdir "C:\QTCScripts\Scheduled\LicenseAudit"

$SFTPserver = "villefort.myqtcloud.com"
$credential = $sftpCreds
$Credential = $sftpCreds
$fileToSFTP = "2021-05 - BI - Citrix Sessions.csv"

Get-SFTPSessionStatus -SFTPserver $SFTPserver -credential $credential


Get-SFTPSession

New-SFTPSession -ComputerName $SFTPserver -Credential $credential -InformationAction SilentlyContinue -ErrorAction SilentlyContinue

Set-SFTPFile -SessionId $sessionID -LocalFile "$($workingdir)\$file" -RemotePath $SFTProotDir -Overwrite -ErrorAction Stop











$Credential = $sftpCreds
$SFTPserver = "villefort.myqtcloud.com"
$sftpIPorURL = $SFTPserver
$fileToSFTP = "2021-05 - BI - Citrix Sessions.csv"
$destSFTPPath ="/Licensing"

# Set the credentials
$Password = ConvertTo-SecureString $SFTPPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($SFTPUser, $Password)

# Load the Posh-SSH module
Import-Module C:\Temp\Posh-SSH

# List active sessions
Get-SFTPSession
Get-SFTPSession | Remove-SFTPSession

# Establish the SFTP connection
New-SFTPSession -ComputerName $sftpIPorURL -Credential $Credential

#Single file upload
#Set-SFTPFile -SessionId 0 -LocalFile $fileToSFTP -RemotePath $destSFTPPath -Verbose -Overwrite

# Loop through files and updload them
Foreach ($file in $filesBeingProcessed) {
    #$FilePath = $filesBeingProcessed + $file.Name
    $FilePath = "$($processingFolder)$($file.Name)"
    #write-host "$($processingFolder)$($file.Name)"
    Set-SFTPFile -SessionId 0 -LocalFile $FilePath -RemotePath $destSFTPPath -Verbose
    Move-Item -Path $FilePath -Destination $destFilePath
    Add-Content $LogPath $FilePath
}

# Disconnect SFTP session
(Get-SFTPSession -SessionId 0).Disconnect()
Get-SFTPSession
Get-SFTPSession | Remove-SFTPSession
Get-SFTPSession

Add-Content $LogPath "Finished: $(get-date)"


#>