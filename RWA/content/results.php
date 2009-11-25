<?php

require_once 'globals.php';
require_once 'cmdparse.php';

$_POST['name'] = urldecode($_POST['name']);

echo '<table style="margin: 30px 30px 0"><tr><td><img id="jqueryresultloading" src="img/loader.gif" /></td>';
$c = command_by_name($_POST['name']);
echo '<td><img id="commandicon" src="img/' . $c->icon . '" style="float:left" /></td>';
echo '<td style="font-size:13pt;font-weight:bold">' . $c->alias . '</td></tr></table>';
echo '<p style="margin-left: 30px; margin-bottom: -5px;">Results</p>';
echo '<div id="jqueryviewframe" style="padding: 5px; font-size: 10pt">';

if ($c->args != null && in_array('INPUT',$c->args))
{
	//necesitamos más información del usuario
	echo "<label for=\"txtInput\">" . USER_INPUT_LABEL . "</label>
		  <input type=\"text\" id=\"txtInput\" style=\"margin-right: 10px; margin-top: 15px; width: 90%;\" value=\"\" />
		  <br />
		  <input type=\"button\" id=\"btnInput\" onclick=\"this.enabled='false'; $.post('content/cmdexec.php', { name:'".$_POST['name']."',target:'".$_POST['target']."',input: document.getElementById('txtInput').value ,extra:'".$_POST['extra']."' }, function(data) { $('#jqueryviewframe').html(data); document.getElementById('jqueryresultloading').src = 'img/check.png'; });\" value=\"" . USER_INPUT_SEND . "\" />
		  </div>";
}else{
	echo "</div>";
	//podemos ejecutar el comando
	echo "<script type=\"text/javascript\"> $.post('content/cmdexec.php', { name:'".$_POST['name']."',target:'".$_POST['target']."',input:'".$_POST['input']."',extra:'".$_POST['extra']."' }, function(data) { $('#jqueryviewframe').html(data); document.getElementById('jqueryresultloading').src = 'img/check.png'; }); </script>";
}
echo "<script type=\"text/javascript\">function adapt(){document.getElementById('jqueryviewframe').style.height=(parseInt(document.getElementById('mainframe').style.height.replace(/px/,''))-157) + 'px';document.getElementById('jqueryviewframe').style.width=(parseInt(document.getElementById('mainframe').style.width.replace(/px/,''))-60) + 'px';} adapt();</script>";
?>