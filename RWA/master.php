<?php 
require_once './content/globals.php';
echo '<?xml version="1.0" encoding="UTF-8" ?>' ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <link href="css/jquery.filetree.css" rel="Stylesheet" type="text/css" media="screen" />
    <link href="css/jquery.textview.css" rel="Stylesheet" type="text/css" media="screen" />
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

    <script type="text/javascript">
	
        $(document).ready( function() {
            $('body').layout({ 
                applyDefaultStyles: true,
                north__applyDefaultStyles: false,
                north__resizable: false,
                north__border: 0,
                north__spacing_open: 0,
                north__size: 65,
                south__initClosed: true,
                south__size: 150,
                west__resizable: true,
                west__border: 4,
                west__maxSize: 300,
				center__onresize: "adapt"
            });
            
            $('#casetree').fileTree({root: 'morgue'}, function(f) { /*$('#contentheader').html('Text Viewer');  $('.contentplaceholder').textViewer({file: f}); */});

            $('#contentheader').html(<?php echo "'" . TEXT_VIEWER . "'" ?>);
            $('.contentplaceholder').textViewer({file: '/home/rwa/revealertoolkit/docs/RVT-userGuide/100103-01-1-disk_TL.txt'});
            
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
        <div class="header"><?php echo NAVIGATION ?></div>
        <div style="min-height: 55%; max-height: 55%; overflow-y: auto; overflow-x: none; margin: 2px">
            <div id="casetree">
            </div>
        </div>
        <div class="header"><?php echo COMMANDS ?></div>
        <div id="commands">
            <input type="image" src="img/partition-list.png" id="command1" style="vertical-align: text-top" />
            <label for="command1" class="command">
                Partition list</label><br />
            <input type="image" src="img/partition-info.png" id="command2" style="vertical-align: text-top" />
            <label for="command2" class="command">
                Partition info</label><br />
            <input type="image" src="img/cluster-status.png" id="command3" style="vertical-align: text-top" />
            <label for="command3" class="command">
                Cluster status</label><br />
            <input type="image" src="img/cluster-toinode.png" id="command4" style="vertical-align: text-top" />
            <label for="command4" class="command">
                Cluster to Inode</label><br />
        </div>
		<div class="header"><?php echo RESULTS ?></div>
        <div id="commands">
            <input type="image" src="img/partition-list.png" id="command1" style="vertical-align: text-top" />
            <label for="command1" class="command">
                Partition list</label><br />
        </div>
    </div>
    <div class="ui-layout-south">
        <div class="header"><?php echo LOG ?></div>
        <div>
        </div>
    </div>
</body>
</html>
