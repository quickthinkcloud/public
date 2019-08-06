﻿# CitrixDirectorLicenseUsageAudit 
# Note: Requires PVS PowerShell SDK x64.msi installation (from Citrix main media) i.e. .\XenApp_and_XenDesktop_7_15_1000\x64\DesktopStudio\PVS PowerShell SDK x64.msi

### PARAMETERS (must be the first section of the script!)###
param (
    $ConfigFile = $(throw "You must specify a config file")
    #Working parameters
    #[parameter(Mandatory=$true,HelpMessage="You must enter a string")]$aString
    
    #Unknown if Working or not parameters
    #[parameter(Mandatory=$true,throw="You must enter a config file path")]$ConfigFile
    #[parameter(Mandatory=$true,HelpMessage="You must specify a config file")]$ConfigFile = $(throw "You must specify a config file")
    #[parameter(Mandatory=$true,HelpMessage="Path to log file")]$LogPath
)
### END OF PARAMETERS ###

$scriptVersion = 20190718
$LogPath = "$($workingDir)LicensingAudit.log"
Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):CitrixDirectorLicensingUsageAudit Started (scriptVersion: $($scriptVersion))"
#Import-Module Citrix*
Add-PSSnapin *Citrix*

#$workingDir = "C:\Users\$($env:USERNAME)\"
#$workingDir = "C:\QTCScripts\Scheduled\LicenseAudit\"
#cd $workingDir
$customerName = "CustomerName"
$citrixDirectorServer = "CitrixDirectorServer" # Storefront Server

#Run the config .ps1 to set the variables
. .\$ConfigFile

#Obtains the user credentials needed for accessing the XenDesktop Site monitoring information
#$cred = Get-Credential $env:USERNAME
$cred = $ctxCreds

#Grab ‘Users’ data from XenDesktop site
#Replace localhost with FQDN of DDC if not running on DDC
#$userdata = Invoke-RestMethod -uri “http://$($citrixDirectorServer)/Citrix/Monitor/Odata/v1/Data/Users” -UseDefaultCredentials
$userdata = Invoke-RestMethod -uri “http://$($citrixDirectorServer)/Citrix/Monitor/Odata/v1/Data/Users” -Credential $cred
 
#Populate User objects in $users variable
$users = $userdata.content.properties
 
#Obtain ‘Sessions’ data from XenDesktop Site
#Replace localhost with FQDN of DDC if not running on DDC
#$sessiondata = Invoke-RestMethod -uri “http://$($citrixDirectorServer)/Citrix/Monitor/Odata/v1/Data/Sessions” -UseDefaultCredentials
$sessiondata = Invoke-RestMethod -uri “http://$($citrixDirectorServer)/Citrix/Monitor/Odata/v1/Data/Sessions” -Credential $cred
 
#Populate Session objects in $sessions variable
$sessions = $sessiondata.content.properties

#Obtain ‘Machines’ data from XenDesktop Site
#Replace localhost with FQDN of DDC if not running on DDC
#$machinedata = Invoke-RestMethod -uri “http://$($citrixDirectorServer)/Citrix/Monitor/Odata/v1/Data/Machines” -UseDefaultCredentials
#$machinedata = Invoke-RestMethod -uri “http://$($citrixDirectorServer)/Citrix/Monitor/Odata/v1/Data/Machines” -Credential $cred
#$machines = $machinedata.content.properties

#Connections
$connectiondata = Invoke-RestMethod -uri “http://$($citrixDirectorServer)/Citrix/Monitor/Odata/v1/Data/Connections” -Credential $cred
$connections = $connectiondata.content.properties


 
#Create $date variable and set date to a temporary value
#$date = “2015-01-06”
#$date = “2017-03”
get-date -Format yyyy-MM-dd
$year = get-date -Format yyyy
$currentMonth = get-date -Format MM
if ($currentMonth -eq "01" ){
    write-host "rolling back a year and setting month to 12" -ForegroundColor Yellow
    $year = $year -1 # last year
    $lastMonth = 12 # #december
} else {
    $lastMonth = $currentMonth -1 # last month
    if ($lastMonth -le 9) {
        $lastMonth = "0$lastMonth" # last month with leading 0 for single digit months
    }
}

# $year
# $currentMonth
# $lastMonth


write-host "Please select an option"
write-host "1. Last Month"
write-host "2. This Month"
write-host "3. Manual input year and month"
write-host ""
#$userinput = read-host -Prompt "Option"
$userinput = 1
write-host "$($userinput) selected." -ForegroundColor Yellow
switch ($userinput)
{
    1 {$date = "$($year)-$($lastMonth)"}
    2 {$date = "$($year)-$($currentMonth)"}
    3 { #Query the user for an updated date value, in specified format
        $date = read-host “Please enter the date you wish to search (YYYY-MM-DD or YYYY-MM): “
    }
}
 
#Returns the sessions for the specified date and populatess them into the $sessionDate1 variable
$sessionDate1 = $sessions | where {$_.startdate.InnerText -like “$($date)*”}


$mycounter = 0
$global:arrCitrixUsersAndSessions = @()
Foreach ($sess in $sessionDate1) {
    
    #Create variables and set the value to $null    
    $sessUserID = $null
    $sessStartDate = $null
    $sessStartDate2 = $null
    $sessConnectionID = $null
    $userName = $null
    $fullName = $null
    $sid = $null
    $ClientAddress = $null
    $ClientName = $null

    #get the session info
    $sessUserID = $sess.Userid.InnerText
    $sessStartDate = $sess.StartDate.InnerText
    $sessStartDate2 = get-date($sessStartDate) -Format u
    $sessConnectionID = $sess.CurrentConnectionId.InnerText
    #$sessConnectionID

    #get the user info
    $userName = $users | where {$_.Id.InnerText -eq $sessUserID} | select username
    $fullName= $users | where {$_.Id.InnerText -eq $sessUserID} | select fullname
    $sid = $users | where {$_.Id.InnerText -eq $sessUserID} | select sid
    
    #get the connection info
    $ClientAddress = $connections| where {$_.Id.InnerText -eq $sessConnectionID }  | select ClientAddress
    $ClientName = $connections| where {$_.Id.InnerText -eq $sessConnectionID }  | select ClientName
    #$ClientAddress.ClientAddress
    #$ClientName.ClientName
    
    # Create a new instance of a .Net object
    $currentCitrixUserSessionObject = New-Object System.Object
    
    # Add user-defined customs members: the records retrieved with the three PowerShell commands
    #$currentCitrixUserSessionObject | Add-Member -MemberType NoteProperty -Value $sess.StartDate.InnerText -Name SessionStartDate
    $currentCitrixUserSessionObject | Add-Member -MemberType NoteProperty -Value $sessStartDate2 -Name SessionStartDate
    $currentCitrixUserSessionObject | Add-Member -MemberType NoteProperty -Value $userName.UserName -Name UserName
    $currentCitrixUserSessionObject | Add-Member -MemberType NoteProperty -Value $fullName.FullName -Name FullName
    $currentCitrixUserSessionObject | Add-Member -MemberType NoteProperty -Value $ClientAddress.ClientAddress -Name ClientAddress
    $currentCitrixUserSessionObject | Add-Member -MemberType NoteProperty -Value $ClientName.ClientName -Name ClientName
    $global:arrCitrixUsersAndSessions += $currentCitrixUserSessionObject  
    
    $mycounter += 1
    write-host "$($mycounter)/$(($sessionDate1).count) : $($currentCitrixUserSessionObject.SessionStartDate) $($currentCitrixUserSessionObject.UserName) $($currentCitrixUserSessionObject.FullName) $($currentCitrixUserSessionObject.ClientAddress) $($currentCitrixUserSessionObject.ClientName) "
    #pause
}
#$global:arrCitrixUsersAndSessions | ft

#$sessions[1].Userid.InnerText
#$sessions[1].StartDate.InnerText
##$users[1].id.InnerText
#$users | where {$_.Id.InnerText -eq $sessions[1].Userid.InnerText} | select username, fullname, Sid
#$thedate = $sessions[1].StartDate.InnerText #.ToDateTime("YYYY-MM-DD hh:mm:ss")
#get-date($thedate) -Format u
#$sessStartDate = $sessionDate1[1].StartDate.InnerText
<#$sessions[1].SessionKey
$sessions[1].StartDate
$sessions[1].LogOnDuration
$sessions[1].EndDate
$sessions[1].ExitCode
$sessions[1].FailureDate
$sessions[1].ConnectionState
$sessions[1].ConnectionStateChangeDate
$sessions[1].LifecycleState
$sessions[1].CurrentConnectionId
$sessions[1].UserId
$sessions[1].MachineId
$sessions[1].CreatedDate
$sessions[1].ModifiedDate
$machines
$sessConnectionID = $sessions[1].CurrentConnectionId
$sessions[1].CurrentConnectionId
$connections| where {$_.Id.InnerText -eq $sessions[1].CurrentConnectionId} # | select username
$connections| where {$_.Id -eq $sessConnectionID }  | select ClientAddress
$connections| where {$_.Id -eq $sessConnectionID }  | select ClientName


#>







 
#Populates the $userIDs variable with the userId value from the filtered sessions
$userIDs = $sessionDate1.UserId.InnerText
 
#Create a null array, used to capture and count user logons
$userObject = @()
 
#Begin for loop to process data
foreach ($userID in $userIDS) {
   
    #Create $userName variable and set the value to $null    
    $userName = $null
 
    #Filter $users so that only the user object with the given userId is returned
    $userName = $users | where {$_.Id.InnerText -eq $userID}
   
    #Check to see if the currently returned username already exists in the $userObject array
    if($userObject.UserName -contains $userName.UserName) {
       
       #Return the index of the location of the current user object
       $i = [array]::indexOf($userObject.UserName,($userName.UserName))
       
       #Since the user object already exists for userName, increase logon count by one
       ($userObject[$i]).count++
    }
 
    #If userName has not already been processed, proceed to object creation
    else{
      
       #Create a new System Object named $userObj
        $userObj = new-object System.Object
 
       #Add a member property of type [string] to the object, with the value of current UserName
        $userObj | add-member -memberType NoteProperty -Name UserName -Value $userName.UserName
       
       #Add a member property of type [int] to the object, with the value of 1, since this is the first occurance
       #of the current user
       $userObj | add-member -memberType NoteProperty -Name Count -Value 1
 
       #Add the newly created user object to the $userObject array
        $userObject += $userObj
    }
    
}
 
#Display Username and Logon Count
#$userObject | ft UserName,Count
$userObject | ft *
$userObject | Select UserName,Count | export-csv "$($workingDir)$($date) - $($customerName) - Citrix Logins.csv"
$userObject.Count

#Session output
$global:arrCitrixUsersAndSessions
$global:arrCitrixUsersAndSessions | export-csv "$($workingDir)$($date) - $($customerName) - Citrix Sessions.csv"

#Upload to dropbox
. .\dropbox-upload.ps1 "$($workingDir)$($date) - $($customerName) - Citrix Logins.csv" "/$($date) - $($customerName) - Citrix Logins.csv"
. .\dropbox-upload.ps1 "$($workingDir)$($date) - $($customerName) - Citrix Sessions.csv" "/$($date) - $($customerName) - Citrix Sessions.csv"