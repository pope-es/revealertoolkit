<?php
//
// jQuery Text Dump PHP Connector
//
// Version 1.00
//
// Emili García Almazán
// 17 July 2009
//
// History:
//
// 1.00 - released
//
// Returns a stream of text formated in a OL
//

function getLineCount($f)
{
	//PHP-only sentence:
	return count( file( $root . $f ) );
	//NOTE: if performance issues are observed we could rely in the OS by using the following:
	//return exec('echo "' . n . ' <= `wc -l ' . $root . $f . ' | cut -f 1 -d " "');
}

function isInside($f,$n)
{
	return ( getLineCount($f) <= $n );
}

function takeLines($f,$start,$length)
{

}

$_POST['file'] = urldecode($_POST['file']);
$_POST['lineOffset'] = urldecode($_POST['lineOffset']);
$_POST['lines'] = urldecode($_POST['lines']);
$title = urldecode($_POST['title']);


if( file_exists($root . $_POST['file']) && is_file($root . $_POST['file']) ) {

	if ($_POST['lineOffset'] < 1) $_POST['lineOffset'] = 1;	//default
	if ($_POST['lines'] < 1) $_POST['lines'] = 25;			//default

	echo "<div class=\"header\">$title</div>"; //print the header

	if (isInside($_POST['file'],$_POST['offset']))
	{
		$lines = explode("\n", takeLines($_POST['file'], $_POST['lineOffset'], $_POST['lines']));
	}
	else
	{
		//$lines = last page
	}
	echo "<div style=\"list-style-type: decimal; max-height: 80%\">";
	
	echo "</div>";
}

?>