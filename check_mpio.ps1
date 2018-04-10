$ok_path = 8
$lun = 0

$returnStateOK = 0
$returnStateWarning = 1
$returnStateCritical = 2
$returnStateUnknown = 3

function Get-PathCount($SearchString){
#Function to get the path count from mpclaim output.
    $line = $mpclaim_result -match "MPIO Disk0:"
    $path_count = [int]$line.split(" ")[2]
    return $path_count
}

function Get-MPIODisks(){
    $mpclaim_result = mpclaim.exe -s -d
    $lines = $mpclaim_result | Select-String -Pattern "MPIO Disk[0-9]"
}

if(Test-Path "$env:systemroot\System32\mpclaim.exe"){
    $mpclaim_result = mpclaim.exe -s -d $lun
}
else{
    Write-Output "UNKNOWN - mpclaim.exe not found. Is the feature MultiPathIO enabled?"
    Exit $returnStateUnknown
}

$path_count = Get-PathCount($mpclaim_result)

if($path_count -lt $ok_path){
    Write-Output ("WARNING - Only {0} of {1} storage paths available for LUN {2}." -f $path_count,$ok_path,$lun)
    Exit $returnStateWarning
}
else{
    Write-Output ("OK - {0} of {1} storage paths available for LUN {2}." -f $path_count,$ok_path,$lun)
    Exit $returnStateOK
}
