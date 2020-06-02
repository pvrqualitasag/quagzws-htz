#!/bin/bash
#' ---
#' title: Init Restic Backup
#' date:  2020-06-02
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Setting up infrastructure to run restic backup jobs. 
#'
#' ## Description
#' This script prepares the infrastructure for running restic backup jobs
#'
#' ## Details
#' The infrastructure consists of root-backup directory, the password-less login to the sftp-remote system, 
#' the directories on the sftp-remote system and the parameter file
#'
#' ## Example
#' ./init_restic_backup.sh
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
  $ECHO "Usage: $SCRIPT -e <exclude_file> -i -j <job_file> -l <restic_log_file> -m <email_address> -p <restic_parfile> -q <repo_path> -r <restic_repository> -u <repository_username> -w <restic_password>"
  $ECHO "  where -e <exclude_file>         --  specify exclude_file containing directories to be excluded (optional)"
  $ECHO "        -i                        --  initialise restic repository (optional)"
  $ECHO "        -j <job_file>             --  specify job_file containing the sources to be backed up (optional)"
  $ECHO "        -l <restic_log_file>      --  specify restic log file (optional)"
  $ECHO "        -m <email_address>        --  notification e-mail address (optional)"
  $ECHO "        -p <restic_parfile>       --  specify parameterfile from where settings are read (optional)"
  $ECHO "        -q <repo_path>            --  specify repository path (optional)"
  $ECHO "        -r <restic_repo_host>     --  specify restic repository host <sftp-host>"
  $ECHO "        -s <restic_script>        --  specify restic backup script (optional)"
  $ECHO "        -u <repository_username>  --  specify restic username"
  $ECHO "        -w <restic_password>      --  specify repository password"
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

#' ### Assign Restic Repository
#' The content of the restic repository is composed of username, host and path
#+ create-restic-repository
assign_restic_repository () {
  RESTICREPOSITORY="sftp:${REPOSITORYUSER}@${REPOSITORYHOST}:${REPOSITORYPATH}"
  log_msg 'assign_restic_repository' " * Restic repo assigned as: $RESTICREPOSITORY"
}

#' ### Check Directory
#' Helper function to check whether a directory exists and if not create it.
#+ check-create-dir-fun
check_create_dir () {
  local l_CHECKDIR=$1
  # check whether directory exists
  if [ ! -d "$l_CHECKDIR" ]
  then
    log_msg 'check_create_dir' " ** Create directory $l_CHECKDIR ..."
    mkdir -p $l_CHECKDIR
  else
    log_msg 'check_create_dir' " ** Found directory $l_CHECKDIR ..."
  fi
}

#' ### Create Local Directories
#' Directories required for backup on local server
#+ create-local-dir-fun
create_local_dir () {
  # loop over required directories
  for d in ${BACKUPSUBDIR[@]}
  do
    log_msg 'create_local_dir' " * Check directory $d ..."
    check_create_dir $BACKUPROOTDIR/$d
  done
  
}

#' ### Copy Restic Shell Script
#' Shell script that does the backup is copied
copy_restic_script () {
  log_msg 'copy_restic_script' " * Coping $RESTICSCRIPT to $BACKUPROOTDIR/bash ..."
  cp $RESTICSCRIPT $BACKUPROOTDIR/bash
}

#' ### Write Parameter File
#' Information required for the backup program are written to a parameter file.
#+ write-param-file
write_param_file () {
  log_msg 'write_param_file' " * Writing parameters to $RESTICPARFILE ..."
  echo "# Restic Parameter file created by $SCRIPT"  >> $RESTICPARFILE
  echo "RESTICREPOSITORY=$RESTICREPOSITORY" >> $RESTICPARFILE
  echo "RESTICPASSWORD=$RESTICPASSWORD" >> $RESTICPARFILE
  echo "JOBFILE=$RESTICJOBFILE" >> $RESTICPARFILE
  echo "EMAILADDRESS=$EMAILADDRESS" >> $RESTICPARFILE
}

#' ### Write a Job File
#' Directories to be backed up are written to a job-file
#+ write-job-file-fun
write_job_file () {
  local l_JOB=''
  log_msg 'write_job_file' ' * Writing backup job file ...'
  while [ "$l_JOB" != "q" ]
  do
    echo -n " * Full path of directory to be backed up [q - to quit]: "
    read l_JOB
    if [ "$l_JOB" != "q" ]
    then
      echo "$l_JOB" >> $RESTICJOBFILE
    fi  
  done
}

#' ### Write a Exclude-File
#' Directories to be excluded from backup are written to an exclude-file
#+ write-exclude-file-fun
write_exclude_file () {
  local l_EXCLUDE=''
  log_msg 'write_exclude_file' ' * Writing exclude-file ...'
  while [ "$l_EXCLUDE" != "q" ]
  do
    echo -n " * Full path of directory to be backed up [q - to quit]: "
    read l_EXCLUDE
    if [ "$l_EXCLUDE" != "q" ]
    then
      echo "$l_EXCLUDE" >> $RESTICEXCLUDEFILE
    fi  
  done  
}

#' ### Initialise restic repository
#' The repository for restic is initialsied
#+ init-restic-repo-fun
init_restic_repo () {
  log_msg 'init_restic_repo' ' * Initialise restic repo ...'
  sudo su - -c "restic -r $RESTICREPOSITORY init"
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
EMAILADDRESS=''
RESTICSCRIPT="$INSTALLDIR/restic_backup.sh"
RESTICJOBFILE=''
RESTICEXCLUDEFILE=''
RESTICPARFILE=/home/quagadmin/backup/par/restic_backup.par
BACKUPROOTDIR=/home/quagadmin/backup
BACKUPSUBDIR=(bash job log par)
REPOSITORYPATH="/${SERVER}/restic-repo"
REPOSITORYHOST=''
REPOSITORYUSER=''
INITRESTIC=''
while getopts ":e:j:m:p:q:r:s:u:w:ih" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    e)  
      RESTICEXCLUDEFILE=$OPTARG
      ;;
    i)
      INITRESTIC='TRUE'
      ;;
    j)
      RESTICJOBFILE=$OPTARG
      ;;
    m)
      EMAILADDRESS=$OPTARG
      ;;
    p)
      RESTICPARFILE=$OPTARG
      ;;
    q)
      REPOSITORYPATH=$OPTARG
      ;;
    r)
      REPOSITORYHOST=$OPTARG
      ;;
    s)
      if [ -f "$OPTARG" ];then
        RESTICSCRIPT=$OPTARG
      else
        usage " * ERROR cannot find restic script: $OPTARG"
      fi
      ;;
    u)
      REPOSITORYUSER=$OPTARG
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



#' ## Argument Check
#' Check whether arguments are assigned
if [ "$REPOSITORYPATH" == "" ]
then
  usage " * Error: -q <repository_path> must be specified"
fi
if [ "$REPOSITORYHOST" == "" ]
then
  usage " * Error: -r <repository_host> must be specified"
fi
if [ "$REPOSITORYUSER" == "" ]
then
  usage " * Error: -u <repository_user> must be specified"
fi

#' ## Put together restic repository
#' Based on user, host and path create restic_repository
log_msg "$SCRIPT" ' * Create restic repository ...'
assign_restic_repository

#' ## Create Backup Directories
#' Directories required for backup on local server are created
#+ create-local-dir
log_msg "$SCRIPT" ' * Create local dirs ...'
create_local_dir

#' ## Copy Restic Script
#' The script that does the backup is copied
log_msg "$SCRIPT" ' * Copy restic script ...'
copy_restic_script

#' ## Produce Parameterfile
#' Information required for backup job is written to a parameterfile
log_msg "$SCRIPT" ' * Write parameter file ...'
write_param_file

#' ## Write Jobfile
#' Directories to be backed-up are written to a jobfile, if a name 
#' of a jobfile is specified
if [ "$RESTICJOBFILE" != "" ]
then
  log_msg "$SCRIPT" ' * Write job file ...'
  write_job_file
fi

#' ## Write Exclude-File
#' Directories to be excluded are written to a jobfile, if a name 
#' of a exclude-file is specified
if [ "$RESTICEXCLUDEFILE" != "" ]
then
  log_msg "$SCRIPT" ' * Write exclude-file ...'
  write_exclude_file
fi

#' ## Initialise the restic repository
#' Before being able to run a backup with restic, the remote repository 
#' must be initialised. This requires password-less ssh connection to 
#' remote backup host. This can be setup with 'init_ssh_key_pass_backup.sh'
if [ "$INITRESTIC" == "TRUE" ]
then
  log_msg "$SCRIPT" ' * Initialise restic repository ...'
  init_restic_repo
fi

#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

