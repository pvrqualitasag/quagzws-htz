#!/bin/bash
#' ---
#' title: Restic Restore
#' date:  2020-08-06 16:30:57
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Seamless restore process from backup data
#'
#' ## Description
#' Restore data from a restic backup repository into a target directory. 
#'
#' ## Details
#' Given the input from the command-line or from a parameter-file containing the required input for the restore process.
#'
#' ## Example
#' ./restic_restore.sh -p <parameter_file> -s <source_data> -t <restore_target> 
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
MKDIR=/bin/mkdir                           # PATH to mkdir                           #
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
  $ECHO "Usage: $SCRIPT -j <restore_job> -p <parameter_file> -s <snapshot_id> -t <restore_target>"
  $ECHO "  where -d <backup dir>      --  directory to be restored from backup                                           (optional)"
  $ECHO "        -j <restore_job>     --  data to be restored, either from job file or by specifying a directory         (optional)"
  $ECHO "        -p <parameter_file>  --  parameter file defining restic repository                                      (optional)"
  $ECHO "        -s <snapshot_id>     --  give specify snapshot_id to be restored, o/w most recent snapshot is restored  (optional)"
  $ECHO "        -t <restore_target>  --  specify target directory where data should be restored                         (optional)"
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

#' ### Log Message
#' Log messages formatted similarly to log4r are produced.
#+ log-msg-fun, eval=FALSE
log_msg () {
  local l_CALLER=$1
  local l_MSG=$2
  local l_RIGHTNOW=`$DATE +"%Y%m%d%H%M%S"`
  $ECHO "[${l_RIGHTNOW} -- ${l_CALLER}] $l_MSG"
}

#' ### Create Dir 
#' Specified directory is created, if it does not yet exist
#+ check-exist-dir-create-fun
check_exist_dir_create () {
  local l_check_dir=$1
  if [ ! -d "$l_check_dir" ]
  then
    log_msg check_exist_dir_create "CANNOT find directory: $l_check_dir ==> create it ..."
    $MKDIR -p $l_check_dir
  else
    log_msg check_exist_dir_create "FOUND directory: $l_check_dir ..."
  fi  

}

#' ### Determine Snapshot ID
#' The ID of the most recent snapshot for the directory to be restored is searched
#+ get-latest-snapshot-id-fun
get_latest_snapshot_id () {
  local l_restore_dir=$1
  log_msg 'get_latest_snapshot_id' " ** Determine id of most recent snapshot for $l_restore_dir ..."
  RESTICSNAPSHOTID=$(restic snapshots | grep "$l_restore_dir" | tail -1 | cut -d ' ' -f1)
  log_msg 'get_latest_snapshot_id' " ** Snapshot ID: $RESTICSNAPSHOTID ..."
}

#' ### Check For Root
#' Check whether script is run by root
#+ check-run-as-root-fun
check_run_as_root () {
  log_msg 'check_run_as_root' ' ** Check whether script is run by root ...'
  if [ `whoami | grep root | wc -l` == '1' ]
  then
    log_msg 'check_run_as_root' ' ** OK running as root ...'
  else
    log_msg 'check_run_as_root' ' ** Not running as root -- stop...'
    usage ' ERROR: Script can only run as root'
  
  fi
}

#' ## Main Body of Script
#' The main body of the script starts here.
#+ start-msg, eval=FALSE
start_msg


#' ## Check For Root
#' This script must be run as root, hence, we check, if not stop
#+ check-run-as-root
check_run_as_root


#' ## Getopts for Commandline Argument Parsing
#' If an option should be followed by an argument, it should be followed by a ":".
#' Notice there is no ":" after "h". The leading ":" suppresses error messages from
#' getopts. This is required to get my unrecognized option code to work.
#+ getopts-parsing, eval=FALSE
BCKUPDIR=''
JOBFILE=/home/quagadmin/backup/job/restic_backup.job
RESTICPARFILE=/home/quagadmin/backup/par/restic_backup.par
RESTICSNAPSHOTID=
RESTICRESTORETARGET=/tmp/restic_restore
while getopts ":d:j:p:s:th" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    d)
      BCKUPDIR=$OPTARG
      ;;
    j)
      JOBDEF=$OPTARG
      ;;
    p)
      RESTICPARFILE=$OPTARG
      ;;
    s)
      RESTICSNAPSHOTID=$OPTARG
      ;;
    t)
      RESTICRESTORETARGET=$OPTARG
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
if test "$JOBDEF" == ""; then
  usage "-j restore_data not defined"
fi
if test "$RESTICPARFILE" == ""; then
  usage "-p restic_parameter_file not defined"
fi
if test "$RESTICRESTORETARGET" == ""; then
  usage "-t restic_restore_target not defined"
fi


#' ## Export Variables
#' To avoid the specification of the repository and the password, they must 
#' be exported as variables
#+ restic-variable-export
export RESTIC_REPOSITORY="$RESTICREPOSITORY"
export RESTIC_PASSWORD="$RESTICPASSWORD"


#' ## Check for Restore Target
#' In case, when the restore target does not exist, created it
check_exist_dir_create $RESTICRESTORETARGET


#' ## Restore Specified Data
#' Data is restored from backup repository, start with the case where a given 
#' snapshot-id is specified
if [ "$RESTICSNAPSHOTID" != '' ]
then
  restic restore $RESTICSNAPSHOTID --target $RESTICRESTORETARGET
else
  # in case the job definition is a file, then all directories in that file
  #  are restored
  if [ "$BCKUPDIR" != '' ]
  then
    log_msg "$SCRIPT" " * Restore data from $JOBDEF ..."
    get_latest_snapshot_id $BCKUPDIR
    restic restore $RESTICSNAPSHOTID --target $RESTICRESTORETARGET
  else  
    if [ -f "$JOBDEF" ]
    then
      cat $JOBDEF | while read f
      do
        log_msg "$SCRIPT" " * Restore data from $f ..."
        get_latest_snapshot_id $f
        restic restore $RESTICSNAPSHOTID --target $RESTICRESTORETARGET
      done
    else
      log_msg "$SCRIPT" " * CANNOT restore with definition $JOBDEF ..."
      exit 1
    fi
  fi  
fi


#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

