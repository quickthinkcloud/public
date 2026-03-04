### ABOUT AND INITIAL SETUP INFO/SCRIPTS ### 
<#
Author: Chris Phillips, for QuickThink Cloud Limited
Date: 20/12/2016
Version: 1.0
PURPOSE:  This script is monitoring group(s) in AD and send an email when someone is added or removed

REQUIRES: ActiveDirectory Module

VERSION HISTORY
Initial Version created from reference TOOL-Monitor-AD_DomainAdmins_EnterpriseAdmins.ps1 / Francois-Xavier CAT. 

### Initial Setup Script ###
# Creating PSCredential object
$trustedDom1 = "AD-NNHS"
$trustedDom1Server = $trustedDom1 # set to an IP i.e."1.2.3.1" # use only if explicitely required, else set this = $trustedDom1
$User = "AD-NNHS\SVC-AgressoCloud"
$File = "$($trustedDom1)_pw.txt"
(Get-Credential $User).Password | ConvertFrom-SecureString | Out-File $File
#>

### PARAMETERS (must be the first section of the script!)### 
param (
    $ConfigFile = $(throw "You must specify a config file")
    #Working parameters
    #[parameter(Mandatory=$true,HelpMessage="You must enter a string")]$aString
)
### END OF PARAMETERS ###

$scriptVersion = "20260304-1354"

$proceed = $false
$daysOfMonthToAudit = @(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31)
#$daysOfMonthToAudit = @(1,2,3,6,9,12,15,18,20,21,24,27,28,28,30,31)
$dayofMonth = get-date -format dd

foreach ($d in $daysOfMonthToAudit) {
    If ($d -eq $dayofMonth) {
        $proceed = $true
    } # end If
} # end foreach

If ($proceed) {

    $LogPath = "$($workingDir)LicensingAudit.log"
    Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):RDSLicensingAudit Started (scriptVersion: $($scriptVersion))"

    ### GLOBAL VARIABLES ###
    ## USER CONFIGURED VARIABLES ##
    # Monitor the following domain and groups
    $customerName = "CustomerName"
    #$workingDir = "C:\Users\$($env:USERNAME)\"
    $GroupName = @("RDS_Users","RDS_Excel","RDS_Word")
    <# Creating PSCredential object
    $trustedDom1 = "TrustedDom1.com"
    $trustedDom1Server = $trustedDom1 # set to an IP i.e."1.2.3.1" # use only if explicitely required, else set this = $trustedDom1
    $User = "TrustedDom1\QTC-user"
    $File = "$($trustedDom1)_pw.txt"
    $DomCreds1=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $File | ConvertTo-SecureString)

    # Creating PSCredential object
    $trustedDom2 = "TrustedDom2.com"
    $trustedDom2Server = $trustedDom2 # set to an IP i.e."1.2.3.2" # use only if explicitely required, else set this = $trustedDom2
    $User = "TrustedDom2\service-qtc"
    $File = "$($trustedDom2)_pw.txt"
    $DomCreds2=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $File | ConvertTo-SecureString)

    # Creating PSCredential object
    $trustedDom3 = "TrustedDom3.com"
    $trustedDom3Server = $trustedDom3 # set to an IP i.e."1.2.3.3" # use only if explicitely required, else set this = $trustedDom3
    $User = "TrustedDom3\service-qtc-me"
    $File = "$($trustedDom3)_pw.txt"
    $DomCreds3=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $File | ConvertTo-SecureString)

    # Creating PSCredential object
    $trustedDom4 = "TrustedDom4.com"
    $trustedDom4Server = $trustedDom4 # set to an IP i.e."1.2.3.4" # use only if explicitely required, else set this = $trustedDom4
    $User = "TrustedDom4\QTCAdmin"
    $File = "$($trustedDom4)_pw.txt"
    $DomCreds4=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $File | ConvertTo-SecureString)
    #>
    $numTrustedDomains = 0

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
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$grpName,

        # Optional: only pass Server/Credential when provided (local domain)
        [string]$DomainController,

        [pscredential]$Credential
    )

    # ----------------------------
    # Init (keeps your global pattern)
    # ----------------------------
    if (-not $global:firstRun -or $global:firstRun -ne 1) {
        $global:parentGrpName = ""
        $global:firstRun = 1
        if (-not $global:arrGroupsWithinDomains) { $global:arrGroupsWithinDomains = @() }
    }

    # ----------------------------
    # Safe AD splat for LOCAL domain calls (PS 5.1)
    # ----------------------------
    $adParams = @{ ErrorAction = 'Stop' }
    if (-not [string]::IsNullOrWhiteSpace($DomainController)) { $adParams.Server = $DomainController }
    if ($null -ne $Credential) { $adParams.Credential = $Credential }

    # ----------------------------
    # Helpers
    # ----------------------------
    function Test-UserRelevant {
        param([Microsoft.ActiveDirectory.Management.ADUser]$User)

        $now = Get-Date

        $loggedOnThisMonth =
            $User.LastLogonDate -and
            $User.LastLogonDate.Year  -eq $now.Year -and
            $User.LastLogonDate.Month -eq $now.Month

        $activeAndValid =
            $User.Enabled -eq $true -and
            (
                $null -eq $User.AccountExpirationDate -or
                $User.AccountExpirationDate -gt $now.AddMonths(-1)
            )

        $allBlank =
            $null -eq $User.LastLogonDate -and
            $null -eq $User.Enabled -and
            $null -eq $User.AccountExpirationDate

        return ($loggedOnThisMonth -or $activeAndValid -or $allBlank)
    }

    function Add-Row {
        param(
            [string]$DomainNetbios,
            [string]$ObjectName,
            [string]$ObjectType,
            [string]$ParentObject
        )
        $global:arrGroupsWithinDomains += [pscustomobject]@{
            Domain       = $DomainNetbios
            ObjectName   = $ObjectName
            ObjectType   = $ObjectType
            ParentObject = $ParentObject
        }
    }

    # ----------------------------
    # Domain info for output
    # ----------------------------
    try {
        $localDomain = Get-ADDomain @adParams
        $localNetbios = $localDomain.NetBIOSName
    } catch {
        $localNetbios = $env:USERDOMAIN
    }

    Write-Host ""
    Write-Host $grpName -ForegroundColor Green
    Write-Host ""

    # ----------------------------
    # Load group (local)
    # ----------------------------
    try {
        $currentGroup = Get-ADGroup @adParams -Identity $grpName -Properties SamAccountName, DistinguishedName, ObjectClass, Name
    } catch {
        Write-Warning ("Failed to load group [{0}]. {1}" -f $grpName, $_.Exception.Message)
        return
    }

    Add-Row -DomainNetbios $localNetbios -ObjectName $currentGroup.Name -ObjectType $currentGroup.ObjectClass -ParentObject $global:parentGrpName

    # ----------------------------
    # Enumerate members (try ADWS; fallback to raw member attribute)
    # ----------------------------
    $groupId = $null
    if (-not [string]::IsNullOrWhiteSpace($currentGroup.DistinguishedName)) { $groupId = $currentGroup.DistinguishedName }
    elseif (-not [string]::IsNullOrWhiteSpace($currentGroup.SamAccountName)) { $groupId = $currentGroup.SamAccountName }
    else { $groupId = $currentGroup.Name }

    $members = $null
    try {
        $members = Get-ADGroupMember @adParams -Identity $groupId
    } catch {
        Write-Warning ("Get-ADGroupMember failed for [{0}]. Falling back to raw 'member' attribute. {1}" -f $grpName, $_.Exception.Message)
        try {
            $g = Get-ADGroup @adParams -Identity $groupId -Properties member
            $resolved = @()
            foreach ($dn in $g.member) {
                try {
                    $resolved += Get-ADObject @adParams -Identity $dn -Properties objectClass, objectSid, samAccountName, distinguishedName, name
                } catch {
                    Write-Warning ("Failed to resolve member DN [{0}] in group [{1}]. {2}" -f $dn, $grpName, $_.Exception.Message)
                }
            }
            $members = $resolved
        } catch {
            Write-Warning ("Fallback enumeration also failed for [{0}]. {1}" -f $grpName, $_.Exception.Message)
            return
        }
    }

    if (-not $members) { return }

    # ----------------------------
    # Expand members
    # ----------------------------
    foreach ($m in $members) {

        # Normalize class/name/sid across Get-ADGroupMember vs Get-ADObject
        $objClass = $m.ObjectClass
        $objName  = $null
        $sidValue = $null
        $dnValue  = $null

        if ($m.PSObject.Properties.Match('DistinguishedName').Count -gt 0 -and $m.DistinguishedName) { $dnValue = $m.DistinguishedName }
        elseif ($m.PSObject.Properties.Match('distinguishedName').Count -gt 0 -and $m.distinguishedName) { $dnValue = $m.distinguishedName }

        if ($m.PSObject.Properties.Match('SID').Count -gt 0 -and $m.SID) {
            try { $sidValue = $m.SID.Value } catch { $sidValue = $null }
        } elseif ($m.PSObject.Properties.Match('objectSid').Count -gt 0 -and $m.objectSid) {
            try { $sidValue = $m.objectSid.Value } catch { $sidValue = $null }
        }

        if ($m.PSObject.Properties.Match('SamAccountName').Count -gt 0 -and $m.SamAccountName) { $objName = $m.SamAccountName }
        elseif ($m.PSObject.Properties.Match('samAccountName').Count -gt 0 -and $m.samAccountName) { $objName = $m.samAccountName }
        elseif ($m.PSObject.Properties.Match('Name').Count -gt 0 -and $m.Name) { $objName = $m.Name }

        # Try resolve SID -> DOMAIN\Name if Convert-FspToUsername exists
        $resolvedSam = $objName
        if ($sidValue -and (Get-Command Convert-FspToUsername -ErrorAction SilentlyContinue)) {
            try {
                $tmp = Convert-FspToUsername $sidValue | Select-Object -First 1
                if ($tmp -and $tmp.sAMAccountName) { $resolvedSam = $tmp.sAMAccountName }
            } catch {}
        }

        # Debug output
        Write-Host "currentObjSID: " -NoNewline
        Write-Host ($sidValue) -ForegroundColor Yellow
        Write-Host "currentObjClass: " -NoNewline
        Write-Host $objClass -ForegroundColor Yellow
        Write-Host "currentObjName: " -NoNewline
        Write-Host $resolvedSam -ForegroundColor Yellow
        Write-Host ""

        switch ($objClass) {

            'user' {
                # Load full user props locally
                $u = $null
                try {
                    if ($dnValue) {
                        $u = Get-ADUser @adParams -Identity $dnValue -Properties *
                    } elseif ($sidValue) {
                        $u = Get-ADUser @adParams -Filter ("SID -eq '{0}'" -f $sidValue) -Properties *
                    } elseif ($resolvedSam) {
                        $u = Get-ADUser @adParams -Identity $resolvedSam -Properties *
                    }
                } catch {
                    Write-Warning ("Failed to load user [{0}]. {1}" -f $resolvedSam, $_.Exception.Message)
                    continue
                }

                if ($u -and (Test-UserRelevant -User $u)) {
                    Add-Row -DomainNetbios $localNetbios -ObjectName $u.SamAccountName -ObjectType $u.ObjectClass -ParentObject $currentGroup.SamAccountName
                }
            }

            'group' {
                $oldParent = $global:parentGrpName
                $global:parentGrpName = $currentGroup.SamAccountName
                $nextGroup = $m.Name
                if (-not $nextGroup) { $nextGroup = $resolvedSam }
                if ($nextGroup) {
                    RecursivelyEnumerateGroupObjects -grpName $nextGroup -DomainController $DomainController -Credential $Credential
                }
                $global:parentGrpName = $oldParent
            }

            'foreignSecurityPrincipal' {
                # ----------------------------
                # Remote domain expansion (restored)
                # ----------------------------
                # Expect resolvedSam like "NETBIOS\SamAccountName" when Convert-FspToUsername works.
                $tempDomain = $null
                $tempObject = $null

                if ($resolvedSam -and ($resolvedSam -is [string]) -and ($resolvedSam.Contains('\'))) {
                    $idx = $resolvedSam.IndexOf('\')
                    if ($idx -gt 0) {
                        $tempDomain = $resolvedSam.Substring(0, $idx)
                        $tempObject = $resolvedSam.Substring($idx + 1)
                    }
                }

                # Always record the FSP itself
                $fspNameToRecord = $resolvedSam
                if (-not $fspNameToRecord) { $fspNameToRecord = $objName }
                Add-Row -DomainNetbios $localNetbios -ObjectName $fspNameToRecord -ObjectType 'foreignSecurityPrincipal' -ParentObject $currentGroup.SamAccountName

                if (-not $tempDomain -or -not $tempObject) {
                    # Can't expand without a parsed NETBIOS\name
                    continue
                }

                # Find trusted domain record (expects arrTrustedDomainsFromCSV like your original)
                $trustedList = $null
                if ($script:arrTrustedDomainsFromCSV) { $trustedList = $script:arrTrustedDomainsFromCSV }
                elseif ($global:arrTrustedDomainsFromCSV) { $trustedList = $global:arrTrustedDomainsFromCSV }

                if (-not $trustedList) {
                    Write-Warning ("No arrTrustedDomainsFromCSV found; cannot expand foreignSecurityPrincipal [{0}]." -f $fspNameToRecord)
                    continue
                }

                foreach ($rec in $trustedList) {
                    if ($rec.NetBIOS -ne $tempDomain) { continue }

                    # Your original pattern: variable named trustedDom<ID>Creds contains creds for that domain
                    $domCreds = $null
                    try { $domCreds = Get-Variable -Name ("trustedDom{0}Creds" -f $rec.ID) -ValueOnly -ErrorAction SilentlyContinue } catch {}

                    $remoteParams = @{ ErrorAction = 'Stop'; Server = $rec.FQDN }
                    if ($domCreds) { $remoteParams.Credential = $domCreds }

                    # 1) Try as USER in remote domain
                    try {
                        $ru = Get-ADUser @remoteParams -Identity $tempObject -Properties *
                        if ($ru -and (Test-UserRelevant -User $ru)) {
                            Add-Row -DomainNetbios $tempDomain -ObjectName $ru.SamAccountName -ObjectType $ru.ObjectClass -ParentObject $currentGroup.SamAccountName
                        }
                        break
                    } catch {
                        # Not a user or lookup failed â€” try as group next
                    }

                    # 2) Try as GROUP in remote domain, expand members recursively (remote only)
                    try {
                        $rmembers = Get-ADGroupMember @remoteParams -Identity $tempObject -Recursive
                        foreach ($rm in $rmembers) {
                            if ($rm.ObjectClass -eq 'user') {
                                try {
                                    $ru2 = Get-ADUser @remoteParams -Identity $rm.DistinguishedName -Properties *
                                    if ($ru2 -and (Test-UserRelevant -User $ru2)) {
                                        Add-Row -DomainNetbios $tempDomain -ObjectName $ru2.SamAccountName -ObjectType $ru2.ObjectClass -ParentObject $currentGroup.SamAccountName
                                    }
                                } catch {
                                    Write-Warning ("Remote user load failed [{0}] via [{1}]. {2}" -f $rm.Name, $rec.FQDN, $_.Exception.Message)
                                }
                            } elseif ($rm.ObjectClass -eq 'group') {
                                Add-Row -DomainNetbios $tempDomain -ObjectName $rm.Name -ObjectType 'group' -ParentObject $currentGroup.SamAccountName
                            }
                        }
                        break
                    } catch {
                        Write-Warning ("Remote expansion failed for [{0}] via [{1}]. {2}" -f $fspNameToRecord, $rec.FQDN, $_.Exception.Message)
                        break
                    }
                }
            }

            Default {
                $nameToRecord = $resolvedSam
                if (-not $nameToRecord) { $nameToRecord = $objName }
                Add-Row -DomainNetbios $localNetbios -ObjectName $nameToRecord -ObjectType $objClass -ParentObject $currentGroup.SamAccountName
            }
        }
    }
} #End Function RecursivelyEnumerateGroupObjects #20260304Update


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
        $qtcUserArray = "chris.phillips","david.barrett","ian.witts","luke.kinson","stephen.wilding","QTCTEST","steffan.thomas"
        Write-Host "Group: $grpName" -ForegroundColor Green
 
        #Get local domain NETBIOS name
        $localDomain = Get-ADDomain | select NetBIOSname
        $localDomain.NetBIOSname
 
        #Get Domain trust NETBIOS names
        $trustedDomains = Get-ADTrust -Filter * -Properties * | Select name, Flatname
        #$trustedDomains.Flatname
        #$trustedDomains.name
    
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
        $arrGroupsWithinDomains | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomains.csv" -NoTypeInformation
 
        #$arrGroupsWithinDomainsUnique | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUnique.csv"
        #$arrGroupsWithinDomainsUniqueNoComps | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueNoComps.csv"
        #$arrGroupsWithinDomainsUniqueUsersONLY | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueUsersONLY.csv"
 
        #$arrGroupsWithinDomainsUniqueMinusParent | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueMinusParent.csv"
        #$arrGroupsWithinDomainsUniqueNoCompsMinusParent | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueNoCompsMinusParent.csv"
        #$arrGroupsWithinDomainsUniqueUsersONLYMinusParent | Export-Csv "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrGroupsWithinDomainsUniqueUsersONLYMinusParent.csv"
        $arrGroupsFileName = "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)"
        $arrGroupsWithinDomainsUniqueUsersONLYMinusParent | Export-Csv "$($arrGroupsFileName)_arrGroupsWithinDomainsUniqueUsersONLYMinusParent.csv" -NoTypeInformation

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
        $ExportCSVfilename = "$(get-date -Format yyyyMMdd)-$($customerName)-$($initialGroup)_arrLowerUniqueUsersONLYMinusParent.csv"
        $arrLowerUniqueUsersONLYMinusParent | Export-Csv $ExportCSVfilename -NoTypeInformation
        $ExportCSVfilename

        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):RDSLicensingAudit Created $($ExportCSVfilename)"
        #Upload to dropbox
        #Start-Sleep -Seconds 3
        #. .\dropbox-upload.ps1 $ExportCSVfilename  "/$($ExportCSVfilename)"

        #Upload to SFTP
        Start-Sleep -Seconds 3
        Send-SFTPData -sourceFiles $ExportCSVfilename -credential $SFTPCreds -SFTProotDir "/licensing"
 
    } #End Main
    Function Test-Cred {
           
        [CmdletBinding()]
        [OutputType([String])] 
       
        Param ( 
            [Parameter( 
                Mandatory = $false, 
                ValueFromPipeLine = $true, 
                ValueFromPipelineByPropertyName = $true
            )] 
            [Alias( 
                'PSCredential'
            )] 
            [ValidateNotNull()] 
            [System.Management.Automation.PSCredential]
            [System.Management.Automation.Credential()] 
            $Credentials
        )
        $Domain = $null
        $Root = $null
        $Username = $null
        $Password = $null
      
        If($Credentials -eq $null)
        {
            Try
            {
                $Credentials = Get-Credential "domain\$env:username" -ErrorAction Stop
            }
            Catch
            {
                $ErrorMsg = $_.Exception.Message
                Write-Warning "Failed to validate credentials: $ErrorMsg "
                Pause
                Break
            }
        }
      
        # Checking module
        Try
        {
            # Split username and password
            $Username = $credentials.username
            $Password = $credentials.GetNetworkCredential().password
  
            # Get Domain
            $Root = "LDAP://" + ([ADSI]'').distinguishedName
            $Domain = New-Object System.DirectoryServices.DirectoryEntry($Root,$UserName,$Password)
        }
        Catch
        {
            $_.Exception.Message
            Continue
        }
  
        If(!$domain)
        {
            Write-Warning "Something went wrong"
        }
        Else
        {
            If ($domain.name -ne $null)
            {
                return "Authenticated"
            }
            Else
            {
                return "Not authenticated"
            }
        }
    }
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

    ### SCRIPT BODY ###
    #Run the config .ps1 to set the variables
    write-host "Current Script Version: $($scriptVersion)"
    Start-Sleep -Seconds 3
    . .\$ConfigFile
    cd $workingDir


    <### This section FORCES Dynamic groups based on the criteria below ###
    $GroupName = @()
    $arrOfGroups = Get-ADGroup -Filter {Name -like "RDS_*"} | sort name | select name
    foreach ($grp in $arrOfGroups) {
        $GroupName += $grp.name
    }
    $arrOfGroups = Get-ADGroup -Filter {Name -like "REPORT_*"} | sort name | select name
    foreach ($grp in $arrOfGroups) {
        $GroupName += $grp.name
    }
    ### End of Dynamic groups Force ###>

    #Additional Functions
    . .\sftp_function.ps1

    ### SELF UPDATER SECTION ###
    #SCRIPT ADMIN VARIABLES!
    $scriptName = "RDSLicensingAudit.ps1"
    $updateDirectoryName = "RDSLUAUpdates"
    $updatedVersionName = "RDSLUA_latest.ps1"
    $scriptSourceURL = "https://raw.githubusercontent.com/quickthinkcloud/public/master/licensing/RDSLicensingAudit.ps1"

    UpdatesAvailable
    Update-Myself "$($updateDirectoryName)\$($updatedVersionName)"
    $SourcePath = "$($updateDirectoryName)\$($updatedVersionName)"

    Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):RDSLicensingAudit Self-Update Check/Complete."
    ### END OF SELF UPDATER SECTION ###


    cd $workingDir

    # Get Domain Trusts
    $domTrusts = Get-ADTrust -Filter {(Direction -eq "Outbound") -or (Direction -eq "BiDirectional")} -Properties * #Get-ADTrust -Filter * #20251105-1216
    $domTrustsCount = ($domtrusts.Name).count
    write-host "Number of domain trusts: $($domTrustsCount)" -ForegroundColor Yellow


    #Check for/create a DTInfo file
    $filename = "DTInfo.csv"
     if (Test-Path $filename ) {
            "$($filename) exists"
        } else {
            "ID,NetBIOS,FQDN,Server,User,EncryptedPassword,DomainSID" | Out-File $filename

            $i = 1
            foreach ($trust in $domTrusts) {
                Write-Host $trust.Name
                Write-Host $trust.FlatName

                $discoveredTrustName = $trust.Name
                if (!($thisTrustName = Read-Host "Domain Name [$discoveredTrustName]")) { $thisTrustName = $discoveredTrustName }

                $discoveredTrustFlatName = $trust.FlatName
                if (!($thisTrustFlatName = Read-Host "Domain NetBIOS Name [$discoveredTrustFlatName]")) { $thisTrustFlatName = $discoveredTrustFlatName }

                $discoveredTrustServer = "$($thisTrustName)"
                if (!($thisTrustServer = Read-Host "Server To Use [$discoveredTrustServer]")) { $thisTrustServer = $discoveredTrustServer }

                $preSetDefaultDomainUsername = "QTCAdmin"
                if (!($User = Read-Host "Username [$preSetDefaultDomainUsername] for the $($trust.Flatname) domain")) { $User = $preSetDefaultDomainUsername }

                #$User = Read-Host -Prompt "Input the user name for the $($trust.Flatname) domain"
                $PassAsEncryptedString = (Get-Credential "$($trust.Flatname)\$User").Password | ConvertFrom-SecureString
                $string = "$($i),$($thisTrustFlatName),$($thisTrustName),$($discoveredTrustServer),$($thisTrustFlatName)\$($User),$($PassAsEncryptedString),$($trust.securityIdentifier)" | Out-File $filename -Append
        
                $i++
            } #End foreach


        } # end if


    #Number of lines in the file
    $rowsInDTInfo = get-content $filename | Measure-Object -Line
    #$rowsInDTInfo 


    #Check if there are enough lines for domain trusts
    if ($rowsInDTInfo.Lines-1 -ne $domTrustsCount) {
        "There are not enough lines for each domain trust, there are $($domTrustsCount) trusts but only $($rowsInDTInfo.lines-1) within the DTInfo File"

        $proceedDefault = "0"
        $proceedDecision = 1
        #if (!($proceedDecision = Read-Host "Do you want to proceed? [$proceedDefault]")) { $User = $proceedDefault }
    
        #Reset the DTInfor File
        If ($proceedDecision = 0) {

            "ID,NetBIOS,FQDN,Server,User,EncryptedPassword,DomainSID" | Out-File $filename
        
            $i = 1
            foreach ($trust in $domTrusts) {
                Write-Host $trust.Name
                Write-Host $trust.FlatName

                $discoveredTrustName = $trust.Name
                if (!($thisTrustName = Read-Host "Domain Name [$discoveredTrustName]")) { $thisTrustName = $discoveredTrustName }

                $discoveredTrustFlatName = $trust.FlatName
                if (!($thisTrustFlatName = Read-Host "Domain NetBIOS Name [$discoveredTrustFlatName]")) { $thisTrustFlatName = $discoveredTrustFlatName }

                $discoveredTrustServer = "$($thisTrustName)"
                if (!($thisTrustServer = Read-Host "Server To Use [$discoveredTrustServer]")) { $thisTrustServer = $discoveredTrustServer }

                $preSetDefaultDomainUsername = "QTCAdmin"
                if (!($User = Read-Host "Username [$preSetDefaultDomainUsername] for the $($trust.Flatname) domain")) { $User = $preSetDefaultDomainUsername }

                #$User = Read-Host -Prompt "Input the user name for the $($trust.Flatname) domain"
                $PassAsEncryptedString = (Get-Credential "$($trust.Flatname)\$User").Password | ConvertFrom-SecureString
                $string = "$($i),$($thisTrustFlatName),$($thisTrustName),$($discoveredTrustServer),$($thisTrustFlatName)\$($User),$($PassAsEncryptedString),$($trust.securityIdentifier)" | Out-File $filename -Append
        

                $i++
            } #End foreach
        } # End if

    } # End If


    #Read and test the creds
    $arrTrustedDomainsFromCSV = Import-Csv $filename

    $i=1
    foreach ($rec in $arrTrustedDomainsFromCSV) {
        $currNETBIOS = $arrTrustedDomainsFromCSV | where ID -eq $i | select NetBIOS
        Get-Variable -Name "trustedDom$($i)NETBOIS" -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
        New-Variable -Name "trustedDom$($i)NETBOIS" -Value $currNETBIOS.NetBIOS
    
        $currFQDN = $arrTrustedDomainsFromCSV | where ID -eq $i | select FQDN
        Get-Variable -Name "trustedDom$i" -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
        New-Variable -Name "trustedDom$i" -Value $currFQDN.FQDN

        $User = $arrTrustedDomainsFromCSV | where ID -eq $i | select User
        $Password = $arrTrustedDomainsFromCSV | where ID -eq $i | select EncryptedPassword
        $DomCreds=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User.User, ($Password.EncryptedPassword | ConvertTo-SecureString)

        Get-Variable -Name "trustedDom$($i)Creds" -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
        New-Variable -Name "trustedDom$($i)Creds" -Value $DomCreds

        $currDSID = $arrTrustedDomainsFromCSV | where ID -eq $i | select DomainSID
        Get-Variable -Name "trustedDom$($i)DomainSID" -ErrorAction SilentlyContinue | Remove-Variable -ErrorAction SilentlyContinue
        New-Variable -Name "trustedDom$($i)DomainSID" -Value $currDSID.DomainSID
    

        if ($customerCode -eq "CAB") {
            #Do nothing
        } Else {
            #Test the Creds
            $result = Test-Cred $DomCreds
            if ($result -eq "Not Authenticated") {
                #Write-host "Something went wrong with the credentials for the $($currFQDN.FQDN) (NETBIOS = $($currNETBIOS.NetBIOS)) domain - Ctrl-C to quit and try again with the correct credentials!" -ForegroundColor Red
                #Copy-Item -Path $filename -Destination "$($filename)_OLD"
                #Remove-Item $filename
                #pause
      
                $err = "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):RDSLicensingAudit - Something went wrong with the credentials for the $($currFQDN.FQDN) (NETBIOS = $($currNETBIOS.NetBIOS)) domain - Ctrl-C to quit and try again with the correct credentials! (scriptVersion: $($scriptVersion))"   
                Write-EventLog -LogName Application -Source "QTC" -EventID 10 -Message "$err" -EntryType Error
                Add-Content "ERROR_$($customerName)_$($currFQDN.FQDN).LOG" $err
                #. .\dropbox-upload.ps1 "ERROR_$($customerName)_$($currFQDN.FQDN).LOG"  "/ERROR_$($customerName)_$($currFQDN.FQDN).LOG"
                Send-SFTPData -sourceFiles "ERROR_$($customerName)_$($currFQDN.FQDN).LOG" -credential $SFTPCreds -SFTProotDir "/licensing"
                Write-host $err -ForegroundColor Red
                Start-Sleep -Seconds 3
            } else {
                Write-host "$($currFQDN.FQDN) (NETBIOS = $($currNETBIOS.NetBIOS)) domain creds are ok" -ForegroundColor Green
            } #End if
        } # End if
        Remove-Variable DomCreds
        $i++
    } #End foreach

    Write-Host "Waiting 2 minutes after credentials check..." -ForegroundColor Yellow
    Start-Sleep -Seconds 120


    Foreach ($initialGroup in $GroupName) {
        Main($initialGroup) #| Add-Content C:\temp\outputusers.csv    
    }
    Write-Host "Number of trusted domains: $($domTrustsCount)" -ForegroundColor Yellow

    <#
    ### EY Microsoft Audit ###
    $EYOutputFolder = "C:\Repository\EY_Output"
    $EYOutputZip = "$($customerName)_EY_Output.7z"

    If (!(Test-Path -PathType Container $EYOutputFolder )) {
        Start-Process -FilePath cmd.exe -ArgumentList "/c cscript EYInventoryScript.vbs /AD" -Wait
    } # End If

    If (Test-Path -PathType Container $EYOutputFolder ) {
        & "C:\Program Files\7-Zip\7z.exe" a $EYOutputZip "$($EYOutputFolder)\*"
    } # End If

    Start-Sleep -Seconds 60

    #$EYOutput = "C:\Repository\$($customerName)_EQ_Output.7z"
    If (Test-Path $EYOutputZip) {
        Send-SFTPData -sourceFiles "$($EYOutputZip)" -credential $SFTPCreds -SFTProotDir "/licensing"
        Start-Sleep -Seconds 60
        Remove-Item $EYOutputZip -Force
    } # End If
    ### EY Microsoft Audit ###
    #>

    # Disconnect SFTP session
    (Get-SFTPSession -SessionId 0).Disconnect()
    Get-SFTPSession
    Get-SFTPSession | Remove-SFTPSession
    Get-SFTPSession

    #Get-QTCFile -filepath "C:\QTCScripts\Scheduled\Audit\QTCCustomerAudit.ps1" -filesourceURL "https://raw.githubusercontent.com/quickthinkcloud/public/master/audit/QTCCustomerAudit.ps1"
    #Update-QTCFile -filepath "C:\QTCScripts\Scheduled\Audit\QTCCustomerAudit.ps1" -filesourceURL "https://raw.githubusercontent.com/quickthinkcloud/public/master/audit/QTCCustomerAudit.ps1"

    #Get-QTCFile -filepath "C:\QTCScripts\Scheduled\General\QTCFileUpdator.ps1" -filesourceURL "https://raw.githubusercontent.com/quickthinkcloud/public/master/general/QTCFileUpdator.ps1"
    #Update-QTCFile -filepath "C:\QTCScripts\Scheduled\General\QTCFileUpdator.ps1" -filesourceURL "https://raw.githubusercontent.com/quickthinkcloud/public/master/general/QTCFileUpdator.ps1"



    
    if (!($SBWCust)) {
        Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):RDSLicensingAudit Checking for Encrypted Databases Starting."
        ### SQL Encryption Check ###
        Add-ADGroupMember SQL_Admins -Members SVC_PSMonitoring

        $sqlServers = Get-ADComputer -filter {Name -like "*sql*"} | sort name | select name


        foreach ($svr in $sqlServers) {

            $svr.name

            Invoke-Command -ComputerName $svr.name -Credential $ctxCreds -ScriptBlock {

                $regKey="HKLM:\SOFTWARE\CentraStage"
                New-ItemProperty -Path $regKey -Name "Custom18" -Value "" -PropertyType String -ErrorAction SilentlyContinue -force

                $qry = "select name, is_encrypted from sys.databases where (name like '%UBW%' or name like '%agr%')"
        
                $result = Invoke-Sqlcmd -ServerInstance localhost -Database master -Query $qry


                $output = $result | Out-String

                $output
        
                New-ItemProperty -Path $regKey -Name "Custom18" -Value "$($output)" -PropertyType String -ErrorAction SilentlyContinue -force

            } #End invoke-command


        }
    Add-Content $LogPath "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss'):RDSLicensingAudit Checking for Encrypted Databases Ended."
    } # End if SBW
} # end If ($proceed)

