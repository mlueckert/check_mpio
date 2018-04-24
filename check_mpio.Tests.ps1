Describe -Name "check_mpio Tests" {
    BeforeAll {
        . .\check_mpio.ps1

    }
    It "Check for error message if mpclaim.exe is not available" {
        . .\check_mpio.ps1 | Should -Match "UNKNOWN - mpclaim.exe not found"
    }
    It "If all 8 paths are ok" {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_result_ok.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            Mock Invoke-MPclaim { return (Get-Content .\mpclaim_result_disk0).Replace("Disk0", "Disk$disk")} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 | Should -Match "OK - All "
    }
    It "Only 7 paths available" {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_result_ok.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            $result_content = Get-Content .\mpclaim_result_disk0
            Mock Invoke-MPclaim { return $result_content[0..($result_content.Length-4)]} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 | Should -Match "WARNING - Some mpio storage paths are down."
    }
    It "Parameter -Ok_Path is working" {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_result_ok.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            $result_content = Get-Content .\mpclaim_result_disk0
            Mock Invoke-MPclaim { return $result_content[0..($result_content.Length-4)]} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 -Ok_Path 7 | Should -Be "OK - All 12 disk(s) have 7 paths each."
    }
}