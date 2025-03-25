$scriptVersion = "20250325_1323"

### GLOBAL VARIABLES ###
## USER CONFIGURED VARIABLES ##
#General Customer Info
$customerName = "CustomerName"
$customerBusinessHoursStart = "08:00" #must be in format HH:mm even with leading 0's
$customerBusinessHoursEnd = "17:30" #must be in format HH:mm even with leading 0's
#Customer Domain Info
#$customerDomain = "DC=QTC,DC=LOCAL" #Format "DC=QTC,DC=LOCAL"
#$customerDottedDomain = "QTC.LOCAL" #Format "QTC.LOCAL"
$domain = "MYQTCLOUD" #NetBIOS format "QTC"
#Email Settings
$emailAlerts = $false
$smtpServer = "DC01"
$mailSender = "$($customerName) Monitoring <$($customerName)Monitoring@qtc.cloud>"
$mailRecipients = @("support@quickthinkcloud.com") #Example: $mailRecipients = @("ops.team@quickthinkcloud.com", "support@quickthinkcloud.com")
#Database and Business Server
$AgressoDBServerName = "SQL01" #$AgressoDBServerName = "Change_Agresso_DB_Server_Name"
$AgressoDBName = "databaseName" #$AgressoDBName = "Change_Agresso_DB_Name"
$AgressoLogicalServerName = "BUS01" #$AgressoLogicalServerName = "Change_Agresso_Logical_Server_Name"
#Queues
$p1CoreNumberOfMinutes = 8 #8 number of minutes an P1 Agresso Core Queue can be running without updating
$UBW_Queue_Scheduler_Minutes = 8 #8 number of minutes the Scheduler can be running without updating before an alarm is triggered
$UBW_Queue_TPS_Minutes = 8 #8 number of minutes the Scheduler can be running without updating before an alarm is triggered
$p2CoreNumberOfMinutes = 15 #15 number of minutes an P2 Agresso Core Queue can be running without updating
$UBW_Queue_ACRALS_Minutes = 30 # 30 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_ALGIPS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_ALGSPS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_AMS_Minutes = 30 # 30 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_RESRATE_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_DWS_Minutes = 30 #15 number of minutes this queue can run without updating before an alarm is triggered
$UBW_Queue_IMS_Minutes = 15 #15 number of minutes this queue can run without updating before an alarm is triggered
$p3CoreNumberOfMinutes = 60 #60 number of minutes an P3 Agresso Core Queue can be running without updating
$UBW_Queue_AINAPS_Minutes = 60 #60 number of minutes this queue can run without updating before an alarm is triggered
#Ordered Reports
$NoDaysforNorWReportsOrderedToBeMonitored = 7 #7 $NoDaysforNorWReportsOrderedToBeMonitored = "DAYS_FOR_N_OR_W_REPORTS_ORDERED_TO_BE_MONITORED"
$MinsForNorWReportsToBeConsideredActive = 60 #60 $MinsForNorWReportsToBeConsideredActive = "MINUTES_FOR_N_OR_W_REPORTS_TO_BE_CONSIDERED_ACTIVE" 
#Workflow Service
$NoWorkflowRows = 1000 #300 $NoWorkflowRows = "NO_OF_WORKFLOW_ROWS_DEFAULT_300"
#Agresso AMS Service Email Queue
$MinsForAMSEmailQueue = 120 #120
$MaxHoursSinceLastBackup = 32 #32 Number of hours since last good backup before an alarm is triggered
$MaxHoursSinceLastDBCC = 32 #32 Number of hours since last good DBCC check before an alarm is triggered
#LongReports Function Variables
$MinsThresholdForLongReports = 60 #Minimum number of mins to consider a report long running
$LongReportsMonitorMins = 120  #120 Number of minutes before now to monitor long running reports for
#AgressoLogins Variables
$MinsToMonitorFailedAgressoLogins = 60 #30 Number of minutes before now to monitor failed Agresso logins
$FailedAgressoLoginsThreshold = 5 #5 Number of failed login attempts before alarm is triggered
$checkForInsecureLogins = $true
## END OF USER CONFIGURED VARIABLES ##


## ADMIN/SRIPT WRITER VARIABLES ##
#Please see the Main Script for these variables
## END OF ADMIN/SRIPT WRITER VARIABLES ##
### END OF GLOBAL VARIABLES ###

#$timeSpan = New-TimeSpan -Days 1
#$newDate = (get-date) + $timeSpan


