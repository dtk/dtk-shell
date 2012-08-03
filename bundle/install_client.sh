#!bin/bash
# This script clear terminal and starts installation process of dtk client.

# FUNCTIONS BEGIN

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
    echo "Ruby needed for installation, please install ruby before installing DTK CLI."
    exit 0
  fi
}

# are there rubygems?
function check_for_ruby_gems {
  gem_output=`which gem | grep gem`
  if [[ $gem_output = "" ]];then
    echo "Ruby gems are needed for installation, please install ruby gems before installing DTK CLI."
    exit 0
  fi
}

# installs gem if not already installed
function install_gem {
  gem_exists $1
  if $found_gem ; then
    echo "Gem $1 already installed."
  else
    echo "Installing gem $1 (please wait) ..."
    # install gem
    gem install $1
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

# FUNCTIONS END

# BEGIN SCRIPT
clear


# install gems
echo "Welcome to DTK CLI Client installation!"

# check pre-requsists
check_for_ruby
check_for_ruby_gems

echo "Wizard is installing necessery gems ..."

install_gem "dtk-common"                            
install_gem "dtk-client"

#: << 'END'
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
printf "Enter port number (default: 7000): "
read port

# set default values
if [ $port="" ]; then
  port="7000"
fi


home_dir=`cd ~ && pwd`
file_path="$home_dir/.dtkclient2"

# check if there is already configuration
if [ -f $file_path ]; then
  # file exists!
  choice=""
  while [[ $choice != "y" ]] && [[ $choice != "n" ]]; do
    printf "Configuration $file_path exists! Overwrite (y/n): "
    read choice
  done

  if [ $choice = "n" ]; then
    # if choice is "no" then exit installation script
    echo "Exiting, DTL CLI Client will use existing configuration $file_path."
    exit
  else
    # if choice is "yes" then delete previous configuration
    rm $file_path
  fi
fi

# print to file
echo "username=$username"  >> $file_path
echo "password=$password"  >> $file_path
echo "server_host=$server" >> $file_path
echo "server_port=$port"   >> $file_path

# check if gem exist if not install them
#END


echo "Installation successfuly finished! Configuration saved to $file_path."
# END SCRIPT


