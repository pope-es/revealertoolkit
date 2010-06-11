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


package RVTscripts::RVT_evt;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_evt_stats
                            &RVT_script_evt_generate
                            &RVT_script_evt_report
                        );
       
       
   }


my $RVT_moduleName = "RVT_evt";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "saritar";

use RVTbase::RVT_core;
use RVTscripts::RVT_files;
use Data::Dumper;
use Date::Manip;

use open "IO" => ":encoding(cp1252):utf8";

sub constructor {
   
   my $reportevt = `evtrpt.pl`;
   my $parsevt = `evtparse.pl -h`;

#	print "$reportevt, $parsevt\n";
#
   if (!$reportevt) {
        RVT_log ('ERR', 'RVT_evt not loaded (couldn\'t find evtrpt.pl)');
   }
   if (!$parsevt) {
        RVT_log ('ERR', 'RVT_evt not loaded (couldn\'t find evtparse.pl)');
   }
   return 0 if (!$reportevt || !$parsevt);
   
   $main::RVT_requirements{'evtparse'} = $parsevt;
   $main::RVT_requirements{'evtreport'} = $reportevt;

   $main::RVT_functions{RVT_script_evt_generate } =
   "generates each folder with the information of all evt files allocated in a disk\n
   script evt generate <disk>";
   
   $main::RVT_functions{RVT_script_evt_report } =
   "generates a report of all evt files allocated in a disk\n
   script evt report <disk>";


}

sub RVT_script_evt_generate {

	my $morguepath;
	my ( $disk ) = @_;
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log ('WARNING', 'that is not a disk'); return 0; }

    $morguepath = RVT_get_morguepath($disk);
	if (! $morguepath) { RVT_log ('WARNING', 'there is no path to the morgue!'); return 0};
	my $evtpath= "$morguepath/output/evt/";
	if (! -e $evtpath) {
		my @args = ('mkdir', $evtpath);
		system (@args);
	}

   	my $parsevt = "evtparse.pl";
    my @evtlist = RVT_get_allocfiles('evt$', $disk);
	my $line;
	
	foreach my $f (@evtlist) {
		print "Opening file $f\n";
		my $fpath = RVT_create_folder($evtpath, 'evt');
		print "Results stored on: $fpath\n\n";
		if (!($fpath)) { RVT_log("ERR","Failed to create output directories."); return 0};
		if (!open (META, ">$fpath/RVT_metadata") ) {RVT_log ("ERR", "Failed to create metadata files."); return 0};
		print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		close (META);

#       $fpath="$fpath/contents";
       	#my @args = ('readpst', '-S', '-q', '-cv', '-o', $fpath, $f);
		#if (!open (PEVT, "$parsevt $f |") ) {RVT_log ('ERR',"Error encountered while parsing $f\n"); return 0;
		#}else{
            	#	RVT_log ('NOTICE', "PST parsed: $f\n");
       	#}
		open (PEVT,"-|", "$parsevt", $f) or die "Error: $!";
		binmode (PEVT, ":encoding(cp1252)") || die "Can't binmode to cp1252 encoding\n";
		open (FOUT,">$fpath/report.csv") or die "Error: $!";
		print FOUT "Fecha#Tipo#Usuario#Id. evento#Descripción\n";
		while (<PEVT>) {
			#print Dumper @list;	
			chomp ($_);
			my @field= split ('\|',$_ ) ;
			my $time=ParseDateString("epoch $field[0]");
#			print "$time---";
			print FOUT $time."#".$field[1]."#".$field[2]."#".$field[3]."#".$field[4]."\n";
		}
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	my @args = ('ln', '-s', $evtpath, $morguepath.'/mnt/p00/output_evt');
	system (@args);
	printf ("Finished parsing EVT files. Updating alloc_files...\n");
	RVT_script_files_allocfiles();
	return 1;

}



sub RVT_script_evt_report {

	my $morguepath;
	my ( $disk ) = @_;
	$disk = $main::RVT_level->{tag} unless $disk;
	if (RVT_check_format($disk) ne 'disk') { RVT_log ('WARNING', 'that is not a disk'); return 0; }

	$morguepath = RVT_get_morguepath($disk);
	if (! $morguepath) { RVT_log ('WARNING', 'there is no path to the morgue!'); return 0};
	my $evtpath= "$morguepath/output/evt";
	if (! -e $evtpath) {
		my @args = ('mkdir', $evtpath);
		system (@args);
	}
	my $reportevt = "evtrpt.pl";

	my @evtlist = RVT_get_allocfiles('evt$', $disk);
	my $line;
	foreach my $f (@evtlist) {
		print "opening file $f\n";
		open (PEVT,"-|", "$reportevt", $f) or die "Error: $!";
		binmode (PEVT, ":encoding(cp1252)") || die "Can't binmode to cp1252 encoding\n";
		open (FOUT,">$evtpath/report.csv") or die "Error: $!";
		while (<PEVT>) {	
			print  FOUT $_;
		}
	}
	my @args = ('ln', '-s', $evtpath, $morguepath.'/mnt/p00/output_evt');
	system (@args);
	RVT_script_files_allocfiles();
}

1;  



