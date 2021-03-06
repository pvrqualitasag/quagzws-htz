#!/bin/bash
#' ---
#' title: Generate autosetup file
#' date:  2020-05-11 14:56:36
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Automated generation of autosetup input file. 
#'
#' ## Description
#' Automated setup of dedicated servers rented from Hetzner require an input file. This input file is genated with this script from a template.
#'
#' ## Details
#' The template of the autosetup script contains place holders which are replaced by this script. The input for the replacement is taken from the commandline arguments.
#'
#' ## Example
#' ./create_autosetup -q 2-htz.quagzws.com 
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
SCRIPTDIR=`$DIRNAME ${BASH_SOURCE[0]}`    # installation dir of bashtools on host   #
PROJDIR=`$DIRNAME $SCRIPTDIR`

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
  $ECHO "Usage: $SCRIPT -q <fqdn_server> -t <autosetup_template> -o <output_file>"
  $ECHO "  where -q <fqdn_server>         --  FQDN server name on which autosetup is run"
  $ECHO "        -t <autosetup_template>  --  path to the autosetup template (optional)"
  $ECHO "        -o <output_file>         --  name of the output file (optional)"
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
FQDNAME=""
AUTOSETUPTMPL="${PROJDIR}/input/installimage/autosetup.template"
OUTPUTFILE='autosetup'
while getopts ":o:q:t:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    o)
      OUTPUTFILE=$OPTARG
      ;;
    q)
      FQDNAME=$OPTARG
      ;;
    t)
      AUTOSETUPTMPL=$OPTARG
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
if test "$FQDNAME" == ""; then
  usage "-q <fqdn_server> not defined"
fi



#' ## Replace Placeholder
#' Currently the servername is the only placeholder to be replaced.
#+ replace-place-holder
log_msg "$SCRIPT" ' * Replace placeholder in template ...'
cat $AUTOSETUPTMPL | sed -e "s/{FQDNAME}/$FQDNAME/" > $OUTPUTFILE



#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

