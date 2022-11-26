# -----------------------------------------------------------------------------
# Author: github.com/scytex
# Date: 20.10.2022
# Version: 1.0
# Description: Backup Confluence and Jira into a local directory
# API Documentation: https://docs.atlassian.com/atlassian-confluence/1000.1829.0/com/atlassian/confluence/test/rest/api/obm/
# -----------------------------------------------------------------------------

param(
   [alias("h")]
   [switch] $help,

   [alias("c")]
   [switch] $confluence,

   [alias("j")]
   [switch] $jira,

   [alias("ie")]
   [switch] $ignore_error,

   [alias("d")]
   [switch] $dry,

   [alias("a")]
   [bool] $attachments,

   [alias("u")]
   [string] $url,

   [alias("pc")]
   [string] $path_conf,

   [alias("pj")]
   [string] $path_jira,

   [alias("fc")]
   [string] $file_name_conf,

   [alias("fj")]
   [string] $file_name_jira,

   [string] $user,

   [string] $token
)

# -----------------------------------------------------------------------------
# Change those parameters to fit your environment
# -----------------------------------------------------------------------------

# Should all Jira attachments be downloaded into your backup (pictures, files etc.)
$include_attachments = $true;
# The username of the Jira account that runs the backups
$username = '';
# API Token, get one here: https://id.atlassian.com/manage-profile/security/api-tokens
$api_token = '';
# Your Jira instance url, eg. "xyz.atlassian.net"
$instance = '';
# Servers timezone, find it via "Get-TimeZone | Select id"
$timezone = 'W. Europe Standard Time';

# Backup save location, use an ABSOLUTE path
$location_confluence = '';
$location_jira = '';
# timestamp formatting
$date = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now,$timezone).ToString('yyyyMMdd');
# naming convention for the backuped files
$naming_convention_confluence = "CONF-backup-$date";
$naming_convention_jira = "JIRA-backup-$date";
# location of *native* curl, pre-installed on win10 version 17063 and up. Not the curl alias for Invoke-Webrequest.
$curl = "C:\Windows\System32\curl.exe";
# max amount of progress checks before stopping / failing
$progress_checks = 1000;
# time between progress checks
$interval_seconds = 30;
# In this case 1000 * 30 = ~8:20h before giving up

# -----------------------------------------------------------------------------
# Don't touch anything after this point if you aren't sure what you are doing.
# -----------------------------------------------------------------------------

if ($help -or (-not $confluence -and -not $jira))
{
   Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
   Write-Host "                    Jira & Confluence Cloud Backup Utility                    " -ForegroundColor DarkCyan
   Write-Host "Backup flags: (can be used together)" -ForegroundColor Cyan
   Write-Host "-confluence, -c            " -ForegroundColor Green -NoNewline
   Write-Host "Start a new Confluence backup"
   Write-Host "-jira, -j                  " -ForegroundColor Green -NoNewline
   Write-Host "Start a new Jira backup"
   Write-Host "-ignore_error, -ie         " -ForegroundColor Green -NoNewline
   Write-Host "Ignors backup creation errors, downloads last backup"
   Write-Host "-dry                       " -ForegroundColor Green -NoNewline
   Write-Host "Dry run, used for testing current configuration."
   Write-Host "Configuration flags:" -ForegroundColor Cyan
   
   Write-Host "For permanent changes please change the values in the script itself." -ForegroundColor DarkGray

   Write-Host "-user                      " -ForegroundColor Green -NoNewline
   Write-Host 'atlassian username of the backup account'
   Write-Host "-token                     " -ForegroundColor Green -NoNewline
   Write-Host 'https://id.atlassian.com/manage-profile/security/api-tokens'
   Write-Host "-attachments, -a           " -ForegroundColor Green -NoNewline
   Write-Host '$True or $False, include attachments in backup'
   Write-Host "-url, -u                   " -ForegroundColor Green -NoNewline
   Write-Host "e.g. xyz.atlassian.net, do not include protocols"
   Write-Host "-path_conf, -pc            " -ForegroundColor Green -NoNewline
   Write-Host 'absolute path to the confluence backup folder'
   Write-Host "-path_jira, -pj            " -ForegroundColor Green -NoNewline
   Write-Host 'absolute path to the jira backup folder'
   Write-Host "-file_name_conf, -fc       " -ForegroundColor Green -NoNewline
   Write-Host 'confluence backup name, advised to add a current timestamp'
   Write-Host "-file_name_jira, -fj       " -ForegroundColor Green -NoNewline
   Write-Host 'jira backup name, advised to add a current timestamp'
   Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkCyan
   exit;
}

if ($PSBoundParameters.ContainsKey('user'))
{
   Write-Host "[Config] " -ForegroundColor Yellow -NoNewline
   Write-Host "Overriding username to $user"
   $username = $user;
}
elseif ($username -eq "") {
   Write-Host "[Error] " -ForegroundColor Red -NoNewline
   Write-Host "Missing username"
   exit;
}

if ($PSBoundParameters.ContainsKey('token'))
{
   Write-Host "[Config] " -ForegroundColor Yellow -NoNewline
   Write-Host "Overriding api token to $token"
   $api_token = $token;
}
elseif ($api_token -eq "") {
   Write-Host "[Error] " -ForegroundColor Red -NoNewline
   Write-Host "Missing API token"
   exit;
}

if ($PSBoundParameters.ContainsKey('attachments'))
{
   Write-Host "[Config] " -ForegroundColor Yellow -NoNewline
   Write-Host "Overriding attachments to $attachments"
   $include_attachments = $attachments;
}
elseif ($attachments -eq $null) {
   Write-Host "[Error] " -ForegroundColor Red -NoNewline
   Write-Host "Missing attachments flag"
   exit;
}

if ($PSBoundParameters.ContainsKey('url'))
{
   Write-Host "[Config] " -ForegroundColor Yellow -NoNewline
   Write-Host "Overriding instance to $url"
   $instance = $url;
}
elseif ($instance -eq "") {
   Write-Host "[Error] " -ForegroundColor Red -NoNewline
   Write-Host "Missing instance url"
   exit;
}

if ($PSBoundParameters.ContainsKey('path_conf'))
{
   Write-Host "[Config] " -ForegroundColor Yellow -NoNewline
   Write-Host "Overriding confluence path to $path_conf"
   $location_confluence = $path_conf;
}
elseif ($location_confluence -eq "" -and $confluence) {
   Write-Host "[Error] " -ForegroundColor Red -NoNewline
   Write-Host "Missing path to confluence backup location"
   exit;
}

if ($PSBoundParameters.ContainsKey('path_jira'))
{
   Write-Host "[Config] " -ForegroundColor Yellow -NoNewline
   Write-Host "Overriding jira path to $path_jira"
   $location_jira = $path_jira;
}
elseif ($location_jira -eq "" -and $jira) {
   Write-Host "[Error] " -ForegroundColor Red -NoNewline
   Write-Host "Missing path to jira backup location"
   exit;
}

if ($PSBoundParameters.ContainsKey('file_name_conf'))
{
   Write-Host "[Config] " -ForegroundColor Yellow -NoNewline
   Write-Host "Overriding conf backup file name to $file_name_conf"
   $naming_convention_confluence = $file_name_conf;
}
elseif ($naming_convention_confluence -eq "" -and $confluence) {
   Write-Host "[Error] " -ForegroundColor Red -NoNewline
   Write-Host "Missing file name for confluence backup"
   exit;
}

if ($PSBoundParameters.ContainsKey('file_name_jira'))
{
   Write-Host "[Config] " -ForegroundColor Yellow -NoNewline
   Write-Host "Overriding jira backup file name to $file_name_jira"
   $naming_convention_jira = $file_name_jira;
}
elseif ($naming_convention_jira -eq "" -and $jira) {
   Write-Host "[Error] " -ForegroundColor Red -NoNewline
   Write-Host "Missing file name for jira backup"
   exit;
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
Write-Debug "Debug Mode enabled";

# -----------------------------------------------------------------------------
# Dry Run
# -----------------------------------------------------------------------------

if ($dry)
{
   $redacted_token = $api_token.Substring(0,4) + ("x"*($api_token.Length - 6)) + $api_token.Substring(($api_token.Length - 4), 4);

   Write-Host "DRY RUN" -ForegroundColor Red;
   Write-Host "------------------------------------------------------------------------------" -ForegroundColor Red
   Write-Host "Run JIRA Backup            " -NoNewline
   Write-Host $jira  -ForegroundColor Yellow
   Write-Host "Run Confluence Backup      " -NoNewline
   Write-Host $confluence  -ForegroundColor Yellow
   Write-Host "Ignore errors              " -NoNewline
   Write-Host $ignore_error  -ForegroundColor Yellow
   Write-Host "Include attachments        " -NoNewline
   Write-Host $include_attachments  -ForegroundColor Yellow
   Write-Host "Username                   " -NoNewline
   Write-Host $username  -ForegroundColor Yellow
   Write-Host "API Token                  " -NoNewline
   Write-Host $redacted_token -ForegroundColor Yellow
   Write-Host "Instance                   " -NoNewline
   Write-Host $instance -ForegroundColor Yellow
   Write-Host "Path Conf                  " -NoNewline
   Write-Host $location_confluence -ForegroundColor Yellow
   Write-Host "Path Jira                  " -NoNewline
   Write-Host $location_jira -ForegroundColor Yellow
   Write-Host "File name Conf             " -NoNewline
   Write-Host $naming_convention_confluence -ForegroundColor Yellow
   Write-Host "File name Jira             " -NoNewline
   Write-Host $naming_convention_jira -ForegroundColor Yellow
   Write-Host "------------------------------------------------------------------------------" -ForegroundColor Red
   exit;
}

# -----------------------------------------------------------------------------
# Confluence Backup Utility
# -----------------------------------------------------------------------------

if ($confluence)
{
   $file_name = "";
   $stopwatch = [System.Diagnostics.Stopwatch]::new()

   Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
   Write-Host "Starting Confluence backup..." -ForegroundColor Cyan;
   Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
   Write-Host "Selected instance: " -NoNewline;
   Write-Host $instance -ForegroundColor Green;
   Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
   Write-Host "Downloading Attachments: " -NoNewline;
   Write-Host $include_attachments -ForegroundColor Green;
   $stopwatch.Start();

   $data = '{\"cbAttachments\":\"'+$include_attachments+'\" }'
   Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
   Write-Host "Requesting backup creation..." -ForegroundColor Cyan;
   $response = (& $curl -s -u "${username}:${api_token}" -H "Content-Type: application/json" -X POST "https://$instance/wiki/rest/obm/1.0/runbackup" -d $data);
   Write-Debug $response;

   if (($response -like "*Unexpected*") -or ($response -like "*error*"))
   {
      if ($ignore_error)
      {
         Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
         Write-Host "Error creating backup." -ForegroundColor Red
         Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
         Write-Host "Ignoring error, continuing...";
         Write-Host $response -ForegroundColor DarkYellow
      }
      else
      {
         Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
         Write-Host "Error creating backup. Quitting." -ForegroundColor Red
         Write-Host $response -ForegroundColor DarkYellow
         exit;
      }
   }

   for ($i = 0; $i -le $progress_checks; $i++)
   {
      $response = (& $curl -s -u ${username}:${api_token} https://${INSTANCE}/wiki/rest/obm/1.0/getprogress.json) | ConvertFrom-Json;

      if ($response.currentStatus -like "*error*")
      {
         Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
         Write-Host "Couldn't create backup. Quitting." -ForegroundColor Red
         exit;
      }

      if ($response.alternativePercentage -eq "100%")
      {
         Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
         Write-Host "Backup created successfully" -ForegroundColor Cyan;
         $file_name = $response.fileName;
         break;
      }

      Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
      Write-Host $response.alternativePercentage;

      Start-Sleep -Seconds $interval_seconds;
   }

   if ($file_name -ne "")
   {
      Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
      Write-Host "Download ready: " -NoNewline
      Write-Host "https://$instance/wiki/download/$file_name" -ForegroundColor Cyan;
      Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
      Write-Host "Beginning Download...";
      & $curl -u "${username}:${api_token}" -L "https://$instance/wiki/download/$file_name" -o "$location_confluence/$naming_convention_confluence.zip"
      $stopwatch.Stop();
      Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
      Write-Host "Download finished. Saved as: $location_confluence\$naming_convention_confluence.zip";
      Write-Host "[Confluence] " -ForegroundColor Green -NoNewline;
      Write-Host ("Total runtine: " + $stopwatch.Elapsed.Minutes + "min" + $stopwatch.Elapsed.Seconds + "sec")
   }
}

# -----------------------------------------------------------------------------
# Jira Backup Utility
# -----------------------------------------------------------------------------

if ($jira)
{
   $file_name = "";
   $stopwatch = [System.Diagnostics.Stopwatch]::new()

   Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
   Write-Host "Starting Jira backup..." -ForegroundColor Cyan;
   Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
   Write-Host "Selected instance: " -NoNewline;
   Write-Host $instance -ForegroundColor Green;
   Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
   Write-Host "Downloading Attachments: " -NoNewline;
   Write-Host $include_attachments -ForegroundColor Green;
   $stopwatch.Start();


   $data = '{\"cbAttachments\":\"'+$include_attachments+'\", \"exportToCloud\":\"true\"}'
   Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
   Write-Host "Requesting backup creation..." -ForegroundColor Cyan;
   $response = (& $curl -s -u "${username}:${api_token}" -H "Accept: application/json" -H "Content-Type: application/json" -X POST "https://$instance/rest/backup/1/export/runbackup" -d $data);
   Write-Debug $response;

   if (($response -like "*Unexpected*") -or ($response -like "*error*"))
   {
      if ($ignore_error)
      {
         Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
         Write-Host "Error creating backup." -ForegroundColor Red
         Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
         Write-Host "Ignoring error, continuing...";
         Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
         Write-Host $response -ForegroundColor DarkYellow
      }
      else
      {
         Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
         Write-Host "Error creating backup. Quitting." -ForegroundColor Red
         Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
         Write-Host $response -ForegroundColor DarkYellow
         exit;
      }
   }

   $task_id = (& $curl -s -u "${username}:${api_token}" -H "Accept: application/json" -H "Content-Type: application/json" "https://$instance/rest/backup/1/export/lastTaskId")

   for ($i = 0; $i -le $progress_checks; $i++)
   {
      $response = (& $curl -s -u "${username}:${api_token}" -H "Accept: application/json" -H "Content-Type: application/json" "https://${instance}/rest/backup/1/export/getProgress?taskId=${task_id}") | ConvertFrom-Json;

      if ($response.status -like "*error*")
      {
         Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
         Write-Host "Couldn't create backup. Quitting." -ForegroundColor Red
         exit;
      }

      if ($response.progress -eq "100")
      {
         Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
         Write-Host "Backup created successfully" -ForegroundColor Cyan;
         $file_name = $response.result;
         break;
      }

      Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
      Write-Host $response.progress + "%";

      Start-Sleep -Seconds $interval_seconds;
   }

   if ($file_name -ne "")
   {
      Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
      Write-Host "Download ready: " -NoNewline
      Write-Host "https://$instance/plugins/servlet/$file_name" -ForegroundColor Cyan;
      Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
      Write-Host "Beginning Download...";
      & $curl -u "${username}:${api_token}" -L "https://$instance/plugins/servlet/$file_name" -o "$location_jira/$naming_convention_jira.zip"
      $stopwatch.Stop();
      Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
      Write-Host "Download finished. Saved as: $location_jira\$naming_convention_jira.zip";
      Write-Host "[JIRA] " -ForegroundColor Green -NoNewline;
      Write-Host ("Total runtine: " + $stopwatch.Elapsed.Minutes + "min" + $stopwatch.Elapsed.Seconds + "sec")
   }
}