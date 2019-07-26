# ------------------------------------------------------------------------------
# Script  : CyberArkBackup.ps1
# Author  : Robert (Rob) Waight
# Modifer : Andrew Price
# Date    : 07/26/2019
# Version : 2
# Keywords: PAReplicate, CyberArk, Backup
# Comments: Use PowerShell to execute PAReplicate (the CyberArk Backup utility)
#            this is used to ensure CyberArk backups are scheduled and executed.
#           
#           The extra logging and the transcript are built-in for audit support.
#
#Location of the github origernal file is https://github.com/rwaight/CABackup
# ------------------------------------------------------------------------------

# Create a timer to track how long backups are taking to execute
$script:startTime = Get-Date
$Elapsed = [System.Diagnostics.Stopwatch]::StartNew()

# Create Email Variables, will send mail anonymously -- only if environment allows anon SMTP
    $serv=$env:computername
    $mTo="CyberArkAdmins@company.com"
    $mFrom="CyberArk_Backup_SVC@company.com"
    $mSMTP="mail.company.com"
    # Configure anonymous credentials
    $anonUser = "anonymous"
    $anonPass = ConvertTo-SecureString "anonymous" -AsPlainText -Force
    $anonCred = New-Object System.Management.Automation.PSCredential($anonUser, $anonPass)

# Set date variables
$date=Get-Date
$dow=(Get-Date).DayOfWeek
log "Script started at $script:startTime"


# Write to the servers Application log, so output can be collected by monitoring software
$LogSource="CyberArk_Backup_SVC"
New-EventLog -LogName Application -Source $LogSource

# Store the Log file and transcript in the CyberArkBackup folder
$zLogOut = "C:\PowerShell\CyberArkBackup"

# Start the logfile and test if directorty is there
if(-not(Test-Path -path $zLogOut))
    {
	Write-Host -ForegroundColor Yellow "The log directory $zLogOut has not been found."
	New-Item -ItemType Directory -Path "$zLogOut" -Confirm
	}

# Start the transcript
if(Test-Path -path $zLogOut -IsValid){
    Start-Transcript -Path "$zLogOut\CABackupTranscript_$(Get-Date -format "YYYYmmdd-HHMM").txt" -Append -NoClobber
    # The logfile will contain entries for the entire month, if a daily log is needed, then change to "YYYYmmdd-HHMM"
    $logfile="$zLogOut\CABackupLog_$(get-date -format `"YYYYmmdd-HHMM`").log"
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
   Write-EventLog Application -Source $LogSource -EventID $EventID -Message $String
   #$string | out-file -Filepath $logfile -append
}

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
    $mAttach=".\cablog.txt"
    $subj="CyberArk Backup Finished with Errors"
    log "$subj, sending the log to $mTo"
    
    # Write message body and send email, attach the entire log file if there was an error
    $mBody="Greetings CyberArk Admins!`n`nThe CyberArkBackup task has finished on $serv.`n`nThe results are as follows:`n`n$CABResult"
    Send-MailMessage -To $mTo -Subject $subj -Body $mBody -From $mFrom -Credential $anonCred -SmtpServer $mSMTP -Attachments $mAttach
    log "Email sent to $mTo!" Cyan
}
else{
    EventLog $CABLogExport 1
    $CABResult=Get-Content .\cablog.txt | Select-Object -Last 1
    $subj="CyberArk Backup Finished (get-date -format `"YYYYmmdd-HHMM`")"
    log "$subj Successfully"
    
    # Write message body and send email
    $mBody="Greetings CyberArk Admins!`n`nThe CyberArkBackup task has finished on $serv.`n`nThe results are as follows:`n`n$CABResult"
    Send-MailMessage -To $mTo -Subject $subj -Body $mBody -From $mFrom -Credential $anonCred -SmtpServer $mSMTP
    log "Email sent to $mTo!" Cyan
}

log "Script completed at $(get-date-format `"YYYYmmdd-HHMM`")"
log "Total Elapsed Time: $($Elapsed.Elapsed.ToString())"
EventLog "Script completed at $(get-date-format `"YYYYmmdd-HHMM`") -- Total Elapsed Time: $($Elapsed.Elapsed.ToString())" 4
log ""
Stop-Transcript
