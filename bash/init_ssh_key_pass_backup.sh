#!/bin/bash
#' ---
#' title: Init SSH Key Pass for Backup
#' date:  2020-06-02
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Setting up ssh key pass to remote backup server
#'
#' ## Description
#' This script generates an ssh key pass
#'
#' ## Details
#' This script must be run as root, because the backup script is run as root
#'
#' ## Example
#' sudo su - -c '/home/quagadmin/source/quagzws-htz/bash/init_ssh_key_pass_backup.sh -r <remote_server> -u <user_name>
#'
#' ## Set Directives
#' General behavior of the script is driven by the following settings
#+ bash-env-setting, eval=FALSE
set -o errexit    # exit immediately, if single command exits with non-zero status
set -o nounset    # treat unset variables as errors
#set -o pipefail   # return value of pipeline is value of last command to exit with non-zero status
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
  $ECHO "Usage: $SCRIPT -r <backup_remote_host> -u <repository_username>"
  $ECHO "  where -r <restic_repo_host>     -- specify restic repository host <sftp-host>"
  $ECHO "        -u <repository_username>  -- specify restic username"
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

#' ### Check whether we are running as root
#' This script must be run as root
#+ check-root-fun
check_root () {
  if [ `whoami` != "root" ]
  then
    usage " * ERROR in check_root: Script must be run as root ..."
  fi
}

#' ### Create SSH key pass
#' Transfer of data to remote repsitory works with key pass
#+ ssh-key-pass-fun
ssh_key_pass () {
  if [ ! -d "/root/.ssh" ]
  then
    log_msg 'ssh_key_pass' ' * Create directory /root/.ssh ...'
    mkdir -p /root/.ssh
  fi
  log_msg 'ssh_key_pass' ' * Running ssh-keygen ...'
  yes "y" | ssh-keygen -f /root/.ssh/id_rsa -N ""
  #[hit enter twice to accept default answers]
  ssh-keygen -e -f /root/.ssh/id_rsa.pub | grep -v "Comment:" > /root/.ssh/id_rsa_rfc.pub
  log_msg 'ssh_key_pass' ' * Write local authorized keys ...'
  cat /root/.ssh/id_rsa.pub >> /root/storagebox_authorized_keys
  cat /root/.ssh/id_rsa_rfc.pub >> /root/storagebox_authorized_keys
  log_msg 'ssh_key_pass' ' * Upload new authorized keys ...'
  log_msg 'ssh_key_pass' ' * Runn the following as root: echo -e "mkdir /.ssh \n put /root/storagebox_authorized_keys /.ssh/authorized_keys \n chmod 600 /.ssh/authorized_keys" | sftp '"${REPOSITORYUSER}@${REPOSITORYHOST}"
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
REPOSITORYHOST=''
REPOSITORYUSER=''
while getopts ":r:u:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    r)
      REPOSITORYHOST=$OPTARG
      ;;
    u)
      REPOSITORYUSER=$OPTARG
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



#' ## Argument Check
#' Check whether arguments are assigned
#+ check-req-var
if [ "$REPOSITORYHOST" == "" ]
then
  usage " * Error: -r <repository_host> must be specified"
fi
if [ "$REPOSITORYUSER" == "" ]
then
  usage " * Error: -u <repository_user> must be specified"
fi


#' ## Check for root
#' Check whether this script runs as root
#+ check-for-root
log_msg "$SCRIPT" ' * Checking for root ...'
check_root

#' ## SSH Key-pass
#' Generate a key pass to connect via ssh w/out password
#+ ssh-key
log_msg "$SCRIPT" ' * SSH key pass ...'
ssh_key_pass



#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

