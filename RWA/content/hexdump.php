<?php
//
// jQuery Hex Dump PHP Connector
//
// Version 1.00
//
// Emili García Almazán
// 16 July 2009
//
// History:
//
// 1.00 - released
//
// Returns a stream of bytes formated in a table
//

function isInside($f,$n)
{
	return exec('echo "' . n . ' < `stat -c %s ' . $root . f . '`" | bc -l')
}


$_POST['file'] = urldecode($_POST['file']);
$_POST['offset'] = urldecode($_POST['offset']);
$_POST['length'] = urldecode($_POST['length']);

if( file_exists($root . $_POST['file']) && is_file($root . $_POST['file']) ) {
	
	echo "<div class=\"header\">Hex Dump viewer</div>"; //print the header
	echo "<tt><table>
			<thead>
				<tr>
					<th colspan = \"9\">
						<table style=\"width: 100%\">
							<tbody>
								<tr>
									<td><input type=\"image\" id=\"first\" /></td>
									<td><input type=\"image\" id=\"previous\" /></td>
									<td><input type=\"text\" id=\"topage\" /><input type=\"image\" id=\"go\" /></td>
									<td><input type=\"image\" id=\"next\" /></td>
									<td><input type=\"image\" id=\"last\" /></td>
								</tr>
							</tbody>
						</table>
					</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td>
						<table>
							<tbody>"
							

	echo "							</tbody>
						</table>
					</td>
				</tr>
			</tbody>
		</table></tt>"
	
	//PHP is unable to handle with files > 2GB
	//so we let the underlying OS to check whether the offset is out of bounds
	if (isInside($_POST['file'],$_POST['offset']))
	{
		
		
	}
	else
	{
		//go to the last page
		
	}

}

?>