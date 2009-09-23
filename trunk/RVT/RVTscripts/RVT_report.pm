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
use File::Path qw(mkpath);
use Time::Local;
use Time::localtime;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_report_search2pdf
                            &RVT_script_report_lnk
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
   $main::RVT_functions{RVT_script_report_lnk } =  "generates a statistics file with the information of the files\n
      script lnk statistics";

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
sub RVT_script_report_lnk
{

	my ( $disk ) = @_;
	my $morguepath;
	my @log;
	
	$disk = $main::RVT_level->{tag} unless $disk;
	if (RVT_check_format($disk) ne 'disk') { RVT_log("ERR"," that is not a disk\n\n"); return 0; }
	$morguepath = RVT_get_morguepath($disk);
	if (! $morguepath) { RVT_log ( "ERR", "there is no path to the morgue!\n\n"); return 0};

	my $lnkpath= "$morguepath/output/reports/lnk";
	if (! -e $lnkpath){
		mkpath ($lnkpath);
#	        my @args = ('mkdir', $lnkpath);
#		system (@args);
	}
	
    	if (! -d $lnkpath) { RVT_log ( 'ERR',  "there is no path to $lnkpath!\n\n"); return 0};

	if (!open (FOUT, ">$lnkpath/$disk" . "_lnkstats.txt") ) { RVT_log ("ERR","The report file can not be opened for writing\n");  return 0;   };
	
	###########################################

	if (!open (FLNK, "<$morguepath/output/lnk/$disk\_lnk.csv")) { RVT_log ("ERR","The lnk file does not exist\n");  return 0;} 
	##100999-01-1_lnk.csv 

	my %resources; my %removables; my %cdroms; my %volumes; my %dates;
	my @field; 
	my $yyyy; my $mm; my $dd; my $epoch_access; my $epoch_modif; my $epoch_i; my $tm;
	my %users; my %users_date_rec; my %users_date_old; my $l; my $u; my $tm_rec; my $tm_old;
	
	my @file = <FLNK>;
	my @lusers = grep (/\/Documents and Settings\// || /\/Users\//,@file);
	
	
#	my @lusers = map {(split /;/)[1,8] } grep (/\/Documents and Settings\// || /\/Users\//,@file); #nos quedamos con el primer y la novena columna
	## Para enumerar los usuarios sólamente se accede la fichero de lnks generado anteriormente, NO se mira en el punto de montaje de manera que puede haber usuarios en los lnks que ya no existan en el sistema
	push (@log,"###################################################\n");
	push (@log, "#####################Users#########################\n");
	push (@log, "###################################################\n");
	foreach $l ( @lusers)
	{
        	chomp($l);
	        @field=split(/;/,$l);
	 	
#		if ($l =~ /;\/Documents and Settings\/(.+?)\//ig || $l =~ /;\/Users\/(.+?)\/?/ig ) 
		if ($field[8] =~ /\/Documents and Settings\/(.+?)\//ig || $field[8] =~ /\/Users\/(.+?)\//ig ) 
	 	{
			$u=$1;
			$users{$u}++;
			
			$epoch_access= convertepoch($field[1]);
			if (! exists ($users_date_old{$u})){
				$users_date_old{$u}=$epoch_access;
				$users_date_rec{$u}=$epoch_access;
			}else{
				if ($epoch_access>$users_date_rec{$u}){
					$users_date_rec{$u}=$epoch_access;
				}elsif ($epoch_access <$users_date_old{$u}  and  $epoch_access > 1){
					$users_date_old{$u}=$epoch_access;
				}
				
			}

		}
	}
	foreach my $u ( keys %users)
	{
		$tm_old = localtime ($users_date_old{$u});	 		
		$tm_rec= localtime ($users_date_rec{$u});	 		
		push (@log,"____________________________________\n");
		push (@log,"$u\n");
		push (@log,"$users{$u} accesos directos\n");
		push (@log, sprintf ("Fecha más reciente: %02d/%02d/%04d\n",$tm_rec->mday, $tm_rec->mon +1, $tm_rec->year + 1900 ));
		push (@log, sprintf ("Fecha más antigua: %02d/%02d/%04d\n\n", $tm_old->mday, $tm_old->mon +1, $tm_old->year + 1900));
	}
	my @llocal = grep (/Fixed \(Hard Disk\)/,@file);
	my @lremovable = grep (/Removable/,@file);
	my @lnetwork = grep (/Network/,@file);
	my @lcdrom = grep (/CD-ROM/,@file);
	
	push (@log,"\n###################################################\n");
	push (@log,"## porcentaje de lnks por medio  ##################\n");
	push (@log,"###################################################\n");
	push (@log,sprintf ( "Número de links en local: %3d\n",  scalar (@llocal)));
	push (@log,sprintf ("Número de links en dispositivos externos: %3d\n",  scalar (@lremovable)));
	push (@log,sprintf ("Número de links en red: %3d\n",  scalar (@lnetwork)));
	push (@log,sprintf ("Número de links en cd-rom: %3d\n",  scalar (@lcdrom)));
	push (@log,sprintf ("Total: %3d\n",scalar(@file)));

	foreach my $l (@llocal)
	{
        	chomp($l);
	        @field=split(/;/,$l);
		$epoch_access = convertepoch ($field[1]);	
		my $vol="$field[6]/$field[5]";

		if (exists($volumes{$vol}))
		{
			$volumes{$vol}++;
			$epoch_i = $dates{$vol};
			if ($epoch_access > $epoch_i)
			{
				$dates{$vol}=$epoch_access;
			}
		}
		else
		{
			$volumes{$vol}=1;
			$dates{$vol}=$epoch_access;
		}
	}
	push(@log, "Unidades locales:\n");
	foreach my $i( sort { $dates{$a}  <=> $dates{$b}} keys %dates )
	{
		$tm = localtime ($dates{$i});	 		
		push (@log,sprintf ("\tLa unidad $i tiene $volumes{$i} accesos directos, accedida el %02d/%02d/%04d\n", $tm->mday, $tm->mon +1, $tm->year + 1900));
		delete $dates{$i};
	}

	foreach my $l (@lremovable)
	{
        	chomp($l);
	        @field=split(/;/,$l);
	
		$epoch_access = convertepoch($field[1]);
		
		my $device="$field[6]/$field[4]";	
		if (exists($removables{$device}))
		{
			$removables{$device}++;
			$epoch_i = $dates{$device};
			if ($epoch_access > $epoch_i)
			{
				$dates{$device}=$epoch_access;
			}
		}
	        else
	        {
			$removables{$device}=1;
			$dates{$device}=$epoch_access;
                }
	}
	push (@log, "\nUnidades externas:\n");
	foreach my $i( sort { $dates{$a}  <=> $dates{$b}} keys %dates )
	{
		$tm = localtime ($dates{$i});	 		
		push (@log,sprintf ("\tLa unidad $i tiene $removables{$i} accesos directos, último acceso el %02d/%02d/%04d\n", $tm->mday, $tm->mon +1, $tm->year + 1900));
		delete ($dates{$i});
	}
	foreach my $l (@lnetwork)
	{
        	chomp($l);
	        @field=split(/;/,$l);
		$epoch_access = convertepoch ($field[1]);

		if (exists($resources{$field[4]}))
		{
			$resources{$field[4]}++;
			$epoch_i = $dates{$field[4]};
			if ($epoch_access > $epoch_i)
			{
				$dates{$field[4]}=$epoch_access;
			}
		}
	        else
	        {
			$resources{$field[4]}=1;
			$dates{$field[4]}=$epoch_access;
	        }
	}
	
	push (@log, "\nRecursos de red:\n");
	foreach my $i( sort { $dates{$a}  <=> $dates{$b}} keys %dates )
	{
		$tm = localtime ($dates{$i});	 		
		push (@log,sprintf ("\tEl recurso de red $i tiene $resources{$i} accesos directos, último acceso el %02d/%02d/%04d\n", $tm->mday, $tm->mon +1, $tm->year + 1900));
		delete $dates{$i};
	}

	foreach my $l (@lcdrom)
	{
        	chomp($l);
	        @field=split(/;/,$l);
		$epoch_modif= convertepoch($field[0]);
		
		my $device="$field[6]/$field[4]";	
		if (exists($cdroms{$device}))
		{
			$cdroms{$device}++;
			$epoch_i = $dates{$device};
			if ($epoch_modif > $epoch_i)
			{
				$dates{$device}=$epoch_modif;
			}
		}
	       else
	        {
			$cdroms{$device}=1;
			$dates{$device}=$epoch_modif;
                }
	}
	
	push (@log, "\nCD-ROMs:\n");
	foreach my $i( sort { $dates{$a}  <=> $dates{$b}} keys %dates )
	{
		$tm = localtime ($dates{$i});	 		
		push(@log,sprintf ("\tEl CD-ROM $i tiene $cdroms{$i} accesos directos, modificado el %02d/%02d/%04d\n", $tm->mday, $tm->mon +1, $tm->year + 1900));
		delete $dates{$i};
	}
	push (@log, "\n####################################################\n");
	push (@log, "### porcentaje de lnks por tipo de fichero #########\n");
	push (@log, "####################################################\n");

	my %types = ("videos", "documentos","imagenes", "audios");
	my %videos=("mpeg",0,"avi",0,"mpg",0,"mp4",0,"mov",0,"mkv",0,"asf",0,"div",0,"divx",0,"qt",0,"rpm",0,"ogm",0,"vcd",0,"svcd");
	my %documents=("doc",0,"docx",0, "xls",0,"xlsx",0,"csv",0,"pdf",0,"ppt",0,"pptx",0);
	my %images=("png",0 ,"jpg",0,"jpeg",0,"gif",0,"bmp",0);
	my %audios=("mp3",0,"wav",0, "mp1",0,"mp2",0, "ogg",0, "cda",0, "mid",0, "midi",0, "aif",0, "ra",0, "voc",0, "wma",0, "ac3",0, "au",0, "mcf",0, "mka");
	
	my $other;
	my @file_names = map {(split /;/)[7] } @file;

	foreach my $i (keys %videos){
		 $videos{$i}+= scalar grep (/\.$i$/i,@file_names);
	}
	foreach my $i (keys %documents){
		 $documents{$i}+= scalar grep (/\.$i$/i,@file_names) ;
	}
	foreach my $i (keys %images){
		 $images{$i}+= scalar grep (/\.$i$/i,@file_names) ;
	}
	foreach my $i (keys %audios){
		 $audios{$i}+= scalar grep (/\.$i$/i,@file_names) ;
	}

	foreach my $i (keys %videos){
		$types{"videos"} += $videos{$i};
		push (@log,sprintf ("\tHay %2d archivos de video con extensión $i\n", $videos{$i}));
	}
	push (@log,sprintf ("Total de archivos de video: %2d\n\n", $types{"video"})) ;
	foreach my $i (keys %documents){
		$types{"documentos"} += $documents{$i};
		push(@log,sprintf ("\tHay %2d documentos con extensión $i\n", $documents{$i}));
	}
	push (@log, "Total de documentos: $types{documentos}\n\n") ;
	
	foreach my $i (keys %images){
		$types{"imagenes"} += $images{$i};
		push(@log,sprintf ("\tHay %2d imágenes con extensión $i\n", $images{$i}));
	}
	push (@log, sprintf ("Total de imágenes: %2d\n\n", $types{"imagenes"})) ;
	
	foreach my $i (keys %audios){
		$types{"audios"} += $audios{$i};
		push (@log,sprintf ("\tHay %2d ficheros de audio con extensión $i\n", $audios{$i}));
	}
	push(@log,sprintf ("Total de ficheros de audio: %2d\n\n", $types{"audios"})) ;
	foreach my $t (keys %types)
	{
		$other += $types{$t};
		push (@log,sprintf ("El porcentaje de accesos a $t de %2d %\n",$types{$t} * 100 / scalar @file_names ) ) if ($types{$t} > 0 ) ;
	
	}
	push (@log,sprintf ("El porcentaje de accesos a otros ficheros o directorios es del %2d %\n",(scalar @file_names - $other ) * 100 / scalar @file_names)) if ($other > 0);

	foreach my $l (@log)
	{
		printf ($l);
		printf FOUT ($l);
	}	
	
	return 1;
}
sub convertepoch 
{
	my $epoch; my $yyyy; my $mm; my $dd; my $date;
#	if ($_ !~ /1\d[0-6]\d{5}/) #descartamos las fechas que anteriores a 1970
	if ($_ !~ /1\d[0-8]\d{5}/ || $_ !~ /19\d[0-6]\d[0-9]/ ) #descartamos las fechas anteriores a 1970
	{
		($yyyy, $mm, $dd) = ( $_[0] =~ /(\d{4})(\d{2})(\d{2})/) ; #date is YYYYMMDD HH:MM:SS form
		$epoch = eval {timelocal(0,0,0,$dd, $mm-1, $yyyy)};
		$epoch = 0 if ($@);
	}else{ 
		$epoch = 0 
	}
	return $epoch;

}


1; 
