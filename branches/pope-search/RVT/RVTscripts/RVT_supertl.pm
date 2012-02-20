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


package RVTscripts::RVT_supertl;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_supertl_generate
                        );
       
       
   }


my $RVT_moduleName = "RVT_supertl";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "saritar";

use RVTbase::RVT_core;
use RVTbase::RVT_morgue;
use RVTscripts::RVT_files;
use Data::Dumper;
#use Date::Manip;

#use open "IO" => ":encoding(cp1252):utf8";

sub constructor {
   
   my $timescanner = `timescanner`;
  #my $mactime = `mactime`;

#	print "$reportevt, $parsevt\n";
#
   if (!$timescanner) {
        RVT_log ('ERR', 'RVT_supertl not loaded (couldn\'t find timescanner)');
   }
   #if (!$mactime) {
    #    RVT_log ('ERR', 'RVT_supertl not loaded (couldn\'t find mactime)');
   #}
  # return 0 if (!$timescanner || !$mactime);
   return 0 if (!$timescanner);
   
   #$main::RVT_requirements{'mactime'} = $mactime;
   $main::RVT_requirements{'timescanner'} = $timescanner;

   $main::RVT_functions{RVT_script_supertl_generate } =
   "generates a super timeline with EVT events, LNK files, EXIF ,RECYCLER, WEB HISTORYetc.\n
	For more information see http://log2timeline.net/ \n
   script supertl generate <disk>";
   


}

sub RVT_script_supertl_generate {
	my $morguepath;
	my ( $disk ) = @_;
	#my ( $part ) = @_;
	#RVT_fill_level(\$part);
    	#my $spart = RVT_split_diskname($part);
    	#return 0 unless ($spart->{partition});
	#my $disk = RVT_chop_diskname('disk', $part);

	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log ('WARNING', 'that is not a disk'); return 0; }
        $morguepath = RVT_get_morguepath($disk);
	if (! $morguepath) { RVT_log ('WARNING', 'there is no path to the morgue!'); return 0};
	my $ad = RVT_split_diskname($disk);
	
	my $supertlpath= "$morguepath/output/supertl";
	my $tmp= $supertlpath . "/temp";
	if (! -e $supertlpath) {
		my @args = ('mkdir', $supertlpath);
		system (@args);
	}
	if (! -e $tmp) {
		my @args = ('mkdir', $tmp);
		system (@args);
	}
	#my %parts = %{$main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
	my @args;
	my $mnt;
        my @parts = RVT_exploit_diskname ('partition', $disk);
        return 0 unless (@parts);
	my $bodyfile;
	my $bodyfdisk= $tmp . "/" . $disk . "_bodyfile";
 	my $cmd;	
	open (FOUT,">$bodyfdisk");

	
	foreach my $p (@parts) {
  #  	foreach my $p ( keys %parts ) {
		if (! RVT_mount_isMounted($p)) { RVT_log ('ERR',"Partition $p isn't mounted\n"); next}
                print  "\t Generando ficheros intermedios para $p ... \n";
		$mnt = $morguepath . "/mnt/p" . RVT_get_partitionnumber($p);
		$bodyfile= $tmp . "/" . $p . "_bodyfile";
		@args = ("timescanner", "-d", $mnt, "-w", $bodyfile);
		#system (@args);
		if (! system (@args)) {
            		RVT_log ('NOTICE', "timescanner completed in $p\n");
			`cat $bodyfile >> $bodyfdisk`;
			
        	} else {
            		RVT_log ('ERR', "Error encountered while executing timescanner in $p\n");
			next;
        	}
		print "Adding $bodyfile to $bodyfdisk\n";
	}
	print "Generating a csv file\n";
	#if (!open (FLNK, "<$morguepath/output/lnk/$disk"."_lnk.csv")) { RVT_log ("ERR","The lnk file does not exist\n");  return 0;} 

	#100686-01-1-disk_body
	my $tl=$morguepath . "/output/timelines/temp/" .$disk ."-disk_body";
	#print "Merging log2timeline with timelines\n";
	if ( -e $tl){
		 print "Merging log2timeline body format with $tl\n";
		`cat $tl $bodyfdisk > $tmp/$disk-all`;
		 $cmd="$main::RVT_cfg->{tsk_path}/mactime -b $tmp/$disk-all -m -y -d > $supertlpath/$disk-tl-all.csv";
	}
	else{
		 print "$tl does not exist\n";
		 print "Generating log2timeline csv file\n";	
		 $cmd="$main::RVT_cfg->{tsk_path}/mactime -b $bodyfdisk -m -y -d > $supertlpath/$disk-tl-all.csv";
	}
	`$cmd`;
	#@args= ("mactime", "-b", $bodyfdisk,"-m","-y","-d",">$bodyfile.csv");
	#system "mactime", "-b", $bodyfdisk, "-m", "-y", "-d", ">","$bodyfdisk.csv";
	#print Dumper($rdo);
#	if (! open (PSCAN,"-|","$TIMESCANNER "," -d ",$mnt)) { 
#		RVT_log('CRIT',"$timescanner can't be executed!\n\n"); return 0
#	} 
    	#if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	#my @args = ('ln', '-s', $supertlpath, $morguepath.'/mnt/p00/output_supertl');
	#system (@args);
	#printf ("Finished  super timeline files. Updating alloc_files...\n");
	#RVT_script_files_allocfiles();
	return 1;

}

1;  



