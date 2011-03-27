<?php

// This file contains a common interface to retrieve commands from 
// the framework, execute them and capture the results

require_once 'globals.php';
require_once 'cmdparse.php';



function customError($errno,$errstr){
	global $res_err;
	$res_err .= "<br/><div class=\"err\" alt=\"Error\" /><b>ERR #$errno</b>: $errstr";
}

function execute_command($cmd){
	global $OBJECT,$res_err;

	//check if specified command exists
	$out = '';
	if (!is_null($cmd)){
		$tmp = $OBJECT;
		if (!is_null($cmd->objects)){
			foreach($cmd->objects as $obj){
				if (expand_object($OBJECT, $obj) != 0){
					foreach(expand_object($OBJECT, $obj) as $sub){
						$OBJECT = $sub;
						try {
							$out .= "<pre>" . str_replace("\n","<br/>",$cmd->execute()) . "</pre>";
						}
						catch (PerlException $exception) {
							$res_err .= '<br/><div class="err" alt="Error" /><b>PERL EXCEPTION</b>:' . $exception->getMessage() ;
						}
						$OBJECT = $tmp;
					}
					$out .= "<br/><br/>";
				}else{
					$out .= "<b>" . COMMAND_NOT_APPLICABLE . "</b><br/><br/>";
				}
			}
		}else{
			$out .= "<pre>" . str_replace("\n","<br/>",$cmd->execute()) . "</pre>";
		}
		return $out;
	}
	
}

$com = urldecode($_POST['name']);		//contains the name of the command
$OBJECT = urldecode($_POST['target']);	//contains the name of the object
$INPUT = urldecode($_POST['input']);	//contains user input, if any, or ''
$RESERVED = urldecode($_POST['extra']);	//contains extra input, if necessary, or ''

$res_err = '';
set_error_handler("customError"); 

//get case number
ob_start();
$p = InitRVT();
$p->eval("use RVTbase::RVT_core;");
$CASE = $p->RVT_get_casenumber($OBJECT);
ob_end_clean();

$c = command_by_name($com);
$comlin = $c->function . "(" . htmlspecialchars($c->proc_args()) . ")";
$lastarg = '';
if (count($c->args) > 0) eval('$lastarg =  $' . $c->args[count($c->args)-1] . ';');
log_execution($comlin,$lastarg,RVT_LOG_WORKING);

echo "<script type=\"text/javascript\"> writeLOG(\"Command <b>$comlin</b> completed!\"); </script>";
//at this point we've got all required data to proceed
echo execute_command($c);

if ($res_err == ''){
	echo RESULTS_FOOTER_OK;
	log_execution($comlin,$lastarg,RVT_LOG_SUCCESS);
}else{
	echo RESULTS_FOOTER_KO . "<br/>" . $res_err;
	log_execution($comlin,$lastarg,RVT_LOG_FAILURE);
}
echo "<script type=\"text/javascript\"> document.getElementById('jqueryresultloading').src = 'img/" . ($res_err==''?"check":"cross") . ".png';  </script>";

restore_error_handler();

?>