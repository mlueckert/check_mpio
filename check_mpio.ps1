Param (
$NoArgs = "", #Only used as a dummy as NSClient sends some characters even there are no arguments defined.
$Ok_Path = 8
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
        $line = $mpclaim_result -match ("MPIO Disk{0}:" -f $disk)
        $path_count = [int]$line.split(" ")[2]
        return $path_count
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
            $res | Add-Member -MemberType NoteProperty -Name "Disk_ID" -Value $res.System_Disk.split(" ")[1] -Force
            $path = Get-PathCount -disk ($res.Disk_ID)
            $res | Add-Member -MemberType NoteProperty -Name "Path_Count" -Value $path -Force
        }
        return $result
    }

function Test-MPclaim{
#Checks whether mpclaim.exe is available.
    return Test-Path "$env:systemroot\System32\mpclaim.exe"
}

if(Test-MPclaim){

    $all_disks = Get-MPIODisks
    $notok_disks = $all_disks | where {$_.Path_Count -ne $ok_path}

    $result = ""

    if($notok_disks.count -eq 0){
            Write-Output ("OK - All {0} disk(s) have {1} paths each." -f ($all_disks.Disk_ID).count,$ok_path)
            Exit $returnStateOK
    }
    else{
        foreach($notok_disk in $notok_disks){
            $result += "DiskID:{0}-PathsAvailable:{1}of{2} " -f $notok_disk.Disk_ID,$notok_disk.Path_Count,$ok_path
        }
        Write-Output ("WARNING - Some paths are down. | {0}" -f $result)
        Exit $returnStateWarning
    }
}
else{
    Write-Output "UNKNOWN - mpclaim.exe not found. Is the feature MultiPathIO enabled?"
    Exit $returnStateUnknown
}