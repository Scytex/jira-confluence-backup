# jira-confluence-backup
Script for creating cloud backups for Jira &amp; Confluence using *Task Scheduler*


## Launch parameter
```
------------------------------------------------------------------------------
                    Jira & Confluence Cloud Backup Utility
Backup flags: (can be used together)
-confluence, -c            Start a new Confluence backup
-jira, -j                  Start a new Jira backup
-ignore_error, -ie         Ignors backup creation errors, downloads last backup
-dry                       Dry run, used for testing current configuration.

Configuration flags:
For permanent changes please change the values in the script itself.
-user                      atlassian username of the backup account
-token                     https://id.atlassian.com/manage-profile/security/api-tokens
-attachments, -a           $True or $False, include attachments in backup
-url, -u                   e.g. xyz.atlassian.net, do not include protocols
-path_conf, -pc            absolute path to the confluence backup folder
-path_jira, -pj            absolute path to the jira backup folder
-file_name_conf, -fc       confluence backup name, advised to add a current timestamp
-file_name_jira, -fj       jira backup name, advised to add a current timestamp
------------------------------------------------------------------------------
```

## Setup
1. Create an atlassian api token [here](https://id.atlassian.com/manage-profile/security/api-tokenshttps://id.atlassian.com/manage-profile/security/api-tokens) 
2. Fill out all environmental variables at the beginning of the script
3. Create two scheduled tasks, and define one task to start using the ``-j`` flag and the other using ``-c``

## Limitations
Jira has a creation limit of 48h - every backup requested in this time will be a duplicate
For a consistent amount of backups one could set it up as follows:
- Monday    0:00
- Wednesday 12:00
- Saturday  0:00
