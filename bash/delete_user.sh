#!/bin/bash
#' ---
#' title: Delete User Account
#' date:  2020-09-24 11:37:01
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Delete user account for temporary users and save data into an archive.
#'
#' ## Description
#' Deletion of user account and convert data into an archive
#'
#' ## Details
#' The script is a wrapper around the userdel command
#'
#' ## Example
#' ./delete_user-sh -u <user_name>
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
  $ECHO "Usage: $SCRIPT -u <user_account>"
  $ECHO "  where -u <user_account>  --  username whose account should be deleted ..."
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

#' ### Sudo Check
#' check whether user is sudoer which includes root
#+ check-for-sudo-fun
check_for_sudo () {
  l_prompt=$(sudo -nv 2<&1)
  if [ `echo $l_prompt | grep sudo | wc -l` -gt "0" ]
  then
    usage "User must have sudoer rights"
  fi
}


#' ### Delete User Account
#' delete the user using userdel
#+ delete-user-fun
delete_user () {
  local l_USERNAME=$1

  # add user account
  userdel $l_USERNAME

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
while getopts :u: FLAG; do
  case $FLAG in
    u) # set option "u" for username
      USERNAME=$OPTARG
      ;;
    *) # invalid command line arguments
      usage "Invalid command line argument $OPTARG"
      ;;
  esac
done  

shift $((OPTIND-1))  #This tells getopts to move on to the next argument.


#' ## Commandline Argument Checks
#' Checking for commandline arguments
#+ check-cmdl-args
if [ -z "${USERNAME}" ]
then
  usage 'Username must be spedified with -u <username>'
fi


#' ## Sudo Checks
#' This script must be run as sudoer
check_for_sudo


#' ## Archive Home Directory
#' Before deleting the user account, the home directory is packed into a tar-archive
#+ tar-home
USERHOME="/home/${USERNAME}"
if [ -e "$USERHOME" ]
then
  echo "Backup user's home directory of $USERNAME ..." 
  tar -cvzf "$USERNAME".tgz $USERHOME
fi


#' ## Delete User Account
#' The account is deleted
#+ del-user
delete_user $USERNAME


#' ## Remove Homedirectory
#' Delete home directory
#+ rm-home-dir
if [ -e "$USERHOME" ]
then
  echo "Delete home directory of $USERNAME ..." 
  rm -rf $USERHOME
fi


#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

