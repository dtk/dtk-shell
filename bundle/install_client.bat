@echo off
REM This script clear terminal and starts installation process of dtk client.

REM GLOBAL VAR

set abh_gem_repository="http://abh:haris@ec2-54-247-191-95.eu-west-1.compute.amazonaws.com:3000/"
set log_file="%TMP%\dtk-client.log"

call :GEM_EXISTS 
call :RUBY_EXISTS

goto :EOF


:GEM_EXISTS
call :ProgInPath gem
IF "%PROG%" == "" (
  echo "Ruby gems are needed for installation, please install ruby gems before installing DTK CLI."
) else (
  echo. %PROG%
)
goto :EOF

:RUBY_EXISTS
call :ProgInPath ruby.exe
IF "%PROG%" == "" (
  echo "Ruby needed for installation, please install ruby before installing DTK CLI."
) else (
  echo. %PROG%
)
goto :EOF

:ProgInPath
set PROG=%~$PATH:1

goto :eof