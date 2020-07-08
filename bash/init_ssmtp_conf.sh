#!/bin/bash
#' ---
#' title: Init SSMTP Configuration
#' date:  2020-07-08 14:24:18
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Seamless init of ssmtp conf. 
#'
#' ## Description
#' Initialise the configuration file for ssmtp based on a template. 
#'
#' ## Details
#' Information to replace placeholders in the template file must be provided as commandline arguments.
#'
#' ## Example
#' ./init_ssmtp_conf.sh -m <machine_name> -p <auth_pass> -t <template_path> 
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
SERVER=`hostname -f`                          # put hostname of server in variable      #



#' ## Functions
#' The following definitions of general purpose functions are local to this script.
#'
#' ### Usage Message
#' Usage message giving help on how to use the script.
#+ usg-msg-fun, eval=FALSE
usage () {
  local l_MSG=$1
  $ECHO "Usage Error: $l_MSG"
  $ECHO "Usage: $SCRIPT -c <conf_target> -m <machine_name> -p <auth_pass> -t <template_path> "
  $ECHO "  where -c <conf_target>    --  target path for configuration file (o)"
  $ECHO "        -m <machine_name>   --  hostmachine name                   (o)"
  $ECHO "        -p <auth_pass>      --  auth-pass for mail account         (r)"
  $ECHO "        -t <template_path>  --  alternative path to template       (o)"
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
CONFTRG=/etc/ssmtp/ssmtp.conf
HOSTMACHINE=$SERVER
AUTHPASS=""
TEMPLATEPATH=${INSTALLDIR}/../input/template/ssmtp.conf.template
while getopts ":c:m:p:t:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    c)
      CONFTRG=$OPTARG
      ;;
    m)
      HOSTMACHINE=$OPTARG
      ;;
    p)
      AUTHPASS=$OPTARG
      ;;
    t)
      TEMPLATEPATH=$OPTARG
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
if test "$CONFTRG" == ""; then
  usage "-c <conf_target> not defined"
fi
if test "$HOSTMACHINE" == ""; then
  usage "-m <host_machine> not defined"
fi
if test "$AUTHPASS" == ""; then
  usage "-p <auth_pass> not defined"
fi
if test "$TEMPLATEPATH" == ""; then
  usage "-t <template_path> not defined"
fi


#' ## Replace Placeholders
#' Placeholders in template are replaced
#+ replace placeholders
log_msg "$SCRIPT" ' * Replacing placeholders ...'
cat $TEMPLATEPATH | sed -e "s/{HOSTNAME}/$HOSTMACHINE/" | sed -e "s/{AUTHPASS}/$AUTHPASS/" > tmp_ssmtp_conf.txt


#' ## Rename Existing Version
#' If an old version exists, then rename it
if sudo test -f "$CONFTRG"
then 
  CONFBCK=${CONFTRG}.`date +"%Y%m%d%H%M%S"`
  log_msg "$SCRIPT" " * Saving away old version of $CONFTRG to $CONFBCK ..."
  sudo mv $CONFTRG $CONFBCK
fi


#' ## Move Created Conf
#' Created conf is moved in place
  log_msg "$SCRIPT" " * Moving tmp_ssmtp_conf.txt to $CONFTRG"
sudo mv tmp_ssmtp_conf.txt $CONFTRG
sudo chown root:root $CONFTRG


#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

