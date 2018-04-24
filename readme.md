# Purpose
- check_mpio.ps1 can be used to check the availability of disk paths in Windows.  
- It gathers the output of mpclaim.exe and compares the amount of paths found for every disk with the specified input parameter.
- The output is formatted to be used with Nagios/Naemon

# NSClient++
To use the check in NSClient++, add the following line to the nsclient.ini section ```[/settings/external scripts/scripts]```
```
check_mpio = cmd /c echo bcustoms\\check_mpio.ps1 $ARG1$; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -command -
```
