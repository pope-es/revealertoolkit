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


package RVTscripts::RVT_report; 

use strict;
use File::Temp qw ( tempfile );
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_report_search2pdf
                        );
       
       
   }


my $RVT_moduleName = "RVT_report";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "brajan";

use RVTbase::RVT_core;
use Data::Dumper;

sub constructor {

   my $check = `pdflatex -v`;
   
   if (!$check) {
        RVT_log ('ERR', 'RVT_report not loaded (couldn\'t find pdflatex)');
        return;
   }


   $main::RVT_functions{RVT_script_report_search2pdf} = "Creates a LaTex and pdf file, removing non-printable characters,for each ibusq-type-file generated from the keyword searches proccess\n   report search2pdf";
}

sub RVT_script_report_search2pdf {

	my $disk = $main::RVT_level->{tag};
    if (RVT_check_format($disk) ne 'disk') {  RVT_log ( 'ERR',  "that is not a disk\n\n"); return 0; }

	my $morguepath = RVT_get_morguepath($disk);
    if (! $morguepath) { RVT_log ( 'ERR',  "there is no path to the morgue!\n\n"); return 0};
    
    my $searchespath = "$morguepath/output/searches";
    my $reportspath = "$morguepath/output/reports";
    mkdir $reportspath unless (-e $reportspath);
    if (! -d $reportspath) { RVT_log ( 'ERR',  "there is no path to $reportspath!\n\n"); return 0};
    
    my $reportssearchespath = "$morguepath/output/reports/searches";    
    mkdir $reportssearchespath unless (-e $reportssearchespath);
    if (! -d $reportssearchespath) { RVT_log ( 'ERR',  "there is no path to $reportssearchespath!\n\n"); return 0};


	opendir DH, $searchespath or RVT_log ( 'CRIT',  "Cannot open $searchespath: $!");
	while (my $ibfile = readdir DH) 
	{
		next unless $ibfile =~ /^ibusq_(.*)-\d\d$/;
		my $key = $1;

		$_=$key;
		s/-/./g;
		my $key2 = $_; 

		my $filename = "$searchespath"."/"."$ibfile"; #?path_to_ibusq_file
		my $fileout = "$reportssearchespath"."/"."$ibfile.tex"; #  .tex filename 

		open(OUT, ">$fileout") or RVT_log ( 'CRIT',  "No puedo abrir $fileout!\n");
		open(IN, "<$filename") or RVT_log ( 'CRIT',  "No puedo abrir $filename!\n");

		# $sapcekeyword will be a variable with spaces (" ") between the letters

		my @array;
		for (my $i=0; $i<(length($key));$i++)     
		 {
			push(@array, substr($key,1*$i,1));
		 }
		
		my $spacekeyword="@array"; 
		$_=$spacekeyword;
		s/-/ /g;
		my $spacekeyword2=$_; # if there is a "-" into the word it's raplaced with a space " "

		# $tmpkey will be a variable with dots "." between the letters
		my $tmpkey; 
		for (my $i=0; $i<(length($key));$i++)
		{
		  $tmpkey=$tmpkey."\\.+".$array[$i];     # tmpkey contiene \.+p\.+a\.+l\.+a\.+b\.+r\.+a\.+_\.+c\.+l\.+a\.+v\.+e
		}
		
		$_=$tmpkey;
		s/-/./g;
		my $tmpkey2=$_;
		
		@array = (); # reinicia el array

		# generation of the .tex file
		# preamble commands
		#my $latexheader="Blind image search of keyword: ";
		my $latexheader="Busquedas ciegas en disco. Palabra clave: ";
		
		
		print OUT "\\documentclass[a4paper,11pt,oneside]{report}\n";
		print OUT "\\usepackage[spanish]{babel}\n";
		print OUT "\\usepackage[utf8]{inputenc}\n";
		print OUT "\\usepackage[pdftex]{color,graphicx}\n";
		print OUT "\\usepackage[pdftex,colorlinks]{hyperref}\n";
		print OUT "\\usepackage{fancyvrb}\n";
		print OUT "\\begin{document}\n";
		print OUT "\n";
		print OUT "\\section*{$latexheader \\emph{$key2}}\n";
		print OUT "\\begin{Verbatim}[commandchars=\\\\\\{\\}]\n";
		
		
		
		# non-printable characters substitution
		# \x00-\x09 control chars 
		# \x0B-\x1F resto of control chars (skiping x0A = return or newline)
		# \x7F-\xFF rest of non-ascii >DEL 
		#?this chars are replaced for LaTex compatibility : \ { }
		
		while(<IN>) { 	
			# This is a 72 chars?hard wrap of the file
			# IF the keyword is broken, it will not be highlighted at the finel latex/PDF output
			# this will be fixed in the future
			for (my $i=0; $i<(length($_)/72);$i++) {
				push(@array, substr($_,72*$i,72));
			}
			foreach my $block (@array) {
				$_ = $block;
				chomp;# removes \n if any
				#print $tmpfileout "$block\n"; 
				s/[\x00-\x09,\x0B-\x1F,\x7F-\xFF]/./g; # replaced with a dot "."
				s/\\/\//g; # replace \ by /
				s/\{/\(/g; # replace { by (
				s/\}/\)/g; # replace } by )
				
				# keyword replacement: \colorbox{green}{keyword}
				# this will highlight the word at the LaTex/pdf file
				
				s/$key2/\\colorbox{green}{$key2}/ig;
				s/($tmpkey2)/\\colorbox{green}{$1}/ig;
				s/$spacekeyword2/\\colorbox{green}{$spacekeyword2}/ig;				
				
				print OUT "$_\n";
			}
			@array = ();
		}

		# last lines of LaTex document

		print OUT "\\end{Verbatim}\n";
		print OUT "\n";

		print OUT "\\end{document}\n";


		# cerramos ficheros

		close (OUT);
		close(IN);

		# pdf file compilation using pdflatex

		print "pdflatex","-interaction=batchmode","-output-directory", "$reportssearchespath", "$fileout";
		system "pdflatex","-interaction=batchmode","-output-directory", "$reportssearchespath", "$fileout";

		print "$fileout\n";

	}
	
	# LaTex temporary files deletion
	unlink ( <$reportssearchespath/*.aux>,  <$reportssearchespath/*.out>,  <$reportssearchespath/*.log>, <$reportssearchespath/*.tex> );
	
}

1; 