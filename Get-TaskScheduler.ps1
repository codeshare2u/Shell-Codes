<#	
	.NOTES
	===========================================================================
	 Created on:   	9/23/2020 
	 Created by:   	Abdul Malik
	 Organization: 	
	 Filename:     	Get-TaskScheduler
	===========================================================================
	.DESCRIPTION
	 Get user defined TaskScheduler
#>

$path = (Get-Location).path

$TaskCollection = New-Object System.Collections.ArrayList

$SchedTasks = (schtasks.exe /query /fo csv /v) -join "`r`n" | ConvertFrom-Csv

$FilteredTasks = $SchedTasks | Where-Object {$_.Author -notmatch "Microsoft|Author|N/A|SystemRoot|version|Adobe"}

$MultiTrigger = $FilteredTasks | Group-Object Taskname -AsHashTable

$MultiTriggerTable = $MultiTrigger.GetEnumerator() | where-Object { ($_.value).count -ge 2 }



foreach ($Sched in $FilteredTasks)
{
	if(!($TaskCollection.TaskName -contains $Sched.TaskName))
		{			
			$obj = '' | select-object 'HostName', 'TaskName', 'Next Run Time', 'Last Run Time', 'Status', 'Author', 'Task To Run', 'Start In', 'Comment', 'Run As User', 'Schedule Type', 'Start Time', 'Start Date', 'End Date', 'Days', 'Months', 'Repeat: Every', 'Repeat: Until: Time', 'Repeat: Until: Duration'
			
			if ($MultiTriggerTable.name -contains $Sched.TaskName)
			{
				$obj.'Start Time' = $MultiTrigger.($Sched.Taskname).'start time' -join ',' | Sort-Object
			}
			else
			{
				$obj.'Start Time' = $Sched.'Start Time'
			}
			$obj.'HostName' = $Sched.'HostName'
			$obj.'TaskName' = $Sched.'TaskName'
			$obj.'Next Run Time' = $Sched.'Next Run Time'
			$obj.'Status' = $Sched.Status
			$obj.'Last Run Time' = $Sched.'Last Run Time'
			$obj.'Author' = $Sched.Author
			$obj.'Task To Run' = $Sched.'Task To Run'
			$obj.'Start In' = $Sched.'Start In'
			$obj.'Comment' = $Sched.Comment
			$obj.'Run As User' = $Sched.'Run As User'
			$obj.'Schedule Type' = $Sched.'Schedule Type'
			$obj.'Start Date' = $Sched.'Start Date'
			$obj.'End Date' = $Sched.'End Date'
			$obj.'Days' = $Sched.Days
			$obj.Months = $sched.Months
			$obj.'Repeat: Every' = $Sched.'Repeat: Every'
			$obj.'Repeat: Until: Time' = $Sched.'Repeat: Until: Time'
			$obj.'Repeat: Until: Duration' = $sched.'Repeat: Until: Duration'
			
			[void]$TaskCollection.add($obj)
		}
	}
$TaskCollection | Export-Csv "$path\$env:COMPUTERNAME-SchedTask.csv" -NoTypeInformation
