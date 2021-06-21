# ------------------------------------------------------------------------------
# Script  : CyberArkBackup.ps1
# Author  : Robert (Rob) Waight
# Modified: Andrew Price
# Date    : 06/15/2021
# Version : 2
# Keywords: PAReplicate, CyberArk, Backup, 7zip
# Comments: Use PowerShell to execute PAReplicate (the CyberArk Backup utility)
#            this is used to ensure CyberArk backups are scheduled and executed.
#           
#           The extra logging and the transcript are built-in for audit support.
#
#Location of the git hub file https://github.com/rwaight/CABackup
# ------------------------------------------------------------------------------

# Create a timer to track how long backups are taking to execute
$script:startTime = Get-Date
$Elapsed = [System.Diagnostics.Stopwatch]::StartNew()

# Create Email Variables, will send mail anonymously -- only if environment allows anon SMTP
    #$serv=$env:computername
    $serv="Vault Backup Server"
    $mTo="cyberark@cyberark.lan"
    $mFrom="cyberark@cyberark.lan"
    $mSMTP="192.168.50.1"
    #$mSmtpPort = "587"
    # Configure anonymous credentials
    $anonUser = "cyberark@cyberark.lan"
    $anonPass = ConvertTo-SecureString "Password@4" -AsPlainText -Force
	$SmtpCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $anonUser,$anonPass

# Write to the servers Application log, so output can be collected by monitoring software
$LogSource="CyberArk_Backup_SVC"
#New-EventLog -LogName Application -Source $LogSource

# Store the Log file and transcript in the CyberArkBackup folder
$zLogOut = "C:\PowerShell\CyberArkBackup"

# Start the logfile
if(-not(Test-Path -path $zLogOut))
    {
	Write-Host -ForegroundColor Yellow "The log directory $zLogOut has not been found."
	New-Item -ItemType Directory -Path "$zLogOut" -Confirm
	}

# Start the transcript
if(Test-Path -path $zLogOut -IsValid){
    Start-Transcript -Path "$zLogOut\CABackupTranscript_$(Get-Date -format "yyyyMMdd-HH-mm").txt" -Append -NoClobber
    # The logfile will contain entries for the entire month, if a daily log is needed, then change to "yyyyMMdd-HH-mm"
    $logfile="$zLogOut\CABackupLog_$(get-date -format `"yyyyMMdd-HH-mm`").log"
  }

# Log function
function Log($string, $color){
   if ($Color -eq $null) {$color = "white"}
   write-host $string -foregroundcolor $color
   $string | out-file -Filepath $logfile -append
}
# Event Log function
function EventLog($String, $EventID, $Color){
   if ($Color -eq $null) {$Color = "white"}
   Write-Host $String -ForegroundColor $Color
#   Write-EventLog Application -Source $LogSource -EventID $EventID -Message $String
   $string | out-file -Filepath $logfile -append
}

# Set date variables
$date=Get-Date
$dow=(Get-Date).DayOfWeek
log "Script started at $script:startTime"

# Go to the PrivateArk\Replicate folder
cd "C:\Program Files (x86)\PrivateArk\Replicate"

If ($dow -ne "Sunday"){ # If it is not Sunday
    # Run incremental Backup for CyberArk
    log "It is $dow, running an incremental backup for CyberArk"
    EventLog "It is $dow, running an incremental backup for CyberArk" 5
    .\PAReplicate.exe Vault.ini /LogonFromFile BackupUser.cred | Out-File .\cablog.txt
}
Else{ # If it is Sunday
    # Run full backup for CyberArk
    log "It is $dow, running a full backup for CyberArk"
    EventLog "It is $dow, running a full backup for CyberArk" 5
    .\PAReplicate.exe Vault.ini /LogonFromFile BackupUser.cred /FullBackup | Out-File .\cablog.txt
}

#$CABLog=(Get-Content .\cablog.txt) -join "`n"  #Use this if the log formatting doesn't include new line entries
$CABLog=Get-Content .\cablog.txt
$CABLogExport=$CABLog | Out-String

# Check and see if PAReplicate had an error
if([bool]($CABLog -match "PAReplicate ended with errors")){
    EventLog $CABLogExport 0
    $CABResult=Get-Content .\cablog.txt | Select-Object -Last 2
    Copy-Item "C:\Program Files (x86)\PrivateArk\Replicate\cablog.txt" C:\PowerShell\CyberArkBackup\folderzip\cablog.txt
    Add-Content -Path C:\PowerShell\CyberArkBackup\folderzip\cablog.txt -Value (Get-Date) -PassThru
    Compress-7Zip -ArchiveFileName .\zippedfile.zip -Path C:\PowerShell\CyberArkBackup\folderzip\cablog.txt -Format Zip -Password Pas!
    $mAttach=".\zippedfile.zip"
    $subj="CyberArk Backup Finished with Errors"
    log "$subj, sending the log to $mTo"
    
    # Write message body and send email, attach the entire log file if there was an error
    $mBody="Greetings CyberArk Admins!`n`nThe CyberArkBackup task has finished on $serv.`n"
    Send-MailMessage -To $mTo -Subject $subj -Body $mBody -From $mFrom -Credential $anonCred -SmtpServer $mSMTP -Port 587 -Attachments $mAttach
    log "Email sent to $mTo!" Cyan
}
else{
    EventLog $CABLogExport 1
    $CABResult=Get-Content .\cablog.txt | Select-Object -Last 1
    Copy-Item "C:\Program Files (x86)\PrivateArk\Replicate\cablog.txt" C:\PowerShell\CyberArkBackup\folderzip\cablog.txt
    Add-Content -Path C:\PowerShell\CyberArkBackup\folderzip\cablog.txt -Value (Get-Date) -PassThru
    Compress-7Zip -ArchiveFileName .\zippedfile.zip -Path C:\PowerShell\CyberArkBackup\folderzip\cablog.txt -Format Zip -Password Pas!
    $mAttach=".\zippedfile.zip"
    $subj="CyberArk Backup Finished Successfully"
    log "$subj Successfully"
    
    # Write message body and send email
    $mBody="Greetings CyberArk Admins!`n`nThe CyberArkBackup task has finished on $serv.`n"
    Send-MailMessage -To $mTo -Subject $subj -Body $mBody -From $mFrom -SmtpServer $mSMTP -Port 25 -Attachments $mAttach
    log "Email sent to $mTo!" Cyan
}

log "Script completed at $(get-date)"
log "Total Elapsed Time: $($Elapsed.Elapsed.ToString())"
EventLog "Script completed at $(get-date) -- Total Elapsed Time: $($Elapsed.Elapsed.ToString())" 4
log ""
Stop-Transcript
