<?php
//
// jQuery Timeline Dump
//
// Version 1.00
//
// Emili García Almazán
// 15 October 2009
//
// History:
//
// 1.00 - released
//
// Parses and formats timelines in a table
//

function dev($str){echo "$str     ";}

function customError($errno, $errstr)
{
	global $error_triggered;
	$error_triggered = $errstr;
	return true;
} 

function rsum($v, $w){ return $v+=$w; }

function specialEncode($txt,$high){ return strtr(htmlspecialchars($txt),array(''=>"<em class=\"$high\">",''=>'</em>')); }

function replaceSearch($needle, $haystack, $regexp){
	global $found;
	$haystack = rtrim($haystack,"\r\n");
	if ($regexp)
		$res = preg_replace("/($needle)/","$1",$haystack,-1,$f);
	else
		$res = str_replace($needle,"$needle",$haystack,$f);
	if ($res == '' && $haystack != '') $res = $haystack; //in case of an error
	$found+=$f;
	return $res;
}

function takeLines($f,$start,$length,$search,$regexp,$highlight,$headers){
	global $offset, $cnt, $found, $lastLineFound;

	$fid = fopen($f,"r");
	$cnt = 1;
	$max = 0;
	$lines = array();
	$founds = array();
	
	//if 'headers' is not specified, read the first line and return it at the beginning
	if ($headers == '') $headers = fgets($fid);
	$max++;
	
	//omit heading offset, but buffer it
	while($cnt < $start && !feof($fid))
	{
		if ($max == $length){
			$lines = array();
			array_push($lines,$headers); //restore the headers
			$founds = array();
			$max = 0;
		}
		$tmp = fgets($fid);
		if ($search != '') //for efficiency purposes, not really necessary
			$tmp = replaceSearch($search, $tmp, $regexp);
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
			array_push($lines,$headers); //restore the headers
			$founds = array();
			$cnt = 0;
			while($cnt < $length && !feof($fid))
			{
				$tmp = fgets($fid);
				if ($search != '')
					$tmp = replaceSearch($search, $tmp, $regexp);
				array_push($lines, $tmp);
				array_push($founds, $found);
				$cnt++;
			}
			$offset += $cnt; //to beat the substraction that will be done later
		}
	}else{
		if ($start == 1) array_push($lines,$headers); //restore the headers
		$founds = array();
		while(!feof($fid))
		{
			if ($max == $length){
				if (array_reduce($founds,"rsum") > 0) break;
				$lines = array();
				array_push($lines,$headers); //restore the headers
				$founds = array();
				$cnt = $max = 0;
			}
			array_push($lines, replaceSearch($search, fgets($fid), $regexp));
			array_push($founds, $found);
			$max++;
			$cnt++;
			$offset++;
		}
	}
	$offset -= ($cnt = count($lines)-1); //-1 because of the headers!!
	fclose($fid);
	$found = array_reduce($founds, "rsum");
	return $lines;
}

if (!function_exists('str_getcsv')) { 
    function str_getcsv($input, $delimiter = ",", $enclosure = '"', $escape = "\\") { 
        $fiveMBs = 5 * 1024 * 1024; 
        $fp = fopen("php://temp/maxmemory:$fiveMBs", 'r+'); 
        fputs($fp, $input); 
        rewind($fp); 
        $data = fgetcsv($fp, 1000, $delimiter, $enclosure); //  $escape only got added in 5.3.0 
        fclose($fp); 
        return $data; 
    } 
} 

function parseLines($lines,$start,$columns,$expression,$delimiter,$highlight){
	$newLines = array();
	$first = true;
	$newColumns = str_getcsv($columns);
	foreach($lines as $line){
		if (trim($line)=='') continue; //WARNING!
		if ($expression=='') //use the delimiter
			$chunks = str_getcsv($line,$delimiter);
		else{ //use the expression
			preg_match_all($expression,$line,$chunks,PREG_SET_ORDER);
			$chunks = $chunks[0];
			array_shift($chunks);
		}
		//render row header
		if ($first)
			$buffer="<th>#</th>";
		else
			$buffer = "<td class=\"rowHeader\">$start</td>";
		$col = 0;
		//render content cells
		foreach($chunks as $chunk){
			if (!(empty($newColumns) || in_array(++$col, $newColumns))) continue;
			//check if we matched the search term inside the chunk
			if (preg_match('/.*.+.*/',$chunk) > 0)
				$chunk = specialencode($chunk,$highlight);
			else
				$chunk = str_replace('','',$chunk); //search term was between two chunks
			$buffer = $buffer . ($first ? "<th>". trim($chunk) ."</th>" : "<td>$chunk</td>");
		}
		array_push($newLines,$buffer);
		if(!$first) $start+=1;
		$first = false;
	}
	return $newLines;
}

require_once 'globals.php';

set_error_handler("customError");

$_POST['file'] = $root . urldecode($_POST['file']);
$_POST['lineOffset'] = urldecode($_POST['lineOffset']);	//add 1 if 'headers' is not specified
$_POST['lines'] = urldecode($_POST['lines']);
$term = $_POST['search']; //search term
$_POST['direction'] = urldecode($_POST['direction']);
$_POST['regexp'] = urldecode($_POST['regexp']);
$_POST['highlight'] = urldecode($_POST['highlight']);
$_POST['headers'] = urldecode($_POST['headers']); 		//if == '' then the values of the first line are used
$_POST['columns'] = urldecode($_POST['columns']); 		//comma-separated zero-based indices of the displayed columns
//$_POST['expression'] = urldecode($_POST['expression']);	//regexp to perform preg_replace
$_POST['delimiter'] = urldecode($_POST['delimiter']);	//only valid if 'expression' is not specified

$offset = 1;		//counter to lineOffset
$cnt = 0;			//counter of returned lines
$found = 0;			//# of matches
$lastLineFound = 0;	//last #line in which a match was found
$error_triggered = '';
eval ("\$term = \"$term\";");

if( file_exists($_POST['file']) && is_file($_POST['file']) ) {

	if ($_POST['lineOffset'] < 1) $_POST['lineOffset'] = TIMELINEVIEW_DEFAULT_LINEOFFSET;
	if ($_POST['lines'] < 1) $_POST['lines'] = TIMELINEVIEW_DEFAULT_LINES;

	if ($_POST['delimiter'] == '' && $_POST['expression'] == '') $_POST['delimiter'] = ',';
	$lines = takeLines($_POST['file'], $_POST['lineOffset'], $_POST['lines'], $term, $_POST['regexp'], $_POST['highlight'], $_POST['headers']); //read the lines in the range
	$lines = parseLines($lines, $offset,$_POST['columns'], $_POST['expression'], $_POST['delimiter'], $_POST['highlight']);
	
	$base = '<td><input type="image" id="jquerytimelineview%s" class="btn%s" src="img/%s.png" title="%s" /></td>';
	
	echo '<input type="hidden" id="jquerytimelineviewoffset" value="'.$offset.'" />';
	echo '<input type="hidden" id="jquerytimelineviewcnt" value="'.$cnt.'" />';
	echo '<input type="hidden" id="jquerytimelineviewq" value="'.htmlspecialchars($term).'" />';
	echo '<input type="hidden" id="jquerytimelineviewregexp" value="'.($error_triggered != '' ? '0' : $_POST['regexp']).'" />';
	echo '<input type="hidden" id="jquerytimelineviewhighlight" value="' . $_POST['highlight'] . '" />';
	echo '<input type="hidden" id="jquerytimelineviewlastline" value="' . $lastLineFound . '" />';
	echo '<div style="text-align: right;margin: 30px 30px 0 30px"><table cellpadding="0" cellspacing="0"><tr>';
	//BEGIN SEARCH BOX
	//textbox
	echo '<td class="txtleft"></td>';
	echo '<td style="width: ' . ($term == '' || $error_triggered != '' ? '250' : '202') . 'px"><input type="text" id="jquerytimelineviewquery" class="txtcent" value="' . htmlspecialchars($term) . '" ' . ($term == ''  || $error_triggered != ''? '' : 'readonly="readonly"') . ' /></td>';
	//buttons
	if($term == '' || $error_triggered != ''){ //NOT in search mode
		echo sprintf($base,'search','cent','search',TIP_SEARCH);
		echo sprintf($base,'srchreg','right','search_regexp',TIP_SEARCH_REGEXP);
	}else{ //search mode
		echo sprintf($base,'up','cent','nav_up',TIP_PREV_MATCH);
		echo sprintf($base,'down','cent','nav_down',TIP_NEXT_MATCH);
		echo sprintf($base,'high','cent'.($_POST['highlight']=='highlight'?'pressed':''),'search_highlight',TIP_HIGHLIGHT);
		echo sprintf($base,'cancel','right','search_cancel',TIP_SEARCH_CANCEL);
	}
	echo '<td style="width: 5px"></td>';
	//END SEARCH BOX
	//BEGIN NAVIGATION BUTTONS
	echo sprintf($base,'first','left','nav_first',TIP_FIRST_PAGE);
	echo sprintf($base,'prev','cent','nav_prev',TIP_PREV_PAGE);
	echo '<td class="txtleft"></td>';
	echo '<td><input type="timeline" id="jquerytimelineviewindex" class="txtcent" value="' . (ceil($offset / $_POST['lines']) + ((($offset - 1) % $_POST['lines'] == 0) ? 0 : 1)) . '" style="font-weight: bold; timeline-align:right; width: 51px" /></td>';
	echo sprintf($base,'go','cent','nav_jump',TIP_JUMP_PAGE);
	echo sprintf($base,'next','cent','nav_next',TIP_NEXT_PAGE);
	echo sprintf($base,'last','right','nav_last',TIP_LAST_PAGE);
	//END NAVIGATION BUTTONS
	//BEGIN #LINES/PAGE
	echo '<td style="width: 15px"></td>';
	echo '<td class="lblleft"><img src="img/numlin.png" title="'.TIP_NUM_LIN.'" /></td>';
	echo '<td class="txtleft"></td>';
	echo '<td><input type="timeline" id="jquerytimelineviewlinnum" class="txtcent" value="' . $_POST['lines'] . '" style="font-weight: bold; width: 51px" /></td>';
	echo '<td class="edgeright"></td>';
	//END #LINES/PAGE
	//BEGIN LOADING ICON
	echo '</tr></table>';
	echo '<img id="jquerytimelineviewloading" src="img/loader.gif" style="position: relative; top: -25px;float:right;visibility:hidden" />';
	//END LOADING ICON
	echo '</div>';
	//BEGIN NOTIFICATION MESSAGES
	if ($error_triggered != ''){
		$error_triggered = strip_tags($error_triggered);
		//$error_triggered = ltrim(substr($error_triggered, strpos($error_triggered,':') + 1));
		echo '<table id="err" cellpadding="0" cellspacing="0" style="margin: 5px 30px"><tr><td class="errleft"><td class="err"><div class="err" alt="Error"></div><span id="errtxt" style="line-height: 16px">'.$error_triggered.'</span></td><td class="errright"></td></tr></table>';
	}else{
		if ($term != '' && $found == 0 && $_POST['direction'] != 0)
			echo '<table id="msg" cellpadding="0" cellspacing="0" style="margin: 5px 30px"><tr><td class="msgleft"><td class="msg"><div class="msg" alt="Notice"></div><span id="msgtxt" style="line-height: 16px">' . MSG_SEARCH_NOT_FOUND . '</span></td><td class="msgright"></td></tr></table>';
	}
	//END NOTIFICATION MESSAGES
	//BEGIN LINE TABLE
	echo '<div id="jqueryviewframe">';
	echo '<table class="jqueryTimelineView" cellspacing="0">';
	$alt = true;
	foreach($lines as $line)
		echo '<tr' . (($alt = !$alt) ? ' class="alt" ' : '') . ">$line</tr>"; //print each line
	echo '</table></div>';
	//END LINE TABLE
	echo "<script type=\"text/javascript\">function adapt(){document.getElementById('jqueryviewframe').style.height=(parseInt(document.getElementById('mainframe').style.height.replace(/px/,''))-120) + 'px';document.getElementById('jqueryviewframe').style.width=(parseInt(document.getElementById('mainframe').style.width.replace(/px/,''))-60) + 'px';} adapt();</script>";
}else{
	echo "<h1>The file '".$_POST['file']."' was not found!</h1>";
}

restore_error_handler();

?>