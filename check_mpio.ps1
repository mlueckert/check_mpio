<#
.Synopsis
   Checks for available MPIO paths.
.DESCRIPTION
   Gathers the output of mpclaim.exe to determine if all paths are available.
.EXAMPLE
    PS C:\> check_mpio.ps1
    Checks if all disks have 8 paths available
.EXAMPLE
    PS C:\> check_mpio.ps1 -Ok_Path 4
    Checks if all disks have 4 paths available
.PARAMETER Ok_Path
    Number of paths that must be available.
.PARAMETER NoArgs
    Only used as a dummy as NSClient sends some characters even there are no arguments defined.
.PARAMETER RequireMicrosoftDSM
    If set to true, all paths where another mpio driver is controlling the paths will
    be reported WARNING because mpclaim cannot determine the path details but only the total path count.
.PARAMETER BeCritical
    If set, the check will return a CRITICAL state if paths are down.
#>
Param (
$NoArgs = "", #Only used as a dummy as NSClient sends some characters even there are no arguments defined.
$Ok_Path = 8,
[Switch]$RequireMicrosoftDSM,
[Switch]$BeCritical
)

$returnStateOK = 0
$returnStateWarning = 1
$returnStateCritical = 2
$returnStateUnknown = 3

function Invoke-MPclaim($param1,$param2,$param3){
    . mpclaim.exe $param1 $param2 $param3
}

function Get-PathCount{
param(
    $disk = 0
)
#Function to get the path count from mpclaim output.
#If the lun is not found, return -1
    $mpclaim_result = Invoke-MPclaim -param1 "-s" -param2 "-d" -param3 $disk
    if($mpclaim_result -match "Element not found"){
        return -1
    }
    else{
        #Matching for the SCSI address in the path line
        #Example: 00000000770d0000 Active/Optimized   013|000|000|000   0
        #                                            -We want to match here
        $lines = $mpclaim_result -match '(\|[0-9]{3})'
        $path_count = $lines.count
        return $path_count
    }
}

function Get-ControllingDSM{
param(
    $disk = 0
)
#Function to get the path count from mpclaim output.
$template = @'
    Controlling DSM: {[string]Controlling_DSM:IBM SDDDSM}
'@

#If the lun is not found, return -1
    $mpclaim_result = Invoke-MPclaim -param1 "-s" -param2 "-d" -param3 $disk
    if($mpclaim_result -match "Element not found"){
        return -1
    }
    else{
        #Matching for the Controlling DSM entry
        #Example: Controlling DSM:
        $lines = $mpclaim_result -match "Controlling DSM:"
        $controlling_dsm = $lines | ConvertFrom-String -TemplateContent $template
        return $controlling_dsm.Controlling_DSM
    }
}

function Get-MPIODisks(){
#Function that returns an object representing the output of mpclaim -s -d
$template = @'
{[string]MPIO_Disk*:MPIO Disk4}  {[string]System_Disk:Disk 4}       {[string]LB_Policy:RR}           {[string]DSM_Name:Microsoft DSM}
{[string]MPIO_Disk*:MPIO Disk0}  {[string]System_Disk:Disk 0}       {[string]LB_Policy:VS}           {[string]DSM_Name:IBM SDDDSM}
{[string]MPIO_Disk*:MPIO Disk11}  {[string]System_Disk:Disk 11}       {[string]LB_Policy:RRWS}         {[string]DSM_Name:Microsoft DSM}
'@
    
        $mpclaim_result = Invoke-MPclaim -param1 "-s" -param2 "-d" -param3 ""
        $lines = $mpclaim_result | Select-String -Pattern "MPIO Disk[0-9]"
        $result = $lines | ConvertFrom-String -TemplateContent $template
        foreach($res in $result){
            $res | Add-Member -MemberType NoteProperty -Name "Disk_ID" -Value $res.MPIO_Disk.split("Disk")[4] -Force
            $path = Get-PathCount -disk ($res.Disk_ID)
            $res | Add-Member -MemberType NoteProperty -Name "Path_Count" -Value $path -Force
            $controlling_dsm = Get-ControllingDSM -disk ($res.Disk_ID)
            $res | Add-Member -MemberType NoteProperty -Name "Controlling_DSM" -Value $controlling_dsm -Force
        }
        return $result
    }

function Test-MPIODisks{
    #Checks whether mpclaim reports no mpio disks are present
    $mpclaim_result = Invoke-MPclaim -param1 "-s" -param2 "-d" -param3 ""
    if(($mpclaim_result | Out-String) -notmatch "No MPIO disks are present."){
        return $true
    }
    return $false
}

function Test-MPclaim{
#Checks whether mpclaim.exe is available.
    return Test-Path "$env:systemroot\System32\mpclaim.exe"
}

if(-not (Test-MPclaim)){
    Write-Output "UNKNOWN - mpclaim.exe not found. Is the feature MultiPathIO enabled?"
    Exit $returnStateUnknown
}

if(Test-MPIODisks){

    $all_disks = Get-MPIODisks
    $notok_disks = $all_disks | where {$_.Path_Count -ne $ok_path}

    if(-not $RequireMicrosoftDSM){
        $all_disks = $all_disks | where {$_.Controlling_DSM -match "Microsoft DSM"} | Sort-Object -Property Disk_ID
        $nonMSDSMDisks = $notok_disks | where {$_.Controlling_DSM -notmatch "Microsoft DSM"} | Sort-Object -Property Disk_ID
        $notok_disks = $notok_disks | where {$_.Controlling_DSM -match "Microsoft DSM"} | Sort-Object -Property Disk_ID
    }

    $result = ""

    if($nonMSDSMDisks.count -ne 0){
        $nonMSDSMText = "`n Some paths are not using Microsoft DSM mpio driver and have been ignored (DiskID(s) {0})" -f ($nonMSDSMDisks.Disk_ID -join " ")
    }

    if($notok_disks.count -eq 0){
            if($all_disks.Disk_ID.count -eq 0 -and (-not $RequireMicrosoftDSM)){
                Write-Output ("OK - No disks to monitor found.{0}" -f $nonMSDSMText)
            }
            else{
                Write-Output ("OK - All {0} disk(s) have {1} paths each. {2}" -f ($all_disks.Disk_ID).count,$ok_path,$nonMSDSMText)
            }
            
            Exit $returnStateOK
    }
    else{
        foreach($notok_disk in $notok_disks){
            $result += "</br>DiskID:{0}-PathsAvailable:{1}of{2} " -f $notok_disk.Disk_ID,$notok_disk.Path_Count,$ok_path  
        }
        $WarnCritText = "Some mpio storage paths are down."
        if($BeCritical){
            Write-Output ("CRITICAL - {0} `n{1}{2}" -f $WarnCritText,$result,$nonMSDSMDisks)
            Exit $returnStateCritical
        }
        else{
            Write-Output ("WARNING - {0} `n{1}{2}" -f $WarnCritText,$result,$nonMSDSMDisks)
            Exit $returnStateWarning
        }
    }
}
else{
    Write-Output "WARNING - No MPIO disks are present."
    Exit $returnStateWarning
}