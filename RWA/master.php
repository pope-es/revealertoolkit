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
    <script type="text/javascript" src="js/jquery.filetree.js"></script>
    <script type="text/javascript" src="js/jquery.textview.js"></script>
	<script type="text/javascript" src="js/jquery.timelineview.js"></script>

    <script type="text/javascript">

		function clearLOG(){
			if (confirm("<?php echo ALERT_CLEAR_LOG ?>")) $('#LOG').empty();
		}

		function writeLOG(msg){
			var d = new Date()
			$('#LOG').prepend('<span><b>['+ d.getDate() +'/'+ (d.getMonth()+1) +'/'+ d.getFullYear() + ' ' + d.toLocaleTimeString() + ']</b>: ' + msg + '</span><br/>');
			if($('#LOG SPAN').length > 10) $('#LOG > *:gt(<?php echo MAX_LOG_ENTRIES*2 ?>)').remove();
		}

		function startTree(){
			writeLOG('Building Navigation Tree...');
			$('#casetree').fileTree({root: 'morgue'}, loadCommands/*function(f) { $('#contentheader').html('Text Viewer');  $('.contentplaceholder').textViewer({file: f}); }*/);
			loadCommands('morgue');
			writeLOG('Finished building Navigation Tree!');
		}

		function startTextViewer(){
            $('#contentheader').html('<?php echo TEXT_VIEWER ?>');
            $('.contentplaceholder').textViewer({file: '/var/www/rwa/master.php'});
		}

		function startTimelineViewer(){
            $('#contentheader').html('<?php echo TIMELINE_VIEWER ?>');
            $('.contentplaceholder').timelineViewer({file: '/var/www/100103-01-1-disk_TL.csv',expression:'/(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)/'});
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
				center__onresize: "adapt"
            });
			writeLOG('Finished building layout!');
            startTree();
			startTimelineViewer();
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
        <div class="header"><?php echo NAVIGATION ?><div title="<?php echo REFRESH_TREE ?>" class="headerbutton reftree" id="reftree"></div></div>
        <div style="min-height: 55%; max-height: 55%; overflow-y: auto; overflow-x: hidden; margin: 2px">
            <div id="casetree">
            </div>
        </div>
        <div class="header"><?php echo COMMANDS ?></div>
        <div id="commands">
			<?php echo EMPTY_COMMAND_BOX ?>
        </div>
		<div class="header"><?php echo RESULTS ?></div>
        <div id="results">

        </div>
    </div>
    <div class="ui-layout-south">
        <div class="header"><?php echo LOG ?><div title="<?php echo CLEAR_LOG ?>" class="headerbutton clearlog" onclick="clearLOG()" ></div></div>
        <div>
		<div id="LOG" style="max-height: 130px;overflow:auto"></div>
        </div>
    </div>
</body>
</html>