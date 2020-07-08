#!/bin/bash
#' ---
#' title: Installation of bash script
#' date:  "2019-10-14"
#' author: Peter von Rohr
#' ---
#'
#' ## Bash Settings
#+ eval=FALSE
set -o errexit    # exit immediately, if single command exits with non-zero status
set -o nounset    # treat unset variables as errors
set -o pipefail   # return value of pipeline is value of last command to exit with non-zero status
                  #  hence pipe fails if one command in pipe fails

#' ## Global Constants
#' ### prog paths
#+ eval=FALSE
ECHO=/bin/echo                             # PATH to echo                            #
DATE=/bin/date                             # PATH to date                            #
BASENAME=/usr/bin/basename                 # PATH to basename function               #
DIRNAME=/usr/bin/dirname                   # PATH to dirname function                #

#' ### Directories
#+ eval=FALSE
INSTALLDIR=`$DIRNAME ${BASH_SOURCE[0]}`    # installation dir of bashtools on host   #

#' ### Files
#+ eval=FALSE
SCRIPT=`$BASENAME ${BASH_SOURCE[0]}`       # Set Script Name variable                #

#' ### Hostname
#+ eval=FALSE
SERVER=`hostname`                          # put hostname of server in variable      #



#' ## Function definitions local to this script
#' usage message
#+ eval=FALSE
usage () {
  local l_MSG=$1
  $ECHO "Usage Error: $l_MSG"
  $ECHO "Usage: $SCRIPT -s <source_path_script> -t <installation_target_path>"
  $ECHO "  where -s <source_path_script>        --  source path for script"
  $ECHO "        -t <installation_target_path>  --  target path where script will be installed"
  $ECHO ""
  exit 1
}

#' produce a start message
#+ eval=FALSE
start_msg () {
  $ECHO "********************************************************************************"
  $ECHO "Starting $SCRIPT at: "`$DATE +"%Y-%m-%d %H:%M:%S"`
  $ECHO "Server:  $SERVER"
  $ECHO
}

#' produce an end message
#+ eval=FALSE
end_msg () {
  $ECHO
  $ECHO "End of $SCRIPT at: "`$DATE +"%Y-%m-%d %H:%M:%S"`
  $ECHO "********************************************************************************"
}

#' functions related to logging
#+ eval=FALSE
log_msg () {
  local l_CALLER=$1
  local l_MSG=$2
  local l_RIGHTNOW=`$DATE +"%Y%m%d%H%M%S"`
  $ECHO "[${l_RIGHTNOW} -- ${l_CALLER}] $l_MSG"
}


#' ## Main part of the script starts here ...
#+ eval=FALSE
start_msg

#' Use getopts for commandline argument parsing
#' If an option should be followed by an argument, it should be followed by a ":".
#' Notice there is no ":" after "h". The leading ":" suppresses error messages from
#' getopts. This is required to get my unrecognized option code to work.
#+ eval=FALSE
SRCPATH=""
TRGPATH=""
while getopts ":s:t:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    s)
      if test -f $OPTARG; then
        SRCPATH=$OPTARG
      else
        usage "$OPTARG isn't a regular file"
      fi
      ;;
    t)
      if [ -d "$OPTARG" ]
      then
        TRGPATH=$OPTARG
      else
        usage "$OPTARG is not an installation target directory"
      fi
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

#' Check whether required arguments have been defined
#+ eval=FALSE
if [ "$SRCPATH" == "" ]
then
  usage "-s <source_path> cannot be undefined"
fi

if [ "$TRGPATH" == "" ]
then
  usage "-t <target_path> cannot be undefined"
fi

log_msg $SCRIPT "Copy script from $SRCPATH to target: $TRGPATH ..."
cp $SRCPATH $TRGPATH


#' Script ends here
#+ eval=FALSE
end_msg

