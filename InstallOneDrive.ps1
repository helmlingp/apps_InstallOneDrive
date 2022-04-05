<#	
  .Synopsis
    Installs OneDrive in per-machine mode and removes per-user mode install
  .NOTES
	  Created:   	    November, 2020
	  Created by:	    Phil Helmling, @philhelmling
	  Organization:   VMware, Inc.
	  Filename:       InstallOneDrive.ps1
	.DESCRIPTION
    Installs OneDrive in per-machine mode.
    Credit to:
    https://docs.microsoft.com/en-us/onedrive/per-machine-installation
    https://byteben.com/bb/installing-the-onedrive-sync-client-in-per-machine-mode-during-your-task-sequence-for-a-lightening-fast-first-logon-experience/#3

    Install command: powershell.exe -ep bypass -file .\InstallOneDrive.ps1
    Uninstall command: OneDriveSetup.exe /uninstall /allusers
    Install Complete: Registry exists - HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe
    or
    Install Complete: File exists - C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe
    
  .EXAMPLE
    powershell.exe -ep bypass -file .\InstallOneDrive.ps1

#>

$current_path = $PSScriptRoot;
if($PSScriptRoot -eq ""){
    #PSScriptRoot only popuates if the script is being run.  Default to default location if empty
    $current_path = "C:\Temp";
}

#Stop Per-User OneDriveSetup
$ods = (Get-Process OneDrive).Id
Stop-Process -Id $ods
Wait-Process -Id $ods

#Stop OneDrive in Administrator context if installing during MDT build
$od = Get-Process OneDrive
if($od){
  $odpath = $od.Path
  $pathtosearch = "\Appdata\Local\Microsoft\OneDrive\OneDrive.exe"
  #'^Sara(h?)$'

  if($odpath.Contains($pathtosearch)){
    Stop-Process -Id $od.Id
  }
  
}
 

#Start OneDriveSetup Per-Device mode
$installProcess = Start-Process $current_path\OneDriveSetup.exe -ArgumentList "/allusers" -WindowStyle Hidden -PassThru
$installProcess.WaitForExit()

#Wait for OneDrive.exe to appear - may not be needed.
while (!(Test-Path "C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe")) { Start-Sleep 10 }

#Remove Default per-user based OneDrive install from executing on each profile.
#Create PSDrive for HKU
New-PSDrive -PSProvider Registry -Name HKUDefaultHive -Root HKEY_USERS
#Load Default User Hive
Reg Load "HKU\DefaultHive" "C:\Users\Default\NTUser.dat"
#Set OneDriveSetup Variable
$OneDriveSetup = Get-ItemProperty "HKUDefaultHive:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Run" | Select-Object -ExpandProperty "OneDriveSetup"
#If Variable returns True, remove the OneDriveSetup Value
If ($OneDriveSetup) { Remove-ItemProperty -Path "HKUDefaultHive:\DefaultHive\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDriveSetup" }
#Unload Hive
Reg Unload "HKU\DefaultHive"
#Remove PSDrive HKUDefaultHive
Remove-PSDrive "HKUDefaultHive"

