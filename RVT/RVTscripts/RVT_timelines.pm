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


package RVTscripts::RVT_timelines;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_timelines_generate
                            &RVT_get_timelinefiles
                        );
       
       
   }


my $RVT_moduleName = "RVT_timelines";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use Data::Dumper;

sub constructor {
   
   $main::RVT_functions{RVT_script_timelines_generate } = "Generates timelines for all partitions of a disk \n
 									script timelines generate <disk>";

}


sub RVT_get_timelinefiles ($$$) {
	# from the timeline of a partition (itimeline-xx files)
	# returns an array with those whose name match the regular expression
	# and MAC state, sorted by time 
	#
	# args:		regular expresion
	#           mac
	#			partition
	
	my ($regexpr, $mac, $part) = @_;
	my @results;
	
	my $sdisk = RVT_split_diskname($part);
	my $disk = RVT_chop_diskname('disk', $part);
	
	open (F, "<" . RVT_get_morguepath($disk) . "/output/timelines/" . $disk . "-p" . $sdisk->{partition} . "_iTL.csv") or die 'Cannot open the timeline';
    @results = grep { /^[^:]*:.*,.*,$mac,.*,.*,.*,.*,.*$regexpr/ } <F>;
    @results = map {my @r = split(','); chomp ($r[7]); "$r[0],$r[2],$r[7]"} @results;
	close (F);
	
	return @results;
}


sub RVT_script_timelines_printfiles ($$$) {
	# args:		regular expresion
	#           mac
	#			partition
	
	my ($regexpr, $mac, $part) = @_;

	foreach my $f (RVT_get_timelinefiles($regexpr, $mac, $part)) { print "$f\n"; };
}


sub RVT_script_timelines_generate  {
    # generates timelines from an image
    # returns 1 if OK, 0 if errors

    my ( $disk ) = @_;
    
    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
    
    my $ad = RVT_split_diskname($disk);
    my $morguepath = RVT_get_morguepath($disk);
    my $imagepath = RVT_get_imagepath($disk);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $timelinespath = "$morguepath/output/timelines";
    mkdir $timelinespath unless (-e $timelinespath);
    if (! -d $timelinespath) { print "ERR: there is no path to the morgue/timelines!\n\n"; return 0};
	mkdir "$timelinespath/temp" unless ( -d "$timelinespath/temp" );
    
	# generation for every partition 

	my %parts = %{$main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
	my $sectorsize = $main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{sectorsize};
    
    foreach my $p ( keys %parts ) {
		# glups ...
		print  "\t Generando ficheros intermedios para $disk-p$p ... \n";
		
    	my $cmd = "$main::RVT_cfg->{tsk_path}/fls -s 0 -m \"$p/\" -r -o " . $parts{$p}{osects} . " -b " . $sectorsize .
    		" -i raw $imagepath >> $timelinespath/temp/${disk}-disk_body ";
    	`$cmd`;
    	
    	my $cmd = "$main::RVT_cfg->{tsk_path}/ils -s 0 -e -m -o " . $parts{$p}{osects} . " -b " . $sectorsize .
    		" -i raw $imagepath > $timelinespath/temp/${disk}-disk_ibody ";
    	`$cmd`;
    }
    
    print  "\t Generating timelines for $disk ... \n";	
    my $cmd = "$main::RVT_cfg->{tsk_path}/mactime -b $timelinespath/temp/${disk}-disk_body -m -y -d -i hour $timelinespath/${disk}-disk_TL-hour.sum > "
    	. "$timelinespath/${disk}-disk_TL.csv";
    `$cmd`;
    my $cmd = "$main::RVT_cfg->{tsk_path}/mactime -b $timelinespath/temp/${disk}-disk_body -m -y -i day $timelinespath/${disk}-disk_TL-day.sum > "
    	. "$timelinespath/${disk}-disk_TL.txt";
    `$cmd`;
   
    foreach my $p ( keys %parts ) {
		# glups ...
		print  "\t Generating itimeline for $disk-p$p ... \n";
		    	
		open (IDEST,">$timelinespath/$disk-p${p}_iTL.csv");
		open (PA,"$main::RVT_cfg->{tsk_path}/mactime -b $timelinespath/temp/${disk}-disk_ibody -m -y -d -i day $timelinespath/$disk-p${p}_iTL-day.sum |");
		<PA>;  # header
		while ( my $line=<PA> ) { 
			chop($line);
			my @line = split(",", $line);
			my $inode = $line[6];
			my $filename = `$main::RVT_cfg->{tsk_path}/ffind -o $parts{$p}{osects} -b $sectorsize -i raw $imagepath $inode`;
			chop($filename);	
			print IDEST join(",",@line[0..6]) . ",$filename\n";
		}
		close (PA);
		close(IDEST);  
    } 
    
    print "\t timelines done\n";
    return 1;
}


1;  

