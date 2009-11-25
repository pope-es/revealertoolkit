<?php

// This file contains a common interface to retrieve commands from 
// the framework, execute them and capture the results

require_once 'globals.php';
require_once 'cmdparse.php';



function execute_command($name){
	$cmd = command_by_name($name);
	//check if specified command exists
	if (!is_null($cmd)){
		$out = $cmd->execute();
		// //check if execution threw something
		// if (!is_null($out)){
			// //dump info to the per user temp file
		// }
		$out = "<pre>" . str_replace("\n","<br/>",$out) . "</pre>";
		return $out;
	}
}

$com = urldecode($_POST['name']);		//contains the name of the command
$OBJECT = urldecode($_POST['target']);	//contains the name of the object
$INPUT = urldecode($_POST['input']);	//contains user input, if any, or ''
$RESERVED = urldecode($_POST['extra']);	//contains extra input, if necessary, or ''
 
//get case number
ob_start();
$p = InitRVT();
$p->eval("use RVTbase::RVT_core;");
$CASE = $p->RVT_get_casenumber($OBJECT);
ob_end_clean();

$c = command_by_name($com);
echo "<script type=\"text/javascript\"> writeLOG(\"Command <b>" . $c->function . "(" . htmlspecialchars($c->proc_args()) . ")</b> completed!\"); </script>";

//at this point we've got all required data to proceed
echo execute_command($com);
echo '<br><br/>' . RESULTS_FOOTER_OK;

restore_error_handler();

?>