Describe -Name "check_mpio Tests" {
    BeforeAll {
        . .\check_mpio.ps1

    }
    It "Check for error message if mpclaim.exe is not available" {
        . .\check_mpio.ps1 | Should -Match "UNKNOWN - mpclaim.exe not found"
        $LASTEXITCODE | Should -Be 3
    }
    It "If all 8 paths are ok" {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_output\mpclaim_result_ok.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            Mock Invoke-MPclaim { return (Get-Content .\mpclaim_output\mpclaim_result_disk0.txt).Replace("Disk0", "Disk$disk")} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 | Should -Match "OK - All "
        $LASTEXITCODE | Should -Be 0
    }
    It "Only 7 paths available" {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_output\mpclaim_result_ok.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            $result_content = Get-Content .\mpclaim_output\mpclaim_result_disk0.txt
            Mock Invoke-MPclaim { return $result_content[0..($result_content.Length-4)]} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 | Should -Match "WARNING - Some mpio storage paths are down."
        $LASTEXITCODE | Should -Be 1
    }
    It "Parameter -Ok_Path is working" {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_output\mpclaim_result_ok.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            $result_content = Get-Content .\mpclaim_output\mpclaim_result_disk0.txt
            Mock Invoke-MPclaim { return $result_content[0..($result_content.Length-4)]} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 -Ok_Path 7 | Should -Be "OK - All 12 disk(s) have 7 paths each. "
        $LASTEXITCODE | Should -Be 0
    }

    It "Parameter -BeCritical is working" {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_output\mpclaim_result_ok.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            $result_content = Get-Content .\mpclaim_output\mpclaim_result_disk0.txt
            Mock Invoke-MPclaim { return $result_content[0..($result_content.Length-4)]} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 -BeCritical | Should -Match "CRITICAL - "
        $LASTEXITCODE | Should -Be 2
    }

    It "Ignore Non Microsoft DSM mpio driver" {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_output\mpclaim_result_ibmsdddsm.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            Mock Invoke-MPclaim { return (Get-Content .\mpclaim_output\mpclaim_result_ibmsdddsm_disk0.txt).Replace("Disk0", "Disk$disk")} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 | Should -Match "OK - No disks to monitor found"
        $LASTEXITCODE | Should -Be 0
    }

    It "Parameter -RequireMicrosoftDSM should give WARNING output with IBM controller disks." {
        Mock Test-MPclaim { return $true}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_output\mpclaim_result_ibmsdddsm.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
        foreach ($disk in 0..20) {
            Mock Invoke-MPclaim { return (Get-Content .\mpclaim_output\mpclaim_result_ibmsdddsm_disk0.txt).Replace("Disk0", "Disk$disk")} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq $disk}
        }     
        . .\check_mpio.ps1 -RequireMicrosoftDSM | Should -Match "WARNING - Some mpio storage paths are down"
        $LASTEXITCODE | Should -Be 1
    }
    It "No MPIO disks present" {
        Mock Test-MPclaim { return $true}
        Mock Test-MPIODisks { return $false}
        Mock Invoke-MPclaim { return Get-Content .\mpclaim_output\mpclaim_no_disks_error.txt} -ParameterFilter { $param1 -eq "-s" -and $param2 -eq "-d" -and $param3 -eq ""}
     
        . .\check_mpio.ps1 | Should -Match "WARNING - No MPIO disks are present."
        $LASTEXITCODE | Should -Be 1
    }
}