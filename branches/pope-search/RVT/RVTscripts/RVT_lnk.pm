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


package RVTscripts::RVT_lnk;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_lnk_generate
                        );
   }


use RVTbase::RVT_core;
use Data::Dumper;
use RVTscripts::RVT_files;

my $RVT_moduleName = "RVT_lnk";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "saritar";


my $script="/usr/local/bin/recursos.pl";
my $DUMPLNK="dumplnk.pl";

my $morguepath;
sub constructor {
   
   my $dumplnk = `dumplnk.pl -V`;
   
   if (!$dumplnk) {
        RVT_log ('ERR', 'RVT_lnk not loaded (couldn\'t find dumplnk)');
        return;
   }
   
   $main::RVT_requirements{'dumplnk'} = $dumplnk;
   
   $main::RVT_functions{RVT_script_lnk_generate } = 
   "generates a file (csv) with the information of all lnk files allocated in a disk\n
   script lnk generate";
}



sub RVT_script_lnk_generate
{
	my ( $disk ) = @_;
	$disk = $main::RVT_level->{tag} unless $disk;
	if (RVT_check_format($disk) ne 'disk') { RVT_log ('WARNING', 'that is not a disk'); return 0; }

	my $morguepath = RVT_get_morguepath($disk);
	if (! $morguepath) { RVT_log ('WARNING', 'there is no path to the morgue!'); return 0};
	my $lnkpath= "$morguepath/output/lnk/";
	if (! -e $lnkpath){
	    my @args = ('mkdir', $lnkpath);
	    system (@args);
	}
	
	my $mntpath= "$morguepath/mnt";
	if (! -e $mntpath){
		RVT_log ('WARNING', 'Couldn\'t find the path to mounted partitions');
		return 0;
	}

	my $fout="$lnkpath/$disk" . "_lnk.csv";
	my @lnklist = RVT_get_allocfiles('\.lnk$', $disk) or die "FATAL: $!";
	
	if (! scalar (@lnklist) > 0){
		RVT_log ('WARNING', 'No lnk file has been founded in allocfiles');
		return 0;
	}
	printf ("Se han encontrado %2d archivos de lnk",scalar (@lnklist));
	
	if (-e $fout){
		RVT_log ('WARNING', "File $fout already exists. It\'s gonna be overwritten");
		unlink ($fout);
	}

	if   (! open (FOUT,">$fout" )) { RVT_log ("ERR", "$!"); return 0; }
	foreach my $lnk (@lnklist) {
#		open (FDUMP, "$DUMPLNK '$lnk' | cat -A |") or die "Error: $!";
#		open (FDUMP,'$DUMPLNK "$lnk"|' ) or die "Error: $!";
		#binmode (FDUMP,">:utf8");
#		my $file=`$DUMPLNK "$lnk"`;		
		open (FDUMP,"-|", "$DUMPLNK", $lnk) or die "Error: $!";
		#binmode (FDUMP,":encoding(cp1252)") || die "Can't binmode to cp1252 encoding\n";
		#binmode (FDUMP,":crlf") || die "Can't binmode to cp1252 encoding\n";
		#my @file=<FDUMP>;
		#TODO: do a proper conversion
		#$file =~ s/\^@//g;
		#$file =~ s/\$+$//;
		#TODO END
		while (<FDUMP>){
		next if ($_ =~ /Invalid Lnk file header/ );
		#next if ($file =~ /Invalid Lnk file header/ );
		#print FOUT $file;
		print FOUT $_;
		}
		
	}
	close FOUT;

	printf ("Finished parsing LNK files. Updating alloc_files...\n");
	RVT_script_files_allocfiles();
	return 1;
}


1;  

