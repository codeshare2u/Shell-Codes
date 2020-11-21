<#	
	.NOTES
	===========================================================================
	 Created on:   	25/9/2020 9:06 PM
	 Created by:   	Abdul
	 Organization: 	
	 Filename:     	Get-InactiveObjects
	===========================================================================
	.DESCRIPTION
		Find inactive objects in AD
    .Synopsis
         Scan thorugh AD to find inactive objects with date option
	.EXAMPLE
     Get-InactiveObjects -item computers -date 90
    .EXAMPLE
     Get-InactiveObjects -item Users -date 90
    .EXAMPLE
     Get-InactiveObjects -item DNS
	.EXAMPLE
     Get-InactiveObjects -item all
    # Default date will be 90 days for computers and users
#>

Function Get-InactiveObjects
{
	[cmdletbinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet('Computers', 'OUs', 'Gpos', 'Users', 'groups', 'Dns', 'All')]
		[String]$Item,
		[parameter(Mandatory = $false)]
		[ValidateRange(30, 180)]
		[int]$Date = 90
	)
	$path = (Get-Location).path
	
	$TDate = (Get-Date).AddDays(-$Date)
	
	$fname = "$path\Inactive"
	
	if ($Item -eq 'All')
	{
		$NItem = @('Computers', 'OUs', 'Gpos', 'Users', 'groups', 'Dns')
		
	}
	else
	{
		$NItem = $Item
	}
	
	try
	{
		Write-Host "please wait for a while,  data is processsing ... ," -ForegroundColor Cyan
		switch ($NItem)
		{
			'computers' {
				#<code>
				$Computers = Get-ADComputer -Filter 'Lastlogondate -le $TDate' -Properties * | Select-Object DNSHostName, OperatingSystem, DistinguishedName, IPv4Address, LastLogonDate, whenChanged, PasswordLastSet, PasswordExpired, @{
					Name	 = 'Ping'; Expression = {
						if ((Test-connection $_.IPv4Address -count 1)) { "True" }
						else { "False" }
					}
				}, @{
					Name	 = 'Manual Creation'; Expression = {
						if ($_.IPv4Address -eq $null) { "True" }
						else { "False" }
					}
				}
				if ($Computers)
				{ $Computers | Export-Csv "$($fname)_computers.csv" -NoTypeInformation }
				else
				{
					Write-Verbose "No data available for the Computers with given range"
				}
			}
			'OUs' {
				#<code>
				$Orgunit = Get-ADOrganizationalUnit -Filter * -Properties * | ForEach-Object {
					if (-not (Get-ADObject -SearchBase $_ -SearchScope OneLevel -Filter *))
					{
						$_ | Select-Object Name, DistinguishedName, Created, @{ Name = 'Changed'; E = { $_.Whenchanged } }
					}
				}
				if ($Orgunit)
				{ $Orgunit | Export-Csv "$($fname)_Ous.csv" -NoTypeInformation }
				else
				{
					Write-Verbose "All OUs are having Objects in it"
				}
			}
			
			'Gpos' {
				#<code>
				$BackupPath = if (!(Test-Path "$path\BackupunlinkedGpos"))
				{ New-Item -ItemType Directory "$path\BackupunlinkedGpos" -Force }
				$allGpo = Get-GPO -All | Where-Object {
					If ($_ | Get-GPOReport -ReportType XML | Select-String -NotMatch "<LinksTo>")
					{
						#Backup-GPO -Name $_.DisplayName -Path "$path\BackupunlinkedGpos"
						#Get-GPOReport -Name $_.DisplayName -ReportType Html -Path "$path\BackupunlinkedGpos\$($_.DisplayName).html"
						$_ 
						#$_.Displayname | remove-gpo -Confirm
					}
					
				}
				if ($allGpo)
				{ $allGpo | Export-Csv "$($fname)_Gpos.csv" -NoTypeInformation }
				else
				{
					Write-Verbose "All Gpos are linked to OUs"
				}
			}
			'Users' {
				#<code>
				$InactiveAccount = Search-ADAccount -AccountInactive -TimeSpan 90 | Where-Object Name -NotMatch "Guest|DefaultAccount|krbtgt"
				if ($InactiveAccount)
				{ $InactiveAccount | Export-Csv "$($fname)_Account.csv" -NoTypeInformation }
				else
				{
					Write-Verbose "All Gpos are linked to OUs"
				}
			}
			'groups' {
				#<code>
				$list = @('WinRMRemoteWMIUsers__',
					'Storage Replica Administrators',
					'Key Admins',
					'Enterprise Key Admins',
					'Print Operators',
					'Backup Operators',
					'Replicator',
					'Remote Desktop Users',
					'Network Configuration Operators',
					'Performance Monitor Users',
					'Performance Log Users',
					'Distributed COM Users'
					'Cryptographic Operators',
					'Event Log Readers',
					'Certificate Service DCOM Access',
					'RDS Remote Access Servers',
					'RDS Endpoint Servers',
					'RDS Management Servers',
					'Hyper-V Administrators',
					'Access Control Assistance Operators',
					'Remote Management Users',
					'Domain Computers',
					'Domain Controllers',
					'Cert Publishers',
					'Domain Users',
					'Domain Guests',
					'RAS and IAS Servers',
					'Server Operators',
					'Account Operators',
					'Incoming Forest Trust Builders',
					'Terminal Server License Servers',
					'Allowed RODC Password Replication Group',
					'Read-only Domain Controllers',
					'Enterprise Read-only Domain Controllers',
					'Cloneable Domain Controllers',
					'Protected Users',
					'DnsAdmins',
					'DnsUpdateProxy')
				
				$getgroups = Get-ADGroup -Filter * -Properties Members | Where-Object { -not $_.members } | Where-Object{ $_.name -notin $list } | Select-Object Name, GroupCategory, GroupScope, DistinguishedName
				if ($getgroups)
				{ $getgroups | Export-Csv "$($fname)_groups.csv" -NoTypeInformation }
				else
				{
					Write-Verbose "All Groups are valid and members in it"
				}
				
			}
			'Dns' {
				#<code>
				$domain = (Get-WmiObject Win32_ComputerSystem).domain
				$Server = (Get-WmiObject Win32_ComputerSystem).name
				$getDNs = Get-DnsServerResourceRecord -ComputerName $Server -ZoneName "$domain" -RRType "A" | Select-Object HostName, @{ Name = 'RecordData'; Expression = { $_.RecordData.IPv4Address } }, Timestamp, TimeToLive, @{
					Name   = 'Ping'; Expression = {
						if ((Test-connection $_.RecordData.IPv4Address -count 1)) { "True" }
						else { "False" }
					}
				} 
				if ($getDNs | Where-Object Ping -Match "false")
				{ $getDNs | Where-Object Ping -Match "false" | Export-Csv "$($fname)_DNS.csv" -NoTypeInformation }
				else
				{
					Write-Verbose "All DNS are Valid"
				}
				
			}
			
		}
		
		Write-Host "Data processing is completed..Files have been saved." -ForegroundColor Cyan
	}
	catch
	{
		$_.Exception.Message
	}
}