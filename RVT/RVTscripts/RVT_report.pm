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
use Date::Manip;
#use open "IN" => ":encoding(cp1252)",
#	"OUT"=> ":utf8";
#use open "IO" => ":encoding(cp1252):utf8";
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_report_search2pdf
                            &RVT_script_report_lnkstats
                            &RVT_script_report_lnk2csv
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
   $main::RVT_functions{RVT_script_report_lnkstats } =  "generates a statistics file with the information of the files\n
      script lnk statistics";
   $main::RVT_functions{RVT_script_report_lnk2csv } =  "generates a final report based on the lnk file\n
Arguments: type (usb|net|local|cdrom|all) , date in format YYYY[DDMM] or a date(+|-) a periof of time\n. 
Ex: script report lnk2csv local 2009\n
Ex: script report lnk2csv usb 2009+2year\n
Ex: script report lnk2csv all today-6months\n
For more information see 'man Date::Manip'";
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
sub RVT_script_report_lnkstats
{

	use open "IO" => ":encoding(cp1252):utf8";
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


sub RVT_script_report_lnk2csv
# Arguments: type, date
## Type: usb,local,cdrom, net, all.
## Date: YYYY[MMDD] or a date+periof of time. Ex: today -1year, 2009 +6months. It does not accept two periods like: 2009 -6months +2days.
{
	use open "IO" => ":encoding(cp1252):utf8";
    	#my ( $ltype, $date, $disk ) =  (@_);
    	my  $ltype =  shift @_;
	my ($date, $disk)= (@_);
	if (!$ltype)  {RVT_log("ERR", "List of arguments invalid."); print_usage_lnk2csv(); return 0}
	print "Tipo: $ltype, Fecha: $date\n";
	
	my $morguepath; my $lpath; my $datef;
	
	$disk = $main::RVT_level->{tag} unless $disk;
	$date="all" unless $date;
	if ( $ltype !~ /^usb$/i and $ltype !~ /^local$/i and $ltype !~ /^cdrom$/i and $ltype !~ /^net$/i and $ltype !~ /^all$/i)  {RVT_log ("ERR", "Argument must be: usb | local | cdrom | net | all"); return 0 };

	my (@t, $tmin , $tmax, $sep, $interval, $sep);
	if ($date ne "all"){
		if ($date =~ /\+/){
			$sep="+";
			@t  = split ('\+',$date);
			if (scalar(@t) > 2) { RVT_log ("ERR","Error in date interval\n"); return 0;  }
		}elsif ($date =~ /-/){
			$sep="-";
			@t  = split ('-',$date);
			if (scalar(@t) > 2) { RVT_log ("ERR","Error in date interval\n"); return 0;  }
		}# else there is no interval	
		if (@t)
		{	
	   	#	$tmin = $t[0];
	   		if (!($tmin=ParseDate($t[0])) ) { RVT_log ("ERR", "Error in date format: " . $t[0]. " Example: YYYY,YYYYMM, YYDD, YYYYMMDD, etc.\n") ; return 0 };
			if (!(ParseDate($t[1]))){  RVT_log ("ERR", "Error in date format of the interval: " . $t[1]. "\nExample: +2years, -2year, +2yr, +1mon, -8months, -2weeks, -2wk, +8day etc.\nFor more information man see 'Date::Manip'\n") ; return 0
			}else{	$interval= $sep . $t[1] ;}
			if ($date =~ /\+/){
				$tmax = DateCalc($tmin,$interval);
			}else{ # es -
				$tmax = $tmin;
				$tmin = DateCalc ($tmin, $interval);
			}
 			if (!$tmin and !$tmax and ($tmin gt $tmax)){ RVT_log ("ERR", "Error in date interval\n") ; return 0 ;}
			print "Interval: $interval , Max: $tmax, Min: $tmin\n";
		}elsif (!ParseDate($date))  { RVT_log ("ERR", "Error in date format: $date\n") ; return 0  ;}
#		print "date max: $tmax , date min: $tmin\n";
	}
	if (RVT_check_format($disk) ne 'disk') { RVT_log("ERR"," that is not a disk\n\n"); return 0; }
	$morguepath = RVT_get_morguepath($disk);
	if (! $morguepath) { RVT_log ( "ERR", "there is no path to the morgue!\n\n"); return 0 };
	$lpath = $morguepath . "/output/reports/lnk";
	if (! -e $lpath){
		mkpath ($lpath);
	}
	if (!open (FLNK, "<$morguepath/output/lnk/$disk"."_lnk.csv")) { RVT_log ("ERR","The lnk file does not exist\n");  return 0;} 
	#if (!open (FLNK, "<:encoding(cp1252)","$morguepath/output/lnk/$disk"."_lnk.csv")) { RVT_log ("ERR","The lnk file does not exist\n");  return 0;} 
#######################	
	binmode (FLNK,":encoding(cp1252)") || die "Can't binmode to cp1252 encoding\n";	
#######################	
	my @file = <FLNK>;
	my @list; my @field ; my @line; my $name; 
	if ($ltype =~ /^local$/i){
		@list = grep (/;Fixed \(Hard Disk\);/,@file)
	}elsif ($ltype =~ /^usb$/i ) {
		@list = grep (/;Removable \(Floppy,Zip,USB,etc.\);/,@file);
	}elsif ($ltype =~ /^net$/i) {
		@list = grep (/;Network;/,@file);
	}elsif ($ltype =~ /^cdrom$/i){
	 	@list = grep (/;CD-ROM;/,@file);
	}
	elsif ($ltype=~ /^all$/i) {@list=@file;} # All devices 
	my %lnks; my $p; my $basename; my $dateact; my $diffdates; my $err;
	foreach my $l (@list)
	{
       		chomp($l);
	        @field=split(/;/,$l);
		$name=$field[7];
		if ( ( $name  !~ /^$/ ) and  ($date eq "all"  or  ( !($interval)   and  ($field[1] =~ /^$date/) ) or ($interval and Date_Cmp($field[1],$tmin) >= 0   and Date_Cmp($field[1],$tmax) <= 0  )  ) )
		{ # si el nombre del fichero o directorio no contiene nada (xej: es un acceso directo a E: no aparece
			$p->{mtime}=convertepochsec ($field[0]);
			$p->{atime}=convertepochsec ($field[1]);
			$p->{ctime}=convertepochsec ($field[2]);
			$p->{device}=$field[3];
			$p->{volid}=$field[4];
			$p->{volume}=$field[5];
			$p->{name}=$name;
			$p->{path}=$field[8];
			$p->{size}=$field[9];
			if ($ltype !~ /^all$/i){ # if all types are listed there is another column: Device Type
				$basename=$name.";".$p->{volume}.";".$p->{path}.";". $p->{volid}.";". $p->{size};
			}else { $basename=$name.";" . $p->{volume}. ";" . $p->{path} . ";" . $p->{volid}. ";". $p->{device}.";". $p->{size}; }

			if (! exists $lnks{$basename})	{
				$lnks{$basename}=$p->{mtime}.";".$p->{atime}.";". $p->{ctime} ;
			}else
			{
				my @fexists=split (/;/,$lnks{$basename});
				if ($fexists[0] < $p->{mtime}){
					$lnks{$basename}=$p->{mtime}.";".$p->{atime}.";". $p->{ctime} ;
				}
				elsif ($fexists[1] < $p->{atime} ){
					$lnks{$basename}=$p->{mtime}.";".$p->{atime}.";". $p->{ctime} ;
				}
				elsif ($fexists[2] < $p->{ctime} ){
					$lnks{$basename}=$p->{mtime}.";".$p->{atime}.";". $p->{ctime} ;
				}
			}
		}
	}
	my @dates;my @datesf; my @tm; my $fileout;
	
	if (scalar(%lnks) > 0){ 
		my $fileout=$lpath ."/". $disk  ."_lnk_" . "$ltype" . "_$date".".csv";
		if (!open (FREP,">$fileout" )) {RVT_log ("ERR","The file report can not be created"); return 0;}
		else {print "All results exported to $fileout successfully\n" }
		if ($ltype =~ /all/i){ #print headers
                  	print FREP "Fecha de última modificación;Fecha de último acceso;Fecha de creación;Fichero o directorio;Unidad;Ruta;Identificador de volumen;Dispositivo;Tamaño
";            }else{
                     	print FREP "Fecha de última modificación;Fecha de último acceso;Fecha de creación;Fichero o directorio;Unidad;Ruta;Identificador de volumen;Tamaño
";
                }
		foreach my $ln (keys %lnks)
		{
			@dates = split(/;/,$lnks{$ln});
			for (my $i=0;$i<3;$i++){
				$tm[$i] = localtime ($dates[$i]);
			}
			printf FREP ("%02d/%02d/%04d %02d:%02d:%02d;%02d/%02d/%04d %02d:%02d:%02d;%02d/%02d/%04d %02d:%02d:%02d;$ln\n", $tm[0]->mday, $tm[0]->mon +1, $tm[0]->year + 1900,$tm[0]->hour, $tm[0]->min, $tm[0]->sec, $tm[1]->mday, $tm[1]->mon +1, $tm[1]->year + 1900,$tm[1]->hour, $tm[1]->min, $tm[1]->sec, $tm[2]->mday, $tm[2]->mon +1, $tm[2]->year + 1900, $tm[2]->hour, $tm[2]->min, $tm[2]->sec) ;
	
		}
	}else {print "There is no results for the arguments given\n";}

}
sub convertepoch 
{
	my $epoch; my $yyyy; my $mm; my $dd; my $date;
#	if ($_ !~ /1\d[0-6]\d{5}/) #descartamos las fechas anteriores a 1970
	if ($_ !~ /1\d[0-8]\d{5}/ || $_ !~ /19\d[0-6]\d[0-9]/ ) #descartamos las fechas anteriores a 1970
	{
		($yyyy, $mm, $dd) = ( $_[0] =~ /(\d{4})(\d{2})(\d{2})/) ; #date is YYYYMMDD the rest is ignored
		$epoch = eval {timelocal(0,0,0,$dd, $mm-1, $yyyy)};
		$epoch = 0 if ($@);
	}else{ 
		$epoch = 0 
	}
	return $epoch;

}

sub convertepochsec
{
	my $epoch; my $yyyy; my $mm; my $dd; my $hh; my $min; my $sec; my $date;
#	if ($_ !~ /1\d[0-6]\d{5}/) #descartamos las fechas anteriores a 1970
	if ($_ !~ /1\d[0-8]\d{5}/ || $_ !~ /19\d[0-6]\d[0-9]/ ) #descartamos las fechas anteriores a 1970
	{
		($yyyy, $mm, $dd,$hh, $min, $sec ) = ( $_[0] =~ /(\d{4})(\d{2})(\d{2}) ?(\d{2}):(\d{2}):(\d{2})/) ; #date is YYYYMMDD HH:MM:SS form or YYYYMMDDHH:MM:SS 
		$epoch = eval {timelocal($sec,$min,$hh,$dd, $mm-1, $yyyy)};
		$epoch = 0 if ($@);
	}else{ 
		$epoch = 0 
	}
	return $epoch;

}

sub print_usage_lnk2csv 
{
	print "script report lnk2csv [device] {date}\n\tdevice\t\tmust be one the following values: usb, net, local, cdrom or all\n\tdate\t\toptional. Must be in format YYYY[DDMM] or a date (+|-) a periof of time without blank spaces.\n\nExamples:\n\tscript report lnk2csv local 2009\n\tscript report lnk2csv usb 2009+2year\n\tscript report lnk2csv all today-6months\n\tscript report lnk2csv all 20090520+15day\n\tscript report lnk2csv cdrom 200805\n\nFor more information see 'man Date::Manip'\n";
}
1; 
