@echo off
:: This script clear terminal and starts installation process of dtk client.

:: GLOBAL VAR

set abh_gem_repository="http://abh:haris@ec2-176-34-95-163.eu-west-1.compute.amazonaws.com:3000/"
set log_file="%TMP%\dtk-client.log"

echo "Welcome to DTK CLI Client installation!"

call :check_for_ruby
call :check_for_ruby_gems 
call :add_abh_gem_repository

gem install dtk-common
gem install dtk-client

goto :EOF


:check_for_ruby_gems
call :ProgInPath gem
IF "%PROG%" == "" (
  echo "Ruby gems are needed for installation, please install ruby gems before installing DTK CLI."
  call :halt 1
) else (
  echo. %PROG%
)
goto :EOF

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

:ProgInPath
set PROG=%~$PATH:1
goto :EOF

:: Sets the errorlevel and stops the batch immediatly
:halt
call :__SetErrorLevel %1
call :__ErrorExit 2> nul
goto :eof