<?php

// This file contains the routines needed to retrieve the list
// of commands (correctly formatted in HTML) when the casetree
// requires them to display in the command box

// REMEMBER:
// - Commands with a null icon are internal -> NOT displayed -> NOT returned
// - Entity expansion is an universal fact, so commands are returned on every supported entity
// - Commands with dependency limitations will be grayed out
// - Commands that cannot be executed more than once will be grayed out whether they've already executed
// - Commands that are currently executing will be marked with an animated icon/grayed out

require_once 'globals.php';
require_once 'cmdparse.php';

function comFormat($accum, $com){
	if ($accum=='0') $accum='';
	$old = array('{id}', '{alias}', '{class}', '{icon}', '{disabled}', '{lbclass}');
	$d = false;//isExecuting($com);
	$new = array($com->name, $com->alias, $d ? 'disabled' : '', $com->icon, $d ? 'disabled' : '', 'command');
	return $accum . str_replace($old, $new, COMMAND_TEMPLATE);
}

function isVisible($com){ return $com->icon != null; }

function canExecute($com) { return $com->can_execute(); }

function isExecuting ($com) { global $OBJECT; return $com->isExecuted($OBJECT) == RVT_LOG_WORKING; }

function getCommands($obj,$arr){
	$tmp = commands_by_object($obj);
	$tmp = array_filter($tmp, "isVisible");
	$tmp = array_filter($tmp,"canExecute");
	foreach($tmp as $k=>$v)
		if (!in_array($v,$arr)) array_push($arr,$v);
	return $arr;
}

$OBJECT = urldecode($_POST['name']);	//contains the name of the object

if($OBJECT == 'morgue'){
	echo EMPTY_COMMAND_BOX;
	return;
}

//check object type
ob_start();
$p = InitRVT();
$p->eval("use RVTbase::RVT_core;");
$t = strtolower($p->RVT_check_format($OBJECT));
$CASE = $p->RVT_get_casenumber($OBJECT);
ob_end_clean();

$commands = array();

switch ($t){
	case 'case code':
	case 'case number':	$commands = getCommands('case',$commands);
	case 'device':		$commands = getCommands('device',$commands);
	case 'disk':		$commands = getCommands('disk',$commands);
	case 'partition':	$commands = getCommands('partition',$commands);
}
//at this point we have the available commands
//let's format them
$result = array_reduce($commands,'comFormat',"");

echo $result;

?>