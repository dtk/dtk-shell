@echo off
:: This script clear terminal and starts installation process of dtk client.

:: GLOBAL VAR

set abh_gem_repository="http://abh:haris@ec2-54-247-191-95.eu-west-1.compute.amazonaws.com:3000/"
set log_file="%APPDATA%\DTK\dtk-client.log"

echo "Welcome to DTK CLI Client installation!"

call :check_for_ruby
call :check_for_ruby_gems 
call :add_abh_gem_repository

::call gem install dtk-common --no-ri
call gem install dtk-client --no-ri --no-rdoc

call :create_config_log

goto :EOF

:: check if rubygems is avaialble on PATH
:check_for_ruby_gems
call :ProgInPath gem
IF "%PROG%" == "" (
  echo "Ruby gems are needed for installation, please install ruby gems before installing DTK CLI."
  call :halt 1
) else (
  echo. %PROG%
)
goto :EOF

:: check if ruby is avaialble on PATH
:check_for_ruby
call :ProgInPath ruby.exe
IF "%PROG%" == "" (
  echo "Ruby needed for installation, please install ruby before installing DTK CLI."
  call :halt 1
) else (
  echo. %PROG%
)
goto :EOF

:gem_exists
REM for /f "delims=" %a in ('gem list json ^| findstr /i "linux"') do @set output=%a 
REM echo %output%
REM TBD
goto :EOF

:: add the abh gem repository to the sources list
:add_abh_gem_repository
gem sources | findstr /i %abh_gem_repository% > %TMP%\gemsources.txt
set gemsources=
set /p gemsources= < %TMP%\gemsources.txt
IF "%gemsources%" == "" (
  echo "Adding DTK Gem Repository."
  gem sources -a %abh_gem_repository%
) else (
  echo. DTK Repo already added
)
goto :EOF


set port=7000
set secure_connection="true"
set secure_connection_server_port=7002

:: Create the configuration file in the home directory
:create_config_log
echo Please enter DTK server information.
set /P username=Enter your username: 
set /P password=Enter your password: 
set /P server=Enter server name: 
set /P port=Enter port number (default: 7000): 
set /P secure_connection=Enable secure connection (default: true) [true,false]: 

:while1
IF NOT "%secure_connection%" == "true" IF NOT "%secure_connection%" == "false" IF NOT "%secure_connection%" == "" (
	set secure_connection = ""
  echo "Invalid secure connection value. Possible values 'true' or 'false', or leave empty for default. "
  set /P secure_connection=Enable secure connection:  
  goto :while1
)

set /P secure_connection_server_port=Enter secure connection port number (default: 7002): 

::set filepath='%HOMEDRIVE%%HOMEPATH%\.dtkclient'

echo username=%username%  > %HOMEDRIVE%%HOMEPATH%\.dtkclient
echo password=%password%  >> %HOMEDRIVE%%HOMEPATH%\.dtkclient
echo server_host=%server% >> %HOMEDRIVE%%HOMEPATH%\.dtkclient
echo server_port=%port%   >> %HOMEDRIVE%%HOMEPATH%\.dtkclient
echo secure_connection=%secure_connection% >> %HOMEDRIVE%%HOMEPATH%\.dtkclient
echo secure_connection_server_port=%secure_connection_server_port%   >> %HOMEDRIVE%%HOMEPATH%\.dtkclient


if not exist %APPDATA%\DTK (
	mkdir "%APPDATA%\DTK
)
echo "" > %log_file%

::create dtk dir in user's home
if not exist %HOMEDRIVE%%HOMEPATH%\dtk (
  mkdir  %HOMEDRIVE%%HOMEPATH%\dtk
  )
if not exist %HOMEDRIVE%%HOMEPATH%\dtk\shell_history.dat (
  echo "" > %HOMEDRIVE%%HOMEPATH%\dtk\shell_history.dat
  )

goto :EOF

:: function for checking if executables are available in PATH
:ProgInPath
set PROG=%~$PATH:1
goto :EOF

:: Sets the errorlevel and stops the batch immediatly
:halt
call :__SetErrorLevel %1
call :__ErrorExit 2> nul
goto :EOF