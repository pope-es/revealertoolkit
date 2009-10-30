<?php

// This file contains all the global constants & variables
// that will be used across the portal.
// This is a way to centralize all configuration parameters and
// provide human-readable/editable data
//
// There is also a section for the literals displayed across the web
//
// The function that stays in the bottom is the one used to initialize the calls to the RVT framework

	/****************************
	 *   GLOBAL CONFIGURATION   *
	 ****************************/

	define('RVT_PATH' , '/home/rwa/revealertoolkit/RVT');				//base path to the RVT framework (used to find PM modules)
	define('XMLCOMMAND_PATH' , '/var/www/rwa/content/commands.xml');	//full path to the commands.xml file
	define('TEMPORARY_PATH', '/usr/tmp');								//full path to the temp directory (to save temp files)
	define('INIT_MODULE', 'RVT_init.pl');								//filename for the initialization script

	define('COMMAND_HTML_TEMPLATE','<input type="image" src="img/{icon}" id="{name}" alt="{alias}" style="vertical-align: text-top" /><label for="{name}" alt="{description}" class="command">{alias}</label><br />');	//HTML template for the command icon/link
	define('DISABLED_COMMAND_HTML_TEMPLATE','<input type="image" src="img/{icon}" id="{name}" alt="{alias}" class="disabled" disabled="disabled" style="vertical-align: text-top" /><label for="{name}" alt="{description}" class="disabled">{alias}</label><br />');	//HTML template for the command icon/link
	define('COMMAND_WORKING_ICON','working.gif');						//icon for a command in progress

	define('RVT_CHECK_EXECUTION','RVT_cmd_isExecuted');					//name of the RVT function that checks whether a command is executing/executed
	define('RVT_LOG_NOT_EXECUTED',0);									//value of the function to indicate that a command has never executed
	define('RVT_LOG_WORKING','STARTED');								//value of the function to indicate that a command has (at least) been launched
	define('RVT_LOG_SUCCESS','SUCCESS');								//value of the function to indicate that a command has finished successfully

	$OUTPUT_FILE = '';													//full path to the temporary file that contains command outputs


	/****************************
	 *     PLUGIN MANAGEMENT    *
	 ****************************/

	define('TEXTVIEW_DEFAULT_LINEOFFSET' , 1);	//the default value if 'lineOffset' is not specified
	define('TEXTVIEW_DEFAULT_LINES' , 25);		//the default value if 'lines' is not specified

	define('TIMELINEVIEW_DEFAULT_LINEOFFSET' , 1);	//the default value if 'lineOffset' is not specified
	define('TIMELINEVIEW_DEFAULT_LINES' , 25);		//the default value if 'lines' is not specified

	
	/****************************
	 *    COMMAND PARAMETERS    *
	 ****************************/

	//WARNING: DO NOT DELETE/MODIFY ENTRIES
	$CASE = '';		//contains the case code
	$INPUT = '';	//contains user input
	$OBJECT = '';	//contains the currently selected object
	$RESERVED = '';	//contains extra data

	
	/****************************
	 *         LITERALS         *
	 ****************************/

	//NOTE: for command literals, see the commands.xml file

	//GENERAL INTERFACE
	define('PAGE_TITLE' , 'Revealer Toolkit Web Access - Alpha');
	define('TITLE' , 'Revealer Toolkit Web Access v.&alpha;lpha');
	define('NAVIGATION' , 'Navigation');
	define('COMMANDS' , 'Commands');
	define('RESULTS' , 'Results');
	define('LOG' , 'Console LOG');
	define('TEXT_VIEWER' , 'Text Viewer');
	define('TIMELINE_VIEWER', 'Timeline Viewer');
	
	//OBJECT TREE PLUGIN
	define('DEVICE' , 'device');
	define('DISK' , 'disk');
	define('PARTITION' , 'partition');
	define('REFRESH_TREE' , 'Refresh');
	
	//LOG MANAGEMENT
	define('CLEAR_LOG' , 'Clear');
	define('ALERT_CLEAR_LOG' , 'Do you really want to clear the log window?');
	define('MAX_LOG_ENTRIES',100);
	
	//COMMAND BOX
	define('EMPTY_COMMAND_BOX','<div style="text-align:center;margin-right:5px"><em>Select an object from the navigation tree to see the available commands here.</em></div>');
	define('COMMAND_TEMPLATE','<input type="image" src="img/{icon}" id="{id}" onclick="launchCommand(this)" style="vertical-align: text-top" class="{class}" {disabled} /> <label for="{id}" class="{lbclass}">{alias}</label><br />');
	
	//COMMON PLUGIN LITERALS
	define('MSG_SEARCH_NOT_FOUND', 'No more matches found in this direction.');
	define('TIP_SEARCH', 'Search simple text');
	define('TIP_SEARCH_REGEXP', 'Search using regular expressions');
	define('TIP_PREV_MATCH', 'Find previous match');
	define('TIP_NEXT_MATCH', 'Find next match');
	define('TIP_HIGHLIGHT', 'Highlight matches');
	define('TIP_SEARCH_CANCEL', 'Reset search');
	define('TIP_FIRST_PAGE', 'Go to first page');
	define('TIP_PREV_PAGE', 'Go to previous page');
	define('TIP_JUMP_PAGE', 'Jump to specified page');
	define('TIP_NEXT_PAGE', 'Go to next page');
	define('TIP_LAST_PAGE', 'Go to last page');
	define('TIP_NUM_LIN', 'Number of lines per page');
	
	//RVT-RWA initialization routine
	//Returns the Perl object ready to use
	$INIT_RVT = 0;
	function InitRVT(){
		if ($INIT_RVT == 1) return;
		ob_start();
		chdir(RVT_PATH);
		$p = new Perl();
		$p->eval("use lib '" . RVT_PATH . "';");
		$p->eval("use XML::Simple;");
		$p->eval("require '" . INIT_MODULE . "';");
		$p->eval("RVT_images_loadconfig();");
		ob_end_clean();
		$INIT_RVT = 1;
		return $p;
	}
	
	
?>