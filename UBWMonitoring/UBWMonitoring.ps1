### ABOUT AND INITIAL SETUP ### 
<#
### ABOUT ###
Author: Chris Phillips, for QuickThink Cloud Limited
Date: 04/05/2017
Version: 1.2
Purpose: Powershell version of the Agresso monitoring
### END ABOUT ###

### INITIAL SETUP ###

use master;
grant select on commandlog to [MYQTCLOUD\SVC_PSMonitoring]

grant VIEW SERVER STATE to [MYQTCLOUD\SVC_PSMonitoring]
1. Account this runs as MUST be have dbreader access - SQL below
USE [master]
GO
CREATE LOGIN [NHTQTC\SVC_PSMonitoring] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [NHTQTC\SVC_PSMonitoring]
GO

-- OR --

USE [master]
GO
CREATE LOGIN [QTC\SVC_AgressoMonitor] FROM WINDOWS WITH DEFAULT_DATABASE=[agressolive]
GO

USE [agressolive]
GO
CREATE USER [QTC\SVC_AgressoMonitor] FOR LOGIN [QTC\SVC_AgressoMonitor]
GO

USE [agressolive]
GO
ALTER ROLE [db_datareader] ADD MEMBER [QTC\SVC_AgressoMonitor]
GO

2. Account must be able to run as scheduled task (local admin is easiest way but may be too high privs for some)
3. Account must have read/write NTFS accesso to the working directory. (local admin is easiest way but may be too liberal privs for some)
### END INITIAL SETUP ###
#>

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

$scriptVersion = "20250325_1323"

# Add Modules
Import-Module sqlserver
#Update-Module sqlserver

$ssmodule22plus = $false
$ssmodversion = Get-InstalledModule sqlserver
if ($ssmodversion.Version.Major -gt 21) {
    $ssmodule22plus = $true
}


### STATIC VARIABLS (PRE CONFIG FILE!) ###
### GLOBAL VARIABLES ###
## USER CONFIGURED VARIABLES ##
#General Customer Info
$customerName = "No Customer Set"
$customerBusinessHoursStart = "08:00"
$customerBusinessHoursEnd = "17:30"
#Customer Domain Info
#$customerDomain = "DC=QTC,DC=LOCAL" #Format "DC=QTC,DC=LOCAL"
#$customerDottedDomain = "QTC.LOCAL" #Format "QTC.LOCAL"
$domain = "QTC" #NetBIOS format "QTC"
#Email Settings
$emailAlerts = $false
$smtpServer = "No SMTP Server Set"
$mailSender = "QTC Monitoring <QTCMonitoring@qtc.cloud>"
$mailRecipients = @("ops.team@quickthinkcloud.com", "support@quickthinkcloud.com") #Example: $mailRecipients = @("ops.team@quickthinkcloud.com", "support@quickthinkcloud.com")
#Database and Business Server
$AgressoDBServerName = "No Agresso DB Server Set" #$AgressoDBServerName = "Change_Agresso_DB_Server_Name"
$AgressoDBName = "No Agresso Database Name Set" #$AgressoDBName = "Change_Agresso_DB_Name"
$AgressoLogicalServerName = "No Agresso Logical Server Set" #$AgressoLogicalServerName = "Change_Agresso_Logical_Server_Name"
#Queues
$p1CoreNumberOfMinutes = 8 #8 number of minutes an P1 Agresso Core Queue can be running without updating
$UBW_Queue_Scheduler_Minutes = 8 #8 number of minutes the Scheduler can be running without updating before an alarm is triggered
$UBW_Queue_TPS_Minutes = 8 #8 number of minutes the Scheduler can be running without updating before an alarm is triggered
$p2CoreNumberOfMinutes = 15 #15 number of minutes an P2 Agresso Core Queue can be running without updating
$UBW_Queue_ACRALS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_ALGIPS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_ALGSPS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_AMS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_RESRATE_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_DWS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_IMS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$p3CoreNumberOfMinutes = 60 #60 number of minutes an P3 Agresso Core Queue can be running without updating
$UBW_Queue_AINAPS_Minutes = 60 #60 number of minutes this queue can run without updating before an alarm is triggered
#Ordered Reports
$NoDaysforNorWReportsOrderedToBeMonitored = 7 #7 $NoDaysforNorWReportsOrderedToBeMonitored = "DAYS_FOR_N_OR_W_REPORTS_ORDERED_TO_BE_MONITORED"
$MinsForNorWReportsToBeConsideredActive = 60 #60 $MinsForNorWReportsToBeConsideredActive = "MINUTES_FOR_N_OR_W_REPORTS_TO_BE_CONSIDERED_ACTIVE" 
#Workflow Service
$NoWorkflowRows = 60 #60 $NoWorkflowRows = "NO_OF_WORKFLOW_ROWS_DEFAULT_60"
#Agresso AMS Service Email Queue
$MinsForAMSEmailQueue = 120 #120
$MaxHoursSinceLastBackup = 32 #32 Number of hours since last good backup before an alarm is triggered
$MaxHoursSinceLastDBCC = 32 #32 Number of hours since last good DBCC check before an alarm is triggered
#LongReports Function Variables
$MinsThresholdForLongReports = 10 #Minimum number of mins to consider a report long running
$LongReportsMonitorMins = 120  #120 Number of minutes before now to monitor long running reports for
#AgressoLogins Variables
$MinsToMonitorFailedAgressoLogins = 30 #30 Number of minutes before now to monitor failed Agresso logins
$FailedAgressoLoginsThreshold = 5 #5 Number of failed login attempts before alarm is triggered
$checkForInsecureLogins = $true
## END OF USER CONFIGURED VARIABLES ##

#Run the config .ps1 to set the variables
. .\$ConfigFile

## ADMIN/SRIPT WRITER VARIABLES ##
$UBWMonitoringScriptVersion = $scriptVersion
$scriptName = $MyInvocation.MyCommand.Name #Returns the Script name (or function name if called from within a function)
$scriptNameNoExt = $scriptName.Split(".",2) | Select -First 1
$configFileNoExt = $ConfigFile.Split(".",2) | Select -First 1
$whoIsTheCallingUser = whoami # Who called this script / what account was it run as?
$workingDir = "$(Get-Location)\" #"C:\Users\$($env:USERNAME)\" #$workingDir = "C:\QTCScripts\Scheduled\AgressoMonitoring\" #"C:\Users\$($env:USERNAME)\" #Working directory for file output etc.
write-host "workingDir updated to: $($workingDir)"
$instanceSpecificWorkingDir = "$($workingDir)$($configFileNoExt)\"
$RunSpeedLog = "$($instanceSpecificWorkingDir)$($scriptNameNoExt)_$($configFileNoExt)_RunSpeed.log"
$LogPath = "$($instanceSpecificWorkingDir)$($scriptNameNoExt)_$($configFileNoExt).log" #C:#Please disable this line if parameterising it for the script
$stateFile = "$($instanceSpecificWorkingDir)$($scriptNameNoExt)_$($configFileNoExt)_stateFile.ps1"
#Set-Culture en-GB
$scheduledTaskName = "$($scriptNameNoExt)_$($configFileNoExt)" #"AgressoMonitoring"
#Set at this level so they are global and can then be reused by other functions#
$MsgBody = "Date: " + $Date + "`n" 
$functionName = "No Function Run Yet"
#$dateDiff = 1
$functionOutputCSV = "No Data"
#$functionReturn = "No Data"
$outOfHoursMode = 0
$eventLogID = 0
$eventLogMessage = ""
$numHoursToReArm = 24
$triggeredCount = 0
$maxFrequencyOfAlarms = 2
$Process_Functional_ErrorTriggerThreshold = 3
<#
$NoWorkflowRowsNighttime = $NoWorkflowRows*2
$MinsForNorWReportsToBeConsideredActiveNighttime = $MinsForNorWReportsToBeConsideredActive*2
#>
## END OF ADMIN/SRIPT WRITER VARIABLES ##
### END OF GLOBAL VARIABLES ###
### END OF STATIC VARIABLS (PRE CONFIG FILE!) ###

#Change the working Directory to the one set in the Config File (or the static one if none set)
cd $workingDir
write-host "workingDir updated to: $($workingDir)"

#Get the current time
$theCurrentTime = Get-Date -Format HH:mm

#Output Script Details
Write-Host "SCRIPT DETAILS - Who Am I?" -ForegroundColor Cyan
Write-Host "Script Name: $($scriptName)"
Write-Host "Config File: $($ConfigFile)"
Write-Host "Calling User: $($whoIsTheCallingUser)"

## ADMIN/SRIPT WRITER VARIABLES ##
Write-Host "EFFECTIVE ADMIN/SCRIPTER VARIABLES AFTER EVAULATING DEFAULTS AND CONFIG FILE" -ForegroundColor Red
Write-Host "workingDir: $($workingDir)"
Write-Host "instanceSpecificWorkingDir: $($instanceSpecificWorkingDir)"
Write-Host "RunSpeedLog: $($RunSpeedLog)"
Write-Host "LogPath: $($LogPath)"
Write-Host "stateFile: $($stateFile)"
#Get-Culture
Write-Host "scheduledTaskName: $($scheduledTaskName)"
#Set at this level so they are global and can then be reused by other functions#
#Write-Host "MsgBody: $($MsgBody)"
#Write-Host "functionName: $($functionName)"
#$dateDiff = 1
#Write-Host "functionOutputCSV: $($functionOutputCSV)"
#$functionReturn = "No Data"
#END OF Set at this level so they are global and can then be reused by other functions#
<#
$NoWorkflowRowsNighttime = $NoWorkflowRows*2
$MinsForNorWReportsToBeConsideredActiveNighttime = $MinsForNorWReportsToBeConsideredActive*2
#>

#Check if instanceSpecificWorkingDir Exists
Write-Host "Check instanceSpecificWorkingDir exists and if not, create it..."
if (!(Test-Path $instanceSpecificWorkingDir -PathType Container)) {
    Write-Host "$($instanceSpecificWorkingDir) - Path DOES NOT exist, creating..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $instanceSpecificWorkingDir
}

#Check if statefile Exists
Write-Host "Check/Create a state file - to determin if this is the first run of this version of the script..."
if (!(Test-Path $stateFile))
{
    #New-Item -path C:\Share -name sample.txt -type "file" -value "my new text"
    Write-Host "$($stateFile) - There is no stateFile, creating..." -ForegroundColor Yellow
    New-Item -path $instanceSpecificWorkingDir -name "$($scriptNameNoExt)_$($configFileNoExt)_stateFile.ps1" -type "file" #-value '$firstRun = 1'
    Add-Content -path $stateFile -value '$firstRunComplete = 0'
}

#Evaluate State File
cd $instanceSpecificWorkingDir
$stateFileNameOnly = "$($scriptNameNoExt)_$($configFileNoExt)_stateFile.ps1"
. .\$stateFileNameOnly
cd $workingDir
write-host "workingDir updated to: $($workingDir)"

#Compare the current time to the business hours and update any parameters required
if (($theCurrentTime -lt $customerBusinessHoursStart) -or ($theCurrentTime -gt $customerBusinessHoursEnd)) {
        Write-Host "We are outside of Business Hours; decreasing monitor sensitivity!" -ForegroundColor Green
        $outOfHoursMode = 1

        #Higher Value = Less sensitive:
        #Queues
        $p1CoreNumberOfMinutes = $p1CoreNumberOfMinutes * 2 #number of minutes an P1 Agresso Core Queue can be running without updating
        $UBW_Queue_Scheduler_Minutes = $UBW_Queue_Scheduler_Minutes * 2 
        $UBW_Queue_TPS_Minutes = $UBW_Queue_TPS_Minutes * 2 
        $p2CoreNumberOfMinutes = $p2CoreNumberOfMinutes * 2 #number of minutes an P2 Agresso Core Queue can be running without updating
        $UBW_Queue_ACRALS_Minutes = $UBW_Queue_ACRALS_Minutes * 2
        $UBW_Queue_ALGIPS_Minutes = $UBW_Queue_ALGIPS_Minutes * 2
        $UBW_Queue_ALGSPS_Minutes = $UBW_Queue_ALGSPS_Minutes * 2
        $UBW_Queue_AMS_Minutes = $UBW_Queue_AMS_Minutes * 2
        $UBW_Queue_RESRATE_Minutes = $UBW_Queue_RESRATE_Minutes * 2
        $UBW_Queue_DWS_Minutes = $UBW_Queue_DWS_Minutes * 2
        $UBW_Queue_IMS_Minutes = $UBW_Queue_IMS_Minutes * 2
        $p3CoreNumberOfMinutes = $p3CoreNumberOfMinutes * 2 #number of minutes an P2 Agresso Core Queue can be running without updating
        $UBW_Queue_AINAPS_Minutes = $UBW_Queue_AINAPS_Minutes * 2

        #Ordered Reports
        $MinsForNorWReportsToBeConsideredActive = $MinsForNorWReportsToBeConsideredActive * 2 #$MinsForNorWReportsToBeConsideredActive = "MINUTES_FOR_N_OR_W_REPORTS_TO_BE_CONSIDERED_ACTIVE"; Lower number=More Sensitive 
        #Workflow Service
        $NoWorkflowRows = $NoWorkflowRows * 2 # Lower number=More sensitive
        #Agresso AMS Service Email Queue        
        $maxFrequencyOfAlarms = $maxFrequencyOfAlarms * 2 # Higher = less sensative
        
                        
        #Lower Value = Less sensitive:
        #Ordered Reports
        $NoDaysforNorWReportsOrderedToBeMonitored = $NoDaysforNorWReportsOrderedToBeMonitored / 2 #$NoDaysforNorWReportsOrderedToBeMonitored = "DAYS_FOR_N_OR_W_REPORTS_ORDERED_TO_BE_MONITORED"; Higher number=More Sensitive
        #Agresso AMS Service Email Queue
        $MinsForAMSEmailQueue = $MinsForAMSEmailQueue / 2 # Higher number=More sensitive
    } 
    <#else {
        Write-host "Business hours, Continue with normal thresholds!" -ForegroundColor red
    }#>

#Output Effective Starting Variables
<#Write-Host "EFFECTIVE USER VARIABLES AFTER EVAULATING DEFAULTS AND CONFIG FILE" -ForegroundColor Yellow
Write-Host "The current time: $($theCurrentTime)" -ForegroundColor Yellow
#General Customer Info
Write-Host "customerName: $($customerName)"
Write-Host "customerBusinessHoursStart: $($customerBusinessHoursStart)"
Write-Host "customerBusinessHoursEnd: $($customerBusinessHoursEnd)"
#Email Settings
Write-Host "smtpServer: $($smtpServer)"
Write-Host "mailSender: $($mailSender)"
Write-Host "mailRecipients: $($mailRecipients)"
#Database and Business Server
Write-Host "AgressoDBServerName: $($AgressoDBServerName)"
Write-Host "AgressoDBName: $($AgressoDBName)"
Write-Host "AgressoLogicalServerName: $($AgressoLogicalServerName)"
#Queues
Write-Host "p1CoreNumberOfMinutes: $($p1CoreNumberOfMinutes)"
Write-Host "UBW_Queue_Scheduler_Minutes: $($UBW_Queue_Scheduler_Minutes)"
Write-Host "UBW_Queue_TPS_Minutes: $($UBW_Queue_TPS_Minutes)"
Write-Host "UBW_Queue_ACRALS_Minutes: $($UBW_Queue_ACRALS_Minutes)"
Write-Host "p2CoreNumberOfMinutes: $($p2CoreNumberOfMinutes)"
#UBW_Queue_ACRALS_Minutes
#UBW_Queue_ALGIPS_Minutes
#UBW_Queue_ALGSPS_Minutes
#UBW_Queue_AMS_Minutes
#UBW_Queue_RESRATE_Minutes
#UBW_Queue_DWS_Minutes
#UBW_Queue_IMS_Minutes
#UBW_Queue_AINAPS_Minutes
Write-Host "p3CoreNumberOfMinutes: $($p3CoreNumberOfMinutes)"
#Ordered Reports
Write-Host "NoDaysforNorWReportsOrderedToBeMonitored: $($NoDaysforNorWReportsOrderedToBeMonitored)"
Write-Host "MinsForNorWReportsToBeConsideredActive: $($MinsForNorWReportsToBeConsideredActive)"
#Workflow Service
Write-Host "NoWorkflowRows: $($NoWorkflowRows)"
#Agresso AMS Service Email Queue
Write-Host "MinsForAMSEmailQueue: $($MinsForAMSEmailQueue)"
#>
#Get-Variable | Select Name,Value
Get-Variable theCur* | Select Name,Value
Get-Variable customer* | Select Name,Value
Get-Variable smtp* | Select Name,Value
Get-Variable mail* | Select Name,Value
Get-Variable Agresso* | Select Name,Value
Get-Variable UBW* | Select Name,Value
Get-Variable NoDays* | Select Name,Value
Get-Variable MinsFor* | Select Name,Value
Get-Variable NoWorkf* | Select Name,Value


### FUNCTIONS ###
Function FirstRun {
    Write-Host "This is the first run of this script, I hope you're running it as the intended service account! (that is a local admin and has READ permissions on the database)" -ForegroundColor Red 
    Write-Host "Press Control-C if not to break the script and start again!" -ForegroundColor Red
    pause
    
    #Check if Scheduled Task Group created
    Write-Host "Check/Create Scheduled Task for future Runs"
    Try {
        $scheduleObject = New-Object -ComObject schedule.service
        $scheduleObject.connect()
        $rootFolder = $scheduleObject.GetFolder("\")
        $rootFolder.CreateFolder("QTC")
    } Catch { }

    #Check if scheduled task XML file exists and delete if it does
    Write-Host "Check/Create a scheudled Task xml file..."
    if (Test-Path "$($scheduledTaskName).xml") {
        Remove-Item "$($scheduledTaskName).xml" -Force
    }

        #Create a new XML file
    New-Item -path $workingDir -name "$($scheduledTaskName).xml" -type "file" #-value '$firstRun = 1'
    Add-Content -path "$($scheduledTaskName).xml" -value '<?xml version="1.0" encoding="UTF-16"?>'
    Add-Content -path "$($scheduledTaskName).xml" -value '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'
    Add-Content -path "$($scheduledTaskName).xml" -value "  <RegistrationInfo>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <Date>$(Get-date -Format yyyy-MM-ddTHH:mm:ss)</Date>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <Author>QuickThink Cloud Ltd.</Author>"
    Add-Content -path "$($scheduledTaskName).xml" -value "  </RegistrationInfo>"
    Add-Content -path "$($scheduledTaskName).xml" -value "  <Triggers>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <CalendarTrigger>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <Repetition>"
    Add-Content -path "$($scheduledTaskName).xml" -value "        <Interval>PT5M</Interval>"
    Add-Content -path "$($scheduledTaskName).xml" -value "        <StopAtDurationEnd>false</StopAtDurationEnd>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      </Repetition>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <StartBoundary>$(Get-date -Format yyyy-MM-ddT)08:00:00</StartBoundary>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <Enabled>true</Enabled>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <ScheduleByWeek>"
    Add-Content -path "$($scheduledTaskName).xml" -value "        <DaysOfWeek>"
    Add-Content -path "$($scheduledTaskName).xml" -value "          <Sunday />"
    Add-Content -path "$($scheduledTaskName).xml" -value "          <Monday />"
    Add-Content -path "$($scheduledTaskName).xml" -value "          <Tuesday />"
    Add-Content -path "$($scheduledTaskName).xml" -value "          <Wednesday />"
    Add-Content -path "$($scheduledTaskName).xml" -value "          <Thursday />"
    Add-Content -path "$($scheduledTaskName).xml" -value "          <Friday />"
    Add-Content -path "$($scheduledTaskName).xml" -value "          <Saturday />"
    Add-Content -path "$($scheduledTaskName).xml" -value "        </DaysOfWeek>"
    Add-Content -path "$($scheduledTaskName).xml" -value "        <WeeksInterval>1</WeeksInterval>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      </ScheduleByWeek>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    </CalendarTrigger>"
    Add-Content -path "$($scheduledTaskName).xml" -value "  </Triggers>"
    Add-Content -path "$($scheduledTaskName).xml" -value "  <Principals>"
    Add-Content -path "$($scheduledTaskName).xml" -value '    <Principal id="Author">'
    Add-Content -path "$($scheduledTaskName).xml" -value "      <UserId>$($whoIsTheCallingUser)</UserId>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <LogonType>Password</LogonType>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <RunLevel>HighestAvailable</RunLevel>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    </Principal>"
    Add-Content -path "$($scheduledTaskName).xml" -value "  </Principals>"
    Add-Content -path "$($scheduledTaskName).xml" -value "  <Settings>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <AllowHardTerminate>true</AllowHardTerminate>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <StartWhenAvailable>false</StartWhenAvailable>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <IdleSettings>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <StopOnIdleEnd>true</StopOnIdleEnd>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <RestartOnIdle>false</RestartOnIdle>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    </IdleSettings>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <AllowStartOnDemand>true</AllowStartOnDemand>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <Enabled>true</Enabled>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <Hidden>false</Hidden>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <RunOnlyIfIdle>false</RunOnlyIfIdle>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <WakeToRun>false</WakeToRun>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    <Priority>7</Priority>"
    Add-Content -path "$($scheduledTaskName).xml" -value "  </Settings>"
    Add-Content -path "$($scheduledTaskName).xml" -value '  <Actions Context="Author">'
    Add-Content -path "$($scheduledTaskName).xml" -value "    <Exec>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <Command>powershell</Command>"
    #$configFileNoExt = "IAmTesting"
    #Write-Host "'      <Arguments>-command ""&amp; ''C:\QTCScripts\Scheduled\AgressoMonitoring\Checks\UBWMonitoring.ps1'' ''$($configFileNoExt)''</Arguments>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <Arguments>-command ""&amp; '$($workingDir)UBWMonitoring.ps1' '$($configFileNoExt)'</Arguments>"
    #Add-Content -path "$($scheduledTaskName).xml" -value "      <Arguments>-command "&amp; ''C:\QTCScripts\Scheduled\AgressoMonitoring\Checks\UBWMonitoring.ps1'' ''$($configFileNoExt)''"</Arguments>"
    Add-Content -path "$($scheduledTaskName).xml" -value "      <WorkingDirectory>$($workingDir)</WorkingDirectory>"
    Add-Content -path "$($scheduledTaskName).xml" -value "    </Exec>"
    Add-Content -path "$($scheduledTaskName).xml" -value "  </Actions>"
    Add-Content -path "$($scheduledTaskName).xml" -value "</Task>"
    
    #Check if scheduled task XML file exists and delete if it does
    Write-Host "Check/Create a scheudled Task xml file..."
    if (Test-Path "UBWMonitoringEnabler.xml") {
        Remove-Item "UBWMonitoringEnabler.xml" -Force
    }

    #Create a new XML file for the enabler
    New-Item -path $workingDir -name "UBWMonitoringEnabler.xml" -type "file" #-value '$firstRun = 1'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '<?xml version="1.0" encoding="UTF-16"?>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  <RegistrationInfo>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value "    <Date>$(Get-date -Format yyyy-MM-ddTHH:mm:ss)</Date>"
    #Add-Content -path "UBWMonitoringEnabler.xml" -value '    <Date>2016-12-16T13:23:52.9198375</Date>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <Author>QuickThink Cloud Ltd.</Author>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  </RegistrationInfo>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  <Triggers>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <CalendarTrigger>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      <Repetition>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '        <Interval>PT2H</Interval>'
    #Add-Content -path "UBWMonitoringEnabler.xml" -value '        <Duration>P1D</Duration>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '        <Duration>PT12H</Duration>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '        <StopAtDurationEnd>false</StopAtDurationEnd>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      </Repetition>'
    #Add-Content -path "UBWMonitoringEnabler.xml" -value '      <StartBoundary>2016-12-16T08:00:00</StartBoundary>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value "      <StartBoundary>$(Get-date -Format yyyy-MM-ddT)08:00:00</StartBoundary>"
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      <Enabled>true</Enabled>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      <ScheduleByWeek>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '        <DaysOfWeek>'
    #Add-Content -path "UBWMonitoringEnabler.xml" -value '          <Sunday />'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '          <Monday />'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '          <Tuesday />'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '          <Wednesday />'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '          <Thursday />'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '          <Friday />'
    #Add-Content -path "UBWMonitoringEnabler.xml" -value '          <Saturday />'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '        </DaysOfWeek>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '        <WeeksInterval>1</WeeksInterval>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      </ScheduleByWeek>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    </CalendarTrigger>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  </Triggers>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  <Principals>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <Principal id="Author">'
    #Add-Content -path "UBWMonitoringEnabler.xml" -value '      <UserId>RDQTC\SVC_AgressoMonitor</UserId>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value "      <UserId>$($whoIsTheCallingUser)</UserId>"
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      <LogonType>Password</LogonType>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      <RunLevel>HighestAvailable</RunLevel>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    </Principal>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  </Principals>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  <Settings>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <AllowHardTerminate>true</AllowHardTerminate>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <StartWhenAvailable>false</StartWhenAvailable>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <IdleSettings>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      <StopOnIdleEnd>true</StopOnIdleEnd>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      <RestartOnIdle>false</RestartOnIdle>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    </IdleSettings>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <AllowStartOnDemand>true</AllowStartOnDemand>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <Enabled>true</Enabled>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <Hidden>false</Hidden>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <RunOnlyIfIdle>false</RunOnlyIfIdle>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <WakeToRun>false</WakeToRun>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <Priority>7</Priority>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  </Settings>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  <Actions Context="Author">'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    <Exec>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '      <Command>powershell</Command>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value "      <Arguments>-command ""&amp; '$($workingDir)UBWMonitoringEnabler.ps1'</Arguments>"
    Add-Content -path "UBWMonitoringEnabler.xml" -value "      <WorkingDirectory>$($workingDir)</WorkingDirectory>"
    Add-Content -path "UBWMonitoringEnabler.xml" -value '    </Exec>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '  </Actions>'
    Add-Content -path "UBWMonitoringEnabler.xml" -value '</Task>'


    #Register Scheduled Task
    $whoIsTheCallingUser
    Write-Host "Please make sure the intended account ($($whoIsTheCallingUser)) is a local admin AND has read access to the database you are monitoring!" -ForegroundColor Yellow
    $pass = Read-Host "Please enter the password for user $($whoIsTheCallingUser)" -AsSecureString
    $passClear = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
    Try {
        Register-ScheduledTask -Xml (get-content "$($scheduledTaskName).xml" | out-string) -TaskName $scheduledTaskName -User $whoIsTheCallingUser -Password $passClear –Force -TaskPath "QTC"
    } Catch {}
    Try {
        Register-ScheduledTask -Xml (get-content "UBWMonitoringEnabler.xml" | out-string) -TaskName "UBWMonitoringEnabler" -User $whoIsTheCallingUser -Password $passClear –Force -TaskPath "QTC"
    } Catch {}
    $passClear = ""

    #Check if Event Log Source Exists and Create if not
    $eventLogSource = "QTC"
    $sourceExists = Get-EventLog -LogName * |
        ForEach-Object {
        $LogName = $_.Log;Get-EventLog -LogName $LogName -ErrorAction SilentlyContinue |
        Where-object {$_.Source -eq "$($eventLogSource)"} |
        Select-Object Source -Unique
        #Select-Object @{Name= "Log Name";Expression = {$LogName}}, Source -Unique
        }
    #$sourceExists.Source
    if ($sourceExists.Source -ne $eventLogSource) {
        Write-host "Event Log Source $($eventLogSource) does not exist, creating and writing a test event to it..."
        Try {
            New-EventLog -Source QTC -LogName Application
            Write-EventLog -logname Application -source "QTC" -eventID 1 -entrytype Information -message "This is a QTC Test Event, and is used only to test writing to the event log."  -Category 0
        }
        Catch {
            #EventLog Source already created
            Write-EventLog -logname Application -source "QTC" -eventID 1 -entrytype Information -message "This is a QTC Test Event, and is used only to test writing to the event log."  -Category 0
        }
    } Else {
        Write-host "Event Log Source $($eventLogSource) already exists."
    }
} #End Function
Function StartStateFile {
    Write-Host "Recreating State File"
    if (Test-Path $stateFile)
    {
        Remove-Item $stateFile -Force
    }
    
    New-Item -path $instanceSpecificWorkingDir -name "$($scriptNameNoExt)_$($configFileNoExt)_stateFile.ps1" -type "file" #-value '$firstRun = 1'
    $value = "#State File Updated: $(Get-Date -format 'dd/MM/yyyy HH:mm:ss')"
    Add-Content -path $stateFile -Value $value
    Add-Content -path $stateFile -Value '$firstRunComplete = 1'
} #End Function
Function EndStateFile {
    $value = "#End of State File Update: $(Get-Date -format 'dd/MM/yyyy HH:mm:ss')"
    Add-Content -path $stateFile -value $value
} #End Function
Function SetupStateFile {
    StartStateFile
    
    #$stateFileBody | Add-Content -Path $statefile
    #Add-Content -path $stateFile -Value $value

    #Add-Content -path $stateFile -Value $stateFileBody.ToString()
    #Add-Content -path $stateFile -Value "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"

    EndStateFile
} #End Function
Function AlertTriggered {
        Write-Host $MsgBody
        Add-Content $LogPath $MsgBody
        $MsgSubject = "MONITORING | $($AgressoDBServerName) | $($AgressoLogicalServerName) | $($AgressoDBName) | $($functionName)"
        if ($emailAlerts -eq $true) {
            Send-MailMessage –From $mailSender –To $mailRecipients –Subject $MsgSubject –Body $MsgBody -Attachments $functionOutputCSV –SmtpServer $smtpServer
        }
        #Log in stateFile when it was triggered/update statefile with new variable?
        if ($outOfHoursMode -eq 1) {
        }
        
        #Write-EventLog -logname Application -source "QTC" -eventID 1 -entrytype Information -message "This is a QTC Test Event, and is used only to test writing to the event log."  -Category 0
        Write-EventLog -logname Application -source "QTC" -eventID $eventLogID -entrytype Warning -message "$($eventLogMessage)"  -Category 0
        Get-ScheduledTask $scheduledTaskName | Disable-ScheduledTask
} #End Function
Function AlertTriggeredNoDisableSchedTask {
        Write-Host $MsgBody
        Add-Content $LogPath $MsgBody
        $MsgSubject = "MONITORING | $($AgressoDBServerName) | $($AgressoLogicalServerName) | $($AgressoDBName) | $($functionName)"
        if ($emailAlerts -eq $true) {
            Send-MailMessage –From $mailSender –To $mailRecipients –Subject $MsgSubject –Body $MsgBody -Attachments $functionOutputCSV –SmtpServer $smtpServer
        }
        #Log in stateFile when it was triggered/update statefile with new variable?
        if ($outOfHoursMode -eq 1) {
        }
        
        #Write-EventLog -logname Application -source "QTC" -eventID 1 -entrytype Information -message "This is a QTC Test Event, and is used only to test writing to the event log."  -Category 0
        Write-EventLog -logname Application -source "QTC" -eventID $eventLogID -entrytype Warning -message "$($eventLogMessage)"  -Category 0
        #Get-ScheduledTask $scheduledTaskName | Disable-ScheduledTask
} #End Function
Function UpdatesAvailable {

    #check that the destination directory exists
    if (!(Test-Path $updateDirectoryName)) {  
        #CreateDirectory
        New-Item -Name "$($updateDirectoryName)" -ItemType "directory"
    }
    
    #check the latest update file exists
    if (!(Test-Path "$($updateDirectoryName)\$($updatedVersionName)")) {
        
        #download the latest
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
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
    $fullSourcePath = "$(Get-Location)\$SourcePath"
    if (Test-Path "$fullSourcePath")
    {
    #The path of THIS script
    $CurrentScript = $MyInvocation.ScriptName
        if (!($SourcePath -eq $CurrentScript ))
        {
            if ($(Get-Item $SourcePath).LastWriteTimeUtc -gt $(Get-Item $CurrentScript ).LastWriteTimeUtc)
            {
                write-host "Updating to version: $($scriptVersion) ..." -ForegroundColor Green
                Start-Sleep -Seconds 3
                Copy-Item $SourcePath $CurrentScript -Force

                $updateNotes= "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'): $($env:COMPUTERNAME) Updated $($MyInvocation.ScriptName) to Script Version: $($scriptVersion))"   
                $me = [io.path]::GetFileNameWithoutExtension($MyInvocation.ScriptName)
                $updateFile = "$($customerName)_$($env:COMPUTERNAME)_$($me)_Update.log" 

                Add-Content .\$updateFile $updateNotes
                #. .\dropbox-upload.ps1 $updateFile  "/$($updateFile)"
                Send-SFTPData -sourceFiles $updateFile -credential $SFTPCreds -SFTProotDir "/licensing"
    
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


#CHECK/ALARM FUNCTIONS

Function UBW_Queue_Scheduler {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_Scheduler_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('Scheduler')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_SchedulerTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_SchedulerTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_SchedulerTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_SchedulerTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_SchedulerTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_SchedulerLastTriggeredAlarm
        if ((Get-Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_SchedulerLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_SchedulerLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_SchedulerLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            } #End if else
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_SchedulerLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_SchedulerLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_SchedulerLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_SchedulerLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -path $stateFile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_SchedulerTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            } # End if else
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_SchedulerLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_SchedulerTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        #Write-Host $_.Exception.GetType().FullName, $_.Exception.Message
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
Function UBW_Queue_TPS {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_TPS_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('TPS')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_TPSTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_TPSTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_TPSTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_TPSTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_TPSTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_TPSLastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_TPSLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_TPSLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_TPSLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            } #End if else

            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_TPSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_TPSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_TPSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_TPSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_TPSTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            } #End if else
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_TPSLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_TPSTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
#Priority 2 Queues
Function UBW_Queue_ACRALS {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_ACRALS_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('ACRALS')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_ACRALSTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_ACRALSTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_ACRALSTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_ACRALSTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_ACRALSTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_ACRALSLastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_ACRALSLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_ACRALSLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_ACRALSLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            } #End if else
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_ACRALSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_ACRALSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_ACRALSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_ACRALSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_ACRALSTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            } #End if else
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_ACRALSLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_ACRALSTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
Function UBW_Queue_ALGIPS {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_ALGIPS_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('ALGIPS')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_ALGIPSTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_ALGIPSTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_ALGIPSTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_ALGIPSTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_ALGIPSTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_ALGIPSLastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_ALGIPSLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_ALGIPSLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_ALGIPSLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            } #End if else
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_ALGIPSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_ALGIPSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_ALGIPSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_ALGIPSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_ALGIPSTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            }
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_ALGIPSLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_ALGIPSTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
Function UBW_Queue_ALGSPS {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_ALGSPS_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('ALGSPS')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_ALGSPSTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_ALGSPSTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_ALGSPSTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_ALGSPSTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_ALGSPSTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_ALGSPSLastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_ALGSPSLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_ALGSPSLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_ALGSPSLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            } #End If else
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_ALGSPSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_ALGSPSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_ALGSPSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_ALGSPSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_ALGSPSTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
            }
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_ALGSPSLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_ALGSPSTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
Function UBW_Queue_AMS {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_AMS_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('AMS')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_AMSTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_AMSTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_AMSTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_AMSTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_AMSTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_AMSLastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_AMSLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_AMSLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_AMSLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            }
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_AMSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_AMSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_AMSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_AMSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_AMSTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            }
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_AMSLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_AMSTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
Function UBW_Queue_RESRATE {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_RESRATE_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('RESRATE')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_RESRATETriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_RESRATETriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_RESRATETriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_RESRATETriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_RESRATETriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_RESRATELastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_RESRATELastTriggeredAlar)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_RESRATELastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_RESRATELastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            } 
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_RESRATELastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_RESRATELastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_RESRATELastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_RESRATELastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_RESRATETriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            } 
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_RESRATELastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_RESRATETriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
Function UBW_Queue_DWS {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_DWS_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('DWS')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_DWSTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_DWSTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_DWSTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_DWSTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_DWSTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_DWSLastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_DWSLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_DWSLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_DWSLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            } 
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_DWSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_DWSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_DWSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_DWSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_DWSTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            }
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_DWSLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_DWSTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
Function UBW_Queue_IMS {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_IMS_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('IMS')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_IMSTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_IMSTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_IMSTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_IMSTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_IMSTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_IMSLastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_IMSLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_IMSLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_IMSLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            }
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_IMSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_IMSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_IMSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_IMSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_IMSTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            } 
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_IMSLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_IMSTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function
#Priority 3 Queues
Function UBW_Queue_AINAPS {
    try {

        $Date = Get-Date
        $functionName = "$($MyInvocation.MyCommand.Name)"
        $dateDiff = $UBW_Queue_AINAPS_Minutes
        $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
        $sqlQry = "USE $AgressoDBName
GO
SELECT * FROM (
SELECT distinct datediff(minute,getutcdate(),max(end_time)) AS dateDifference, server_queue, server_name 
FROM aagprocessinfo 
WHERE server_queue in ('AINAPS')
GROUP BY server_queue, server_name
) X
WHERE dateDifference <= -$dateDiff
AND server_name = '$AgressoLogicalServerName'
"

        #Check if this has triggered before / is this a re-check?
        if ($UBW_Queue_AINAPSTriggeredCount -gt 0) {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_AINAPSTriggeredCount) times, checking if need to increase alarm frequency." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) has previously alarmed $($UBW_Queue_AINAPSTriggeredCount) times, checking if need to increase alarm frequency." # Log to LogFile
            if (($numHoursToReArm - $UBW_Queue_AINAPSTriggeredCount) -le $maxFrequencyOfAlarms) {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) is already alarming as often as the maxFrequencyOfAlarms, every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } else { 
                $numHoursToReArm = $numHoursToReArm - $UBW_Queue_AINAPSTriggeredCount
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." -ForegroundColor Red # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) current alarm frequency is every $($numHoursToReArm) hours but this will become more frequent up until the point where it's alarming every $($maxFrequencyOfAlarms) hours." # Log to LogFile
            } #End else    
        } #End If
    
        #Check if this has triggered recently, and if so, check if it's self reset but DO NOT alarm!
        #Compare-Object ($Date).AddHours(-2) $UBW_Queue_AINAPSLastTriggeredAlarm
        if (($Date).AddHours(-$numHoursToReArm) -lt ($UBW_Queue_AINAPSLastTriggeredAlarm)) #Check but DO NOT alarm!
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as as alerted too recently; at $($UBW_Queue_AINAPSLastTriggeredAlarm)." -ForegroundColor Red # Log to Screen
            Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking but NO alert as alerted too recently; at $($UBW_Queue_AINAPSLastTriggeredAlarm)." # Log to LogFile
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            }
            if ($functionReturn.ItemArray.Count -lt 1) #Self resolved
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_AINAPSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # $((Get-Date($UBW_Queue_AINAPSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) alert last triggered at $($UBW_Queue_AINAPSLastTriggeredAlarm) but has subsequently resolved/cleared. This check will resume on the next run." # at $((Get-Date($UBW_Queue_AINAPSLastTriggeredAlarm)).Addhours($numHoursToReArm))" # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #This is a reset value as the alarm self resolved." #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #This is a reset value as the alarm self resolved."
            } Else { #Still an issue
                $triggeredCount = $UBW_Queue_AINAPSTriggeredCount + 1
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile
            }
        } #End if
        else #Run the Check
        {
            Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): Checking..." -ForegroundColor Green # Log to Screen
            if ($ssmodule22plus) {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
            } Else {
                $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
            } 
            if ($functionReturn.ItemArray.Count -lt 1) #All OK
            {
                Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to Screen
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName): All ok." # Log to LogFile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($UBW_Queue_AINAPSLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates stateFile and resets the TriggeredCount
            } else {
                $triggeredCount = $UBW_Queue_AINAPSTriggeredCount + 1
                #$functionReturn | ft
                #Add-Content $LogPath "$($functionReturn | ft)"
                Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionReturn | ft)"

                $functionReturn | export-csv $functionOutputCSV

                $MsgBody = "Date: " + $Date + "`n" 
                $MsgBody += "Check: " + $functionName + "`n" 
                $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
                $MsgBody += "`n"
                $MsgBody += "Database Server: $($AgressoDBServerName) `n"
                $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
                $MsgBody += "Database Name: $($AgressoDBName) `n"
                $MsgBody += "`n"
                #$MsgBody += "To investigate, please run the following query: `n "
                #$MsgBody += "$($sqlQry)"
        
                #if ($outOfHoursMode -eq 1) {
                #}
            
                #Update Statefile
                Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"" #updates stateFile to state when it was last triggered
                Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $($triggeredCount)" #updates the TriggeredCount in the stateFile

                #Parameters for AlertTriggered and call AlertTriggered
                $eventLogID = 3
                $eventLogMessage = $MsgBody
                # AlertTriggeredNoDisableSchedTask
                AlertTriggered
            } #End Else
        } #End Else
    } Catch {
        Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to Screen
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
    } # End Catch
} #End of Function

<#Priority 1 Core Functions#
Function Agresso_Queues_Scheduler_TPS {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $dateDiff = $p1CoreNumberOfMinutes
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
    $sqlQry = "
            Use $AgressoDBName
            go
            select * from (
            select distinct datediff(minute,getutcdate(),max(end_time)) as dateDifference, server_queue, server_name 
            from aagprocessinfo where server_queue in ('Scheduler','TPS')
            group by server_queue, server_name
            ) X
            where dateDifference <= -$dateDiff
            and server_name = '$AgressoLogicalServerName'
            "
    $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)" 
    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        $functionReturn | ft
        Add-Content $LogPath "$($functionReturn | ft)"
        $functionReturn | export-csv $functionOutputCSV

        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "To investigate, please run the following query: `n "
        $MsgBody += "$($sqlQry)"

        #Log in stateFile when it was triggered
        #update statefile with new variable?
        if ($outOfHoursMode -eq 1) {

        }

        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 3
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function Agresso_Queues_Scheduler_TPS
#>
<#Priority 2 Core Functions#
Function Agresso_Queues_ACRALS_ALGIPS_ALGSPS_AMS_RESRATE_DWS_IMS {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $dateDiff = $p2CoreNumberOfMinutes
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
    $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "
    Use $AgressoDBName
    go
    select * from (
    select distinct datediff(minute,getutcdate(),max(end_time)) as dateDifference, server_queue, server_name 
    from aagprocessinfo where server_queue in ('ACRALS','ALGIPS','ALGSPS','AMS','RESRATE','DWS','IMS')
    group by server_queue, server_name
    ) X
    where dateDifference <= -$dateDiff
    and server_name = '$AgressoLogicalServerName'
    "  
    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        #$myOutput = "Records: " + $AAGServerQueueReturn.count + "`n"
        #write-host $myOutput
        $functionReturn | ft
        $functionReturn | export-csv $functionOutputCSV
        #$functionReturn | ft #fl #Select bflag,controller_type
        #$functionReturn.Get(0) | ft
        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "To investigate, please run the following query: `n "
        $MsgBody += "
Use $AgressoDBName
go
select * from (
select distinct datediff(minute,getutcdate(),max(end_time)) as dateDifference, server_queue, server_name 
from aagprocessinfo where server_queue in ('ACRALS','ALGIPS','ALGSPS','AMS','RESRATE','DWS','IMS')
group by server_queue, server_name
) X
where dateDifference <= -$dateDiff
and server_name = '$AgressoLogicalServerName'
"
        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 4
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function Agresso_Queues_ACRALS_ALGIPS_ALGSPS_AMS_RESRATE_DWS_IMS
#>
<#Priority 3 Core Functions#
Function Agresso_Queues_AINAPS {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $dateDiff = $p3CoreNumberOfMinutes
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
    $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "
    Use $AgressoDBName
    go
    select * from (
    select distinct datediff(minute,getutcdate(),max(end_time)) as dateDifference, server_queue, server_name 
    from aagprocessinfo where server_queue in ('AINAPS')
    group by server_queue, server_name
    ) X
    where dateDifference <= -$dateDiff
    and server_name = '$AgressoLogicalServerName'
    " 
    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        #$myOutput = "Records: " + $AAGServerQueueReturn.count + "`n"
        #write-host $myOutput
        $functionReturn | ft
        $functionReturn | export-csv $functionOutputCSV
        #$functionReturn | ft #fl #Select bflag,controller_type
        #$functionReturn.Get(0) | ft
        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "To investigate, please run the following query: `n "
        $MsgBody += "
Use $AgressoDBName
go
select * from (
select distinct datediff(minute,getutcdate(),max(end_time)) as dateDifference, server_queue, server_name 
from aagprocessinfo where server_queue in ('AINAPS')
group by server_queue, server_name
) X
where dateDifference <= -$dateDiff
and server_name = '$AgressoLogicalServerName'
"
        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 5
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function Agresso_Queues_AINAPS
#>

Function Agresso_Reports_Stuck_at_N_or_W {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
    $sqlQry = "Use $AgressoDBName
                go
                SELECT DATEDIFF(MINUTE,t.invoke_time,GETDATE()) as mins_since_invoked, 
                t.user_id,t.status,t.server_queue,t.report_name,t.orderno,  
                t.invoke_time,t.date_started,t.client,
                @@SERVERNAME as server_name, agrtid
                FROM acrrepord t 
                WHERE t.status in ('W','N')
                AND FORMAT(CONVERT(DATETIME, t.order_date), 'yyyyMMdd')>=FORMAT(CONVERT(DATETIME,GETDATE()-$NoDaysforNorWReportsOrderedToBeMonitored,110), 'yyyyMMdd')
                AND DATEDIFF(MINUTE,t.invoke_time,GETDATE()) > $MinsForNorWReportsToBeConsideredActive
                --AND report_name = 'AG01'
                --ORDER BY date_started desc
                "
    
    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }
    
     
    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        <##$myOutput = "Records: " + $AAGServerQueueReturn.count + "`n"
        #write-host $myOutput#>
        $functionReturn | ft
        $functionReturn | export-csv $functionOutputCSV
	$functionReturnB = $functionReturn | select report_name, orderno, status, invoke_time, agrtid | Select-Object -First 5 | ft -autosize | out-string
        <#$functionReturn | ft #fl #Select bflag,controller_type
        #$functionReturn.Get(0) | ft#>
        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "TOP 5 Records:"
	$MsgBody += "$($functionReturnB)"
        $MsgBody += "`n"
        #$MsgBody += "To investigate, please run the following query: `n "
        #$MsgBody += "$($sqlQry)"

        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 6
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function 
Function Agresso_Workflow_Service {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"

    $sqlQry = "
        Use $AgressoDBName
        go
        select count(*) as totalRows from awftrans
        where status = 'N' and priority > -1
        having totalRows > $NoWorkflowRows
        "

    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {

        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn + " (Please see attached csv for details) `n"
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"

        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 7
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function 
Function Agresso_AMS_Service_Email_Queue {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $dateDiff = $MinsForAMSEmailQueue
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"

    $sqlQry = "Use $AgressoDBName
    go
    select max(datediff(minute,created_date,getdate())) as dateDifference 
    from $AgressoDBName.dbo.acrmailqueuehead
    where status in ('N','W')
    having max(datediff(minute,created_date,getdate())) >= $dateDiff
    " 

    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }
    
    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        $functionReturn | ft
        $functionReturn | export-csv $functionOutputCSV

        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"

        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 8
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function 

Function Process_Technical_Error { #THIS was previously called TPS_Stopped_Processing but picked up other queues?
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"

    $sqlQry = "Use $AgressoDBName
        go
        select top 10 server_name,server_queue,report_name,sequence_no,message 
        from aagprocessinfo 
        where message = 'Technical Error'
        and end_time <> '1900-01-01 00:00:00.000'
        and end_time > dateadd(minute,-5,GETUTCDATE())
        and process_type = 'T'
        " 

    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        
        $functionReturn = $functionReturn | ft -autosize | out-string

        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += $functionReturn + "`n"

        $eventLogID = 9
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function 


Function Process_Functional_Error { #THIS was previously called TPS_Stopped_Processing but picked up other queues?

Try{
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"

    $sqlQry = "
        Use $AgressoDBName
        go
        select top 10 server_name,server_queue,report_name,sequence_no,message 
        from aagprocessinfo 
        where message = 'Functional Error'
        and end_time <> '1900-01-01 00:00:00.000'
        and end_time > dateadd(minute,-5,GETUTCDATE())
        and process_type = 'T'
        " 

    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) { # Check OK, reset triggered count and do not alert
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($Process_Functional_ErrorLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0" #updates the TriggeredCount in the stateFile
    } else { # Check not OK but trigger threshold not reached, do not alert
        $triggeredCount = $Process_Functional_ErrorTriggeredCount + 1 
    if ($triggeredCount -lt ($Process_Functional_ErrorTriggerThreshold)) {
        Add-Content $LogPath "$($functionName): Not alerting yet: Trigger count $triggeredCount, threshold $Process_Functional_ErrorTriggerThreshold"
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$($Process_Functional_ErrorLastTriggeredAlarm)`"" #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile    
    } else { # Check not OK, trigger threshold reached, ALERT

        $functionReturn = $functionReturn | ft -autosize | out-string

        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += $functionReturn + "`n"

		$functionReturn | export-csv $functionOutputCSV
        Add-Content $LogPath "$($functionName): ALERTING: Trigger count $triggeredCount, threshold $Process_Functional_ErrorTriggerThreshold"
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')`"" #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = $triggeredCount" #updates the TriggeredCount in the stateFile    
        $eventLogID = 9
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
}
}
Catch {
        Add-Content $LogPath "$_.Exception.GetType().FullName, $_.Exception.Message"
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):$($functionName) was not initialised, initialising now." # Log to LogFile
        Add-Content -Path $statefile "`$$($functionName)LastTriggeredAlarm = `"01/01/2001 00:00:00`" #Initialization value." #Updates stateFile to state when it was last triggered
        Add-Content -Path $statefile "`$$($functionName)TriggeredCount = 0 #Initialization value.."
}
} #End Function 


Function AMS_Server_Queue {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
    $sqlQry = "Use $AgressoDBName
               go
               select created_date,status,response_text,message,subject from acrmailqueuehead 
               where status = 'E'
               and DATEDIFF(MINUTE,last_update,GETUTCDATE()) < 6
               and message not like '%invalid address%'
	           and message not like '%recipient%'
               and message not like '%UNEXPECTED_RCPT_TO_RESPONSE: 501 5.1.8 UTF-8 addresses not supported%'
               and message not like '%Unhandled exception when loading CaConfigReader%'
	           and message not like '%Failed to send via SSL%'
	       and message not like '%Unable to Relay%'
	       and message not like '%Unrouteable address%'
	       and message not like '%domain missing%'
	       and message not like '%UNEXPECTED_RCPT_TO_RESPONSE: 501 Invalid RCPT TO address provided%'
               "
    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }


    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        
        $functionReturn | ft
        $functionReturn | export-csv $functionOutputCSV

        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + " (Please see attached csv for details) `n"
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "To investigate: `n "
        $MsgBody += "1. Check AMC Mail Queue Monitoring to find the issue details `n "
        $MsgBody += "2. Assign the ticket to the customer for remidial action `n "
        $MsgBody += "3. Close the ticket `n "
        $MsgBody += "`n"
        #$MsgBody += "Additional Information: `n "
        #$MsgBody += "SQL query that triggered alert: `n "
        #$MsgBody += "$($sqlQry)"
        
        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 10
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function 
Function Check_Backups {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"

    $sqlQry = "select * 
	from master.dbo.commandlog 
	where commandtype = 'BACKUP_DATABASE' 
	and databasename = '$AgressoDBName'
	and errornumber = 0
	and datediff(hh, endtime, getdate()) < $MaxHoursSinceLastBackup"

    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) {
$MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "No good backup records found in last $($MaxHoursSinceLastBackup) hours for database, please check backups. `n"
        $MsgBody += "`n"
        #$MsgBody += "SQL query that triggered alert: `n "
        #$MsgBody += "$($sqlQry)"
        
        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 10
        $eventLogMessage = $MsgBody
        AlertTriggered
    } else {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    }	
} #End Function 


Function Check_DBCC {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"

    $sqlQry = "select * 
	from master.dbo.commandlog 
	where commandtype = 'DBCC_CHECKDB' 
	and databasename = '$AgressoDBName'
	and errornumber = 0
	and datediff(hh, endtime, getdate()) < $MaxHoursSinceLastDBCC"

    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) {
$MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "No good DBCC records found in last $($MaxHoursSinceLastDBCC) hours for database, please check DBCC checks. `n"
        $MsgBody += "`n"
        #$MsgBody += "SQL query that triggered alert: `n "
        #$MsgBody += "$($sqlQry)"
        
        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 10
        $eventLogMessage = $MsgBody
        AlertTriggered
    } else {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    }	
} #End Function 

Function Check_DB_Encryption {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"

    $sqlQry = "SELECT db_name(database_id), * FROM sys.dm_database_encryption_keys 
	where database_id = db_id('$AgressoDBName')
	and encryption_state = 3"

    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) {
$MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "Database $($AgressoDBName) is not encrypted, please check if it should be. `n"
        $MsgBody += "`n"
        #$MsgBody += "SQL query that triggered alert: `n "
        #$MsgBody += "$($sqlQry)"
        
        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 10
        $eventLogMessage = $MsgBody
        AlertTriggered
    } else {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    }	
} #End Function 


Function Long_Running_Agresso_Reports {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
    $sqlQry = "Use $AgressoDBName
                go
                select report_name,orderno,variant,DATEDIFF(MINUTE,date_started,date_ended) as runtime
                from acrrepord
                where 1=1
                and DATEDIFF(MINUTE,date_started,date_ended) >= $MinsThresholdForLongReports
                and DATEDIFF(MINUTE,date_started,GETDATE()) < $LongReportsMonitorMins
                and status = 'T'
                and date_ended != '1900-01-01'
                order by 3 desc
                "
    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        <##$myOutput = "Records: " + $AAGServerQueueReturn.count + "`n"
        #write-host $myOutput#>
        $functionReturn | ft
        $functionReturn | export-csv $functionOutputCSV
	$functionReturnB = $functionReturn | select report_name, orderno, variant, runtime | Select-Object -First 5 | ft -autosize | out-string
        <#$functionReturn | ft #fl #Select bflag,controller_type
        #$functionReturn.Get(0) | ft#>
        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "TOP 5 Records:"
	$MsgBody += "$($functionReturnB)"
        $MsgBody += "`n"
        #$MsgBody += "To investigate, please run the following query: `n "
        #$MsgBody += "$($sqlQry)"

        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 6
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function 

Function Failed_Agresso_Logins {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
    $sqlQry = "Use $AgressoDBName
                go
                select user_id,count(*) as failedattempts from aagsesshist
                where DATEDIFF(MINUTE,login_time,getdate()) < $MinsToMonitorFailedAgressoLogins
                and status != 'N'
                group by user_id
                having count(*) >= $FailedAgressoLoginsThreshold
                "
    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        <##$myOutput = "Records: " + $AAGServerQueueReturn.count + "`n"
        #write-host $myOutput#>
        $functionReturn | ft
        $functionReturn | export-csv $functionOutputCSV
	$functionReturnB = $functionReturn | select user_id, failedattempts | Select-Object -First 5 | ft -autosize | out-string
        <#$functionReturn | ft #fl #Select bflag,controller_type
        #$functionReturn.Get(0) | ft#>
        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "TOP 5 Records:"
	$MsgBody += "$($functionReturnB)"
        $MsgBody += "`n"
        #$MsgBody += "To investigate, please run the following query: `n "
        #$MsgBody += "$($sqlQry)"

        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 6
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function 

Function Insecure_Agresso_Logins {
    $Date = Get-Date
    $functionName = "$($MyInvocation.MyCommand.Name)"
    $functionOutputCSV = "$($instanceSpecificWorkingDir)\$($functionName).csv"
    $sqlQry = "Use $AgressoDBName
                go
                select u.user_id, u.user_name,s.variant
                from aagusersec s, aaguser u
                where s.user_id = u.user_id
                and s.variant < 4 and u.status = 'N'
                "

    if ($ssmodule22plus) {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"  -TrustServerCertificate
    } Else {
        $functionReturn = Invoke-Sqlcmd -ServerInstance $AgressoDBServerName -QueryTimeout 3600 -Query "$($sqlQry)"
    }

    if ($functionReturn.ItemArray.Count -lt 1) {
        write-host "$($functionName): All ok. `n"
        Add-Content $LogPath "$($functionName): All ok."
    } else {
        <##$myOutput = "Records: " + $AAGServerQueueReturn.count + "`n"
        #write-host $myOutput#>
        $functionReturn | ft
        $functionReturn | export-csv $functionOutputCSV
	$functionReturnB = $functionReturn | select user_id, user_name, variant | Select-Object -First 5 | ft -autosize | out-string
        <#$functionReturn | ft #fl #Select bflag,controller_type
        #$functionReturn.Get(0) | ft#>
        $MsgBody = "Date: " + $Date + "`n" 
        $MsgBody += "Check: " + $functionName + "`n" 
        $MsgBody += "Records: " + $functionReturn.count + "`n" 
        $MsgBody += "`n"
        $MsgBody += "Database Server: $($AgressoDBServerName) `n"
        $MsgBody += "Business Server: $($AgressoLogicalServerName) `n"
        $MsgBody += "Database Name: $($AgressoDBName) `n"
        $MsgBody += "`n"
        $MsgBody += "TOP 5 Records:"
	$MsgBody += "$($functionReturnB)"
        $MsgBody += "`n"
        #$MsgBody += "To investigate, please run the following query: `n "
        #$MsgBody += "$($sqlQry)"

        $stateFileBody += "`$$($functionName)LastTriggeredAlarm = `"$(Get-Date)`"`n"
        $eventLogID = 6
        $eventLogMessage = $MsgBody
        AlertTriggered
    }
} #End Function 

### END OF FUNCTIONS ###


#Initial Script Setup, or stateFile intialize.
if ($firstRunComplete -eq 0) {
    FirstRun
    SetupStateFile
} Else {
    StartStateFile
}


### SCRIPT BODY (there is no END OF to this section) ###
Set-Culture en-GB
$scriptStartTime = Get-Date
write-host "Current Script Version: $($scriptVersion)"
cd $workingDir 
write-host "workingDir updated to: $($workingDir)"
#cls


### SELF UPDATER SECTION ###
#SCRIPT ADMIN VARIABLES!
$scriptName = "UBWMonitoring.ps1"
$updateDirectoryName = "UBWMonitoringUpdates"
$updatedVersionName = "UBWMonitoring_latest.ps1"
$scriptSourceURL = "https://raw.githubusercontent.com/quickthinkcloud/public/refs/heads/master/UBWMonitoring/UBWMonitoring.ps1"

UpdatesAvailable
Update-Myself "$($updateDirectoryName)\$($updatedVersionName)"
$SourcePath = "$($updateDirectoryName)\$($updatedVersionName)"

Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):RDSLicensingAudit Self-Update Check/Complete."
### END OF SELF UPDATER SECTION ###




$fileExists = (Test-Path $LogPath)
if($fileExists) {
    #Check the Log Files haven't got too big
    $log1TooBig = (Get-Item $LogPath).Length
    if($log1TooBig -gt 2mb)
    {
        #Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\Software\QTC -Name MonthLogFull -Value 1
        Remove-Item $LogPath"9"
        #$SchedTasks = Get-ScheduledTask -TaskName QTC*Month* | Where {$_.State -ne 'Disabled'} | select taskname, state
        #$SchedTasks | Foreach {Disable-ScheduledTask -TaskName $_.Taskname}
        Rename-Item $LogPath"8" $LogPath"9"
        Rename-Item $LogPath"7" $LogPath"8"
        Rename-Item $LogPath"6" $LogPath"7"
        Rename-Item $LogPath"5" $LogPath"6"
        Rename-Item $LogPath"4" $LogPath"5"
        Rename-Item $LogPath"3" $LogPath"4"
        Rename-Item $LogPath"2" $LogPath"3"
        Rename-Item $LogPath"1" $LogPath"2"
        Rename-Item $LogPath $LogPath"1"
        #$SchedTasks | Foreach {Enable-ScheduledTask -TaskName $_.Taskname}
        #Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\Software\QTC -Name MonthLogFull -Value 0
        #Remove-Item -Path HKLM:\Software\QTC
    }
    Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):Start of pass. (UBWMonitoringScriptVersion = $UBWMonitoringScriptVersion) Log file size: $($log1TooBig) bytes"
    #Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\Software\QTC -Name MonthLogFull -Value 0
}

$fileExists = (Test-Path $RunSpeedLog)
if($fileExists) {
    $log2TooBig = (Get-Item $RunSpeedLog).Length
    if($log2TooBig -gt 1mb)
    {
        Remove-Item $RunSpeedLog"9"
    
        Rename-Item $RunSpeedLog"9" $RunSpeedLog"10"
        Rename-Item $RunSpeedLog"8" $RunSpeedLog"9"
        Rename-Item $RunSpeedLog"7" $RunSpeedLog"8"
        Rename-Item $RunSpeedLog"6" $RunSpeedLog"7"
        Rename-Item $RunSpeedLog"5" $RunSpeedLog"6"
        Rename-Item $RunSpeedLog"4" $RunSpeedLog"5"
        Rename-Item $RunSpeedLog"3" $RunSpeedLog"4"
        Rename-Item $RunSpeedLog"2" $RunSpeedLog"3"
        Rename-Item $RunSpeedLog"1" $RunSpeedLog"2"
        Rename-Item $RunSpeedLog $RunSpeedLog"1"
        Add-Content $RunSpeedLog "Start Time, End Time, Duration"
    }
} 
else {
    #Add-Content $RunSpeedLog "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):Start of pass. Log file size: $($log2TooBig) bytes"
}


#Calling the checks
# CheckDatabaseConnectivity
UBW_Queue_Scheduler
UBW_Queue_TPS
UBW_Queue_ACRALS
UBW_Queue_ALGIPS
UBW_Queue_ALGSPS
UBW_Queue_AMS
UBW_Queue_RESRATE
UBW_Queue_DWS
UBW_Queue_IMS
UBW_Queue_AINAPS

#Agresso_Queues_Scheduler_TPS
#Agresso_Queues_ACRALS_ALGIPS_ALGSPS_AMS_RESRATE_DWS_IMS
#Agresso_Queues_AINAPS
Agresso_Reports_Stuck_at_N_or_W
Agresso_Workflow_Service
Agresso_AMS_Service_Email_Queue
Process_Technical_Error
Process_Functional_Error
AMS_Server_Queue
Check_backups
Check_DBCC
Check_DB_Encryption
Long_Running_Agresso_Reports
Failed_Agresso_Logins
if ($checkForInsecureLogins) {Insecure_Agresso_Logins}


#Script finished
$scriptEndTime = get-date

EndStateFile


#Add log End line to main log
#Add-Content $LogPath "Log ending at: $($scriptEndTime.Tostring())"
Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):End of pass."


#Capture Run Speed in the RunSpeedLog
$fileExists = (Test-Path $RunSpeedLog)
if(!($fileExists))
{
    Add-Content $RunSpeedLog "Start Time, End Time, Duration, Duration in Seconds"
}

#Write RunSpeedLog information
$timespan1 = New-TimeSpan -Start $scriptStartTime -End $scriptEndTime

#By including the delimiters in the formatting string it's easier when we contatenate in the end
$hours = $timespan1.Hours.ToString("00")
$minutes = $timespan1.Minutes.ToString("\:00")
$seconds = $timespan1.Seconds.ToString("\:00")
<#$milliseconds = $timespan1.Milliseconds.ToString("\,000")
#$duration = ($hours + $minutes + $seconds + $milliseconds) #>
$duration = ($hours + $minutes + $seconds)
$totalSeconds = $timespan1.TotalSeconds
Add-Content $RunSpeedLog "$($scriptStartTime.Tostring()), $($scriptEndTime.Tostring()), $duration, $totalSeconds"