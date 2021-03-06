#!/bin/bash
#' ---
#' title: Qualitas AG Hetzner Application Installation
#' date:  2020-05-06 17:11:33
#' author: Peter von Rohr
#' ---
#' ## Purpose
#' The required application should be installed and configured in a standard way.
#'
#' ## Description
#' Applications that are needed on the server are to be installed and configured. 
#' The applications are chosen from the definition file of the singularity 
#' container that is running on the Qualitas-ZWS servers. The option -m {all,apt,curl,local,rstudio}
#' can be used to install only part of the programs. 
#'
#' ## Details
#' The installed applications are the basic data-science tools. Specialised programs 
#' are copied from an existing server. The data-science tools are either installed 
#' using `apt` for all applications that are available in ubuntu repositories. 
#' All other tools are installed using a download with `curl`. The downloaded 
#' tar.gz-archives are extracted in a specific directory. For the curl-tools and the 
#' local tools the path of all users are extended in /etc/profile.d/apps-bin-path.sh. 
#' The local tools are copied from a source-server. That does only work, if the 
#' ssh-key-based login to the source-server. 
#'
#' ## Example
#' QSRCDIR=/home/quagadmin/source
#' QHTZDIR=${QSRCDIR}/quagzws-htz
#' if [ ! -d "$QSRCDIR" ]; then mkdir -p $QSRCDIR;fi
#' if [ ! -d "$QHTZDIR" ]; then 
#'   git -C "$QSRCDIR" clone https://github.com/pvrqualitasag/quagzws-htz.git
#' else
#'   git -C $QHTZDIR pull
#' fi
#' sudo su - -c "$QHTZDIR/bash/install_app_htz.sh -q <host_name> \
#' -a /home/quagadmin/source/quagzws-htz/input/apt_pkg/apt_pkg.txt \
#' -c /home/quagadmin/source/quagzws-htz/input/curl_input/curl_input.par \
#' -k /home/quagadmin/source/quagzws-htz/input/apt_pkg/rkey_file.par \
#' -l /home/quagadmin/source/quagzws-htz/input/local_app/local_app.txt \
#' -r /home/quagadmin/source/quagzws-htz/input/r_pkg/r_pkg.txt"
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
  $ECHO "Usage: $SCRIPT -a <apt_pkg_file> -c <curl_input> -k <r_key_file> -l <local_app_dir> -m <install_mode> -q <server_fqdname> -r <r_pkg_file>"
  $ECHO "  where -a <apt_pkg_file>    --  file with apt-pkg to be installed (optional)"
  $ECHO "        -c <curl_input>      --  input specifying curl-based installations (optional)"
  $ECHO "        -k <r_key_file>      --  file with r ubuntu repo key (optional)"
  $ECHO "        -l <local_app_dir>   --  remote directory including username usable with scp to be copied to new server (optional)"
  $ECHO "        -m <install_mode>    --  installation mode to selectively install only parts of the applications (optional)"
  $ECHO "        -q <server_fqdname>  --  FQDNAME of server to be configured"
  $ECHO "        -r <r_pkg_file>      --  file with r-packages to be installed (optional)"
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

#' ### Installation of Apt-Based Tools
#' Some data-science tools are available from ubuntu repositories. These are 
#' installed in the following function.
#+ apt-tools-install-fun
apt_tools_install () {
  # install additional tools, if the input file is specified
  if [ "$APTPKGFILE" != "" ]
  then
    # start with an updata/upgrade of the existing system
    apt update
    apt upgrade -y
  
    # check whether r-base is to be installed
    if [ "$(grep r-base $APTPKGFILE | wc -l)" != "0" ]
    then
      log_msg 'apt_tools_install' ' ** Add key and repo for R'
      # default settings
      KEYSERVER=keyserver.ubuntu.com
      RECVKEY=E298A3A825C0D65DFD57CBB651716619E084DAB9
      REPO='deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/'
      # read input from file, if it exists
      if [ "$RKEYFILE" != "" ]
      then
        log_msg 'apt_tools_install' " ** Sourcing rkey_file: $RKEYFILE ... "
        source $RKEYFILE
      fi  
      # add key and repository for R
      log_msg 'apt_tools_install' " ** Specify keyserver: $KEYSERVER with key: $RECVKEY ... "
      apt-key adv --keyserver $KEYSERVER --recv-keys $RECVKEY
      log_msg 'apt_tools_install' " ** Adding repository: $REPO ... "
      add-apt-repository "$REPO"
      apt update
    fi

    log_msg 'apt_tools_install' ' ** Install R, python and co ...'
    # install R, python and co.
    cat $APTPKGFILE | while read p
    do
      log_msg 'apt_tools_install' " ** Installing pkg $p ..."
      apt install -y $p
    done  
    apt update
    apt upgrade -y
  fi
  
  # install R packages, if R is available and if input file is specified
  if [ "$RPKGFILE" != "" ]
  then
    # check whether R is installed
    if [ "$(which R | wc -l)" == "0" ]
    then
      log_msg 'apt_tools_install' " ** Cannot find R and therefore cannot install r-packages from $RPKGFILE"
    else
      cat $RPKGFILE | while read rpkg
      do
        log_msg 'apt_tools_install' " ** Install r-pgk: $rpkg ..."
        R -e "if (! '$rpkg' %in% installed.packages()) {
          cat(' *** R: install.package: $rpkg \n')
          install.packages('$rpkg', repos='https://cran.rstudio.com/', dependencies = TRUE)}"
      done
    fi
  fi

  # check whether pip3 has been installed already
  PIP3PATH=/usr/bin/pip3
  if [ -f "$PIP3PATH" ]
  then
    log_msg 'apt_tools_install' ' ** Install pandas and numpy ...'
    # use pip to get numpy and pandas for py3
    $PIP3PATH install pandas
    $PIP3PATH install numpy
  fi
  
}

#' ### Installation of Tools with curl
#' Tools downloaded with curl and unpacked to a specific directory. The applications 
#' are added to the path such that they can be used without specifying the path.
#+ curl-tools-install-fun
curl_tools_install () {
  # initialise variables
  JULIA_URL=''
  JULIA_ROOT=''
  JULIA_PATH=''
  JDK_URL=''
  JDK_ROOT=''
  JDK_PATH=''
  SIMG_URL=''
  # source the input file
  source $CURLINPUT
  # check whether julia must be installed
  if [ "$JULIA_URL" != "" ] && [ "$JULIA_ROOT" != "" ] && [ "$JULIA_PATH" != "" ]
  then
    log_msg 'curl_tools_install' ' ** Install julia ...'
    # Install jula from download-host
    curl -sSL "$JULIA_URL" > julia.tar.gz 
    if [ ! -d "$JULIA_ROOT" ];then mkdir -p $JULIA_ROOT;fi
    tar -C $JULIA_ROOT -zxf julia.tar.gz 
    rm -f julia.tar.gz
    # define julia path
    local l_JULIAPATH=$JULIA_PATH
    # check whether julia must be added to path
    if [ "$(grep julia_path /etc/profile.d/apps-bin-path.sh | wc -l)" == "0" ]
    then
      log_msg 'curl_tools_install' " ** Adding $l_JULIAPATH to path: $PATH ..."
      echo "
# Adding julia to path
julia_path=$l_JULIAPATH" >> /etc/profile.d/apps-bin-path.sh
      echo '
if [ -n "${PATH##*${julia_path}}" -a -n "${PATH##*${julia_path}:*}" ]; then
   export PATH=$PATH:${julia_path}
fi' >> /etc/profile.d/apps-bin-path.sh
    else
      log_msg 'curl_tools_install' " ** Dir $l_JULIAPATH already in path: $PATH ..."
    fi
  fi
  
  # check whether jdk must be installed
  if [ "$JDK_URL" != "" ] && [ "$JDK_ROOT" != "" ] && [ "$JDK_PATH" != "" ]
  then
    log_msg 'curl_tools_install' ' ** Install openjdk8 ...'
    # install OpenJDK 8 (LTS) from https://adoptopenjdk.net
    curl -sSL "$JDK_URL" > openjdk8.tar.gz
    if [ ! -d "$JDK_ROOT" ];then mkdir -p ${JDK_ROOT};fi
    tar -C $JDK_ROOT -xf openjdk8.tar.gz
    rm -f openjdk8.tar.gz
    # Assign jdk
    local l_JDKPATH=$JDK_PATH
    # Check whether jdk must be added to path
    if [ "$(grep jdk_path /etc/profile.d/apps-bin-path.sh | wc -l)" == "0" ]
    then
      log_msg 'cur_tools_install' " ** Adding $l_JDKPATH to path: $PATH ..."
      echo "
# Adding jdk to path
jdk_path=$l_JDKPATH" >> /etc/profile.d/apps-bin-path.sh
      echo '
if [ -n "${PATH##*${jdk_path}}" -a -n "${PATH##*${jdk_path}:*}" ]; then
   export PATH=$PATH:${jdk_path}
fi' >> /etc/profile.d/apps-bin-path.sh
    else
      log_msg 'cur_tools_install' " ** Dir $l_JDKPATH already in path: $PATH ..."  
    fi
  fi  
  
  # check whether to install go
    if [ "$GO_URL" != "" ] && [ "$GO_ROOT" != "" ] && [ "$GO_PATH" != "" ]
  then
    log_msg 'curl_tools_install' ' ** Install go ...'
    # install go from $GO_URL
    curl -sSL "$GO_URL" > go.tar.gz
    if [ ! -d "$GO_ROOT" ];then mkdir -p ${GO_ROOT};fi
    tar -C $GO_ROOT -xf go.tar.gz
    rm -f go.tar.gz
    # Assign jdk
    local l_GOPATH=$GO_PATH
    # Check whether GO must be added to path
    if [ "$(grep go_path /etc/profile.d/apps-bin-path.sh | wc -l)" == "0" ]
    then
      log_msg 'cur_tools_install' " ** Adding $l_GOPATH to path: $PATH ..."
      echo "
# Adding GO to path
go_path=$l_GOPATH" >> /etc/profile.d/apps-bin-path.sh
      echo '
if [ -n "${PATH##*${go_path}}" -a -n "${PATH##*${go_path}:*}" ]; then
   export PATH=$PATH:${go_path}
fi' >> /etc/profile.d/apps-bin-path.sh
    else
      log_msg 'cur_tools_install' " ** Dir $l_GOPATH already in path: $PATH ..."  
    fi
  fi  
  
  # check whether simg is to be installed
  if [ "$SIMG_URL" != "" ]
  then
    log_msg 'curl_tools_install' ' ** Install singularity-container ...'
    SIMG_DEB=$(basename $SIMG_URL)
    curl -sSL "$SIMG_URL" > $SIMG_DEB
    # check whether gdebi-core is available
    if [ "$(dpkg --list | grep gdebi-core | wc -l)" == "0" ]
    then
      apt-get update -y
      apt-get install -y gdebi-core
    fi
    gdebi --n $SIMG_DEB
    rm -rf $SIMG_DEB
  fi
}

#' ### Installation of Local Tools
#' Local tools are installed based on an input file containing the locations from 
#' where the tools can be copied from
#+ local-tools-install-fun
local_tools_install () {
  local l_TOOSDIR=$1
  local l_SRCSERVER=$(echo $l_TOOSDIR | cut -d ':' -f 1)
  local l_LOCALDIR=$(echo $l_TOOSDIR | cut -d ':' -f 2)
  local l_LOCALROOT=$(dirname "$l_LOCALDIR")
  # check whether local dir already exists, if yes do not copy
  if [ -d "$l_LOCALDIR" ]
  then
    log_msg 'local_tools_install' " ** Local tools already exists in $l_LOCALDIR"
  else
    log_msg 'local_tools_install' " ** Installation of local tools from $l_TOOSDIR ..."
    # change to root to get the same path
    curwd=$(pwd)
    cd /
    ssh $l_SRCSERVER "tar cvf - $l_LOCALDIR" | tar xvf -
    cd $curwd
    log_msg 'local_tools_install' " ** Change owner of $l_LOCALROOT ..."
    chown -R quagadmin:zwsgrp $l_LOCALROOT
  fi  
  # add linuxBin to path, if required
  if [ "$(grep linux_bin_path /etc/profile.d/apps-bin-path.sh | wc -l)" == "0" ]
  then
    log_msg 'local_tools_install' " ** Add $l_LOCALDIR to path: $PATH ..."
    echo "
# Adding linuxBin to path
linux_bin_path=$l_LOCALDIR" >> /etc/profile.d/apps-bin-path.sh
  echo '
if [ -n "${PATH##*${linux_bin_path}}" -a -n "${PATH##*${linux_bin_path}:*}" ]; then
   export PATH=$PATH:${linux_bin_path}
fi' >> /etc/profile.d/apps-bin-path.sh
  else  
    log_msg 'local_tools_install' " ** Dir $l_LOCALDIR already found in path: $PATH ..."
  fi
}

#' ### Rstudio Server Installation
#' The rstudio server is installed
#+ rstudio-server-install-fun
rstudio_server_install () {
  log_msg 'rstudio_server_install' ' ** Installation of Rstudio server ...'
  # according to https://rstudio.com/products/rstudio/download-server/debian-ubuntu/
  if [ "$(dpkg -l | grep gdebi-core | wc -l)" == "0" ]
  then
    log_msg 'rstudio_server_install' ' ** Install gdebi-core ...'
    apt update
    apt install -y gdebi-core
  fi  
  # check whether rstudio server has already been installed
  if [ "$(service rstudio-server status 2> /dev/null | wc -l)" == "0" ]
  then
    wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-1.2.5042-amd64.deb
    gdebi --n rstudio-server-1.2.5042-amd64.deb
    rm rstudio-server-1.2.5042-amd64.deb
  else 
    log_msg 'rstudio_server_install' ' ** Rstudio server already seams to be installed...'
  fi

}

#' ### Shiny Server Installation
#' The shiny server is installed
#+ shiny-server-install-fun
shiny_server_install () {
  log_msg 'shiny_server_install' ' ** Installation of shiny server ...'
  
  # check whether rstudio server has already been installed
  if [ "$(service shiny-server status 2> /dev/null | wc -l)" == "0" ]
  then
    # according to https://rstudio.com/products/shiny/download-server/ubuntu/
    R -e "install.packages('shiny', repos='https://cran.rstudio.com/')"
    wget https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-1.5.13.944-amd64.deb
    gdebi --n shiny-server-1.5.13.944-amd64.deb
    rm shiny-server-1.5.13.944-amd64.deb
  else 
    log_msg 'shiny_server_install' ' ** Shiny server already seams to be installed...'
  fi
    
}

#' ### Nginx Configuration
#' The configuration of nginx is generated from a template
config_nginx () {
  log_msg 'config_nginx' ' ** Generate nginx from template ...'
  # check availablility of templated
  local l_NGINXTMPL='/home/quagadmin/source/quagzws-htz/input/nginx/n-htz_nginx.template'
  if [ ! -f "$l_NGINXTMPL" ]; then usage " * ERROR: cannot find nginx-template: $l_NGINXTMPL";fi
  # specify nginx default config
  local l_NGINXCONFIGDEFAULT=/etc/nginx/sites-enabled/default
  # generate nginx config file name from $FQDNAME
  local l_NGINXCONFIG=/etc/nginx/sites-enabled/$(echo $FQDNAME | cut -d '.' -f1)
  if [ -f "$l_NGINXCONFIG" ]
  then 
    log_msg 'config_nginx' ' * nginx config file already exists'
  else  
    # replace placeholder in template file
    log_msg 'config_nginx' ' ** Create nginx logfile from template ...'
    cat $l_NGINXTMPL | sed -e "s/{FQDNAME}/$FQDNAME/" > $l_NGINXCONFIG
    if [ -e "$l_NGINXCONFIGDEFAULT" ]
    then 
      log_msg 'config_nginx' " ** Remove default config: $l_NGINXCONFIGDEFAULT ..."
      rm $l_NGINXCONFIGDEFAULT
    fi  
  fi  
  # check whether referenced certificates are available
  grep ssl_certificate $l_NGINXCONFIG | cut -d ' ' -f4 | sed -e 's/;//' | while read f
  do
    if [ -f "$f" ]
    then
      log_msg 'config_nginx' " ** Found certificate file: $f"
    else
      log_msg 'config_nginx' " * Cannot find $f -- RUN 'letsencrypt certonly' to generate the certificates."
    fi
  done

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
APTPKGFILE=''
CURLINPUT=''
RKEYFILE=''
RPKGFILE=''
FQDNAME=''
LOCALDIR=''
INSTALLMODE='all'
while getopts ":a:c:k:l:m:q:r:h" FLAG; do
  case $FLAG in
    h)
      usage "Help message for $SCRIPT"
      ;;
    a)
      APTPKGFILE=$OPTARG
      ;;
    c)
      CURLINPUT=$OPTARG
      ;;
    k)
      RKEYFILE=$OPTARG
      ;;
    l)
      LOCALDIR=$OPTARG
      ;;
    m)
      INSTALLMODE=$OPTARG
      ;;
    q)
      FQDNAME=$OPTARG
      ;;
    r)
      RPKGFILE=$OPTARG
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
  usage "-q <server_fqdname> not defined"
fi
if test "$INSTALLMODE" == ""; then
  usage "-m <install_mode> not defined"
fi


#' ## Apt-based Tools
#' In a first step, the tools available in ubuntu repositories are installed.
#+ apt-tools-install
if [ "$INSTALLMODE" == 'all' ] || [ "$INSTALLMODE" == 'apt' ]
then
  log_msg "$SCRIPT" ' * Apt tools installation ...'
  apt_tools_install
fi

#' ## Curl-based Tools
#' Tools not available in an ubuntu repository are downloaded and installed, 
#' if an input file is specified.
if [ "$INSTALLMODE" == 'all' ] || [ "$INSTALLMODE" == 'curl' ]
then
  if [ "$CURLINPUT" != "" ]
  then
    log_msg "$SCRIPT" ' * Curl tools installation ...'
    curl_tools_install
  fi
fi

#' ## Local Tools Installation
#' Local tools are programs that are obtained or purchased and cannot be downloaded from 
#' anywhere. Hence they are just copied from an existing installation.
if [ "$INSTALLMODE" == 'all' ] || [ "$INSTALLMODE" == 'local' ]
then
  if [ "$LOCALDIR" != "" ]
  then
    if [ -f "$LOCALDIR" ]
    then
      # installation of a list of local apps
      cat $LOCALDIR | while read f
      do
        log_msg "$SCRIPT" " * Local tools installation of $f ..."
        local_tools_install $f
        sleep 2
      done
    else
      log_msg "$SCRIPT" " * Local tools installation $LOCALDIR ..."
      local_tools_install $LOCALDIR
    fi  
  fi
fi

#' ## RStudio-Server and Shiny Server
#' Installation of rstudio server and shiny server
if [ "$INSTALLMODE" == 'all' ] || [ "$INSTALLMODE" == 'rstudio' ]
then
  log_msg "$SCRIPT" ' * Install RStudio-server ...'
  rstudio_server_install
  log_msg "$SCRIPT" ' * Install shiny server ...'
  shiny_server_install
  log_msg "$SCRIPT" ' * Configure nginx ...'
  config_nginx
fi


#' ## End of Script
#+ end-msg, eval=FALSE
end_msg

