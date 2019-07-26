# CyberArk-Replicate
Backup of the Safes from MySQL database from Cyberark
This makes use of sending email to send the backup out.

Here are some changes to be made in down the line:

-Always put all your variables at the top before any actual code starts, except where you declare a Variable that requires some code:

-Like to get the date/time or something small, not a huge Function.

-Limiting the user no to go through the whole program also limits mistakes they can make between actual code.

-Make sure you also use the Date-Time inside your start and end of the logfiles. (Track times)

-These Date-Time String should also be present in your SUBJECT Field in the email... Makes life much easier when looking for emails.

-I still see a lo of hardcoding of filenames and paths of exe's etc...

-Never Assume Folders or Exe's are there, ALWAYS when you "cd Vault".... make sure your return code is 0, else there is a problem changing to that folder (example)

-Remember, the Aim of the logfile-Email is to not have to login to a backup server to check backup and to use this as proof for auditors, etc... So make sure that logfile contains what you need, but not to much un-necessary mumbo jumbo... ;

These are changes that have been made
Always rather use the YYYYmmdd-HHMM to make up your log file(s).--done
