### PARAMETERS (must be the first section of the script!)###
param (
    $ConfigFile = $(throw "You must specify a config file")
    <#Working parameters
    #[parameter(Mandatory=$true,HelpMessage="You must enter a string")]$aString
    
    #Unknown if Working or not parameters
    #[parameter(Mandatory=$true,throw="You must enter a config file path")]$ConfigFile
    #[parameter(Mandatory=$true,HelpMessage="You must specify a config file")]$ConfigFile = $(throw "You must specify a config file")
    #[parameter(Mandatory=$true,HelpMessage="Path to log file")]$LogPath
    #>
)
### END OF PARAMETERS ###


#Run the config .ps1 to set the variables
. .\$ConfigFile


#cd 'C:\Files\ZDrive\QuickThink Cloud Dropbox\Operations\Scripts\boxstarter'
$scriptVersion = 20190806
Write-Host "Script Version = $($scriptVersion)"


#SCRIPT ADMIN VARIABLES!
$scriptName = "SelfUpdater.ps1"
$updateDirectoryName = "SelfUpdaterUpdates"
$updatedVersionName = "SelfUpdater_latest.ps1"
#$scriptSourceURL = "https://www.dropbox.com/s/n63hlqg0v5k8piz/UpdatedVersion.ps1?dl=1"
$scriptSourceURL = "https://raw.githubusercontent.com/quickthinkcloud/public/master/SelfUpdater.ps1"


Function UpdatesAvailable {

    #check that the destination directory exists
    if (!(Test-Path $updateDirectoryName)) {  
        #CreateDirectory
        New-Item -Name "$($updateDirectoryName)" -ItemType "directory"
    }
    
    #check the latest update file exists
    if (!(Test-Path "$($updateDirectoryName)\$($updatedVersionName)")) {
        
        #download the latest
        Invoke-WebRequest $scriptSourceURL -OutFile "$($updateDirectoryName)\$($updatedVersionName)"
    }

} # End Function
Function Update-Myself {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true,
                   Position = 0)]
        [string]$SourcePath
    )
    #check that the destination file exists
    if (Test-Path $SourcePath)
    {
    #The path of THIS script
    $CurrentScript = $MyInvocation.ScriptName
        if (!($SourcePath -eq $CurrentScript ))
        {
            if ($(Get-Item $SourcePath).LastWriteTimeUtc -gt $(Get-Item $CurrentScript ).LastWriteTimeUtc)
            {
                write-host "Updating..."
                Copy-Item $SourcePath $CurrentScript 
                #If the script was updated, run it with orginal parameters
                #&$CurrentScript $script:args
                &$CurrentScript $ConfigFile
                exit
            }
        }
    }
    write-host "No update required"
    Remove-Item "$($updateDirectoryName)" -Recurse -Force -Confirm:$false
} # End Function

UpdatesAvailable
Update-Myself "$($updateDirectoryName)\$($updatedVersionName)"