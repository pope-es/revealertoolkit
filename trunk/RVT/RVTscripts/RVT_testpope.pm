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


package RVTscripts::RVT_testpope;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
       						&RVT_script_testpope_go
       						&RVT_script_testpope_filelist
                        );
       
       
   }


my $RVT_moduleName = "RVT_testpope";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "Pope";

use RVTbase::RVT_core;
use Data::Dumper;

sub constructor {
	$main::RVT_functions{RVT_script_testpope_go} = "test, pope, pope, test... und Das ist kool ;)";
	$main::RVT_functions{RVT_script_testpope_filelist} = "Generate various file lists for every partition in a disk\n
				script testpope list <disk>";

	
}



sub RVT_script_testpope_go  {





	printf("xx Function RVT_script_testpope_go HAPPILY got to its end :D\n");
	return 1;
}




sub RVT_script_testpope_filelist {
    # Generates various filelists for every partition in a disk

	#init:
	my ( $disk ) = @_;

	$disk = $main::RVT_level->{tag} unless $disk;
	if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }

    my $ad = RVT_split_diskname($disk);
	my $morguepath = RVT_get_morguepath($disk);
	my $imagepath = RVT_get_imagepath($disk);
	if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};
     
	my $timelinespath = "$morguepath/output/timelines";
	if (! -d "$timelinespath" ) { print "ERR: timelines are not generated\n\n"; return 0 } ;  

	my $listpath = "$morguepath/output/FileList";
	mkdir $listpath unless (-e $listpath);
	if (! -d $listpath) { print "ERR: there is no path to the morgue/list!\n\n"; return 0};

	opendir (DIR, "$timelinespath") or die ("ERR: timelines path not readable");
	my @tlfiles = grep { /^(timeline|itimeline-\d\d)\.csv$/ } readdir(DIR);
	close DIR;
	if (! @tlfiles) { print "ERR: timelines are not generated\n\n"; return 0; }
	# end init.


	# For every given partition, generate 100ccc-DD-dd-pPP_Filelist.csv
	my %parts = %{$main::RVT_cases->{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
    foreach my $p ( keys %parts ) {
		print "\tGenerating file list for $disk-p$p ... \n";
		my $cmd = "cat $timelinespath/itimeline-". $p .".csv | cut -d, -f7- | sort -un | sed 's/^\\([^,]*\\),/\\1\\t". $disk ."-p". $p ."\\t/g' > ". $listpath ."/". $disk ."-p". $p ."_FileList.csv";
		`$cmd`;
	}
	
	# Concatenate all 100ccc-DD-dd-p??_FileList.csv (ie 100ccc-DD-dd@partitions) to generate 100ccc-DD-dd-disk_FileList.csv
	my $cmd = "cat ". $listpath ."/". $disk ."-p??_FileList.csv > ".$listpath ."/". $disk ."-disk_FileList.csv";
	`$cmd`;

	# For every given partition, 100ccc-DD-dd-p??_Filelist.csv, generate two new sets of lists:
	# one based on allocation criteria; and another one splitting by EXTENSION: doc, jpg, lnk...
	my %parts = %{$main::RVT_cases->{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
    foreach my $p ( keys %parts ) {
# xx por aki :		my $cmd = "cat ". $listpath ."/". $disk ."-p". $p ."_FileList.csv";
		`$cmd`;
	}
	





	
	printf("\tFinished generating file lists for $disk\n");
	
     return 1;
}



1;  

