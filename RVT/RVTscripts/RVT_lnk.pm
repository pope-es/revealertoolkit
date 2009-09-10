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

#my @videos=("mpeg", "avi", "mpg", "mp4", "mov", "mkv", "asf", "div", "divx", "qt", "rpm", "ogm", "vcd", "svcd");
#my @documentos=("doc", "docx", "xls", "xlsx", "csv", "pdf", "ppt", "pptx");
#my @imagenes=("png","jpg","jpeg","gif","bmp");
#my @audio=("mp3","wav", "mp1","mp2", "ogg", "cda", "mid", "midi", "aif", "ra", "voc", "wma", "ac3", "au", "mcf", "mka");

my $script="/usr/local/bin/recursos.pl";
my $DUMPLNK="dumplnk.pl";

my @pathusers=("Documents and Settings","Users");
my $morguepath;
sub constructor {
   
   my $dumplnk = `dumplnk.pl -V`;
   my $fstrings = `f-strings -h`;   
   
   if (!$dumplnk) {
        RVT_log ('ERR', 'RVT_lnk not loaded (couldn\'t find dumplnk)');
        return;
   }
   
   if (!$fstrings) {
        RVT_log ('ERR', 'RVT_lnk not loaded (couldn\'t find f-strings)');
        return;
   }
   
   $main::RVT_requirements{'dumplnk'} = $dumplnk;
   
   $main::RVT_functions{RVT_script_lnk_generate } = 
   "generates a file (csv) with the information of all lnk files allocated in a disk\n
   script lnk generate";
   #$main::RVT_functions{RVT_script_lnk_statistics } = 
   #"generates a statistics file with the information of the files\n
   #   script lnk statistics";
}



sub RVT_script_lnk_generate
{
	my ( $disk ) = @_;
	$disk = $main::RVT_level->{tag} unless $disk;
	if (RVT_check_format($disk) ne 'disk') { RVT_log ('WARNING', 'that is not a disk'); return 0; }

	$morguepath = RVT_get_morguepath($disk);
	if (! $morguepath) { RVT_log ('WARNING', 'there is no path to the morgue!'); return 0};
	my $lnkpath= "$morguepath/output/lnk";
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
	
	if (-e $fout){
		RVT_log ('WARNING', 'File lnk.csv already exists. It\'s gonna be overwritten');
		unlink ($fout);
	}

    open (FOUT, ">>$fout" ) or die "Error: $!";
	foreach my $lnk (@lnklist) {
		open (FDUMP, "$DUMPLNK '$lnk' | cat -A |") or die "Error: $!";
		my $file=<FDUMP>;
		close FDUMP;
		#TODO: do a proper conversion
		$file =~ s/\^@//g;
		$file =~ s/\$+$//mg;
		#TODO END
		next if ($file =~ /Invalid Lnk file header/ );
		print FOUT $file;
	}
	close FOUT;
	
	return 1;
}


sub RVT_script_lnk_statistics
{
    # not ready yet
    return;
    
	my ( $disk ) = @_;

	$disk = $main::RVT_level->{tag} unless $disk;
	if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
	$morguepath = RVT_get_morguepath($disk);
	if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

	my $lnkpath= "$morguepath/output/lnk";
	if (! -e $lnkpath){
	        my @args = ('mkdir', $lnkpath);
		system (@args);
	}
	if (! -e $script  ){
	        print "El programa $script no existe\n";
		return 0;
	}
	if(! -X $script) {
		print "El programa $script no tiene permisos de ejecución\n";
		return 0;
	}	
	my $mntpath= "$morguepath/mnt";
        if (! -e $mntpath){
		print "Error la partición no está montada\n";
		return 0;
        }
	my $ad = RVT_split_diskname($disk);
	my %parts = %{$main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
	my $partition;
	my $mydocs;
	foreach $partition ( keys %parts)
	{
		if (-e "$mntpath/p$partition/$pathusers[0]"){
			$mydocs="$pathusers[0]"
		}elsif (-e "$mntpath/p$partition/$pathusers[1]") {
			$mydocs="$pathusers[1]"
		}else{	
			print "No existe la ruta de $pathusers[0] ni $pathusers[1]\n";
			next;
		}
		
	}
	my @lnklist = RVT_get_allocfiles('\.lnk$', $disk) or die "FATAL: $!";
	
	return 1;
}


1;  

