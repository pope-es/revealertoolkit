#!/usr/bin/perl
#
#  Revealer Tools Shell
#
#    Copyright (C) 2008 Jose Navarro a.k.a. Dervitx
#
#    Acknowledgements:
#     - INCIDE (Investigacion Digital S.L., www.incide.es)
#       where developers and testers work
#     - Manu Ginés aka xkulio 
#       creator of the original Chanchullos Revealer
#     - Generalitat de Catalunya
#       for partial funding of the project
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#    For more information, please visit
#    http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt


BEGIN {

	use encoding "utf-8";

	# loading RVT libraries path
	use FindBin;
	use lib "$FindBin::Bin/../lib" ;

	our $RVT_realPath = $FindBin::RealBin;
	push (@INC, $RVT_realPath);

}


our $RVT_version = '0.2.2';



sub usage {

   my $error;
   if ($error = shift(@_)) { print "\nERROR: $error \n\n"; }

   print <<EOF ;

   Revealer Toolkit Shell version $_version, 
   Copyright (C) 2008 by Jose Navarro, a.k.a dervitx
   This is free software distributed under GNU GPL v2 license

   the Revealer Toolkit is a framework and simple scripts for computer 
   forensics. It uses Brian Carrier's The Sleuth Kit as the backbone, 
   as well as other free tools.

   The aim of the Revealer Toolkit is to automate rutinary tasks and to
   manage sources and results from another perspective than the usual 
   forensic frameworks.
 

   perl RVT.pl [--option=option value] 

        --batch=filename   
        -b filename     Batch Mode.  RVT Shell takes commands for the 
                        file provided, or from the standard input if this
                        file name is omitted
        
        --level=level   
        -l level        RVT Shell will execute the command 'set level' with
                        the provided level before executing other commands
        
        --shell         RVT Shell will start in Shell Mode. This is the 
                        default behaviour of RVT Shell

        --config        RVT Shell config file

        --verbose       outputs all the messages sent to syslog

   Examples:

      1) to obtain a shell, simply execute RVT

      perl RVT.pl

      2) batch mode: obtaining a list of cases stored in the morgue

      echo "case list; quit" |  perl RVT.pl -b

      3) batch mode: executing predefined commands on case 100101-01-1
      
      perl RVT.pl -l "100101-01-1" -b predefined-commands.rvt


      For further reading, look for User Guide and Developer Guide at the
      website:   http://code.google.com/p/revealertoolkit

EOF

   exit;
}

use Getopt::Long;
GetOptions(
        "batch:s"			=> \$RVT_batchmode,
        "level:s"           => \$RVT_initial_level,
        "shell"				=> \$RVT_shellmode,
        "config:s"          => \$RVT_optConfigFileName,
        "verbose"           => \$RVT_verbose,
        "help"				=> \$RVT_usage
        );

usage() if ($RVT_usage);
usage('Level must be specified if using --level option') if (defined($RVT_initial_level) and !$RVT_initial_level);
usage('Could not open provided config file') if ( defined($RVT_optConfigFileName) and (! -r $RVT_optConfigFileName) );
if (defined($RVT_batchmode) and !$RVT_batchmode) { $RVT_batchmode = '-'; }
if (!$RVT_batchmode and !$RVT_shellmode) { $RVT_shellmode = 1; }





#######################################################################
#
#  Initialization:
#	
#	- loads config
#	- default configuration
#	- global variables
#	- general functions
#
#######################################################################


die ($!) unless ( do 'RVT_init.pl' );
die ($@) if ($@);


		
#######################################################################
#
#  main
#
#######################################################################		


RVT_log ('INFO', 'loading configuration');
RVT_images_scan('all') unless ( RVT_images_loadconfig() );
RVT_shell(); 
exit;






END {

    RVT_log ('INFO', 'ending session');
    closelog();

}






