<?php 
require_once './content/globals.php';
echo '<?xml version="1.0" encoding="UTF-8" ?>' ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <link href="css/jquery.filetree.css" rel="Stylesheet" type="text/css" media="screen" />
    <link href="css/jquery.textview.css" rel="Stylesheet" type="text/css" media="screen" />
	<link href="css/jquery.timelineview.css" rel="Stylesheet" type="text/css" media="screen" />
    <link href="css/rwa.css" rel="stylesheet" type="text/css" media="screen" />
    <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
    <meta http-equiv="Encoding" content="" />
    <meta http-equiv="cache-control" content="no-cache" />
    <meta http-equiv="X-UA-Compatible" content="IE=Edge" />

    <script type="text/javascript" src="js/jquery.js"></script>
    <script type="text/javascript" src="js/jquery-ui.js"></script>
    <script type="text/javascript" src="js/jquery.layout.js"></script>
    <script type="text/javascript" src="js/jquery.casetree.js"></script>
	<script type="text/javascript" src="js/jquery.filetree.js"></script>
    <script type="text/javascript" src="js/jquery.textview.js"></script>
	<script type="text/javascript" src="js/jquery.timelineview.js"></script>
	
    <script type="text/javascript">
	
		function resize_trees(){
			var Val = (($('.ui-layout-west')[0].clientHeight - 78) / 3)+'px';
			if ($('#resultstree').length > 0){
				$('#resultstree').parent()[0].style.height = Val;
				$('#resultstree').parent()[0].style.width = $('.ui-layout-west')[0].clientWidth - 5;
			}
			$('#casetree').parent()[0].style.height = Val;
			$('#casetree').parent()[0].style.width = $('.ui-layout-west')[0].clientWidth - 5
			$('#commands')[0].style.height = Val;
		}

		function clearLOG() { if (confirm("<?php echo ALERT_CLEAR_LOG ?>")) $('#LOG').empty(); }

		function writeLOG(msg){
			var d = new Date()
			$('#LOG').prepend('<span><b>['+ d.getDate() +'/'+ (d.getMonth()+1) +'/'+ d.getFullYear() + ' ' + d.toLocaleTimeString() + ']</b>: ' + msg + '</span><br/>');
			if($('#LOG SPAN').length > 10) $('#LOG > *:gt(<?php echo MAX_LOG_ENTRIES*2 ?>)').remove();
		}

		function startTree(){
			writeLOG('Building Navigation Tree...');
			$('#selectedobject')[0].value = '';
			$('#casetree').caseTree({root: 'morgue'}, function(f) { 
						$('#selectedobject')[0].value = f;
						refreshResultsTree();
						loadCommands(f);
					});
			loadCommands('morgue');
			refreshResultsTree();
			writeLOG('Finished building Navigation Tree!');
		}

		function starttextViewer() { $('#contentheader').html('<?php echo TEXT_VIEWER ?>'); }

		function starttimelineViewer() { $('#contentheader').html('<?php echo TIMELINE_VIEWER ?>'); }
		
		function startResultsPage(page){
			$('#contentheader').html('<?php echo RESULTS_PAGE ?>');
			$('.contentplaceholder').html(page);
		}
		
		function refreshResultsTree(){
			var folder = $('#selectedobject')[0].value;
			writeLOG('Refreshing Results Tree...');
			$('#resultstree').fileTree({root: folder}, fileSelected);
			writeLOG('Finished refreshing Results Tree!');
		}
		
        $(document).ready( function() {
			writeLOG('Building layout...');
			$('body').layout({ 
                applyDefaultStyles: true,
                north__applyDefaultStyles: false,
                north__resizable: false,
                north__border: 0,
                north__spacing_open: 0,
                north__size: 65,
                south__initClosed: true,
                south__size: 155,
                west__resizable: true,
                west__border: 4,
                west__maxSize: 300,
				center__onresize: "adapt",
				west__onresize: "resize_trees"
            });
			resize_trees();
			writeLOG('Finished building layout!');
            startTree();
            writeLOG('<span style="color:#00A000">Finished starting up!</span> RWA is ready.');
        });
    </script>

    <title><?php echo PAGE_TITLE ?></title>
</head>
<body>
    <div class="ui-layout-center init" style="overflow: hidden" id="mainframe">
        <div id="contentheader" class="header"></div>
        <div class="contentplaceholder"></div>
    </div>
    <div class="ui-layout-north" style="vertical-align: middle">
        <img src="img/logo.jpg" alt="Revealer Toolkit" style="padding: 8px; vertical-align: middle" />
		<span class="title"><?php echo TITLE ?></span>
    </div>
    <div class="ui-layout-west">
	<table style="width:100%" cellpadding="0" cellspacing="0">
		<tr>
			<td>
				<div class="header"><?php echo NAVIGATION ?><div title="<?php echo REFRESH_TREE ?>" class="headerbutton reftree" id="reftree"></div></div>
				<input type="hidden" id="selectedobject" />
				<div style="overflow-y: auto; overflow-x: hidden; padding: 2px">
					<div id="casetree">
					</div>
				</div>
			</td>
		</tr>
		<tr>
			<td>
				<div class="header"><?php echo COMMANDS ?></div>
				<div id="commands">
					<?php echo EMPTY_COMMAND_BOX ?>
				</div>
			</td>
		</tr>
		<tr>
			<td>
				<div class="header"><?php echo RESULTS ?><div title="<?php echo REFRESH_TREE ?>" class="headerbutton reftree" id="refresults"></div></div>
				<div style="overflow-y: auto; overflow-x: hidden; padding: 2px">
					<?php echo EMPTY_RESULTS_TREE ?>
					<div id="resultstree" style="display: none">
					</div>
				</div>
			</td>
		</tr>
	</table>
    </div>
    <div class="ui-layout-south">
        <div class="header"><?php echo LOG ?><div title="<?php echo CLEAR_LOG ?>" class="headerbutton clearlog" onclick="clearLOG()" ></div></div>
        <div>
		<div id="LOG" style="max-height: 130px;overflow:auto"></div>
        </div>
    </div>
</body>
</html>