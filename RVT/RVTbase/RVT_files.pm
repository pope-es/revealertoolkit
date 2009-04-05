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


package RVTbase::RVT_files;  

use strict;
           #use warnings;

           BEGIN {
               use Exporter   ();
               our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

               $VERSION     = 1.00;

               @ISA         = qw(Exporter);
               @EXPORT      = qw(   &constructor
                                    &RVT_script_files_allocfiles 
                                );
               
               
           }


my $RVT_moduleName = "RVT_files";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use Data::Dumper;

sub constructor {
    
	$main::RVT_functions{RVT_script_files_allocfiles } = "Creates a file with a list of all the allocated files\n   files allocfiles <disk>";

}


sub RVT_script_files_allocfiles  { 
    # creates a list of all allocated files on a device
    # arguments:  disk
	
    my $disk = shift(@_);

    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
    
    my $morguepath = RVT_get_morguepath($disk);    
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};
    my $infopath = "$morguepath/output/info";
    mkdir $infopath unless (-e $infopath);
    if (! -d $infopath) { print "ERR: there is no path to the morgue/info!\n\n"; return 0};

    my $command = "find $morguepath/mnt > $infopath/alloc_files.txt";
    
    print "$command\n\n";
    `$command`;
    
    return 1;
}


1; 

