#!/bin/bash
#' ---
#' title: Find Path in Restic Repository
#' date:  2021-03-29 17:00:46
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Seamless search for given file or directory path
#'
#' ## Description
#' Find a given path to a file or directory in a given restic repository
#'
#' ## Details
#' When trying to restore a given file, we have to first determine the snapshot ID. This can be done with the find command of restic.
#'
#' ## Example
#' ./restic_find.sh -p <path_to_item_to_find>
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
  $ECHO "Usage: $SCRIPT -f <path_to_item_to_find> -p <parameter_file>"
  $ECHO "  where -f <path_to_item_to_find>  --  path to item to find in repository ..."
  $ECHO "        -p <parameter_file>        --  parameter file defining restic repository ..."
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
#' The main body of the script starts here with a start script message.
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
ITEMPATH=""
RESTICPARFILE=/home/quagadmin/backup/par/restic_backup.par
while getopts ":f:p:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    f)
      ITEMPATH=$OPTARG
      ;;
    p)
      RESTICPARFILE=$OPTARG
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
if test "$ITEMPATH" == ""; then
  usage "-p <item_path> not defined"
fi


#' ## Export Variables
#' To avoid the specification of the repository and the password, they must 
#' be exported as variables
#+ restic-variable-export
export RESTIC_REPOSITORY="$RESTICREPOSITORY"
export RESTIC_PASSWORD="$RESTICPASSWORD"


#' ## Search for Path
#' Search for a path in a given repository.
#+ repo-find-path
restic find "$ITEMPATH"



#' ## End of Script
#' This is the end of the script with an end-of-script message.
#+ end-msg, eval=FALSE
end_msg

