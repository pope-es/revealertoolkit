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

function dev($str){echo "$str     ";}

function customError($errno, $errstr)
{
	global $error_triggered;
	$error_triggered = $errstr;
	return true;
} 

function rsum($v, $w)
{
    //$v += $w;
    //return $v;
	return $v+=$w;
}

function replaceSearch($needle, $haystack, $regexp, $highlight){
	global $found;
	if ($regexp)
		$res = preg_replace("/($needle)/","<em class=\"$highlight\">$1</em>",$haystack,-1,$f);
	else
		$res = str_replace($needle,"<em class=\"$highlight\">$needle</em>",$haystack,$f);
	if ($res == '' && $haystack != '') $res = $haystack; //in case of an error
	$found+=$f;
	return $res;
}

function takeLines($f,$start,$length,$search,$regexp,$highlight){
	global $offset, $cnt, $found, $lastLineFound;

	$fid = fopen($f,"r");
	$cnt = 1;
	$max = 0;
	$lines = array();
	$founds = array();
	
	//omit heading offset, but buffer it
	while($cnt < $start && !feof($fid))
	{
		if ($max == $length){
			$lines = array();
			$founds = array();
			$max = 0;
		}
		$tmp = fgets($fid);
		if ($search != '') //for efficiency purposes, not really necessary
			$tmp = replaceSearch($search, ($tmp), $regexp, $highlight);
		else
			$tmp = ($tmp);
		array_push($lines, $tmp);
		array_push($founds, $found);
		if ($found) $lastLineFound = $cnt;
		$found = 0;
		$max++;
		$cnt++;
		$offset++;
	}
	if ($_POST['direction'] != 1){
		//if not eof reached, take selected lines
		if(!feof($fid))
		{
			$lines = array();
			$founds = array();
			$cnt = 0;
			while($cnt < $length && !feof($fid))
			{
				$tmp = fgets($fid);
				if ($search != '')
					$tmp = replaceSearch($search, ($tmp), $regexp, $highlight);
				else
					$tmp = ($tmp);
				array_push($lines, $tmp);
				array_push($founds, $found);
				$cnt++;
			}
			$offset += $cnt; //to beat the substraction that will be done later
		}
	}else{
		$founds = array();
		while(!feof($fid))
		{
			if ($max == $length){
				if (array_reduce($founds,"rsum") > 0) break;
				$lines = array();
				$founds = array();
				$cnt = $max = 0;
			}
			array_push($lines, replaceSearch($search, (fgets($fid)), $regexp, $highlight));
			array_push($founds, $found);
			$max++;
			$cnt++;
			$offset++;
		}
	}
	$offset -= ($cnt = count($lines));
	fclose($fid);
	$found = array_reduce($founds, "rsum");
	return $lines;
}

require_once 'globals.php';

set_error_handler("customError");

$_POST['file'] = $root . urldecode($_POST['file']);
$_POST['lineOffset'] = urldecode($_POST['lineOffset']);
$_POST['lines'] = urldecode($_POST['lines']);
$term = $_POST['search']; //search term
$_POST['direction'] = urldecode($_POST['direction']);
$_POST['regexp'] = urldecode($_POST['regexp']);
$_POST['highlight'] = urldecode($_POST['highlight']);


$offset = 1;		//counter to lineOffset
$cnt = 0;			//counter of returned lines
$found = 0;			//# of matches
$lastLineFound = 0;	//last #line in which a match was found
$error_triggered = '';
eval ("\$term = \"$term\";");

if( file_exists($_POST['file']) && is_file($_POST['file']) ) {

	if ($_POST['lineOffset'] < 1) $_POST['lineOffset'] = TEXTVIEW_DEFAULT_LINEOFFSET;
	if ($_POST['lines'] < 1) $_POST['lines'] = TEXTVIEW_DEFAULT_LINES;

	$lines = takeLines($_POST['file'], $_POST['lineOffset'], $_POST['lines'], $term, $_POST['regexp'], $_POST['highlight']); //read the lines in the range	
	$base = '<td><input type="image" id="jquerytextview%s" class="btn%s" src="img/%s.png" title="%s" /></td>';
	
	//form??
	echo '<input type="hidden" id="jquerytextviewoffset" value="'.$offset.'" />';
	echo '<input type="hidden" id="jquerytextviewcnt" value="'.$cnt.'" />';
	echo '<input type="hidden" id="jquerytextviewq" value="'.$term.'" />';
	echo '<input type="hidden" id="jquerytextviewregexp" value="'.($error_triggered != '' ? '0' : $_POST['regexp']).'" />';
	echo '<input type="hidden" id="jquerytextviewhighlight" value="' . $_POST['highlight'] . '" />';
	echo '<input type="hidden" id="jquerytextviewlastline" value="' . $lastLineFound . '" />';
	echo '<div style="text-align: right;margin: 30px 30px 0 30px"><table cellpadding="0" cellspacing="0"><tr>';
	//search box
	echo '<td class="txtleft"></td>';
	echo '<td style="width: ' . ($term == '' || $error_triggered != '' ? '250' : '202') . 'px"><input type="text" id="jquerytextviewquery" class="txtcent" value="' . $term . '" ' . ($term == ''  || $error_triggered != ''? '' : 'readonly="readonly"') . ' /></td>';
	echo '<td class="txtright"></td>';
	if($term == '' || $error_triggered != ''){
		echo sprintf($base,'search','cent','search',TIP_SEARCH);
		echo sprintf($base,'srchreg','right','search_regexp',TIP_SEARCH_REGEXP);
	}else{
		echo sprintf($base,'up','cent','nav_up',TIP_PREV_MATCH);
		echo sprintf($base,'down','cent','nav_down',TIP_NEXT_MATCH);
		echo sprintf($base,'high','cent'.($_POST['highlight']=='highlight'?'pressed':''),'search_highlight',TIP_HIGHLIGHT);
		echo sprintf($base,'cancel','right','search_cancel',TIP_SEARCH_CANCEL);
	}
	echo '<td style="width: 5px"></td>';
	//navigation buttons
	echo sprintf($base,'first','left','nav_first',TIP_FIRST_PAGE);
	echo sprintf($base,'prev','cent','nav_prev',TIP_PREV_PAGE);
	echo '<td class="txtleft"></td>';
	echo '<td><input type="text" id="jquerytextviewindex" class="txtcent" value="' . (ceil($offset / $_POST['lines']) + ((($offset - 1) % $_POST['lines'] == 0) ? 0 : 1)) . '" style="font-weight: bold; text-align:right; width: 51px" /></td>';
	echo '<td class="txtright"></td>';
	echo sprintf($base,'go','cent','nav_jump',TIP_JUMP_PAGE);
	echo sprintf($base,'next','cent','nav_next',TIP_NEXT_PAGE);
	echo sprintf($base,'last','right','nav_last',TIP_LAST_PAGE);
	echo '</tr></table></div>';
	//messages
	if ($error_triggered != ''){
		$error_triggered = strip_tags($error_triggered);
		//$error_triggered = ltrim(substr($error_triggered, strpos($error_triggered,':') + 1));
		echo '<table id="err" cellpadding="0" cellspacing="0" style="margin: 5px 30px"><tr><td class="errleft"><td class="err"><div class="err"></div><span id="errtxt" style="line-height: 16px">'.$error_triggered.'</span></td><td class="errright"></td></tr></table>';
	}else{
		if ($term != '' && $found == 0 && $_POST['direction'] != 0)
			echo '<table id="msg" cellpadding="0" cellspacing="0" style="margin: 5px 30px"><tr><td class="msgleft"><td class="msg"><div class="msg"></div><span id="msgtxt" style="line-height: 16px">' . MSG_SEARCH_NOT_FOUND . '</span></td><td class="msgright"></td></tr></table>';
	}
	//list of lines
	echo '<div id="jquerytextviewframe">';
	echo "<ol class=\"jqueryTextView\" start=\"$offset\">";
	$alt = true;
	foreach($lines as $line)
		echo '<li' . (($alt = !$alt) ? ' class="alt" ' : '') . "><pre>$line</pre></li>"; //print each line
	echo '</ol></div>';
	echo "<script type=\"text/javascript\">function adapt(){document.getElementById('jquerytextviewframe').style.height=(parseInt(document.getElementById('mainframe').style.height.replace(/px/,''))-120) + 'px';document.getElementById('jquerytextviewframe').style.width=(parseInt(document.getElementById('mainframe').style.width.replace(/px/,''))-60) + 'px';} adapt();</script>";
}

restore_error_handler();

?>