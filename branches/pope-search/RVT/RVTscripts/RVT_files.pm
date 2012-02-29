#  Revealer Tools Shell - package
#
#    Copyright (C) 2008 Jose Navarro a.k.a. Dervitx
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


package RVTscripts::RVT_files;  

use strict;
           #use warnings;

           BEGIN {
               use Exporter   ();
               our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

               $VERSION     = 1.00;

               @ISA         = qw(Exporter);
               @EXPORT      = qw(   &constructor
                                    &RVT_script_files_allocfiles
                                    &RVT_get_allocfiles
                                    &RVT_script_files_printfiles
                                );
               
               
           }


my $RVT_moduleName = "RVT_files";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use Data::Dumper;

sub constructor {

   my $find = `find --version`;
   
   if (!$find) {
        RVT_log ('ERR', 'RVT_file not loaded (couldn\'t find find)');
        return;
   }
   
   $main::RVT_requirements{'find'} = $find;
    
	$main::RVT_functions{RVT_script_files_allocfiles } = "Creates a file with a list of all the allocated files\n   files allocfiles <disk>";
	
	$main::RVT_functions{RVT_script_files_printfiles } = "Gives a list of all the allocated files that matches\n
						a regular expresion.\n
						script files printfiles <regular expression> <disk>";

}


sub RVT_script_files_allocfiles  { 
    # creates a list of all allocated files on a device
    # arguments:  disk
	
    my $disk = shift(@_);

    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log ('ERR', "that is not a disk"); return 0; }
    
    my $morguepath = RVT_get_morguepath($disk);    
    if (! $morguepath) { RVT_log ('ERR', "there is no path to the morgue!"); return 0};
    my $infopath = "$morguepath/output/info";
    mkdir $infopath unless (-e $infopath);
    if (! -d $infopath) { RVT_log ('ERR', "there is no path to the morgue/info!"); return 0};

   	printf ("Updating alloc_files... ");
    my $command = "find -L $morguepath/mnt > $infopath/alloc_files.txt";
    `$command`;
    printf ("Done.\n");
    return 1;
}


sub RVT_get_allocfiles ($$) {
	# from the list of allocated files created by RVT_script_files_allocfiles
	# returns an array with those whose name match the regular expression
	#
	# args:		regular expresion
	#			disk
	
	my ($regexpr, $disk) = @_;
	my @results;
	
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log ('ERR', "that is not a disk"); return 0; }
	
	open (F, "<" . RVT_get_morguepath($disk) . "/output/info/alloc_files.txt") or RVT_log ('CRIT', 'Could not open output/info/alloc_files.txt');
	while (<F>) {
		next if (/^\s*#/);
		chomp;
		unshift(@results, $_) if (/$regexpr/i);
	}
	
	return @results;
}


sub RVT_script_files_printfiles ($$) {
	# given a disk and a regular expression, return the path of all allocated files
	# that matches that regular expression
	#
	# args:		regular expresions
	#			disk

    my ($regexpr, $disk) = @_;

	foreach my $f (RVT_get_allocfiles($regexpr, $disk)) { print "$f\n"; };
}


1; 

