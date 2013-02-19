

IF NOT "tDrue" == "true" if NOT "fDa" == "fa" if NOT "bD" == "b" (
	echo "sadfads"
	echo "jos nest"
)


set /P secure_connection=Enable secure connection (default: true) [true,false]: 

	IF NOT %secure_connection% == "true" IF NOT %secure_connection% == "false" IF NOT %secure_connection% == "" (
	  echo "u ifu"
	  echo "Invalid secure connection value. Possible values 'true' or 'false', or leave empty for default. "
	  set /P secure_connection=Enable secure connection:  
	)
		
