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


package RVTscripts::RVT_filelist;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_filelist_generate
                        );
       
       
   }


my $RVT_moduleName = "RVT_filelist";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "Pope";

use RVTbase::RVT_core;
use Data::Dumper;

sub constructor {
   
   $main::RVT_functions{RVT_script_filelist_generate } = "Generate various file lists for every partition in a disk\n
				script filelist generate <disk>";

}




sub RVT_script_filelist_generate {
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
 	my @tlfiles = grep { /_i?TL\.csv$/ } readdir(DIR);
 	close DIR;
 	if (! @tlfiles) { print "ERR: timelines are not generated\n\n"; return 0; }
	# end init.
	
	my @Filelist;
	my @FilelistTemp;
	my @FilelistSorted;
	my %seen = ( );
	my $item;
	my @splitline;
	my $TL_datetime;
	my $TL_inode;
	my $TL_mactimes;
	my $TL_permissions;
	my $TL_owner;
	my $TL_group;
	my $TL_size;
	my $TL_path;
	my $allocstatus;
	my $file_mode;
	my @splitpath;
	my $file_dirname;
	my $file_basename;


	# For every given partition, generate 100ccc-DD-dd-pPP_Filelist.csv
	my %parts = %{$main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
    foreach my $p ( keys %parts ) {
		print "\tGenerating file list for $disk-p$p ... \n";
		open ( F , "${timelinespath}/${disk}-p${p}_iTL.csv" ) or die("ERROR opening the iTimeline.");
		open ( DEST , ">$listpath/${disk}-p${p}_FileList.csv" ) or die("ERROR opening the Filelist for writing.");
		print DEST "Inode, Allocation status, Size, Type, Device, Path, Name\n";
		while ( <F> ) {
			$item=$_;
			chop($item);
			$allocstatus="Undetermined";
			
			@splitline = split(',' , $item);
			# it contains: 0)datetime; 1) size, 2) macb, 3) perms, 4) owner, 5) group, 6) size, 7) path+name+allocation_status
		
			$TL_datetime = $splitline[0];
			$TL_inode = $splitline[1];
			$TL_mactimes = $splitline[2];
			$TL_permissions = $splitline[3];
			$TL_owner = $splitline[4];
			$TL_group = $splitline[5];
			$TL_size = $splitline[6];
			$TL_path = $splitline[7];
		
			# This block sets the allocation status and normalizes the path+name field
			if ( $TL_path =~ /^\// ) {
				$allocstatus="Allocated";
			} elsif ( $TL_path =~ s/\* \/-ORPHAN_FILE-\///g ) { # WARNING! "s"
				$allocstatus="Deleted and orphan";
			} elsif ( $TL_path =~ s/\* //g ) { # WARNING! "s"
				$allocstatus="Deleted";
			}
			
			# This block uses the permissions field to calculate the type (file or dir)
			$file_mode = $TL_permissions;
			if ( $file_mode =~ s/^(.\/.).*$/\1/g ) {
				# guay
			} else {
				$file_mode =~ s/^(.).*$/\1/g;
			}
			# and here we make them more readable, if possible:
			$file_mode =~ s/^-\/r/File/g;
			$file_mode =~ s/^-\/d/Dir/g;
			
			# This block splits the TL_path field into dirname and basename, but without using external functions.
			$file_basename = $TL_path;
			$file_basename =~ s/^.*\///g;
			$file_dirname = $TL_path;
			if ( $file_dirname =~ /\// ) {
				$file_dirname =~ s/^(.*\/).*$/\1/g;
			} else {
				$file_dirname = "";
			}
			
			$item = "$TL_inode,$allocstatus,$TL_size,$file_mode,${disk}-p${p},$file_dirname,$file_basename";
			# That is: inode, allocation_status, size, perms, disk_and_part, path	
			
			# This will avoid duplicates (from Perl Cookbook recipe 4.7.2.1)
			unless ($seen{$item}) {
				# if we get here, we have not seen it before
				$seen{$item} = 1;
				push(@Filelist, $item);
			}
		}
		
		# We sort by dir + name. The "delimiter" hack helps keep things in order when
		# basename or dirname contain commas themselves.
		# XX_ToDo: we should work with tab-separated timelines.
		foreach $item (@Filelist) {
			$item =~ s/^([^,]*,[^,]*,[^,]*,[^,]*,[^,]*,)(.*)$/\2 I_Am_A_Delimiter_Oh_Yeah_XDD \1/g;
			push ( @FilelistTemp, $item);	
		}
		@FilelistSorted = sort { lc($a) cmp lc($b); } @FilelistTemp;
		foreach $item (@FilelistSorted) {
			$item =~ s/(.*) I_Am_A_Delimiter_Oh_Yeah_XDD (.*)/\2\1/g;
			printf DEST "$item\n";
		}
		
		close F;
		close DEST;

# ToDo - xx_por_aki:
	# Concatenate all 100ccc-DD-dd-p??_FileList.csv (ie 100ccc-DD-dd@partitions) to generate 100ccc-DD-dd-disk_FileList.csv
# 	my $cmd = "cat ". $listpath ."/". $disk ."-p??_FileList.csv > ".$listpath ."/". $disk ."-disk_FileList.csv";
# 	`$cmd`;
# 
# 	# For every given partition, 100ccc-DD-dd-p??_Filelist.csv, generate two new sets of lists:
# 	# one based on allocation criteria; and another one splitting by EXTENSION: doc, jpg, lnk...
# 	my %parts = %{$main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
#     foreach my $p ( keys %parts ) {

	}

	printf("\tFinished generating file lists for $disk\n");
	
     return 1;
}




1;  

