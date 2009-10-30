<?php

// This file contains the routines needed to retrieve the list
// of commands (correctly formatted in HTML) when the filetree
// requires them to display in the command box

// REMEMBER:
// - Commands with a null icon are internal -> NOT displayed -> NOT returned
// - Commands with entity expansion are also returned on every supported entity
// - Commands with dependency limitations will be grayed out
// - Commands that cannot be executed more than once will be grayed out whether they've already executed
// - Commands that are currently executing will be marked with an animated icon/grayed out

require_once 'globals.php';
require_once 'cmdparse.php';

function comFormat($accum, $com){
	if ($accum=='0') $accum='';
	$old = array('{id}', '{alias}', '{class}', '{icon}', '{disabled}', '{lbclass}');
	$new = array($com->name, $com->alias, '', $com->icon, '', 'command');
	return $accum . str_replace($old, $new, COMMAND_TEMPLATE);
}

function isVisible($com){ return $com->icon != null; }

function isExpandable($com) { global $t; return true; }

function canExecute($com) { global $n; return true; }

function getCommands($obj,$arr){
	$tmp = commands_by_object($obj);
	$tmp = array_filter($tmp, "isVisible");
	$tmp = array_filter($tmp,"canExecute");
	foreach($tmp as $k=>$v){
		//print_r($v);
		if (!in_array($v,$arr)) array_push($arr,$v);
	}
	return $arr;
}

$n = urldecode($_POST['name']);	//contains the name of the object

if($n == 'morgue'){
	echo EMPTY_COMMAND_BOX;
	return;
}

//check the type of the object
ob_start();
$p = InitRVT();
$p->eval("use RVTbase::RVT_core;");
$t = $p->RVT_check_format($n);
ob_end_clean();

$commands = array();

switch ($t){
	case 'partition':	$commands = getCommands('partition',$commands);
	//print_r($commands);
	//print('<br/>');
	case 'disk':		$commands = getCommands('disk',$commands);
	//print_r($commands);
	//print('<br/>');
	case 'device':		$commands = getCommands('device',$commands);
	//print_r($commands);
	//print('<br/>');
	case 'case code':
	case 'case number':	$commands = getCommands('case',$commands);
	//print_r($commands);
	//print('<br/>');
}
//at this point we have the available commands
//let's format them
$result = array_reduce($commands,'comFormat',"");

echo $result;

?>