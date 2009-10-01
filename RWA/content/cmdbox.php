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


function isVisible($com){ return $com->icon != null; }

function isExpandable($com) { global $t; return true; }

function canExecute($com) { global $n; return true; }

$t = urldecode($_POST['type']);	//contains the type of the object
$n = urldecode($_POST['name']);	//contains the name of the object

$commands = array();

switch ($t){
	case 'morgue':	echo EMPTY_COMMAND_BOX;
					return;
	case 'case':	$commands = commands_by_object('case');
					$commands = array_filter($commands, "isVisible");
					$commands = array_filter($commands, "canExecute");
	case 'device':	$tmp = commands_by_object('device')
					$tmp = array_filter($tmp, "isVisible");
					$tmp = array_filter($tmp,"canExecute");
					$commands = $commands + $tmp;
	case 'disk':	$tmp = commands_by_object('disk')
					$tmp = array_filter($tmp, "isVisible");
					$tmp = array_filter($tmp,"canExecute");
					$commands = $commands + $tmp;
	case 'partition':$tmp = commands_by_object('partition')
					$tmp = array_filter($tmp, "isVisible");
					$tmp = array_filter($tmp,"canExecute");
					$commands = $commands + $tmp;
}

?>