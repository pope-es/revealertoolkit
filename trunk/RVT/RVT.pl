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


use Data::Dumper;
use Getopt::Long;
use XML::Simple;
use Sys::Syslog;

our $RVT_version = '0.2';

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


      For further reading, look for User Guide and Developer Guide at The
      website:   http://code.google.com/p/revealertoolkit

EOF

   exit;
}

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
#  logging and accounting
#
#######################################################################


my $RVTlog_fd;   # general log file descriptor
our $RVT_user = getpwuid($<);
my @tt = split(' ', $ENV{SSH_CLIENT});
our $RVT_remoteIP = $tt[0];

if ($RVT_verbose)  {
    openlog('RVT', 'ndelay, perror', 'local0');
} else {
    openlog('RVT', 'ndelay', 'local0');
}    

RVT_log('INFO', "starting up RVT v$RVT_version" );

#######################################################################
#
#  general variables
#
#######################################################################

my $configFileName;

$configFileName = '/etc/rvt/rvt.cfg' if (-e '/etc/rvt/rvt.cfg');
$configFileName = '~/rvt.cfg' if (-e '~/rvt.cfg');
$configFileName = 'rvt.cfg' if (-e 'rvt.cfg');
$configFileName = $RVT_optConfigFileName if ($RVT_optConfigFileName);

our $RVT_cfg = eval { XMLin ($configFileName, ForceArray => 1) };
if (!$RVT_cfg or $@) {
    #default configuration
    
    $RVT_cfg->{paths}[0] = {
        morgues => ['/media/morgue']    ,
        images => ['/media/morgue/imagenes']  ,
        tmp => '/tmp'
    };

    $RVT_cfg->{tsk_path} = "/usr/local/bin";
    $RVT_cfg->{morgueInfoXML} = "/media/morgue/RVTmorgueInfo.xml";
    $RVT_cfg->{mount_umask} = "007";
    $RVT_cfg->{mount_gid} = "1010";
    $RVT_cfg->{log_level} = "0";
}


# $RVT_cases->{case}{100xxx}
#                     {code}
#		              {imagepath}
#		              {morguepath}
#                     {device}{}
#                         {code}
#                           {disk}{}
#                               {sectorsize}
#                               {partition}{}
#                                   {type}
#                                   {osects}  offset in sectors
#                                   {obytes}  offset in bytes
#                                   {size}
#                                   {loop}
#									{clustersize}

our $RVT_cases;   

our %RVT_functions = (
 'RVT_test' => "test",
 
 'RVT_set_level' => 'Sets working level a case, device, disk or partition',

 );
		

# dynamic module loading does not work, i don't know why
#my $jarl = 'use RVTscripts::RVT_files;' ;
#eval ($jarl);
#print $@ if ($@);


use RVTbase::RVT_core;
use RVTbase::RVT_tsk;

use RVTbase::RVT_morgue;
RVTbase::RVT_morgue::constructor;

use RVTbase::RVT_info;
RVTbase::RVT_info::constructor;

use RVTbase::RVT_cluster;
RVTbase::RVT_cluster::constructor;

# script modules
use RVTscripts::RVT_search;
RVTscripts::RVT_search::constructor;

use RVTscripts::RVT_timelines;
RVTscripts::RVT_timelines::constructor;

use RVTscripts::RVT_software;
RVTscripts::RVT_software::constructor;
	
use RVTscripts::RVT_webmail;
RVTscripts::RVT_webmail::constructor;	

use RVTscripts::RVT_files;
RVTscripts::RVT_files::constructor;

use RVTscripts::RVT_regripper;
RVTscripts::RVT_regripper::constructor;

		
#######################################################################
#
#  main
#
#######################################################################		


RVT_log ('INFO', 'loading configuration');
RVT_images_scanall() unless ( RVT_images_loadconfig() );
RVT_shell(); 
exit;




#######################################################################
#
#  general functions
#
#######################################################################


sub RVT_test {

    print "args: " . join(',',@_) . "\n";

}



sub RVT_charge_file ($) {
   # receives a path to a filename
   # then, reads the contents of the file into an array
   # but removes all the lines that begin with '\s+#'
   # returns the reference to the array if OK, 0 if errors

    my $filename = shift;
    my $array;
    
    open (FILE, $filename) or return 0;
    @{$array} = grep {!/^\s+#/} <FILE>;
    return $array;

};



sub RVT_set_level ($) {
        my $new = shift(@_);
        if (!$new) {
                $RVT_level = {};
                return 1;
        }

        my $new_format = RVT_check_format($new);
        if (!$new_format or $new_format eq "case code") {
                $new_format = RVT_check_format($RVT_level->{tag} .'-'. $new);
                $new = $RVT_level->{tag} .'-'. $new;
        }
        if (!$new_format or $new_format eq "case code") { return 0; }

        $RVT_level->{tag}       = $new;
        $RVT_level->{type}      = $new_format;
        $RVT_level->{case}      = RVT_get_casenumber ($new);
        $RVT_level->{device}    = RVT_get_devicenumber ($new);
        $RVT_level->{disk}      = RVT_get_disknumber ($new);
        $RVT_level->{partition} = RVT_get_partitionnumber ($new);

        print "\n new format: $RVT_level->{type}\n";
        return 1;
}








#######################################################################
#
#  Shell functions
#
#######################################################################




sub RVT_shell_help {

    my $command = shift(@_);
    $command = RVT_shell_function_build($command);
    
    if (RVT_shell_isfunction($command)) {
        print "? \n$command:\n";
        print $RVT_functions{$command} . "\n\n";
    } else {
        my @results = grep (/^$command/, keys %RVT_functions);
        my @ss = split ('_', $command);
        %results = map { 
                            my @t = split('_',$_);
                            my $t = ($#t == $#ss)?join('_',@t[0..$#ss]):join('_',@t[0..$#ss+1]);
                            $t  => 1
                       } @results;
        
        for $r (sort keys %results) { print "? $r\n"; }
    }
}

sub RVT_shell_function_build {
    my $command = shift(@_);
    $command =~ s/\?.*$//;
    $command =~ s/^\s*//;
    $command =~ s/\s*$//;
    $command =~ s/\s{2,}/ /g;
    $command = lc($command);
    
    $command =~s/\s/_/g;
    $command = 'RVT_' . $command;
    return $command;
}

sub RVT_shell_function_unbuild {
	my $command = shift(@_);
	$command =~ s/^RVT_//;
	$command =~ s/_/ /g;
	return $command;
}

sub RVT_shell_isfunction {
    my $command = shift(@_);
    if ( (grep (/^$command$/, keys %RVT_functions)) ) { return 1; }
    return 0;
}


sub RVT_shell_function_exec ($$) {

    my ($command, $cmdgrp) = @_;

    $command =~ s/^\s*//;

    my @c = split(/\s+/, $command);

    for (my $cc=0; $cc<=$#c; $cc++ ) {
        my $fun = 'RVT_' . join('_',@c[0..$cc]);
        if ( $RVT_functions{ $fun } ) {
            
            # expanding @disks
            # now, only works with last argument
            my @objects;
            if (($c[$#c] =~ /^(.*)@(case|disk|device|partition)s/) ) {
            
                my $object = ($1)?$1:$RVT_level->{tag};
                my $level = $2;
            
                @objects = RVT_exploit_diskname( $level, $object );
            
            } else {
                # puts one element in @objects just to execute the command
                # ... yes, this is a chunk of ugly code...
                @objects[0] = ($#c == $cc)?'':$c[$#c];
            }
            
            foreach my $obj ( @objects ) {
                #print "\nexecuting: $fun " . join(" ",@c[$cc+1..$#c-1], $disk) . "\n\n";
                RVT_log('INFO', "executing ". $RVT_level->{tag} .": ". $fun ." ".join(' ', @c[$cc+1..$#c-1], $obj));
                eval {
                    &{$fun}( @c[$cc+1..$#c-1], $obj );
                };
                if ($@) { print "\n\n--> ERROR:  the command exited with errors: \n$@\n\n"; return 0; }
            }
            return 1;
        }
    }

    # $command is not a command. Maybe is a part...
    $command = 'RVT_' . join('_',@c);
    if ( grep { /^$command\_/ || /^$command$/ } keys(%RVT_functions) ) {
        return join(' ',@c);
    }

    return 0;
}



sub RVT_getcommand {
	
	my ($cmdgrp, $cmdhist) = @_;
	my $cmd = '';

	system "stty", '-icanon', 'eol', '001';

	while () {
		 my $k = getc();
         if (ord($k) == 27 ) {
                next unless ord(getc()) == 91;
                next unless ord(getc()) == 65;
                $cmd = $cmdhist;
                print "\r                                                                              \r";
                RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp, $cmd);
                next;
         }
		 if (ord($k) == 127) {
		 	chop $cmd;
			print "\r                                                                              \r";
			RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp, $cmd);
			next;
		 }
		 if (ord($k) == 27 ) { 
		 	$cmd = ""; 
			RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp, $cmd);
		 	next; 
		 }
		 if ($k eq "\t") {
		 	$cmd =~ s/\s+$//;
		 	$cmd =~ s/^\s+//;
		 	$cmd =~ s/\s{2,}/ /;
		 	my $cb = RVT_shell_function_build($cmdgrp . ' ' . $cmd);
		 	my @cbm = grep {/^$cb/} keys %RVT_functions;
		 	@cbm = map { RVT_shell_function_unbuild($_) } @cbm;
			my %cbm = map { s/($cmdgrp ?$cmd ?\w*) ?.*?$/$1/; $_ => $_  } @cbm;
			@cbm = keys %cbm;
			print "\n";
			if ($#cbm != -1) {
		 		$cmd =  $cbm[0] ;
		 		foreach my $tmp ( sort @cbm ) { 
					while ( ($tmp !~ /^$cmd/ ) and $cmd ) {
						chop $cmd; 
					} 
					print "\t" . $tmp . "\n";
				}
				$cmd =~ s/^$cmdgrp//;
		 	}

		 	RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp, $cmd);
		 	next;
 		 }
		 
		 $cmd .= $k;  
		 if ($k eq "\n") {last;};  
	}
	
    system "stty", 'icanon', 'eol', '^@';
    return $cmd;
}


sub RVT_shell_prompt {
  
   my ($level, $cmdgrp, $cmd, $preffix) = @_;

   print "$preffix RVT $level $cmdgrp> $cmd";

}

sub RVT_shell {

    RVT_log('INFO', 'RVT shell started');
    print "\n\nWelcome to Revealer Tools Shell (v$RVT_version):\n\n";
    my ($cmdgrp, $command, $cmdhist);

    if ($RVT_initial_level) { 
        RVT_log('INFO', 'executing : RVT_set_level ' . $RVT_initial_level);
        RVT_set_level($RVT_initial_level); 
    }

    if ($RVT_batchmode) {
    	open (BATCH, "<$RVT_batchmode") or die "FATAL: $!";
    }

    RVT_shell_prompt ($RVT_level->{tag});
    EXECLOOP: while () {
        if ($RVT_shellmode) { $command = RVT_getcommand($cmdgrp, $cmdhist); }
	    if ($RVT_batchmode) { return unless ($command=<BATCH>); print $command;  }

        chomp $command;
        foreach my $cmd ( split(';', $command )) {
            $cmdhist = $cmd if $cmd;
            last EXECLOOP if ($cmd =~ /quit$/);
            if ( $cmd =~ /^\s*r(e|et|etu|etur|eturn)?/ ) {
                    $cmdgrp =~ s/^(.*?) *\S*$/$1/;
                    next;
            }
            if ($cmd =~ /\?/) { RVT_shell_help("$cmdgrp $cmd"); next; }
            my $exec_result = RVT_shell_function_exec("$cmdgrp $cmd", $cmdgrp);
            $cmdgrp = $exec_result if ($exec_result and ($exec_result != 1));
            print "syntax error\n" unless $exec_result;
        }
    } continue { RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp) if ($RVT_shellmode); }

    if ($RVT_batchmode) { close(BATCH); }

    print "\n\nBye!\n";
}



END {

    RVT_log ('INFO', 'ending session');
    closelog();

}






