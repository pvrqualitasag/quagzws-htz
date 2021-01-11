#!/bin/bash
#' ---
#' title: Creation of User Account
#' date:  2020-05-13 14:11:37
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Seamless creation of user account on a linux machine.
#'
#' ## Description
#' Create new user on the local machine. 
#'
#' ## Details
#' This script must be run as root.
#'
#' ## Example
#' ./create_user.sh -u <user> -p <password> -s <default_shell> -g <additional_group>
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
  $ECHO "Usage: $SCRIPT -u <user> -p <password> -s <default_shell> -g <additional_group>"
  $ECHO "  where -u <user>              --  username"
  $ECHO "        -p <password>          --  password(optional)"
  $ECHO "        -s <default_shell>     --  specify default shell to be used (optional)"
  $ECHO "        -g <additional_group>  --  additional user group to which user should be added (optional)"
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

#' ### Generate Password
#' In case the password is not sepcified on commandline, generate a random one.
#+ generate-password-fun
generate_password () {
  # This will generate a random, 8-character password:
  PASSWORD=`tr -dc A-Za-z0-9_ < /dev/urandom | head -c8`
}

#' ### Create User Account
#' The following function creates a user account.
#+ create-user-fun
create_user () {
  local l_USERNAME=$1
  local l_PASS=$2
  local l_DEFAULTSHELL=$3

   
  # add user account
  log_msg 'create_user' " ** Create account for user: $l_USERNAME ..."
  useradd $l_USERNAME -s $l_DEFAULTSHELL -m

  # This will actually set the password:
  log_msg 'create_user' " ** Set password for user: $l_USERNAME ..."
  echo "$l_USERNAME:$l_PASS" | chpasswd  
  
  # check whether outputdir exists
  if [ ! -d "$OUTPUTDIR" ]
  then
    log_msg 'create_user' " ** Create dir: $OUTPUTDIR ..."
    mkdir -p $OUTPUTDIR
    chmod 700 $OUTPUTDIR
  fi
  # write username and password to a file
  log_msg 'create_user' " ** Write credentials to: $OUTPUTDIR ..."
  echo "${l_USERNAME},${l_PASS}" > "${OUTPUTDIR}/.${l_USERNAME}.pwd"
}  

#' ### Add User to Additional Group
#' User is added to an additional group
#+ add-user-to-grp-fun
add_user_to_grp () {
  local l_grp=$1
  local l_user=$2
  usermod -a -G $l_grp $l_user
  
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
ADDUGROUP=""
OUTPUTDIR=/home/quagadmin/user_admin/created
PASSWORD=$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c8)
USERNAME=""
DEFAULTSHELL=/bin/bash
while getopts ":g:o:p:u:s:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    g)
      ADDUGROUP=$OPTARG
      ;;
    o)
      OUTPUTDIR=$OPTARG
      ;;
    p)
      PASSWORD=$OPTARG
      ;;
    u)
      USERNAME=$OPTARG
      ;;
    s)
      DEFAULTSHELL=$OPTARG
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

#' ## Checks for Command Line Arguments
#' The following statements are used to check whether required arguments
#' have been assigned with a non-empty value
#+ argument-test, eval=FALSE
if test "$OUTPUTDIR" == ""; then
  usage "-o <output_dir> not defined"
fi
if test "$USERNAME" == ""; then
  usage "-u <user_name> not defined"
fi
if test "$DEFAULTSHELL" == ""; then
  usage "-s <default_shell> not defined"
fi


#' ## Check Password
#' If password is not specified, the generate a random password.
#+ check-password
if [ "$PASSWORD" == "" ]
then
  usage " -p <password> Password not specified"
fi


#' ## Create User Account
#' The user account is created using the information specified so far.
#+ create-user
log_msg "$SCRIPT" " * Create user account ..."
create_user $USERNAME $PASSWORD $DEFAULTSHELL

#' ## Add Created User To Additional Group
#' If specified the user is added to a user group
if [ "$ADDUGROUP" != "" ]
then
  log_msg "$SCRIPT" " * Add user to group: $ADDUGROUP ..."
  add_user_to_grp $ADDUGROUP $USERNAME
fi

#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

