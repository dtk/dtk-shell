#!/bin/bash
# This script clear terminal and starts installation process of dtk client.

# GLOBAL VAR

abh_gem_repository="http://abh:haris@ec2-54-247-191-95.eu-west-1.compute.amazonaws.com:3000/"
home_dir=`cd ~ && pwd`
etc_location="${home_dir}/.dtk/"
conf_path="${etc_location}/dtkconfig"

# FUNCTIONS BEGIN

# print usage instructions
function usage {
cat << EOF
usage: install_client.sh [username password dtk_server port]
If all of the parameters are provided, installation is performed automatically without additional user input.
See https://github.com/rich-reactor8/dtk-client/blob/master/README.md for additional information.
EOF
}

# check if gem exists sets global var $found_gem to true or false
function gem_exists {
  output=`gem list $1 | grep -i $1`
  if [[ $output != "" ]]; then
    found_gem=true
  else
    found_gem=false
  fi
}

# is there ruby?
function check_for_ruby {
  ruby_output=`which ruby | grep ruby`
  if [[ $ruby_output = "" ]];then
    echo "Ruby needed for installation, please install ruby before installing DTK CLI. Example: sudo apt-get install ruby1.8 "
    exit 0
  fi
}

# are there rubygems?
function check_for_ruby_gems {
  gem_output=`which gem | grep gem`
  if [[ $gem_output = "" ]];then
    echo "Ruby gems are needed for installation, please install ruby gems before installing DTK CLI. Example: sudo apt-get install rubygems "
    exit 0
  fi
}

# check for ruby doc generation
function check_ruby_doc {
  ruby_doc_args="--no-rdoc --no-ri"
  read -p "Do you want to generate documentation for the installed Ruby Gems? [y/N]" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
      ruby_doc_args=""
  fi
  export ruby_doc_args
}

# checks that git is configured properly
function check_git_config {
  if [[ `command -v git 2>&1` ]]; then
    if [[ ! `git config --get user.name` ]]; then
      echo "Git username not set. Please set it before continuing installation."
      echo "Command for setting username:"
      echo "git config --global user.name "User Name""
      git_misconfigured=1
    fi;
    if [[ ! `git config --get user.email` ]]; then
      echo "Git email not set. Please set it before continuing installation."
      echo "Command for setting username:"
      echo "git config --global user.email "me@example.com""
      git_misconfigured=1
    fi;
    [[ $git_misconfigured == 1 ]] && exit 1
  else
    echo "Please install Git before using DTK Client. Installation will now continue, but some features will not work until Git is installed."
    sleep 3
  fi;
}

# checks if native gems can be installed
function check_native_gems {
  echo "Checking for dependencies..."
  gem install json --no-rdoc --no-ri  >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "An error occured while trying to install native ruby gems on your system."
    echo "Please make sure all required dependencies are installed before continuing."
    echo -e "\nHint: you can install the dependencies by running this command:"
    if [[ `which apt-get` ]]; then
      echo "apt-get install build-essential libopenssl-ruby ruby-dev"
    elif [[ `which yum` ]]; then
      echo "yum -y install ruby-devel openssl-devel"
      echo "yum -y groupinstall "Development tools""
    fi;
    exit 1
  fi;
}

function create_client_conf {
  if [[ ! -f ${conf_path}/client.conf ]]; then
    cat > ${conf_path}/client.conf << EOF
    development_mode=false
    meta_table_ttl=7200000            # time to live (ms)
    meta_constants_ttl=7200000        # time to live (ms)
    meta_pretty_print_ttl=7200000     # time to live (ms)
    task_check_frequency=60           # check frequency for task status threads (seconds)
    tail_log_frequency=2              # assembly - frequency between requests (seconds)
    debug_task_frequency=5            # assembly - frequency between requests (seconds)
    auto_commit_changes=false         # autocommit for modules
    verbose_rest_calls=false          # logging of REST calls

    # if relative path is used we will use HOME + relative path, apsoluth path will override this
    module_location=component_modules
    service_location=service_modules
    EOF
  fi;
}

# installs gem if not already installed
function install_gem {
  gem_exists $1

  if $found_gem ; then
    echo "Gem $1 already installed."
  else
    # special case for geminabox
    if [[ $1 = "geminabox" ]]; then
      echo "[NOTE] Please ignore error output (if it happens) when installing geminabox since that is known issue, this will not affect installation process."
    fi

    echo "Installing gem $1 (please wait) ..."
    # install gem
    gem install $1 ${ruby_doc_args}
    # check installation
    gem_exists $1

    if $found_gem ; then
      echo "Gem $1 successfuly instaled!"
    else
      echo "There was a problem install gem $1, please review output and make sure that gem is in the same folder as install script."
      exit 0
    fi
  fi
}

# method will add ABH gem repository if not alredy added
function add_abh_gem_repository {
  sources_output=`gem sources | grep $abh_gem_repository`

  if [[ $sources_output = "" ]]; then
    # if there is no grep match there is no added repo
    output=`gem sources -a $abh_gem_repository`
  fi

}

function perform_uninstall {
  echo "Uninstalling DTK Client..."
  gem  uninstall -aIx dtk-client
  gem  uninstall -aIx dtk-common
  rm -rfv ${log_location}
  rm -fv ~/.dtkclient
}

# FUNCTIONS END

# BEGIN SCRIPT

# check for uninstall
if [[ $# == 1 ]] && [[ $1 == "uninstall" ]]; then
  uninstall="true"
  perform_uninstall
  exit 0
fi;

check_git_config

# check number of arguments
if [[ $# -ne 0 ]] && [[ $# -ne 6 ]]; then
        err_msg="ERROR: Invalid number of arguments \n";
        usage
        exit -1;
elif [[ $# == 6 ]]; then
  autoinstall="true"
elif [[ $# == 0 ]]; then
  autoinstall="false"
fi;

# install gems
echo "Welcome to DTK CLI Client installation."

# check pre-requsists
check_for_ruby
check_for_ruby_gems
check_native_gems
check_ruby_doc

echo "Wizard is installing necessery gems ..."

# install geminabox
# install_gem "geminabox"

# add ABH gem repository for dtk gems
add_abh_gem_repository

# install rdoc if document generation is selected
[[ !$ruby_doc_args ]] && install_gem rdoc
# install dtk gems
install_gem "dtk-common"                            
install_gem "dtk-client"

# check if there is already configuration
if [ -f ${conf_path} ]; then
  # file exists!
  REPLY=""
  read -p "Configuration ${conf_path} exists. Overwrite? [y/N]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    rm ${conf_path}
  else
    echo "DTL CLI Client will use existing configuration: ${conf_path}."
    echo "Exiting..."
    exit
  fi

fi

#create dtk dir in /etc
if [[ ! -d ${etc_location} ]]; then
  mkdir -p ${etc_location}
fi
if [[ ! -f ${etc_location}/shell_history ]]; then
  touch ${etc_location}/shell_history
fi


#: << 'END'
if [[ ${autoinstall} == "false" ]]; then
  # enter values
  echo "Please enter DTK server information."
  echo
  printf "Enter your username: "
  read username
  printf "Enter your password: "
  stty -echo                                      
  read password                                  
  stty echo               
  echo                                      
  printf "Enter server name: "
  read server
  #printf "Enter port number (default: 7000): "
 # read port
 # printf "Enable secure connection (default: true) [true,false]: "
 # read secure_connection

  while [[ $secure_connection != "true" ]] && [[ $secure_connection != "false" ]] && [[ $secure_connection != "" ]]; do
    printf "Invalid secure connection value. Possible values 'true' or 'false', or leave empty for default. "
    printf "Enable secure connection (default: true) : "
    read secure_connection
  done
  
 # printf "Enter secure connection port number (default: 7002): "
 # read secure_connection_port
elif [[ ${autoinstall} == "true" ]]; then
  username=$1
  password=$2
  server=$3
  port=$4
  secure_connection=$5
  secure_connection_port=$6
fi;

# set default values
if [[ $port == "" ]]; then
  port="80"
fi
if [[ $secure_connection == "" ]]; then
  secure_connection="true"
fi
if [[ $secure_connection_port == "" ]]; then
  secure_connection_port="443"
fi

# print to file
echo "username=$username"  >> ${conf_path}
echo "password=$password"  >> ${conf_path}
echo "server_host=$server" >> ${conf_path}
echo "server_port=$port"   >> ${conf_path}
echo "secure_connection=$secure_connection"           >> ${conf_path}
echo "secure_connection_server_port=$secure_connection_port" >> ${conf_path}

echo "Installation successfuly finished! Configuration saved to ${conf_path}."

# change the owner back to the original
chown -R ${SUDO_USER}:${SUDO_USER} ${etc_location}
# END SCRIPT


