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


package RVTscripts::RVT_carving;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_carving_default
                            &RVT_script_carving_graphics
                        );
       
       
   }


my $RVT_moduleName = "RVT_carving";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "Pope";

use RVTbase::RVT_core;
use RVTscripts::RVT_files;
use Data::Dumper;
use Date::Manip;


sub constructor {
   
    my $photorec = `which photorec`;

   if (!$photorec) {
        RVT_log ('ERR', 'RVT_carving not loaded (couldn\'t find photorec)');
   }
   return 0 if (!$photorec);
   
   $main::RVT_requirements{'photorec'} = $photorec;

   $main::RVT_functions{RVT_script_carving_default } =
   "Extracts files in raw mode; types: compressed, MS Office, HTML, PST, EVT, LNK...\n
   script carving default <disk>";
   $main::RVT_functions{RVT_script_carving_graphics } =
   "Extracts files in raw mode; types: graphic, images...\n
   script carving graphics <disk>";

}

sub RVT_script_carving_default {

	my $imagepath;
	my $morguepath;
   	my $photorec = "photorec";
	my ( $disk ) = @_;
	$disk = $main::RVT_level->{tag} unless $disk;
        if (RVT_check_format($disk) ne 'disk') { RVT_log ('WARNING', 'that is not a disk'); return 0; }

	$imagepath = RVT_get_imagepath($disk);
        $morguepath = RVT_get_morguepath($disk);
        if (! $morguepath) { RVT_log ('WARNING', 'there is no path to the morgue!'); return 0};
        my $carvingpath= "$morguepath/output/carving/";
        if (! -e $carvingpath){
            my @args = ('mkdir', $carvingpath);
            system (@args);
        }

   	print "Starting file carving on $disk...\n";   	
#         mkdir ("$carvingpath/contents") or die ("ERR: failed to create output directories.");
#         open (META, ">$carvingpath/RVT_metadata.txt") or die ("ERR: failed to create metadata files.");
#             print META "Source file: $imagepath\n";
#             print META "Parsed by RVT module $RVT_moduleName version $RVT_moduleVersion\n";
#         close (META);   	
   	my @args = ("$photorec", "/log", "/d", "$carvingpath", "/cmd", "$imagepath", "partition_none,fileopt,everything,disable,accdb,enable,dat,enable,doc,enable,evt,enable,gz,enable,jpg,enable,lnk,enable,mdb,enable,mov,enable,mpg,enable,pdf,enable,png,enable,pst,enable,rar,enable,reg,enable,tar,enable,tx?,enable,txt,enable,zip,enable,options,keep_corrupted_file,search");
   	system(@args);
   	printf ("Finished data carving. NOT updating alloc_files. This content is not linked in mnt/p00\n");
	return 1;

}

sub RVT_script_carving_graphics {

	my $imagepath;
	my $morguepath;
   	my $photorec = "photorec";
	my ( $disk ) = @_;
	$disk = $main::RVT_level->{tag} unless $disk;
        if (RVT_check_format($disk) ne 'disk') { RVT_log ('WARNING', 'that is not a disk'); return 0; }

	$imagepath = RVT_get_imagepath($disk);
        $morguepath = RVT_get_morguepath($disk);
        if (! $morguepath) { RVT_log ('WARNING', 'there is no path to the morgue!'); return 0};
        my $carvingpath= "$morguepath/output/carving/";
        if (! -e $carvingpath){
            my @args = ('mkdir', $carvingpath);
            system (@args);
        }

   	print "Starting file carving on $disk...\n";   	
   	my @args = ("$photorec", "/log", "/d", "$carvingpath", "/cmd", "$imagepath", "partition_none,fileopt,everything,disable,gif,enable,jpg,enable,png,enable,options,keep_corrupted_file,search");
   	system(@args);
   	printf ("Finished data carving. NOT updating alloc_files. This content is not linked in mnt/p00\n");
	return 1;

}

1;  

