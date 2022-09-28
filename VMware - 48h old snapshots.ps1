#Requires -Version 5.1
#Requires -Modules VMware.VimAutomation.Core
<#

 __      ____  __                          _  _   ___  _             _     _                             _           _              _                      
 \ \    / /  \/  |                        | || | / _ \| |           | |   | |                           | |         | |       /\   | |                     
  \ \  / /| \  / |_      ____ _ _ __ ___  | || || (_) | |__     ___ | | __| |  ___ _ __   __ _ _ __  ___| |__   ___ | |_     /  \  | | __ _ _ __ _ __ ___  
   \ \/ / | |\/| \ \ /\ / / _` | '__/ _ \ |__   _> _ <| '_ \   / _ \| |/ _` | / __| '_ \ / _` | '_ \/ __| '_ \ / _ \| __|   / /\ \ | |/ _` | '__| '_ ` _ \ 
    \  /  | |  | |\ V  V / (_| | | |  __/    | || (_) | | | | | (_) | | (_| | \__ \ | | | (_| | |_) \__ \ | | | (_) | |_   / ____ \| | (_| | |  | | | | | |
     \/   |_|  |_| \_/\_/ \__,_|_|  \___|    |_| \___/|_| |_|  \___/|_|\__,_| |___/_| |_|\__,_| .__/|___/_| |_|\___/ \__| /_/    \_\_|\__,_|_|  |_| |_| |_|
                                                                                              | |                                                          
                                                                                              |_|                                                          
#>
#region------------------------------------------| HELP |------------------------------------------------#
<#
.Synopsis
    Creates an alarm, if a VM have had a snapshot mounted for more than 48 hours. 

.PARAMETER vCenterCredential
    Creds file to import for authorization on vCenters

.PARAMETER IgnoreList
    Supply an array of VMnames to ignore. This can be used to overlook certain VMs

.NOTES
    Version: 1.3
    Author:  Ottetal
#>
#endregion

#region---------------------------------------| PARAMETERS |---------------------------------------------#
Param 
(
    [Parameter(Mandatory = $true)]
    [pscredential]
    $vCenterCredential,
    
    [Parameter()]
    [String[]]
    $IgnoreList = $Null
)
#endregion

#region------------------------------------------| SETUP |-----------------------------------------------#
# Variables for connection
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Establishing connection to all vCenter servers with "-alllinked" flag
try 
{
    [Void](Connect-VIServer -Server "vCenter01.nchosting.dk" -Credential $vCenterCredential -AllLinked)
}
catch
{
    Write-Host "Could not connect to vCenter. Exiting"
    Exit 1
}

# Set statics
$Today      = [DateTime]::Today
$TwoDaysAgo = $Today.AddDays(-2)
$AllVMs     = Get-VM
$VMcount    = $AllVMs.count
$Counter    = 0

#endregion

#region--------------------------------------| PROGRAM LOGIC |-------------------------------------------#

$Output = foreach ($VM in ($AllVMs)) 
{
    
    # Continue on unwanted VM
    if ($VM.name -in $IgnoreList) {
        Write-Host "`t`$IgnoreList contains $VM"
        continue
    }

    # Get Snapshot from VM
    $Snapshot = Get-Snapshot -VM $VM
    
    # Send information to Cusotmobject
    if (($null -ne $Snapshot) -and ($Snapshot[0].Created -lt $TwoDaysAgo)) 
    {
        $VMsize       = [Math]::Round($VM.UsedSpaceGB,2)
        
        $SnapshotSize = 0
        foreach ($SS in $Snapshot)
        {
            $SnapshotSize += $SS.SizeGB
        }

        $FinalSize = [Math]::Round($SnapshotSize,2)
        
        [pscustomobject]@{
            "VM"               = $VM.Name
            "Snapshot Created" = $Snapshot[0].Created.ToString("yyyy-dd-MM")
            "VM Size GB"       = "$VMsize"
            "Snapshot Size GB" = "$FinalSize"
        }
    }

    
    # Write percentstatus to console every 100 VMs
    $Counter ++
    
    if ($counter % 100 -eq 0)
    {
        $Percentage = [Math]::Round(($Counter / $VMcount * 100),2)
        Write-Host "Progress is at $Percentage%"
    }

}

# Exit if no machines are affected
if ($Null -eq $Output)
{
    Write-Host "No affected VMs, exitting"
    Exit
}

$HTML = $Output | Sort-Object -Property "Snapshot Created" | ConvertTo-Html    
#endregion

#region--------------------------------------| HANDLE OUTPUT |-------------------------------------------#

#TODO: Handle your ouput here. I usually send a mail to our task pipeline

#endregion

#region---------------------------------------| DISCONNECT |---------------------------------------------#
# Don't leave open sessions to VIserver
Disconnect-VIServer * -Confirm:$false

# -------- ON ERROR --------
if ($error) {
    exit 1
}
#endregion
#-------------------------------------------------| END |------------------------------------------------#
