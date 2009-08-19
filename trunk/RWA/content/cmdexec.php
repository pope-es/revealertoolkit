<?php

// This file contains a common interface to retrieve commands from 
// the framework and to execute them and capture the results

require_once 'globals.php';
require_once 'cmdparse.php';

function execute_command($name){
	$cmd = command_by_name($name);
	//check if specified command exists
	if (!is_null($cmd)){
		$out = $cmd->execute();
		//check if execution threw something
		if (!is_null($out)){
			//dump info to the per user temp file
			
		}
	}
}

?>