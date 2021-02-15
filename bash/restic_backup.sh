#!/bin/bash
#' ---
#' title: Run Restic Backup
#' date:  2020-05-02 13:57:00
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Seamless automatic backup of source directories.
#'
#' ## Description
#' Backups of different source directories are done using restic. This script can 
#' be run as daily cronjob to do backups regularly. The backup-script implements 
#' a backup plan that keeps seven daily-backups, five weekly backups, twelve 
#' monthly backups and ten yearly backups. All other snapshots are removed from 
#' the backup repository.
#'
#' ## Details
#' The repository used by restic is directly on the sftp-server that is rented 
#' together with the dedicated server. To avoid permission problems, the backup 
#' script is run as root. 
#'
#' ## Example
#' # use default inputs
#' ./restic_backup.sh -j /home/quagadmin/backup/job/restic_backup.job
#' # read inputs from parameter file
#' ./restic_backup.sh -p /home/quagadmin/backup/par/restic_backup.par
#'
#' ## Set Directives
#' General behavior of the script is driven by the following settings
#+ bash-env-setting, eval=FALSE
set -o errexit    # exit immediately, if single command exits with non-zero status
set -o nounset    # treat unset variables as errors
set -o pipefail   # return value of pipeline is value of last command to exit with non-zero status
                  #  hence pipe fails if one command in pipe fails


#' ## Global Constants
#' ### Paths to shell tools
#+ shell-tools, eval=FALSE
ECHO=/bin/echo                             # PATH to echo                            #
DATE=/bin/date                             # PATH to date                            #
BASENAME=/usr/bin/basename                 # PATH to basename function               #
DIRNAME=/usr/bin/dirname                   # PATH to dirname function                #

#' ### Directories
#' Installation directory of this script
#+ script-directories, eval=FALSE
INSTALLDIR=`$DIRNAME ${BASH_SOURCE[0]}`    # installation dir of bashtools on host   #

#' ### Files
#' This section stores the name of this script and the
#' hostname in a variable. Both variables are important for logfiles to be able to
#' trace back which output was produced by which script and on which server.
#+ script-files, eval=FALSE
SCRIPT=`$BASENAME ${BASH_SOURCE[0]}`       # Set Script Name variable                #
SERVER=`hostname`                          # put hostname of server in variable      #


#' ## Functions
#' The following definitions of general purpose functions are local to this script.
#'
#' ### Usage Message
#' Usage message giving help on how to use the script.
#+ usg-msg-fun, eval=FALSE
usage () {
  local l_MSG=$1
  $ECHO "Usage Error: $l_MSG"
  $ECHO "Usage: $SCRIPT -d <backup_dir> -e <exclude_file> -j <job_file> -l <restic_log_file> -m <email_address> -r <restic_repository> -p <restic_password> -r <restic_repository> -w <restic_password> -v"
  $ECHO "  where -d <backup dir>         --  specify directory to be backed up                                         (optional)"
  $ECHO "        -e <exclude_file>       --  specify exclude_file containing directories to be excluded                (optional)"
  $ECHO "        -j <job_file>           --  specify job_file containing the sources to be backed up                   (optional)"
  $ECHO "        -l <restic_log_file>    --  specify restic log file                                                   (optional)"
  $ECHO "        -m <email_address>      --  notification e-mail address                                               (optional)"
  $ECHO "        -p <restic_parfile>     -- specify parameterfile from where settings are read                         (optional)"
  $ECHO "        -r <restic_repository>  -- specify restic repository as sftp:<username>@<sftp-host>:<repository_path> (optional)"
  $ECHO "        -w <restic_password>    -- specify repository password                                                (optional)"
  $ECHO "        -v                      -- verbose output                                                             (optional)"
  $ECHO ""
  exit 1
}

#' ### Start Message
#' The following function produces a start message showing the time
#' when the script started and on which server it was started.
#+ start-msg-fun, eval=FALSE
start_msg () {
  $ECHO "********************************************************************************"
  $ECHO "Starting $SCRIPT at: "`$DATE +"%Y-%m-%d %H:%M:%S"`
  $ECHO "Server:  $SERVER"
  $ECHO
}

#' ### Start Message To Logfile
#' The following function writes a start message to the logfile.
#+ start-msg-to-log-fun, eval=FALSE
start_msg_to_logfile () {
  $ECHO "********************************************************************************" >> $RESTICLOGFILE
  $ECHO "Starting $SCRIPT at: "`$DATE +"%Y-%m-%d %H:%M:%S"` >> $RESTICLOGFILE
  $ECHO "Server:  $SERVER" >> $RESTICLOGFILE
  $ECHO >> $RESTICLOGFILE
}

#' ### End Message
#' This function produces a message denoting the end of the script including
#' the time when the script ended. This is important to check whether a script
#' did run successfully to its end.
#+ end-msg-fun, eval=FALSE
end_msg () {
  $ECHO
  $ECHO "End of $SCRIPT at: "`$DATE +"%Y-%m-%d %H:%M:%S"`
  $ECHO "********************************************************************************"
}

#' ### End Message To Logfile
#' This function writes an end message to the logfile.
#+ end-msg-to-log-fun, eval=FALSE
end_msg_to_logfile () {
  $ECHO  >> $RESTICLOGFILE
  $ECHO "End of $SCRIPT at: "`$DATE +"%Y-%m-%d %H:%M:%S"` >> $RESTICLOGFILE
  $ECHO "********************************************************************************" >> $RESTICLOGFILE
}

#' ### Log Message
#' Log messages formatted similarly to log4r are produced.
#+ log-msg-fun, eval=FALSE
log_msg () {
  local l_CALLER=$1
  local l_MSG=$2
  local l_RIGHTNOW=`$DATE +"%Y%m%d%H%M%S"`
  $ECHO "[${l_RIGHTNOW} -- ${l_CALLER}] $l_MSG"
}

#' ### Log Message To Logfile
#' Log messages formatted similarly to log4r written to logfile.
#+ log-msg-to-log-fun, eval=FALSE
log_msg_to_logfile () {
  local l_CALLER=$1
  local l_MSG=$2
  local l_RIGHTNOW=`$DATE +"%Y%m%d%H%M%S"`
  $ECHO "[${l_RIGHTNOW} -- ${l_CALLER}] $l_MSG" >> $RESTICLOGFILE
}

#' ### Disk Free Status
#' Get the diskfree-status of a backup-server
#+ df-remote-backup
df_remote_backup () {
 local l_REMOTE=$(echo $RESTICREPOSITORY | cut -d ':' -f2)
 log_msg_to_logfile 'df_remote_backup' ''
 log_msg_to_logfile 'df_remote_backup' ' *********************************** '
 log_msg_to_logfile 'df_remote_backup' ' * Disk free status ...'
 echo "df -h" | sftp $l_REMOTE >> $RESTICLOGFILE
}

#' ### Run Restic Backup Job
#' Run restic backup for a given directory
#+ run-restic-bck-fun
run_restic_bck () {
  local l_BCK_DIR=$1
  if [ -d "$l_BCK_DIR" ]
  then
    if [ "$RESTICEXCLUDEFILE" != '' ] && [ -f "$RESTICEXCLUDEFILE" ]
    then
      restic backup --exclude-file=$RESTICEXCLUDEFILE $l_BCK_DIR &>> $RESTICLOGFILE
    else
      restic backup $l_BCK_DIR &>> $RESTICLOGFILE
    fi
  else
    log_msg_to_logfile 'run_restic_bck' " * Cannot find path to backup source: $l_BCK_DIR"
  fi  
}


#' ## Main Body of Script
#' The main body of the script starts here. 

#' ## Getopts for Commandline Argument Parsing
#' If an option should be followed by an argument, it should be followed by a ":".
#' Notice there is no ":" after "h". The leading ":" suppresses error messages from
#' getopts. This is required to get my unrecognized option code to work.
#+ getopts-parsing, eval=FALSE
BCKUPDIR=''
JOBFILE=/home/quagadmin/backup/job/restic_backup.job
RESTICEXCLUDEFILE=/home/quagadmin/backup/job/restic_exclude.txt
RESTICREPOSITORY=''
RESTICPASSWORD=''
RESTICLOGFILE=/home/quagadmin/backup/log/$(date +"%Y%m%d%H%M%S"_restic_backup.log)
EMAILADDRESS=''
RESTICPARFILE=/home/quagadmin/backup/par/restic_backup.par
VERBOSE='FALSE'
while getopts ":d:e:j:l:m:p:r:w:Vh" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    d)
      if [ -d "$OPTARG" ]
      then
        BCKUPDIR=$OPTARG
      else
        usage " * ERROR: Cannot find backup directory: $OPTARG"
      fi
      ;;
    e)  
      if [ -f "$OPTARG" ]
      then
        RESTICEXCLUDEFILE=$OPTARG
      else
        usage " * ERROR: Cannot find restic-job file: $OPTARG"
      fi
      ;;
    j)
      if [ -f "$OPTARG" ]
      then
        JOBFILE=$OPTARG
      else
        usage " * ERROR: Cannot find restic-job file: $OPTARG"
      fi
      ;;
    l) 
      RESTICLOGFILE=$OPTARG
      ;;
    m)
      EMAILADDRESS=$OPTARG
      ;;
    p)
      RESTICPARFILE=$OPTARG
      ;;
    r)
      RESTICREPOSITORY=$OPTARG
      ;;
    w)
      RESTICPASSWORD=$OPTARG
      ;;
    v)
      VERBOSE='TRUE'
      ;;
    :)
      usage "-$OPTARG requires an argument"
      ;;
    ?)
      usage "Invalid command line argument (-$OPTARG) found"
      ;;
  esac
done

shift $((OPTIND-1))  #This tells getopts to move on to the next argument.

#' ## Start Message
#' In verbose mode we write a start message
#+ start-msg, eval=FALSE
if [ "$VERBOSE" == "TRUE" ];then start_msg; fi
start_msg_to_logfile


#' ## Read Input from Parameterfile
#' If a parameter file is specified, the input is read from that file
#+ read-input-from-parfile
if [ "$RESTICPARFILE" != "" ]; then
  source $RESTICPARFILE
fi

#' ## Checks for Command Line Arguments
#' The following statements are used to check whether required arguments
#' have been assigned with a non-empty value
#+ argument-test, eval=FALSE
if test "$JOBFILE" == ""; then
  usage "-j <job_file> not defined"
fi
if test "$RESTICLOGFILE" == ""; then
  usage "-l <restic_log_file> not defined"
fi
if test "$RESTICPASSWORD" == ""; then
  usage "-p <restic_password> not defined"
fi
if test "$RESTICREPOSITORY" == ""; then
  usage "-r <restic_repository> not defined"
fi


#' ## Export Variables
#' To avoid the specification of the repository and the password, they must 
#' be exported as variables
#+ restic-variable-export
export RESTIC_REPOSITORY="$RESTICREPOSITORY"
export RESTIC_PASSWORD="$RESTICPASSWORD"

#' ## Run Backup Jobs
#' In a loop over the lines of JOBFILE do the backup for every directory
#+ run-backup-job
if [ "$BCKUPDIR" != '' ]
then
  run_restic_bck $BCKUPDIR
else
  cat $JOBFILE | while read job
  do
    run_restic_bck $job
  done
fi

#' ## Forget Old Snapshots
#' Snapshots that do not match the backup plan are removed
echo >> $RESTICLOGFILE
log_msg_to_logfile $SCRIPT ' * Prune old snapshots ...'
restic forget --prune --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 10 &>> $RESTICLOGFILE


#' ## List the Snapshots
#' Write the list of snapshots to the logfile
#+ write-snapshots-to-log
echo >> $RESTICLOGFILE
log_msg_to_logfile $SCRIPT ' * List of snapshots ...'
restic snapshots > tmp_restic_snapshots.txt
if [ `cat tmp_restic_snapshots.txt | wc -l` -gt 100 ]
then
  head -50 tmp_restic_snapshots.txt >> $RESTICLOGFILE
  tail -50 tmp_restic_snapshots.txt >> $RESTICLOGFILE
else
  cat tmp_restic_snapshots.txt >> $RESTICLOGFILE
fi
rm -rf tmp_restic_snapshots.txt

#' ## Check Backup Data Integrety
#' The integrety of the backup data is checked and the result is written to the logfile
#+ restic-check-data-to-log
echo >> $RESTICLOGFILE
log_msg_to_logfile $SCRIPT ' * Checking backup data integrity ...'
restic check &>> $RESTICLOGFILE

#' ## Write Disk-Free to Logfile
#' Disk-free status of remote sftp-backup is written to logfile
#+ df-to-log
echo  >> $RESTICLOGFILE
log_msg_to_logfile $SCRIPT ' * Disk free status of backup-host ...'
df_remote_backup


#' ## End Message to Logfile
#' Write an end of script message to the logfile
#+ end-msg-to-log
end_msg_to_logfile

#' ## E-mail Notification
#' Send a notification containing the logfile of the backup
if [ "$EMAILADDRESS" != "" ]
then
  (echo "To: $EMAILADDRESS";\
  echo "From: $SERVER";\
  echo "Subject: restic log from $(date)";\
  echo;\
  cat $RESTICLOGFILE ) | /usr/sbin/ssmtp $EMAILADDRESS
fi

#' ## End of Script
#+ end-msg, eval=FALSE
if [ "$VERBOSE" == "TRUE" ];then end_msg; fi

