﻿cd C:\QTCScripts\Scheduled\LicenseAudit
Add-DnsServerResourceRecordA -Name "QTCServices" -ZoneName "myqtcloud.com" -IPv4Address "213.39.63.77"
Add-DnsServerResourceRecordCName -Name "VILLEFORT" -HostNameAlias "QTCServices.myqtcloud.com." -ZoneName "myqtcloud.com"


[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
#Register-PSRepository -Default -Verbose
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

Install-Module posh-ssh

get-module posh-ssh
get-command -Module *POSH*
Get-PSRepository