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

### GLOBAL VARIABLES ###
## USER CONFIGURED VARIABLES ##
# Monitor the following domain and groups
$customerName = "CustomerName"
#$workingDir = "C:\Users\$($env:USERNAME)\"
$workingDir = Get-Location
$GroupName = @("RDS_Users","RDS_Excelerator")

$scriptVersion = 201908063
$LogPath = "$($workingDir)LicensingAudit.log"
Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):RDSLicensingAudit Started (scriptVersion: $($scriptVersion))"
 
<# Creating PSCredential object
$trustedDom1 = "TrustedDom1.com"
$trustedDom1Server = $trustedDom1 # set to an IP i.e."1.2.3.1" # use only if explicitely required, else set this = $trustedDom1
$User = "TrustedDom1\QTC-user"
$File = "$($trustedDom1)_pw.txt"
$DomCreds1=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $File | ConvertTo-SecureString)
#>

$numTrustedDomains = 0


#Run the config .ps1 to set the variables
. .\$ConfigFile

### SELF UPDATER SECTION ###
#SCRIPT ADMIN VARIABLES!
$scriptName = "RDSLicensingAudit.ps1"
$updateDirectoryName = "RDSLAUpdates"
$updatedVersionName = "RDSLAU_latest.ps1"
$scriptSourceURL = "https://raw.githubusercontent.com/quickthinkcloud/public/master/licensing/RDSLicensingAudit.ps1"

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
                Copy-Item $SourcePath $CurrentScript -Force
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
### END OF SELF UPDATER SECTION ###


### FUNCTIONS ###
Function Convert-FspToUsername 
{ 
	    <# 
	        .SYNOPSIS 
	            Convert a FSP to a sAMAccountName 
	        .DESCRIPTION 
	            This function converts FSP's to sAMAccountName's. 
	        .PARAMETER UserSID 
	            This is the SID of the FSP in the form of S-1-5-20. These can be found 
	            in the ForeignSecurityPrincipals container of your domain. 
	        .EXAMPLE 
	            Convert-FspToUsername -UserSID "S-1-5-11","S-1-5-17","S-1-5-20" 
	 
	            sAMAccountName                      Sid 
	            --------------                      --- 
	            NT AUTHORITY\Authenticated Users    S-1-5-11 
	            NT AUTHORITY\IUSR                   S-1-5-17 
	            NT AUTHORITY\NETWORK SERVICE        S-1-5-20 
	 
	            Description 
	            =========== 
	            This example shows passing in multipe sids to the function 
	        .EXAMPLE 
	            Get-ADObjects -ADSPath "LDAP://CN=ForeignSecurityPrincipals,DC=company,DC=com" -SearchFilter "(objectClass=foreignSecurityPrincipal)" | 
	            foreach {$_.Properties.name} |Convert-FspToUsername 
	 
	            sAMAccountName                      Sid 
	            --------------                      --- 
	            NT AUTHORITY\Authenticated Users    S-1-5-11 
	            NT AUTHORITY\IUSR                   S-1-5-17 
	            NT AUTHORITY\NETWORK SERVICE        S-1-5-20 
	 
	            Description 
	            =========== 
	            This example takes the output of the Get-ADObjects function, and pipes it through foreach to get to the name 
	            property, and the resulting output is piped through Convert-FspToUsername. 
	        .NOTES 
	            This function currently expects a SID in the same format as you see being displayed 
	            as the name property of each object in the ForeignSecurityPrincipals container in your 
	            domain.  
	        .LINK 
	            https://code.google.com/p/mod-posh/wiki/ActiveDirectoryManagement#Convert-FspToUsername 
	    #> 
	    [CmdletBinding()] 
	    Param 
	        ( 
	        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)] 
	        $UserSID 
	        ) 
	    Begin 
	    { 
	        } 
	    Process 
	    { 
	        foreach ($Sid in $UserSID) 
	        { 
	            try 
	            { 
	                $SAM = (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate([System.Security.Principal.NTAccount]) 
	                $Result = New-Object -TypeName PSObject -Property @{ 
	                    Sid = $Sid 
	                    sAMAccountName = $SAM.Value 
	                    } 
	                Return $Result 
	                } 
	            catch 
	            { 
	                $Result = New-Object -TypeName PSObject -Property @{ 
	                    Sid = $Sid 
	                    sAMAccountName = $Error[0].Exception.InnerException.Message.ToString().Trim() 
	                    } 
	                Return $Result 
	                } 
	            } 
	        } 
	    End 
	    { 
	        } 
	    } #End Function FspToUsername
#Convert-FspToUsername("S-1-5-21-3560827488-1958027982-390507998-3767") | select sAMAccountName
Function RecursivelyEnumerateGroupObjects {
    Param(
        [string]$grpName #,
        #[string]$global:parentObject = ""
    )

    #First Run check
    if ($firstRun -ne 1) {
        ##Create a blank array
        #$global:arrGroupsWithinDomains = @()
        #write-host "First Run" -ForegroundColor Yellow
        $global:parentGrpName = ""
        $global:firstRun = 1
        #$global:parentGrpName = $grpName
        #write-host "parentGrpName = $($parentGrpName)"
        #write-host "firstRun = $($firstRun)"
        #pause
    } 
    Else {
        #Write-Host "This is not the first run through"
        #$global:parentGrpName = $grpName
        #write-host "firstRun = $($firstRun)"
        #pause
    }
    
    $currentObjSID = ""
    $currentObjClass = ""
    $currentObj = ""
    $currentObjName = ""

    #Write out the current group name
    Write-Host ""
    Write-Host $grpName -ForegroundColor green
    Write-Host ""
 
    #$grpName = "ME_DATA_IMPORT_LIVE"
    #Populate the currentGroup
    #TRY{$currentGroup = get-adgroup $grpName -Properties * | sort ObjectClass -Descending}CATCH{}
    $currentGroup = get-adgroup $grpName -Properties * | sort ObjectClass -Descending
    
    $currentGroup | ForEach-Object {
        # Create a new instance of a .Net object
        $currentAdObject = New-Object System.Object
 
        # Add user-defined customs members: the records retrieved with the three PowerShell commands
        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $localDomain.NetBIOSname -Name Domain #The Domain that hosts this object
        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $_.name -Name ObjectName #The object Name i.e. name of a group
        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $_.objectClass -Name ObjectType # The type of object i.e. User or Group
        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $parentGrpName -Name ParentObject #The name of a parent obeject
        $global:arrGroupsWithinDomains += $currentAdObject       
        }
 
     <#if ($firstRun -eq 1) {
        #$global:parentGrpName = $grpName
     }#>
      
    #For each USER member of the group
    foreach($grp in $currentGroup.Members) {
        #Get-ADObject -Filter {DistinguishedName -eq $grp} -Properties * | select *
        $currentObj = Get-ADObject -Filter {DistinguishedName -eq $grp} -Properties * #| select *
        
        # Get-ADObject -Filter {DistinguishedName -eq $grp} -Properties * | select *
        # Write-Host "SamAccountname $($currentObj.sAMAccountName)"
        # pause

        $currentObjSID = $currentObj.objectSid
        $currentObjClass = $currentObj.ObjectClass
        $currentObjName = Convert-FspToUsername($currentObj.objectSid.Value) | select sAMAccountName
        
        #if($currentObjClass.ToString() = "user") {
        switch ($currentObjClass.ToString())
        {
        #"foreignSecurityPrincipal" {$currentObjName}
        "user" {
            write-host "It's a user..." -ForegroundColor Yellow
            $varMyLocalADUser = Get-ADUser -Identity "$($currentObj.objectSid)" -properties * # | select *name*, *abl*
            if($varMyLocalADUser.Enabled -eq $True) {
                # Write-Host "An Enabled account $($varMyLocalADUser.samAccountName)" -ForegroundColor Red
       
                #write-host "user"
                $currentObj.Name
                # Create a new instance of a .Net object
                $currentAdObject = New-Object System.Object
 
                # Add user-defined customs members: the records retrieved with the three PowerShell commands
                $currentAdObject  | Add-Member -MemberType NoteProperty -Value $localDomain.NetBIOSname -Name Domain #The Domain that hosts this object
                $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObj.Name -Name ObjectName #The object Name i.e. name of a group
                $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObj.objectClass -Name ObjectType # The type of object i.e. User or Group
                $currentAdObject  | Add-Member -MemberType NoteProperty -Value "NoneStaticString" -Name ParentObject #The name of a parent obeject
                #$currentAdObject  | Add-Member -MemberType NoteProperty -Value $parentGrpName -Name ParentObject #The name of a parent obeject
                $global:arrGroupsWithinDomains += $currentAdObject
                #write-host "end of user"    
                }#End of "user"
        
            } # end if($varMyLocalADUser.Enabled -eq $True)
        } #End of switch
    } #End of foreach($grp of $currentGroup.Members)
    

    #For each GROUP within the group
    foreach($grp in $currentGroup.Members) {
        #Get-ADObject -Filter {DistinguishedName -eq $grp} -Properties * | select *       
        $currentObj = Get-ADObject -Filter {DistinguishedName -eq $grp} -Properties * #| select *
        
        $currentObjSID = $currentObj.objectSid
        $currentObjClass = $currentObj.ObjectClass
        $currentObjName = Convert-FspToUsername($currentObj.objectSid.Value) | select sAMAccountName
        
        #if($currentObjClass.ToString() = "group") {
        switch ($currentObjClass.ToString())
        {
        #"foreignSecurityPrincipal" {$currentObjName}
        #"user" {$currentObj.Name}
        "group" {
            write-host "Group..." -ForegroundColor Cyan
            <#
            #$a = $currentObj.Name
            #$b = $global:newParentObject
            #$a = $a.Trim()
            #$b = $b.Trim()
            #$a
            #$b
#>
            <#
            write-host "GROUP" -ForegroundColor Yellow
            $currentObj
            write-host "END GROUP" -ForegroundColor Yellow
            $currentObj.Name

            # Create a new instance of a .Net object
            $currentAdObject = New-Object System.Object
 
            # Add user-defined customs members: the records retrieved with the three PowerShell commands
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $localDomain.NetBIOSname -Name Domain #The Domain that hosts this object
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObj.Name -Name ObjectName #The object Name i.e. name of a group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObj.ObjectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentGroup.sAMAccountName -Name ParentObject #The name of a parent obeject
            $global:arrGroupsWithinDomains += $currentAdObject

            #>
            RecursivelyEnumerateGroupObjects($currentObj.Name)
            #RecursivelyEnumerateGroupObjects("$($a)$($b)")
      
            ## Create a new instance of a .Net object
            #$currentAdObject = New-Object System.Object
            #
            ## Add user-defined customs members: the records retrieved with the three PowerShell commands
            #$currentAdObject  | Add-Member -MemberType NoteProperty -Value "LocalDomainStaticString" -Name Domain #The Domain that hosts this object
            #$currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObj.Name -Name ObjectName #The object Name i.e. name of a group
            #$currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObj.objectClass -Name ObjectType # The type of object i.e. User or Group
            #$currentAdObject  | Add-Member -MemberType NoteProperty -Value "NoneStaticString" -Name ParentObject #The name of a parent obeject
            #$arrGroupsWithinDomains += $currentAdObject
            #write-host "End of group"
            } #End of "group"
        }#End of switch
 #pause  
    } #End of foreach($grp of $currentGroup.Members)
    

    #For each FSP within the group
    foreach($grp in $currentGroup.Members) {
        #Get-ADObject -Filter {DistinguishedName -eq $grp} -Properties * | select *
        $currentObj = Get-ADObject -Filter {DistinguishedName -eq $grp} -Properties * #| select *
        
        $currentObjSID = $currentObj.objectSid
        $currentObjClass = $currentObj.ObjectClass
        $currentObjName = Convert-FspToUsername($currentObj.objectSid.Value) | select sAMAccountName
 
        #write-host "$($currentObjSID) $($currentObjClass) $($currentObjName)"
        #$grp

        #String Splitting:
        $tempString = $currentObjName.sAMAccountName
#Write-Host "sAMAccountName: $($tempString)"
        #$tempLength = $tempString.Length
        #$tempLength
        $tempSlash = $tempString.IndexOf("\")
        #$tempSlash
        TRY {$tempDomain = $tempString.Substring(0,$tempSlash)}Catch{}
        #$tempDomain 
        $tempGroup = $tempString.Substring($tempSlash+1)
        #$tempGroup 
 
        #Write-Host "TempDomain = $tempDomain and TempGroup = $tempGroup and currentObjClass $($currentObjClass.ToString())"
        #Start-Sleep -s 60
 
        #if($currentObjClass.ToString() = "foreignSecurityPrincipal") {
        switch ($currentObjClass.ToString())
        {
            "foreignSecurityPrincipal" {
               write-host "foreignSecurityPrincipal..." -ForegroundColor Gray
               # $currentObjName
   
                #get-adobject -Identity $grpName -Server eu.cyrilsweett.com -Credential $DomCreds | sort samaccountname | select samaccountname,objectClass, distinguishedname #,*
                #Start-Sleep -s 5
 
                #Write-host "You triggered me" -ForegroundColor Yellow
                #$grpName = "RESGROUP - Excel2007"
                $grpName = $tempGroup
                
                <#
                write-host "What is it?" -ForegroundColor Yellow
                $grpName
                $tempGroup
                $tempDomain
                $currentObj
                $currentObjSID
                $currentObjClass
                $currentObjName
 
                
                write-host "EU here" -ForegroundColor Yellow
                if ((Get-ADuser -Identity $grpName -Server eu.cyrilsweett.com -Credential $DomCreds | Select SamAccountName) -eq $grpName) {
                    write-host "We have an EU username match" -ForegroundColor Yellow
                    pause
                } Else {
                    pause
                    write-host "We DO NOT have an EU username match" -ForegroundColor green
                    write-host "ME here" -ForegroundColor Yellow
                    pause
                    if ((Get-ADuser -Identity $grpName -Server me.cyrilsweett.com -Credential $DomCredsME | Select SamAccountName) -eq $grpName) {
                        pause
                        write-host "We have an ME username match" -ForegroundColor Yellow
                        pause
                    } Else {
                    pause
                        write-host "We DO NOT have an ME username match" -ForegroundColor green
                        pause
 
                    }
                }
                #>

#write-host "notInDomainCounter: $($notInDomainCounter) (initialised) - grpName: $($grpName) - tempGroup: $($tempGroup) - tempString: $($tempString) - currentObjName: $($currentObjName) - grp: $($grp)" -ForegroundColor Yellow
$notInDomainCounter=1
#write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: Local" -ForegroundColor Yellow
                #Try {get-AdGroupMember -Identity $grpName -ErrorAction Stop -Recursive | sort samaccountname | select samaccountname,objectClass}
                #Catch {
                #$fspMembers = Get-AdGroupMember -Identity $grpName -Server eu.cyrilsweett.com -Credential $DomCreds -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname #,*
#trustedDom1
Try {
    #$fspMembers = Get-AdGroupMember -Identity $grpName -Server eu.cyrilsweett.com -Credential $DomCreds -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
    Try { #If it's a user...
    $fspMembers = Get-ADUser -Identity $grpName -Server $trustedDom1Server -Credential $DomCreds1 -properties *  | sort samaccountname | select samaccountname, objectClass, distinguishedname
        ForEach ($fspMem in $fspMembers) { 
	        #$fspMem | fl
	        #String Splitting:
	        $tempString = $currentObjName.sAMAccountName
	        #$tempLength = $tempString.Length
	        #$tempLength
	        $tempSlash = $tempString.IndexOf("\")
	        #$tempSlash
	        $tempDomain = $tempString.Substring(0,$tempSlash)
	        #$tempDomain 
	        $tempGroup = $tempString.Substring($tempSlash+1)
	        #$tempGroup 
	        # Create a new instance of a .Net object
	        $currentAdObject = New-Object System.Object
	        # Add user-defined customs members: the records retrieved with the three PowerShell commands
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentGroup.sAMAccountName -Name ParentObject #The name of a parent obeject
	        $global:arrGroupsWithinDomains += $currentAdObject
        }
    }
    Catch { #if it's not a user...
        #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: $($trustedDom1) - Not a user." -ForegroundColor Yellow
        $fspMembers = Get-AdGroupMember -Identity $grpName -Server $trustedDom1 -Credential $DomCreds1 -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
        ForEach ($fspMem in $fspMembers) { 
            #$fspMem | fl
            #String Splitting:
            $tempString = $currentObjName.sAMAccountName
            #$tempLength = $tempString.Length
            #$tempLength
            $tempSlash = $tempString.IndexOf("\")
            #$tempSlash
            $tempDomain = $tempString.Substring(0,$tempSlash)
            #$tempDomain 
            $tempGroup = $tempString.Substring($tempSlash+1)
            #$tempGroup 
            # Create a new instance of a .Net object
            $currentAdObject = New-Object System.Object
            # Add user-defined customs members: the records retrieved with the three PowerShell commands
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObjName.sAMAccountName -Name ParentObject #The name of a parent obeject
            $global:arrGroupsWithinDomains += $currentAdObject
        }
    } #End Catch
}
Catch {
    #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: $($trustedDom1)" -ForegroundColor Yellow
    $notInDomainCounter = 2
    <#
    #$fspMembers = Get-AdGroupMember -Identity $grpName -Server me.cyrilsweett.com -Credential $DomCredsME -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
    Try { #If it's a user...
        $fspMembers = Get-ADUser -Identity $grpName -Server $trustedDom2 -Credential $DomCreds2 | sort samaccountname | select samaccountname,objectClass, distinguishedname
        ForEach ($fspMem in $fspMembers) { 
	        #$fspMem | fl
	        #String Splitting:
	        $tempString = $currentObjName.sAMAccountName
	        #$tempLength = $tempString.Length
	        #$tempLength
	        $tempSlash = $tempString.IndexOf("\")
	        #$tempSlash
	        $tempDomain = $tempString.Substring(0,$tempSlash)
	        #$tempDomain 
	        $tempGroup = $tempString.Substring($tempSlash+1)
	        #$tempGroup 
	        # Create a new instance of a .Net object
	        $currentAdObject = New-Object System.Object
	        # Add user-defined customs members: the records retrieved with the three PowerShell commands
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentGroup.sAMAccountName -Name ParentObject #The name of a parent obeject
	        $global:arrGroupsWithinDomains += $currentAdObject
        }
    }
    Catch { #if it's not a user...
        $fspMembers = Get-AdGroupMember -Identity $grpName -Server $trustedDom2 -Credential $DomCreds2 -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
        ForEach ($fspMem in $fspMembers) { 
            #$fspMem | fl
            #String Splitting:
            $tempString = $currentObjName.sAMAccountName
            #$tempLength = $tempString.Length
            #$tempLength
            $tempSlash = $tempString.IndexOf("\")
            #$tempSlash
            $tempDomain = $tempString.Substring(0,$tempSlash)
            #$tempDomain 
            $tempGroup = $tempString.Substring($tempSlash+1)
            #$tempGroup 
            # Create a new instance of a .Net object
            $currentAdObject = New-Object System.Object
            # Add user-defined customs members: the records retrieved with the three PowerShell commands
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObjName.sAMAccountName -Name ParentObject #The name of a parent obeject
            $global:arrGroupsWithinDomains += $currentAdObject
        } #End ForEach ($fspMem in $fspMembers)
    } #End Catch
    #>
} #End Catch
<#
Finally {
    #$fspMembers = Get-AdGroupMember -Identity $grpName -Server me.cyrilsweett.com -Credential $DomCredsME -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
    Try { #If it's a user...
        $fspMembers = Get-ADUser -Identity $grpName -Server $trustedDom3 -Credential $DomCreds3 | sort samaccountname | select samaccountname,objectClass, distinguishedname
        ForEach ($fspMem in $fspMembers) { 
	        #$fspMem | fl
	        #String Splitting:
	        $tempString = $currentObjName.sAMAccountName
	        #$tempLength = $tempString.Length
	        #$tempLength
	        $tempSlash = $tempString.IndexOf("\")
	        #$tempSlash
	        $tempDomain = $tempString.Substring(0,$tempSlash)
	        #$tempDomain 
	        $tempGroup = $tempString.Substring($tempSlash+1)
	        #$tempGroup 
	        # Create a new instance of a .Net object
	        $currentAdObject = New-Object System.Object
	        # Add user-defined customs members: the records retrieved with the three PowerShell commands
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentGroup.sAMAccountName -Name ParentObject #The name of a parent obeject
	        $global:arrGroupsWithinDomains += $currentAdObject
        }
    }
    Catch { #if it's not a user...
        $fspMembers = Get-AdGroupMember -Identity $grpName -Server $trustedDom3 -Credential $DomCreds3 -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
        ForEach ($fspMem in $fspMembers) { 
            #$fspMem | fl
            #String Splitting:
            $tempString = $currentObjName.sAMAccountName
            #$tempLength = $tempString.Length
            #$tempLength
            $tempSlash = $tempString.IndexOf("\")
            #$tempSlash
            $tempDomain = $tempString.Substring(0,$tempSlash)
            #$tempDomain 
            $tempGroup = $tempString.Substring($tempSlash+1)
            #$tempGroup 
            # Create a new instance of a .Net object
            $currentAdObject = New-Object System.Object
            # Add user-defined customs members: the records retrieved with the three PowerShell commands
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObjName.sAMAccountName -Name ParentObject #The name of a parent obeject
            $global:arrGroupsWithinDomains += $currentAdObject
        } #End ForEach ($fspMem in $fspMembers)
    } #End Catch
} #End Finally
#>

if ($numTrustedDomains > 1) {
#trustedDom2
If ($notInDomainCounter = 2) {
    Try {
        #$fspMembers = Get-AdGroupMember -Identity $grpName -Server eu.cyrilsweett.com -Credential $DomCreds -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
        Try { #If it's a user...
        $fspMembers = Get-ADUser -Identity $grpName -Server $trustedDom2Server -Credential $DomCreds2 | sort samaccountname | select samaccountname,objectClass, distinguishedname
            ForEach ($fspMem in $fspMembers) { 
	        #$fspMem | fl
	        #String Splitting:
	        $tempString = $currentObjName.sAMAccountName
	        #$tempLength = $tempString.Length
	        #$tempLength
	        $tempSlash = $tempString.IndexOf("\")
	        #$tempSlash
	        $tempDomain = $tempString.Substring(0,$tempSlash)
	        #$tempDomain 
	        $tempGroup = $tempString.Substring($tempSlash+1)
	        #$tempGroup 
	        # Create a new instance of a .Net object
	        $currentAdObject = New-Object System.Object
	        # Add user-defined customs members: the records retrieved with the three PowerShell commands
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentGroup.sAMAccountName -Name ParentObject #The name of a parent obeject
	        $global:arrGroupsWithinDomains += $currentAdObject
        }
        }
        Catch { #if it's not a user...
            #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: $($trustedDom2) - Not a user." -ForegroundColor Yellow
            $fspMembers = Get-AdGroupMember -Identity $grpName -Server $trustedDom2 -Credential $DomCreds2 -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
            ForEach ($fspMem in $fspMembers) { 
            #$fspMem | fl
            #String Splitting:
            $tempString = $currentObjName.sAMAccountName
            #$tempLength = $tempString.Length
            #$tempLength
            $tempSlash = $tempString.IndexOf("\")
            #$tempSlash
            $tempDomain = $tempString.Substring(0,$tempSlash)
            #$tempDomain 
            $tempGroup = $tempString.Substring($tempSlash+1)
            #$tempGroup 
            # Create a new instance of a .Net object
            $currentAdObject = New-Object System.Object
            # Add user-defined customs members: the records retrieved with the three PowerShell commands
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObjName.sAMAccountName -Name ParentObject #The name of a parent obeject
            $global:arrGroupsWithinDomains += $currentAdObject
        }
        } #End Catch
    }
    Catch {
        #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: $($trustedDom2)" -ForegroundColor Yellow
        $notInDomainCounter = 3
    } #End Catch
}
}
if ($numTrustedDomains > 2) {
#trustedDom3
If ($notInDomainCounter = 3) {
    Try {
        Try { #If it's a user...
        $fspMembers = Get-ADUser -Identity $grpName -Server $trustedDom3Server -Credential $DomCreds3 | sort samaccountname | select samaccountname,objectClass, distinguishedname
            ForEach ($fspMem in $fspMembers) { 
	        #$fspMem | fl
	        #String Splitting:
	        $tempString = $currentObjName.sAMAccountName
	        #$tempLength = $tempString.Length
	        #$tempLength
	        $tempSlash = $tempString.IndexOf("\")
	        #$tempSlash
	        $tempDomain = $tempString.Substring(0,$tempSlash)
	        #$tempDomain 
	        $tempGroup = $tempString.Substring($tempSlash+1)
	        #$tempGroup 
	        # Create a new instance of a .Net object
	        $currentAdObject = New-Object System.Object
	        # Add user-defined customs members: the records retrieved with the three PowerShell commands
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentGroup.sAMAccountName -Name ParentObject #The name of a parent obeject
	        $global:arrGroupsWithinDomains += $currentAdObject
        }
        }
        Catch { #if it's not a user...
            #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: $($trustedDom3) - Not a user." -ForegroundColor Yellow
            $fspMembers = Get-AdGroupMember -Identity $grpName -Server $trustedDom3 -Credential $DomCreds3 -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
            ForEach ($fspMem in $fspMembers) { 
            #$fspMem | fl
            #String Splitting:
            $tempString = $currentObjName.sAMAccountName
            #$tempLength = $tempString.Length
            #$tempLength
            $tempSlash = $tempString.IndexOf("\")
            #$tempSlash
            $tempDomain = $tempString.Substring(0,$tempSlash)
            #$tempDomain 
            $tempGroup = $tempString.Substring($tempSlash+1)
            #$tempGroup 
            # Create a new instance of a .Net object
            $currentAdObject = New-Object System.Object
            # Add user-defined customs members: the records retrieved with the three PowerShell commands
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObjName.sAMAccountName -Name ParentObject #The name of a parent obeject
            $global:arrGroupsWithinDomains += $currentAdObject
        }
        } #End Catch
    }
    Catch {
        #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: $($trustedDom3)" -ForegroundColor Yellow
        $notInDomainCounter = 4
    } #End Catch
}
}
if ($numTrustedDomains > 3) {
#trustedDom4
If ($notInDomainCounter = 4) {
    Try {
        Try { #If it's a user...
        $fspMembers = Get-ADUser -Identity $grpName -Server $trustedDom4Server -Credential $DomCreds4 | sort samaccountname | select samaccountname,objectClass, distinguishedname
            ForEach ($fspMem in $fspMembers) { 
	        #$fspMem | fl
	        #String Splitting:
	        $tempString = $currentObjName.sAMAccountName
	        #$tempLength = $tempString.Length
	        #$tempLength
	        $tempSlash = $tempString.IndexOf("\")
	        #$tempSlash
	        $tempDomain = $tempString.Substring(0,$tempSlash)
	        #$tempDomain 
	        $tempGroup = $tempString.Substring($tempSlash+1)
	        #$tempGroup 
	        # Create a new instance of a .Net object
	        $currentAdObject = New-Object System.Object
	        # Add user-defined customs members: the records retrieved with the three PowerShell commands
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
	        $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentGroup.sAMAccountName -Name ParentObject #The name of a parent obeject
	        $global:arrGroupsWithinDomains += $currentAdObject
        }
        }
        Catch { #if it's not a user...
            #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: $($trustedDom4) - Not a user." -ForegroundColor Yellow
            $fspMembers = Get-AdGroupMember -Identity $grpName -Server $trustedDom4 -Credential $DomCreds4 -Recursive | sort samaccountname | select samaccountname,objectClass, distinguishedname
            ForEach ($fspMem in $fspMembers) { 
            #$fspMem | fl
            #String Splitting:
            $tempString = $currentObjName.sAMAccountName
            #$tempLength = $tempString.Length
            #$tempLength
            $tempSlash = $tempString.IndexOf("\")
            #$tempSlash
            $tempDomain = $tempString.Substring(0,$tempSlash)
            #$tempDomain 
            $tempGroup = $tempString.Substring($tempSlash+1)
            #$tempGroup 
            # Create a new instance of a .Net object
            $currentAdObject = New-Object System.Object
            # Add user-defined customs members: the records retrieved with the three PowerShell commands
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
            $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObjName.sAMAccountName -Name ParentObject #The name of a parent obeject
            $global:arrGroupsWithinDomains += $currentAdObject
        }
        } #End Catch
    }
    Catch {
        #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - Domain: $($trustedDom4)" -ForegroundColor Yellow
        $notInDomainCounter = 5
    } #End Catch
}
}
if ($numTrustedDomains > 4) {
    If ($notInDomainCounter = 5) {
        #write-host "notInDomainCounter: $($notInDomainCounter) - grpName: $($grpName) - No Domains left to try!" -ForegroundColor Red
    }
}


ForEach ($fspMem in $fspMembers) { 
    #$fspMem | fl
  
    #String Splitting:
    $tempString = $currentObjName.sAMAccountName
    #$tempLength = $tempString.Length
    #$tempLength
    $tempSlash = $tempString.IndexOf("\")
    #$tempSlash
    TRY {$tempDomain = $tempString.Substring(0,$tempSlash)}CATCH{}
    #$tempDomain 
    $tempGroup = $tempString.Substring($tempSlash+1)
    #$tempGroup 
  
    # Create a new instance of a .Net object
    $currentAdObject = New-Object System.Object
 
    # Add user-defined customs members: the records retrieved with the three PowerShell commands
    $currentAdObject  | Add-Member -MemberType NoteProperty -Value $tempDomain -Name Domain #The Domain that hosts this object
    $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.samaccountname -Name ObjectName #The object Name i.e. name of a group
    $currentAdObject  | Add-Member -MemberType NoteProperty -Value $fspMem.objectClass -Name ObjectType # The type of object i.e. User or Group
    $currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObjName.sAMAccountName -Name ParentObject #The name of a parent obeject
    $global:arrGroupsWithinDomains += $currentAdObject
} #End ForEach ($fspMem in $fspMembers)
                               
                    <#
					# Create a new instance of a .Net object
					$currentAdObject = New-Object System.Object
	 
					# Add user-defined customs members: the records retrieved with the three PowerShell commands
					$currentAdObject  | Add-Member -MemberType NoteProperty -Value "LocalDomainStaticString" -Name Domain #The Domain that hosts this object
					$currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObjName.sAMAccountName -Name ObjectName #The object Name i.e. name of a group
					$currentAdObject  | Add-Member -MemberType NoteProperty -Value $currentObj.objectClass -Name ObjectType # The type of object i.e. User or Group
					$currentAdObject  | Add-Member -MemberType NoteProperty -Value "NoneStaticString" -Name ParentObject #The name of a parent obeject
					$global:arrGroupsWithinDomains += $currentAdObject
					#>        
#write-host "End of foreignSecurityPrincipal"
} #end "foreignSecurityPrincipal"
<#
            #"user" {$currentObj.Name}
            #group" {RecursivelyEnumerateGroupObjects($currentObj.Name)}
#>
        }#End of switch
<#
        #$FSPStrings = Convert-FspToUsername($currentObj.objectSid.Value) | select sAMAccountName
        #$FSPStrings
#> 
    } #End of foreach($grp of $currentGroup.Members)
} #End Function RecursivelyEnumerateGroupObjects
Function Get-LocalDomainNETBIOSName {
    #Get local domain NETBIOS name
    $global:localDomain = Get-ADDomain | select NetBIOSname
    
    Write-Host "Local Domain NETBIOS Name:" -ForegroundColor Yellow
    Write-Host "$($localDomain.NetBIOSname)"
    Write-Host ""
} #End Function Get-LocalDomainNETBIOSName
Function Get-DomainTrustDomains {
    #Get Domain trust NETBIOS names
    $trustedDomains = Get-ADTrust -Filter * -Properties * | Select name, Flatname
    #$trustedDomains.Flatname
    #$trustedDomains.name
    
    #Heading for domains list (output from ForEach-object below)
    Write-Host "Domains:" -ForegroundColor Yellow

    #For Each trusted domain
    $trustedDomains | ForEach-Object {

<# #For creating objects later        
        # Create a new instance of a .Net object
        $currentTrustedDomain = New-Object System.Object
 
        # Add user-defined customs members: the records retrieved with the three PowerShell commands
        $currentTrustedDomain  | Add-Member -MemberType NoteProperty -Value $_.FlatName -Name FlatName
        $currentTrustedDomain  | Add-Member -MemberType NoteProperty -Value $_.name -Name name
        $global:arrTrustedDomains += $currentTrustedDomain   

        $arrTrustedDomains | Select FlatName, name
        }
    #>
    
    write-host "$($_.Flatname) - $($_.name)"
        
    # 1. Check if an domainNameFlatName.txt file exists (this should contain username and encrypted password - if not - prompt user to enter the creds (and offer to store the encrypted file)
    If (Test-Path  "$($_.Flatname).txt") {
        #Success, File exists
        #Write-Host "A file by the name of $($_.Flatname).txt exists"
    } Else {
        #Failure, create file with creds (username, encrypted_password)
        Write-Host "$($_.Flatname).txt did does not exist, creating file..."
        New-Item "$($_.Flatname).txt" -type file        
        Write-Host "$($_.Flatname).txt created."
    } #End If (Test-Path  "$($_.Flatname).txt")
        
    # 2. Check if the creds in the file from step 1 work - if failure - prompt user to enter the creds (and offer to store the encrypted file), then retest (loop).             
    # 2.1 Can you and check whos in "trustedDomain\Domain Users"?

    #write-host ""
    }#Foreach ($trustedDomain in $trustedDomains.FlatName)

    Write-Host ""
} #End Function Get-DomainTrustDomains
Function StringSplitter {
	    #String Splitting:
	    $tempString = "ThisisMyDOMAINname\AndHere isMyGROUPname"
	    #$tempLength = $tempString.Length
	    #$tempLength
	    $tempSlash = $tempString.IndexOf("\")
	    #$tempSlash
	    $tempDomain = $tempString.Substring(0,$tempSlash)
	    $tempDomain 
	    $tempGroup = $tempString.Substring($tempSlash+1)
	    $tempGroup 
	} #End StringSplitter
Function DomainsAndGroups {
	    <#
	    #Take domain\username string
	    #add type, domain name and group name to an array of powershell objects
	    #for each domain, check if there are creds, if not prompt
	    #for each group within a domain, use the creds to enumerate the groups
	    #>
	    Param(
	     [string]$strRawDomainGroupNameString
	    )
	    $arrGroupsWithinDomains = @()
} #End Function DomainsAndGroups  
Function Main {
    Param(
     [string]$grpName 
    )
    
    #Set List of QTC users  (QTC ADMINS)
    $qtcUserArray = "chris.phillips","david.barrett","ian.witts","luke.kinson","Test","Test001"
    Write-Host "Group: $grpName" -ForegroundColor Green
 
    #Obtain Creds for Remote domain
    #$DomCreds = Get-Credential CB\QTC-user
    #$DomCreds = $MyCredential
 
    #Get local domain NETBIOS name
    $localDomain = Get-ADDomain | select NetBIOSname
    $localDomain.NetBIOSname
 
    #Get Domain trust NETBIOS names
    $trustedDomains = Get-ADTrust -Filter * -Properties * | Select name, Flatname
    #$trustedDomains.Flatname
    #$trustedDomains.name
    
    #For Each trusted domain
    $trustedDomains | ForEach-Object {
        
        write-host "$($_.Flatname)"
        write-host "$($_.name)"
        
        # 1. Check if an domainNameFlatName.txt file exists (this should contain username and encrypted password - if not - prompt user to enter the creds (and offer to store the encrypted file)
        If (Test-Path  "$($_.Flatname).txt") {
            #Success, File exists
        } Else {
            #Failure, create file with creds (username, encrypted_password)
            Write-Host "File doesn't exist"
            # New-Item "$($_.Flatname).txt" -type file        
        }
        
        # 2. Check if the creds in the file from step 1 work - if failure - prompt user to enter the creds (and offer to store the encrypted file), then retest (loop).             
        # 2.1 Can you and check whos in "trustedDomain\Domain Users"?
        
        
 
        write-host ""
    }#Foreach ($trustedDomain in $trustedDomains.FlatName)
 
    #Initialise Array
    $global:arrGroupsWithinDomains = @()
 
    #Populate Array
    RecursivelyEnumerateGroupObjects($grpName) #| Add-Content C:\temp\outputusers.csv
 
    #Remove Duplicates
    $arrGroupsWithinDomainsUnique = $arrGroupsWithinDomains | Select Domain, objectName, ObjectType, ParentObject -Unique 
    $arrGroupsWithinDomainsUniqueNoComps = $arrGroupsWithinDomainsUnique | Where-Object -Property ObjectType -Ne "Computer"
    $arrGroupsWithinDomainsUniqueUsersONLY  = $arrGroupsWithinDomainsUnique | Where-Object -Property ObjectType -eq "user"
 
    $arrGroupsWithinDomainsUniqueMinusParent = $arrGroupsWithinDomains | Select Domain, objectName, ObjectType -Unique #, ParentObject
    $arrGroupsWithinDomainsUniqueNoCompsMinusParent = $arrGroupsWithinDomainsUniqueMinusParent | Where-Object -Property ObjectType -Ne "Computer"
    $arrGroupsWithinDomainsUniqueUsersONLYMinusParent  = $arrGroupsWithinDomainsUniqueMinusParent | Where-Object -Property ObjectType -eq "user"
    #Output Heading
    Write-Host "Output" -ForegroundColor Yellow
 
    #Output
    #cls
    #$arrGroupsWithinDomains
 
    #$arrGroupsWithinDomainsUnique 
    #$arrGroupsWithinDomainsUniqueNoComps
    #$arrGroupsWithinDomainsUniqueUsersONLY
 
    #$arrGroupsWithinDomainsUniqueMinusParent
    #$arrGroupsWithinDomainsUniqueNoCompsMinusParent
    #$arrGroupsWithinDomainsUniqueUsersONLYMinusParent
 
    Write-host ""
    Write-host $initialGroup -ForegroundColor Yellow
    Write-host "Total: $($arrGroupsWithinDomains.count)"
 
    Write-host ""
    Write-host "Unique: $($arrGroupsWithinDomainsUnique.count)"
    Write-host "Unique and No Computers: $($arrGroupsWithinDomainsUniqueNoComps.count)"
    Write-host "Unique Users Only: $($arrGroupsWithinDomainsUniqueUsersONLY.count)"
 
    Write-host ""
    Write-Host "Unique (minus parent): $($arrGroupsWithinDomainsUniqueMinusParent.count)"
    Write-host "Unique and No Computers (minus parent): $($arrGroupsWithinDomainsUniqueNoCompsMinusParent.count)"
    Write-host "Unique Users Only (minus parent): $($arrGroupsWithinDomainsUniqueUsersONLYMinusParent.count)" -ForegroundColor Yellow
 
    #Export
    $arrGroupsWithinDomains | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomains.csv"
 
    #$arrGroupsWithinDomainsUnique | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUnique.csv"
    #$arrGroupsWithinDomainsUniqueNoComps | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueNoComps.csv"
    #$arrGroupsWithinDomainsUniqueUsersONLY | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueUsersONLY.csv"
 
    #$arrGroupsWithinDomainsUniqueMinusParent | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueMinusParent.csv"
    #$arrGroupsWithinDomainsUniqueNoCompsMinusParent | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueNoCompsMinusParent.csv"
    #$arrGroupsWithinDomainsUniqueUsersONLYMinusParent | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueUsersONLYMinusParent.csv"
    $arrGroupsFileName = "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)"
    $arrGroupsWithinDomainsUniqueUsersONLYMinusParent | Export-Csv "$($arrGroupsFileName)_arrGroupsWithinDomainsUniqueUsersONLYMinusParent.csv"

$file = "$($arrGroupsFileName)_arrGroupsWithinDomainsUniqueUsersONLYMinusParent.csv" # "20180914-Currie and Brown-UserLookupGroup_arrGroupsWithinDomainsUniqueUsersONLYMinusParent.csv"
#$outfile = "($($arrGroupsFileName)_arrGroupsWithinDomainsUniqueUsersONLYMinusParentLowerCase.csv" #"20180914-Currie and Brown-UserLookupGroup_arrGroupsWithinDomainsUniqueUsersONLYMinusParent_lowercase.csv"
#(Get-Content "$file" -Raw).ToLower() | Out-File "$outfile"

$global:arrLower = @()

$inputDataSet = Import-Csv $file

ForEach ($a in $inputDataSet) {
        # Create a new instance of a .Net object
        $strDomain = $a.Domain.ToString()
        $strDomainLower = $strDomain.toLower()
        #$strDomainLower

        $strObjectName = $a.ObjectName.ToString()
        $strObjectNameLower = $strObjectName.toLower()
        #$strObjectNameLower

        $strObjectType = $a.ObjectType.ToString()
        $strObjectTypeLower = $strObjectType.toLower()
        #$strObjectTypeLower
               
        
        $myNewObj= New-Object System.Object

        $myNewObj  | Add-Member -MemberType NoteProperty -Value $strDomainLower -Name Domain
        $myNewObj  | Add-Member -MemberType NoteProperty -Value $strObjectNameLower -Name ObjectName
        $myNewObj  | Add-Member -MemberType NoteProperty -Value $strObjectTypeLower -Name ObjectType
        $global:arrLower += $myNewObj
}

#Remove Duplicates
    $arrLowerUnique = $arrLower | Select Domain, objectName, ObjectType, ParentObject -Unique 
    #$arrLowerUniqueNoComps = $arrLowerUnique | Where-Object -Property ObjectType -Ne "Computer" 
    $arrLowerUniqueUsersONLY  = $arrLowerUnique | Where-Object -Property ObjectType -eq "user"
 
    $arrLowerUniqueMinusParent = $arrLower | Select Domain, objectName, ObjectType -Unique #, ParentObject 
    #$arrLowerUniqueNoCompsMinusParent = $arrLowerUniqueMinusParent | Where-Object -Property ObjectType -Ne "Computer"
    $arrLowerUniqueUsersONLYMinusParent  = $arrLowerUniqueMinusParent | Where-Object -Property ObjectType -eq "user"
    #Output Heading

 #Export
    #$arrLower | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrLower.csv"
 
    #$arrLowerUnique | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrLowerUnique.csv"
    #$arrLowerUniqueNoComps | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrLowerUniqueNoComps.csv"
    #$arrLowerUniqueUsersONLY | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrLowerUniqueUsersONLY.csv"
 
    #$arrLowerUniqueMinusParent | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrLowerUniqueMinusParent.csv"
    #$arrLowerUniqueNoCompsMinusParent | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrLowerUniqueNoCompsMinusParent.csv"
    #$customerName = "SHA"
    #$initialGroup = "RDS_USERS"
    $ExportCSVfilename = "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrLowerUniqueUsersONLYMinusParent.csv"
    $arrLowerUniqueUsersONLYMinusParent | Export-Csv $ExportCSVfilename 
    $ExportCSVfilename

#Upload to dropbox
. .\dropbox-upload.ps1 $ExportCSVfilename  "/$($ExportCSVfilename)"
 
} #End Main
 


### SCRIPT BODY ###
cd $workingDir

Foreach ($initialGroup in $GroupName) {
    Main($initialGroup) #| Add-Content C:\temp\outputusers.csv    
    # pause
}

Write-Host "Number of trusted domains: $($numTrustedDomains)" -ForegroundColor Yellow

<#cls
$initialGroup = "RDS_USERS"

 
pause
write-host ""
$initialGroup = "RDS_Excelerator"
Main($initialGroup) #| Add-Content C:\temp\outputusers.csv
#>