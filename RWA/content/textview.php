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

function takeLines($f,$start,$length)
{
	global $offset, $cnt;

	$fid = fopen($f,"r");
	$cnt = 1;
	$lines = array();
	while($cnt < $start && !feof($fid))
	{
		array_push($lines, fgets($fid));
		if (count($lines) > $length) array_shift($lines);
		$cnt++;
		$offset++;
	}
	$cnt--;
	if(!feof($fid))
	{	
		$lines = array();
		$cnt = 0;
		while($cnt < $length && !feof($fid))
		{
			array_push($lines, fgets($fid));
			$cnt++;
		}
	}
	else
	{
		if ($cnt > $length)
		{
			$offset -= $length;
			$cnt = $length;
		}
	}
	fclose($fid);
	return $lines;
}

$_POST['file'] = $root . urldecode($_POST['file']);
$_POST['lineOffset'] = urldecode($_POST['lineOffset']);
$_POST['lines'] = urldecode($_POST['lines']);

$offset = 1;
$cnt = 0;

if( file_exists($_POST['file']) && is_file($_POST['file']) ) {

	if ($_POST['lineOffset'] < 1) $_POST['lineOffset'] = 1;	//default
	if ($_POST['lines'] < 1) $_POST['lines'] = 20;			//default

	$lines = takeLines($_POST['file'], $_POST['lineOffset'], $_POST['lines']); //read the lines in the range

	echo "<div style=\"list-style-type: decimal; margin: 0 30px\">";
	echo "<input type=\"hidden\" id=\"jquerytextviewoffset\" value=\"$offset\" />";
	echo "<input type=\"hidden\" id=\"jquerytextviewcnt\" value=\"$cnt\" />";
	echo "<input type=\"image\" id=\"jquerytextviewfirst\" class=\"btnleft\" src=\"img/nav_first.png\" />";
	echo "<input type=\"image\" id=\"jquerytextviewprev\" class=\"btncent\" src=\"img/nav_prev.png\" />";
	echo "<input type=\"text\" id=\"jquerytextviewindex\" class=\"text\" value=\"1\" />";
	echo "<input type=\"image\" id=\"jquerytextviewgo\" class=\"btncent\" src=\"img/nav_jump.png\" />";
	echo "<input type=\"image\" id=\"jquerytextviewnext\" class=\"btncent\" src=\"img/nav_next.png\" />";
	echo "<input type=\"image\" id=\"jquerytextviewlast\" class=\"btnright\" src=\"img/nav_last.png\" />";
	echo "<ol class=\"jqueryTextView\" start=\"$offset\">"; //list start tag
	$alt = true;
	foreach($lines as $line)
		echo "<li" . (($alt = !$alt) ? " class=\"alt\" " : "") . "><pre>" . htmlspecialchars($line) . "</pre></li>"; //print each line
	echo "</ol>"; //list end tag
	echo "</div>";
}

?>