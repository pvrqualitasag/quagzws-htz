#!/bin/bash
#' ---
#' title: Restic Unlock
#' date:  2021-03-02 16:12:14
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Seamless removal of locks from backup repositories
#'
#' ## Description
#' Removing backup locks from repository after crash of backup
#'
#' ## Details
#' After backup fails, locks must be removed manually from repositories
#'
#' ## Example
#' ./restic_unlock.sh
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
  $ECHO "Usage: $SCRIPT -p <restic_parfile> -r <restic_repository> -w <restic_password>"
  $ECHO "  where -p <restic_parfile>     --  path to restic parameter file ..."
  $ECHO "        -r <restic_repository>  --  restic repository  (optional) ..."
  $ECHO "        -w <restic_password>    --  restic password    (optional) ..."
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


#' ## Main Body of Script
#' The main body of the script starts here.
#+ start-msg, eval=FALSE
start_msg

#' ## Getopts for Commandline Argument Parsing
#' If an option should be followed by an argument, it should be followed by a ":".
#' Notice there is no ":" after "h". The leading ":" suppresses error messages from
#' getopts. This is required to get my unrecognized option code to work.
#+ getopts-parsing, eval=FALSE
RESTICREPOSITORY=''
RESTICPASSWORD=''
RESTICPARFILE=/home/quagadmin/backup/par/restic_backup.par
while getopts ":p:r:w:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
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


#' ## Export Variables
#' To avoid the specification of the repository and the password, they must 
#' be exported as variables
#+ restic-variable-export
export RESTIC_REPOSITORY="$RESTICREPOSITORY"
export RESTIC_PASSWORD="$RESTICPASSWORD"


#' ## Unlock
#' The unlock command should run without parameters, because repository and password
#' were specified in env variables
#+ run-unlock
restic unlock


#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

