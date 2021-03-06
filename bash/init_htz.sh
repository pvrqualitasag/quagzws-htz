#!/bin/bash
#' ---
#' title: Hetzner Remote Server Init
#' date:  2020-05-05 08:50:49
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' Automated setup of remote server rented from hetzner.
#'
#' ## Description
#' Initial steps when installing a new remote server from hetzner. These steps 
#' consist of
#' 
#' * Changing the root-password (-r)
#' * Adding a common user group (-g)
#' * Adding a user as administrator (-u)
#' * Specifying the administrator password (-p)
#' * Installing additional software packages based on an input file (-a)
#' * Deny ssh-access for root
#' * Configure the firewall to only allow port 22, 80 and 443
#'
#' ## Details
#' When renting a new remote server from hetzer, the server is started into 
#' the rescue system from the robot-website of hetzner. The rescue system 
#' allows for the partitioning of the HDs of the server, the installation of 
#' the basic operating system and the configuration of the basic services. This 
#' can be done via an autosetup file. This file is generated using the script 
#' 'create_autosetup.sh'. Once this setup is completed this initialisation 
#' script can be uploaded to the server and executed as shown below.
#'
#' ## Example
#' ./bash/init_htz.sh -r <root_password> -u <admin_user> -p <admin_password>
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
  $ECHO "Usage: $SCRIPT -r <root_password> -u <admin_user> -p <admin_password> -g <zws_group> -a <apt_pkg_file>"
  $ECHO "  where -r <root_password>   --  root password"
  $ECHO "        -u <admin_user>      --  admin user"
  $ECHO "        -p <admin_password>  --  password for admin user (optional)"
  $ECHO "        -g <zws_group>       --  additional user group (optional)"
  $ECHO "        -a <apt_pkg_file>    --  input file with apt packages (optional)"
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

#' ### Changing Root Password
#' The existing root password is changed to a specified value
#+ change-root-password-fun
change_root_password () {
  echo "root:$ROOT_PASSWORD" | chpasswd 
  
}

#' ### Add Admin User
#' Specific admin user is added to avoid having to work as root
#+ add-admin-user
add_admin_user () {
  # check whether home-directory already exists
  if [ -d "/home/$ADMIN_USER" ]
  then
    log_msg 'add_admin_user' "Found existing home directory of admin user: $ADMIN_USER"
  else  
    # add user
    useradd $ADMIN_USER -s /bin/bash -m
    # set password
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
    if [ ! -d "/root/user_admin/created" ]; then mkdir -p /root/user_admin/created;fi
    echo "$ADMIN_USER:$ADMIN_PASSWORD" > /root/user_admin/created/.${ADMIN_USER}.pwd
    # do a chmod on the info on the user admin
    chmod -R 700 /root/user_admin
    # add $ADMIN_USER to sudoer
    usermod -a -G sudo $ADMIN_USER
    # admin user is added to zws_group, if zws_grp was specified
    if [ "$ZWS_GROUP" != "" ]
    then
      usermod -a -G $ZWS_GROUP $ADMIN_USER
    fi
  fi

}

#' ### Add user group zwsgrp
#' Users of fb-zws should have special permissions in directory /qualstorzws
#' this is granted with a special group.
#+ add-zws-grp-fun
add_zws_grp () {
  if [ $(grep "$ZWS_GROUP" /etc/group | wc -l) == "0" ]
  then
    log_msg 'add_zws_grp' " * Adding group $ZWS_GROUP"
    groupadd $ZWS_GROUP
  fi
}

#' ### Install System Software
#' The software that is used for further installation is installed
install_software () {
  #sed -i 's/main/main restricted universe/g' /etc/apt/sources.list
  apt update
  apt upgrade -y

  # install software given in the apt-pkg file
  cat $APT_PKG | while read p
  do
    log_msg 'install_software' " * Installing package $p ..."
    apt install -y $p
  done
  
  apt update
  apt upgrade -y
  
}

#' ### Enable Firewall
#' After installing ufw, it must be configured and enabled
#+ enable-ufw-fun
enable_ufw () {
  ufw allow ssh
  ufw allow 443/tcp
  ufw allow 80/tcp
  log_msg 'enable_ufw' ' * Enable ufw with: yes | ufw enable ...'
  log_msg 'enable_ufw' ' * Check the status with: ufw status ...'
}

#' ### Deny root Access
#' Access to the server as user root via ssh is denied, because this user 
#' is on all linux machines, it is not advisable to permit ssh login as root.
#+ deny-ssh-root-fun
deny_ssh_root () {
  if [ ! -e /etc/ssh/sshd_config.org ]
  then
    log_msg 'deny_ssh_root' ' ** Copy away the original ssh config file ...'
    # keep a copy of the original config file
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.org
  fi
  log_msg 'deny_ssh_root' ' ** Deny ssh access to root ...'
  cat /etc/ssh/sshd_config.org | sed -e 's/PermitRootLogin yes/PermitRootLogin no/' > /etc/ssh/sshd_config  
  # restart ssh demon
  /etc/init.d/ssh restart

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
ZWS_GROUP=''
ROOT_PASSWORD=""
ADMIN_USER=quagadmin
ADMIN_PASSWORD=""
APT_PKG=''
while getopts ":a:g:r:u:p:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    a)
      APT_PKG=$OPTARG
      ;;
    g)
      ZWS_GROUP=$OPTARG
      ;;
    r)
      ROOT_PASSWORD=$OPTARG
      ;;
    u)
      ADMIN_USER=$OPTARG
      ;;
    p)
      ADMIN_PASSWORD=$OPTARG
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
if test "$ROOT_PASSWORD" == ""; then
  usage "-r <root_password> not defined"
fi
if test "$ADMIN_USER" == ""; then
  usage "-u <admin_user> not defined"
fi
if test "$ADMIN_PASSWORD" == ""; then
  usage "-p <admin_password> not defined"
fi


#' ## Change Root Password
#' The root password was set by htz and is changed to a specified value
#+ change-root-password
log_msg $SCRIPT ' * Change root password ...'
change_root_password


#' ## Add Group for zwsgrp
#' Add group for all members of fb-zws
if [ "$ZWS_GROUP" != "" ]
then
  log_msg $SCRIPT ' * Add zws group ...'
  add_zws_grp
fi


#' ## Add Admin User
#' Add an admin user
#+ add-admin-user
log_msg $SCRIPT ' * Add admin user ...'
add_admin_user


#' ## Installation of System Programs
#' Software that is required for further setup is installed
#+ install-software
if [ "$APT_PKG" != "" ]
then
  log_msg $SCRIPT ' * Install system software ...'
  install_software
fi


#' ## Deny ssh Login for root
#' The ssh acces for root should be denied
#+ deny-ssh-root
log_msg $SCRIPT ' * Deny ssh access for root ...'
deny_ssh_root


#' ## Enable Firewall
#' Once the ufw firewall is installed, it must be configured and enabled
#+ enable-ufw
log_msg $SCRIPT ' * Enable firewall ...'
enable_ufw


#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

