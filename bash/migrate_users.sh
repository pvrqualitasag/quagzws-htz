#!/bin/bash
#' ---
#' title: Migrate User Accounts
#' date:  2020-05-12 14:47:18
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Seamless migration of user accounts. 
#'
#' ## Description
#' Migrate a list of user accounts from a source server to a new server. 
#'
#' ## Details
#' User info are saved in files with usernames and passwords. These are migrated from the source to the new server. 
#'
#' ## Example
#' ./migrate_users.sh -u <user_file> 
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
  $ECHO "Usage: $SCRIPT -u <user_file> -s <login_shell> -g <user_group>"
  $ECHO "  where -u <user_file>    --  list of user files to be transfered"
  $ECHO "        -s <login_shell>  --  login shell for user (optional)"
  $ECHO "        -g <user_group>   --  additional group for user (optional)"
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

#' ### Create User Account
#' Create the user using useradd and set the password with a default shell
#+ create-user-fun
create_user () {
  local l_USERNAME=$1
  local l_PASS=$2
  local l_DEFAULTSHELL=$3
  local l_OUTDIR=${USERADMINDIR}/created

  # check whether home directory of user already exists
  if [ -d "/home/${l_USERNAME}" ]
  then
    log_msg 'create_user' " ** Found home directory for $l_USERNAME ..."
  else
    # add user account
    log_msg 'create_user' " ** Add user account for $l_USERNAME ..."
    useradd $l_USERNAME -s $l_DEFAULTSHELL -m
    # password
    log_msg 'create_user' " ** Set password for $l_USERNAME ..."
    echo "$l_USERNAME:$l_PASS" | chpasswd
    # write user info to a file
    if [ ! -d "$l_OUTDIR" ];then
      log_msg 'create_user' " ** Create output dir $l_OUTDIR ..."
      mkdir -p $l_OUTDIR
    fi
    # write username and password to a file
    log_msg 'create_user' " ** Write info to ${l_OUTDIR}/.${l_USERNAME}.pwd ..."
    echo "${l_USERNAME},${l_PASS}" > "${l_OUTDIR}/.${l_USERNAME}.pwd"
  fi
  

}  

#' ### Add user to an additional group
#' Users can be grouped with user groups
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
USERFILE=""
USERGROUP=""
USERADMINDIR=/root/user_admin
DEFAULTSHELL=/bin/bash
while getopts ":g:u:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    g)
      USERGROUP=$OPTARG
      ;;
    u)
      USERFILE=$OPTARG
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
if test "$USERFILE" == ""; then
  usage "-u user_file not defined"
fi
if test "$DEFAULTSHELL" == ""; then
  usage "-s login_shell not defined"
fi

#' ## Setup a User Admin Directory
#' The following directory is used for storing user files
# user-files
if [ ! -d "$USERADMINDIR" ]
then
  log_msg "$SCRIPT" " * Create user admin dir: $USERADMINDIR ..."
  mkdir -p $USERADMINDIR
  chmod 700 $USERADMINDIR
else
  log_msg "$SCRIPT" " * Found user admin dir: $USERADMINDIR ..."
fi

#' ## Migrate Users in USERFILE
#' The userfile contains a list of files with account information of the users to be migrated.
#+ migrate-user-files
cat $USERFILE | while read f
do 
  SRCSERVER=`echo $f | cut -d ':' -f1`
  ACCOUNTFILE=`echo $f | cut -d ':' -f2`
  log_msg "$SCRIPT" " * Running input $f ..."
  scp $f $USERADMINDIR
  sleep 2
done

#' ## Create User Accounts
#' The migrated user files are used to create accounts
#+ create-user-accounts
find $USERADMINDIR -maxdepth 1 -name "*.pwd" -print | while read f
do 
  log_msg "$SCRIPT" " * Process $f ..."
  LOGINNAME=$(cat $f | cut -d ',' -f1)
  LOGINPWD=$(cat $f | cut -d ',' -f2)
  log_msg "$SCRIPT" " * Create account for $LOGINNAME ..."
  create_user $LOGINNAME $LOGINPWD $DEFAULTSHELL
  sleep 2
  # add user to group, if specified
  if [ "$USERGROUP" != "" ]
  then
    log_msg "$SCRIPT" " * Add $LOGINNAME to group $USERGROUP ..."
    add_user_to_grp $USERGROUP $LOGINNAME
    sleep 2
  fi
  log_msg "$SCRIPT" " * Cleanup $f ..."
  rm $f
  sleep 2
done


#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

