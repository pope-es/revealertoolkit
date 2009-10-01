<?php
//
// jQuery File Tree PHP Connector
//
// Version 1.01
//
// Cory S.N. LaViska
// A Beautiful Site (http://abeautifulsite.net/)
// 24 March 2008
//
// History:
//
// 1.01 - updated to work with foreign characters in directory/file names (12 April 2008)
// 1.00 - released (24 March 2008)
//
// Output a list of files for jQuery File Tree
//

function add_cases($text, $pattern){
	global $children;
	if (preg_match_all($pattern, $text, $matches) > 0)
		$children = array_combine($matches[1],$matches[2]);
}

function add_devices($text, $pattern){
	global $children;
	if(preg_match_all($pattern, $text, $matches) > 0)
	{
		$i = 0; $max = count($matches[0]); $added = array();
		//walk across the arrays and fill the children
		while ($i < $max ){
			if ($matches[4][$i]==$_POST['dir'] && !in_array($matches[3][$i], $added)){
				$children[$matches[3][$i]] = DEVICE . ' ' . $matches[5][$i]; //return entry
				$added[]=$matches[3][$i]; //avoid duplicating device entries
			}
			$i++;
		}
	}
}

function add_disks($text, $pattern){
	global $children;
	if(preg_match_all($pattern, $text, $matches) > 0)
	{
		$i = 0; $max = count($matches[0]); $added = array();
		//walk across the arrays and fill the children
		while ($i < $max ){
			if ($matches[3][$i]==$_POST['dir'] && !in_array($matches[2][$i], $added)){
				$children[$matches[2][$i]] = DISK . ' ' . $matches[6][$i]; //return entry
				$added[]=$matches[2][$i]; //avoid duplicating device entries
			}
			$i++;
		}
	}
}

function add_partitions($text, $pattern){
	global $children;
	if(preg_match_all($pattern, $text, $matches) > 0)
	{
		$i = 0; $max = count($matches[0]);
		//sort results
		sort($matches[1]);
		//walk across the array and fill the children
		while ($i < $max ){
			$children[$_POST['dir'] . '-p' . $matches[1][$i]] = PARTITION . ' ' . $matches[1][$i]; //return entry
			$i++;
		}
	}
}


require_once 'globals.php';
require_once 'cmdparse.php';

$_POST['dir'] = urldecode($_POST['dir']);

$children = array();
$class = 'disk';
//decide what we'll return
if ($_POST['dir'] == 'morgue'){//init root
	//list cases
	$c = command_by_name('case_list');
	if ($c != null)
	{
		//autofill names & rels
		add_cases($c->execute(),$c->standard);
		$class = 'case collapsed';
	}
}else{
	switch (substr_count($_POST['dir'] , '-')){
		case 0: //clicked case
			//list devices
			$c = command_by_name('images_list');
			if ($c != null)
			{
				add_devices($c->execute(),$c->standard);
				$class = 'device collapsed';
			}
			break;
		case 1: //clicked device
			//list disks
			$c = command_by_name('images_list');
			if ($c != null)
			{
				add_disks($c->execute(),$c->standard);
				$class = 'disk collapsed';
			}
			break;
		case 2: //clicked disk
			//list partitions
			$c = command_by_name('images_partition_table');
			if ($c != null)
			{
				global $OBJECT;
				$OBJECT = $_POST['dir'];
				add_partitions($c->execute(),$c->standard);
				$class = 'partition';
			}
			break;
	}
}

//build the list
if (count($children) > 0){
	echo "<ul class=\"jqueryFileTree\" style=\"display: none;\">";
	reset($children);
	while ($child = current($children)) {
		echo "<li class=\"$class\"><a href=\"#\" rel=\"" . key($children) . "\">$child</a></li>";// [" . key($children) . "]</a></li>";
		next($children);
	}
	echo "</ul>";
}

?>