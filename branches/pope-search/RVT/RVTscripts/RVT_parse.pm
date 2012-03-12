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

package RVTscripts::RVT_parse;  

use strict;
#use warnings;

BEGIN {
   use Exporter   ();
   our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

   $VERSION     = 1.00;

   @ISA         = qw(Exporter);
   @EXPORT      = qw(   &constructor
						&RVT_script_parse_pff
						&RVT_script_parse_bkf
						&RVT_script_parse_zip
						&RVT_script_parse_rar
						&RVT_script_parse_pdf
						&RVT_script_parse_lnk
						&RVT_script_parse_evt
						&RVT_script_parse_text
						&RVT_script_parse_search_launch
						&RVT_script_parse_search_export
					);
}

# XX_TODO:
# - pdftotext nos ha dicho alguna vez "Error: Incorrect password". Hay que mirar cómo darle un pass y LOG de los PDFs cifrados
# - LOG de zips y rar cifrados
# - LOG de office cifrados?

my $RVT_moduleName = "RVT_parse";
my $RVT_moduleVersion = "1.1";
my $RVT_moduleAuthor = "Pope";

# Changelog:
# 1.1 - 
# 1.0 - Initial release. Messy!

use RVTbase::RVT_core;
use RVTscripts::RVT_files;
use File::Copy;
use File::Copy::Recursive qw (dircopy);
use File::Path qw(mkpath);
use File::Basename;
use File::Find;
use Data::Dumper;
use Date::Manip;

sub constructor {
   
   my $pdftotext = `pdftotext -v 2>&1`;
   my $pffexport = `pffexport -V`;
   my $mtftar = `mtftar 2>&1`;
   my $unzip = `unzip -v`;
   my $unrar = `unrar --help`;
   my $fstrings = `f-strings -h`;
   my $lnkparse = `lnk-parse-1.0.pl`;
   my $evtparse = `evtparse.pl`;
   
   if (!$pdftotext) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find pdftotext)');
        return;
   }
   if (!$pffexport) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find pffexport)');
        return;
   }
   if (!$mtftar) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find mtftar)');
        return;
   }
      if (!$unzip) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find unzip)');
        return;
   }
      if (!$unrar) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find unrar)');
        return;
   }
      if (!$fstrings) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find f-strings, please locate in tools directory, compile (gcc f-strings.c -o f-strings) and copy to /usr/local/bin or somewhere in your path)');
        return;
   }
      if (!$lnkparse) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find Jacob Cunningham\'s lnk-parse-1.0.pl, please locate in tools directory and copy to /usr/local/bin or somewhere in your path)');
        return;
   }
      if (!$evtparse) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find Harlan Carvey\'s evtparse.pl, please locate in tools directory and copy to /usr/local/bin or somewhere in your path)');
        return;
   }



   $main::RVT_requirements{'pffexport'} = $pffexport;
   $main::RVT_requirements{'pdftotext'} = $pdftotext;
   $main::RVT_requirements{'mtftar'} = $mtftar;
   $main::RVT_requirements{'unzip'} = $unzip;
   $main::RVT_requirements{'unrar'} = $unrar;
   $main::RVT_requirements{'fstrings'} = $fstrings;
   $main::RVT_requirements{'lnkparse'} = $lnkparse;
   $main::RVT_requirements{'evtparse'} = $evtparse;

   $main::RVT_functions{RVT_script_parse_pff } = "Parses all PST, OST and PAB files found on the partition using libpff\n
                                                    script parse pff <partition>";
   $main::RVT_functions{RVT_script_parse_bkf } = "Extracts contents from Windows backup (.bkf) files\n
                                                    script parse bkf <partition>";
   $main::RVT_functions{RVT_script_parse_zip } = "Extracts contents from ZIP, ODT and OOXML files\n
                                                    script parse zip <partition>";
   $main::RVT_functions{RVT_script_parse_rar } = "Extracts contents from RAR archives\n
                                                    script parse rar <partition>";
   $main::RVT_functions{RVT_script_parse_pdf } = "Extracts text from PDFs using pdftotext\n
                                                    script parse pdf <partition>";
   $main::RVT_functions{RVT_script_parse_lnk } = "Parses Windows LNK files\n
                                                    script parse lnk <partition>";
   $main::RVT_functions{RVT_script_parse_evt } = "Parses Windows event logs (EVT files)\n
                                                    script parse evt <partition>";
   $main::RVT_functions{RVT_script_parse_text } = "Extracts raw text strings from suitable files\n
                                                    script parse text <partition>";
   $main::RVT_functions{RVT_script_parse_search_launch } = "Find PARSED files containing keywords from a search file\n
                                                    script parse search launch <search file> <disk>";
   $main::RVT_functions{RVT_script_parse_search_export } = "Exports search results to disk\n
                                                    script parse search export <search file> <disk>";
}



sub RVT_script_parse_pff {

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/pff';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};
    my @pablist = grep {/$repath/} RVT_get_allocfiles('\.pab$', $disk);
    my @pstlist = grep {/$repath/} RVT_get_allocfiles('\.pst$', $disk);
    my @ostlist = grep {/$repath/} RVT_get_allocfiles('\.ost$', $disk);
    my @filelist = (@pablist,@pstlist, @ostlist);
    
	printf ("Parsing PST, OST, PAB files...\n");
    foreach my $f (@filelist) {
    	my $fpath = RVT_create_file($opath, 'pff', 'RVT_metadata');    	
        open (META,">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create metadata files."); # XX Lo del encoding habría que hacerlo en muchos otros sitios.
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        $fpath =~ s/.RVT_metadata//; 
        my @args = ('pffexport', '-f', 'text', '-m', 'all', '-q', '-t', "$fpath", $f); # -f text and -m all are in fact default options.
        system(@args);
        
        foreach my $mode ('export','orphan','recovered') { finddepth( \&RVT_sanitize_libpff_item, "$fpath.$mode" ) }
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { 
		$opath = RVT_get_morguepath($disk) . '/output/parser/control';
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
		system (@args);
	}
	printf ("Finished parsing PST, OST, PAB files.\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}




sub RVT_script_parse_bkf {

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/bkf';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    
    my @listbkf = grep {/$repath/} RVT_get_allocfiles('\.bkf$', $disk);

	printf ("Parsing BKF files...\n");
    foreach my $f (@listbkf) {
        my $fpath = RVT_create_folder($opath, 'bkf');
        
        mkdir ("$fpath/contents") or die ("ERR: failed to create output directories.");
        open (META, ">$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
            print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        
        $fpath="$fpath/contents";
        my $command = 'mtftar < "'.$f.'" | tar xv -C '.$fpath;
        `$command`;
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	$opath = RVT_get_morguepath($disk) . '/output/parser/control';
	my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { system (@args); }
	printf ("Finished parsing BKF files.\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}



sub RVT_script_parse_zip {

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/zip';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    
    my @listzip = grep {/$repath/} RVT_get_allocfiles('\.zip$', $disk);
    my @listodt = grep {/$repath/} RVT_get_allocfiles('\.odt$', $disk);
    my @listods = grep {/$repath/} RVT_get_allocfiles('\.ods$', $disk);
    my @listodp = grep {/$repath/} RVT_get_allocfiles('\.odp$', $disk);
    my @listodg = grep {/$repath/} RVT_get_allocfiles('\.odg$', $disk);
    my @listdocx = grep {/$repath/} RVT_get_allocfiles('\.docx$', $disk);
    my @listxlsx = grep {/$repath/} RVT_get_allocfiles('\.xlsx$', $disk);
    my @listpptx = grep {/$repath/} RVT_get_allocfiles('\.pptx$', $disk);
    my @listppsx = grep {/$repath/} RVT_get_allocfiles('\.ppsx$', $disk);
    my @filelist = (@listzip, @listodt, @listods, @listodp, @listodg, @listdocx, @listxlsx, @listpptx, @listppsx);

	printf ("Parsing ZIP (plus ODF plus OOXML) files...\n");
    foreach my $f (@filelist) {
        my $fpath = RVT_create_folder($opath, 'zip');
        
        mkdir ("$fpath/contents") or die ("ERR: failed to create output directories.");
        open (META, ">$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
            print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        
        $fpath="$fpath/contents";
        my @args = ('unzip', '-q', '-P', 'SiCuelaCuela', $f, '-d', $fpath);
        system (@args)
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	$opath = RVT_get_morguepath($disk) . '/output/parser/control';
	my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { system (@args); }
	printf ("Finished parsing ZIP (plus ODF plus OOXML) files.\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}


sub RVT_script_parse_rar {

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/rar';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    
    my @filelist = grep {/$repath/} RVT_get_allocfiles('\.rar$', $disk);

	printf ("Parsing RAR files...\n");
    foreach my $f (@filelist) {
        my $fpath = RVT_create_folder($opath, 'rar');
        
        mkdir ("$fpath/contents") or die ("ERR: failed to create output directories.");
        open (META, ">$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
            print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        
        $fpath="$fpath/contents";
        my @args = ('unrar', 'x', '-pSiCuelaCuela', '-inul', $f, $fpath);
        system (@args)
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	$opath = RVT_get_morguepath($disk) . '/output/parser/control';
	my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { system (@args); }
	printf ("Finished parsing RAR files.\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}



sub RVT_script_parse_pdf {

	my $PDFTOTEXT = "pdftotext";

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/pdf';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    my @filelist = grep {/$repath/} RVT_get_allocfiles('\.pdf$', $disk);

	printf ("Parsing PDF files...\n");
    foreach my $f (@filelist) { 
        my $fpath = RVT_create_file($opath, 'pdf', 'txt');
        open (FPDF, "-|", "$PDFTOTEXT", $f, '-');
        open (FOUT, ">$fpath") or die ("ERR: failed to create metadata files.");
		print FOUT "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		while (<FPDF>) {
			print FOUT $_;
		}
		close (FPDF);
        close (FOUT);
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { 
		$opath = RVT_get_morguepath($disk) . '/output/parser/control';
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
		system (@args);
	}
	printf ("Finished parsing PDF files.\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}


sub RVT_script_parse_lnk {

	my $LNKPARSE = "lnk-parse-1.0.pl";

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/lnk';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    my @filelist = grep {/$repath/} RVT_get_allocfiles('\.lnk$', $disk);

	printf ("Parsing LNK files...\n");
    foreach my $f (@filelist) { 
        my $fpath = RVT_create_file($opath, 'lnk', 'txt');
        open (FLNK, "-|", "$LNKPARSE", $f);
        open (FOUT, ">$fpath") or die ("ERR: failed to create output file.");
		print FOUT "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		while (<FLNK>) {
			print FOUT $_;
		}
		close (FLNK);
        close (FOUT);
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { 
		$opath = RVT_get_morguepath($disk) . '/output/parser/control';
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
		system (@args);
	}
	printf ("Finished parsing LNK files.\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}


sub RVT_script_parse_evt {

	my $EVTPARSE = "evtparse.pl";

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/evt';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    my @filelist = grep {/$repath/} RVT_get_allocfiles('\.evt$', $disk);

	printf ("Parsing EVT files...\n");
    foreach my $f (@filelist) { 
        my $fpath = RVT_create_file($opath, 'evt', 'txt');
        open (FEVT, "-|", "$EVTPARSE", $f) or die "Error: $!";
        binmode (FEVT, ":encoding(cp1252)") || die "Can't binmode to cp1252 encoding\n";
        open (FOUT, ">$fpath") or die ("ERR: failed to create output file.");
		print FOUT "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		print FOUT "Date#Type#User#Event ID#Description\n";
		while (<FEVT>) {
			chomp ($_);
			my @field= split ('\|',$_ ) ;
			my $time=ParseDateString("epoch $field[0]");
			print FOUT $time."#".$field[1]."#".$field[2]."#".$field[3]."#".$field[4]."\n";
		}
		close (FEVT);
        close (FOUT);
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { 
		$opath = RVT_get_morguepath($disk) . '/output/parser/control';
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
		system (@args);
	}
	printf ("Finished parsing EVT files.\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}


sub RVT_script_parse_text {
	## XX_FIXME: we should check that files in output/parser/control/text are NOT taken as input.

	my $FSTRINGS = "f-strings";

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/text';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    # typical text files:
    my @listtxt = grep {/$repath/} RVT_get_allocfiles('\.txt$', $disk);
    my @listcsv = grep {/$repath/} RVT_get_allocfiles('\.csv$', $disk);
    # emails:
    my @listeml = grep {/$repath/} RVT_get_allocfiles('\.eml$', $disk);
    my @listdbx = grep {/$repath/} RVT_get_allocfiles('\.dbx$', $disk);
    # office file types:
    my @listdoc = grep {/$repath/} RVT_get_allocfiles('\.doc$', $disk);
    my @listppt = grep {/$repath/} RVT_get_allocfiles('\.ppt$', $disk);
    my @listxls = grep {/$repath/} RVT_get_allocfiles('\.xls$', $disk);
    my @listrtf = grep {/$repath/} RVT_get_allocfiles('\.rtf$', $disk);
    # likely to be found in cached webpages:
    my @listhtm = grep {/$repath/} RVT_get_allocfiles('\.htm$', $disk);
    my @listhtml = grep {/$repath/} RVT_get_allocfiles('\.html$', $disk);
    my @listphp = grep {/$repath/} RVT_get_allocfiles('\.php$', $disk);
    my @listasp = grep {/$repath/} RVT_get_allocfiles('\.asp$', $disk);
    my @listxml = grep {/$repath/} RVT_get_allocfiles('\.xml$', $disk);

    my @filelist = (@listtxt, @listcsv, @listeml, @listdbx, @listdoc, @listppt, @listxls, @listrtf, @listhtm, @listhtml, @listphp, @listasp, @listxml);

	printf ("Parsing text files...\n");
	
	my $fpath = RVT_create_file($opath, 'text', 'txt');
	my $count = $fpath;
	$count =~ s/.*-([0-9]*).txt$/\1/;
	foreach my $f (@filelist) {
		$fpath = "$opath/text-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
		my $normalized = `echo "$f" | f-strings`;
		chomp ($normalized);

		open (FTEXT, "-|", "$FSTRINGS", "$f") or die ("ERROR: Failed to open input file $f\n");
		open (FOUT, ">$fpath") or die ("ERR: failed to create output files.");
		print FOUT "# BEGIN RVT METADATA\n# Source file: $f\n# Normalized name and path: $normalized\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		while (<FTEXT>){
			print FOUT $_;
		}
		close (FTEXT);
		close (FOUT);
		$count++;
	} # end foreach my $f (@filelist)

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { 
		$opath = RVT_get_morguepath($disk) . '/output/parser/control';
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
		system (@args);
	}
	printf ("Finished parsing files with text strings.\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}


sub RVT_script_parse_search_launch  {
    # launches a search over indexed (PARSEd) files writing results (hits) to a file.
    # takes as arguments:
    #   file with searches: one per line
    #   disk from the morgue

    my ( $searchesfilename, $disk ) = @_;
    my $string;
    
    $disk = $main::RVT_level->{tag} unless $disk;
    print "\t launching $disk\n";
    my $case = RVT_get_casenumber($disk);
    my $diskpath = RVT_get_morguepath($disk);
    my $parsedfiles = "$diskpath/output/parser/control/text/";
    my $searchespath = "$diskpath/output/parser/";
    return 0 if (! $diskpath);
    return 0 if (! -d $parsedfiles);
    if (! -e $searchespath) { mkdir $searchespath or return 0; }

    open (F, "<".RVT_get_morguepath($case)."/searches_files/$searchesfilename") or return 0;
    my @searches = grep {!/^\s*#/} <F>;
    close (F);
    
    print "\n\nLaunching searches:\n\n";    
    for $string ( @searches ) {
        chomp $string;
		$string = lc($string);
        print "-- $string\n";
		open (FMATCH, "-|", "grep", "-Hl", $string, $parsedfiles, "-R");
		open (FOUT, ">$searchespath/$string");
		while (<FMATCH>) {
			# Tengo en $_ el fichero que ha hecho match. Puedo ir buscando su source recursivamente.
			my $file = $_;
			chomp ($file);
			my $source = RVT_get_source($file);
			my $line = $file;

			while ( $source ) {
				$line = $line . '#' . $source;
				$file = $source;
				$source = RVT_get_source($file);
			}
			
# 			unless ( $file =~ /\/mnt\/p0[^0]\// ) {
# 				my $source = RVT_get_source ($file);
# 				if ( $source ) {
# 					RVT_copy_with_source ($source, $opath.'/'.basename($file).'_RVT-Source');
# 				} else { # If there was no source we create a metafile indicating it.
# 					$opath = $opath.'/'.basename($file).'_RVT-Source';
# 					mkpath $opath;
# 					my $exceptionfile = $opath.'/'.basename($file).'_RVT-Exception-No_Source.txt';
# 					open (OFILE, ">", $exceptionfile);
# 					print OFILE "# BEGIN RVT METADATA\n# Exception: File does not have a Source header.\n# Source file: $file\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
# 					close OFILE;			
# 				}
# 			} # unless

			print FOUT "$line\n";
		} # while FMATCH
		close FMATCH;
		close FOUT;
    }
    return 1;
}


sub RVT_script_parse_search_export  {
    # Exports results (from script parse search launch) to disk.
    # takes as arguments:
    #   file with searches: one per line
    #   disk from the morgue

    my ( $searchesfilename, $disk ) = @_;
    my $string;
    
    $disk = $main::RVT_level->{tag} unless $disk;
    print "\t launching $disk\n";
    my $case = RVT_get_casenumber($disk);
    my $diskpath = RVT_get_morguepath($disk);
    my $searchespath = "$diskpath/output/parser/";
    my $exportpath = "$searchespath/export/";
    return 0 if (! $diskpath);
    if (! -e $exportpath) { mkdir $exportpath or return 0; }
    
    open (F, "<".RVT_get_morguepath($case)."/searches_files/$searchesfilename") or return 0;
    my @searches = grep {!/^\s*#/} <F>;
    close (F);
    
    for $string ( @searches ) {
        chomp $string;
		$string = lc($string);
        print "-- $string\n";
		open (FMATCH, "$searchespath/$string");
		my $opath = "$exportpath/$string";
		mkdir $opath;
		while (<FMATCH>) {
			chomp ();
			my $match = $_;
			$match =~ s/#.*//;
			RVT_copy_with_source ($match, $opath);
		}
	}
}


sub RVT_copy_with_source  {
#	Copies a file to a directory.
#	If the file presents a RVT_METADATA structure, this function is applied recursively to the SOURCE.
#	Parameters:
#		The FILE that you want to copy.
#		The destination DIRECTORY where you want it copied.

    my ( $file, $opath ) = @_;
    
    my $RVT_parse_Copy_Size_Limit = 20000000; # 20 Megabytes

    chomp ($file);
    print "RVT_copy_with_source ( $file , $opath )\n";
    if ( ! -e $opath ) {mkpath $opath}

	# Here we can raise EXCEPTIONS based on certain conditions.
	# for instance: not copying big files, or files of certain types.
    if ( -s $file > $RVT_parse_Copy_Size_Limit ) { #  EXCEPTION: Size limit
		my $exceptionfile = $opath.'/'.basename($file).'_RVT-Exception-Exceeded_Copy_Size_Limit.txt';
     	open (OFILE, ">", $exceptionfile);
     	print OFILE "# BEGIN RVT METADATA\n# Exception: File skipped for exceeding size limit (\$RVT_parse_Copy_Size_Limit = $RVT_parse_Copy_Size_Limit).\n# Source file: $file\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
     	close OFILE;
	# XX Pope> En algún lugar por aquí cerca, tenemos que darnos cuenta de que si algo viene de "Message[0-9]{5}/FullMessage.html" o de "Message[0-9]{5}/Attachments/*", tenemos que coger todo el paquete ""Message[0-9]{5}"
    } elsif (( $file =~ s/(^.*Message[0-9][0-9][0-9][0-9][0-9])\/FullMessage.html$/\1/ ) or ( $file =~ s/(^.*Message[0-9][0-9][0-9][0-9][0-9])\/Attachments\/[^\/]*$/\1/ )) {
    	# This is what happens when our file happens to be a part of an e-mail (parsed by libpff).
    	dircopy ($file, $opath);
#     
#     } else if (....) {
#     
    } else { ################################## NORMAL CASE, file is copied.
    	copy ($file, $opath);
    }

	unless ( $file =~ /\/mnt\/p0[^0]\// ) {
	    my $source = RVT_get_source ($file);
	    if ( $source ) {
	    	RVT_copy_with_source ($source, $opath.'/'.basename($file).'_RVT-Source');
	    } else { # If there was no source we create a metafile indicating it.
	    	$opath = $opath.'/'.basename($file).'_RVT-Source';
	    	mkpath $opath;
			my $exceptionfile = $opath.'/'.basename($file).'_RVT-Exception-No_Source.txt';
			open (OFILE, ">", $exceptionfile);
			print OFILE "# BEGIN RVT METADATA\n# Exception: File does not have a Source header.\n# Source file: $file\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
			close OFILE;			
	    }
	} 
	if ( $file =~ /\/mnt\/p0[^0]\// ) { print "--\n"; }
	return 1;
}


sub RVT_get_source () { 
	# dado un contenido en parser, encuentra su fuente según RVT METADATA.
	my $file = shift;
	print "Getting source for $file\n";
	my $source = 0;
	my $control = 0;
	if ( ! -e $file ) {print "ERROR $file does not exist!!\n"; } #exit }
	
	# If the file was generated by a one-input-many-output-files plugin (such 
	# as PST, RAR, ZIP), we have to look for metadata in the output directory:
	my $aux = $file;
	$aux =~ s/(.*\/mnt\/p00\/parser\/[a-zA-Z0-9]+\/[a-zA-Z0-9]+-[0-9]+\/).*/\1\/RVT_metadata/; # XX OJO, esto va bien siempre? (creemos que sí, pero quizá puede fallar con nuevos plugins que vayamos haciendo)
	if ( -e $aux ) { $file = $aux; }
	if ( ($file =~ /.*\/mnt\/p00\/.*/) or ($file =~ /.*\/output\/parser\/control\/.*/) ) {
		open (FILE, $file);	
		my $count = 0;
		while ( $source = <FILE>) {
			if ($source =~ s/# Source file: //) { $control = 1; last; }
			if ($count > 5) { last; } ## THIS is the number of lines that will be read when looking for the RVT_Source metadata.
			$count++ ;
		}
		close (FILE);
		if ( $control == 0 ) {print "  RVT_get_source: ERROR, SOURCE not found.\n"}
	} else {
		print "  Hit primitive file, no source. This is normal.\n"
	}
	
	chomp ($source);
#	print "RVT_get_source: Source of $file is $source\n";
	return $source;
}


sub RVT_sanitize_libpff_item {
	
	return unless ( -d ); # We are only interested in DIRECTORIES
	return unless ( $File::Find::name =~ /\/[A-Z][a-z]*[0-9]{5}$/ );

	# LIST OF AVAILABLE FIELDS:
	# Client submit time
	# Delivery time
	# Creation time
	# Modification time
	# Size
	# Flags
	# Display name
	# Conversation topic
	# Subject
	# Sender name			
	# Sender email address				# it is not necessary to declare the name of this field, because its value will be shown under the Field Name of 'Sender name'
	# Sent representing name
	# Sent representing email address
	# Importance
	# Priority
	# Sensitivity
	# Is a reminder
	# Reminder time
	# Is private
	
	# This defines which fields we want for each item type, and what name to give them.
	my %field_names;
	### Appointments:
	$field_names{'Appointment'}{'Creation time'} = "Creation";
	$field_names{'Appointment'}{'Modification time'} = "Modification";
	$field_names{'Appointment'}{'Flags'} = "Flags";
	$field_names{'Appointment'}{'Subject'} = "Subject";
	$field_names{'Appointment'}{'Sender name'} = "Creator";
	$field_names{'Appointment'}{'Sender email address'} = "Creator e-mail address"; # this label is not used
	$field_names{'Appointment'}{'Importance'} = "Importance";
	$field_names{'Appointment'}{'Priority'} = "Priority";
	### Contacts:
	$field_names{'Contact'}{'Creation time'} = "Creation";
	$field_names{'Contact'}{'Modification time'} = "Modification";
	$field_names{'Contact'}{'Flags'} = "Flags";
	$field_names{'Contact'}{'Subject'} = "Contact name";
	$field_names{'Contact'}{'Sender name'} = "Creator";
	$field_names{'Contact'}{'Sender email address'} = "Creator e-mail address"; # this label is not used
	$field_names{'Contact'}{'Importance'} = "Importance";
	$field_names{'Contact'}{'Priority'} = "Priority";
	### Meetings:
	$field_names{'Meeting'}{'Creation time'} = "Creation";
	$field_names{'Meeting'}{'Modification time'} = "Modification";
	$field_names{'Meeting'}{'Flags'} = "Flags";
	$field_names{'Meeting'}{'Subject'} = "Subject";
	$field_names{'Meeting'}{'Sender name'} = "Creator";
	$field_names{'Meeting'}{'Sender email address'} = "Creator e-mail address"; # this label is not used
	$field_names{'Meeting'}{'Importance'} = "Importance";
	$field_names{'Meeting'}{'Priority'} = "Priority";
	### Messages:
	$field_names{'Message'}{'Creation time'} = "Creation";
	$field_names{'Message'}{'Modification time'} = "Modification";
	$field_names{'Message'}{'Flags'} = "Flags";
	$field_names{'Message'}{'Subject'} = "Subject";
	$field_names{'Message'}{'Sender name'} = "From";
	$field_names{'Message'}{'Sender email address'} = "Creator e-mail address"; # this label is not used
	$field_names{'Message'}{'Importance'} = "Importance";
	$field_names{'Message'}{'Priority'} = "Priority";
	### Notes:
	$field_names{'Note'}{'Creation time'} = "Creation";
	$field_names{'Note'}{'Modification time'} = "Modification";
	$field_names{'Note'}{'Flags'} = "Flags";
	$field_names{'Note'}{'Subject'} = "Subject";
	$field_names{'Note'}{'Sender name'} = "Creator";
	$field_names{'Note'}{'Sender email address'} = "Creator e-mail address"; # this label is not used
	$field_names{'Note'}{'Importance'} = "Importance";
	$field_names{'Note'}{'Priority'} = "Priority";
	### Tasks:
	$field_names{'Task'}{'Creation time'} = "Creation";
	$field_names{'Task'}{'Modification time'} = "Modification";
	$field_names{'Task'}{'Flags'} = "Flags";
	$field_names{'Task'}{'Subject'} = "Subject";
	$field_names{'Task'}{'Sender name'} = "Created by";
	$field_names{'Task'}{'Sender email address'} = "Creator e-mail address"; # this label is not used
	$field_names{'Task'}{'Importance'} = "Importance";
	$field_names{'Task'}{'Priority'} = "Priority";
	###	

	my @sortorder = ( 'Creation time', 'Client submit time', 'Delivery time', 'Modification time', 'Sender name', 'Sender email address', 'Sent representing name', 'Sent representing email address', 'Display name', 'Conversation topic', 'Subject', 'Importance', 'Priority', 'Sensitivity', 'Is a reminder', 'Is private', 'Size','Flags' ); # This affects in which order fields are written to RVT_ITEMs

	my %field_values = (
		'Subject' => undef,
		'Sender name' => undef,
		'Sender email address' => undef,
		'Importance' => undef,
		'Priority' => undef,
		'Flags' => undef,
		'Client submit time' => undef,
		'Delivery time' => undef,
		'Creation time' => undef,
		'Modification time' => undef,
	);

	my $folder = $File::Find::name;
	my $source = $folder; $source =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9]).output.parser.control.pff/\1/;
	my $item_type = basename( $folder ); $item_type =~ s/[0-9]{5}//;
	my $file = basename( $folder );	$file =~ s/[0-9]{5}/.txt/;
	if( $item_type eq 'Message' ) { $file =~ s/Message/OutlookHeaders/ }
	
	return if( $item_type eq 'Attachment' ); # Folders like Attachment00001 must not be treated directly by us; instead they will be treated during the sub parse_attachment of their parent directory.
	return if( $item_type eq 'Folder' ); # Folders like Folder00001 are likely to be found in recovered structures, but they are not "by themselves" items to be analyzed. Note that the normal items (Message, Contact...) inside WILL be analyzed normally.

	if( exists $field_names{$item_type} ) { print "Item: $item_type ($source)\n" }
	else {
		warn "WARNING: Skipping unknown item type $item_type ($source)\n";
		return
	}
	
	open( LIBPFF_ITEM, "<:encoding(UTF-8)", "$folder/$file" ) || warn( "WARNING: Cannot open $folder/$file for reading - skipping item.\n" ) && return;
	open( RVT_ITEM, ">:encoding(UTF-8)", "$folder.html" ) || warn( "WARNING: Cannot open $folder.txt for writing - skipping item.\n" ) && return;
	open( RVT_META, ">:encoding(UTF-8)", "$folder.RVT_metadata" ) || warn( "WARNING: Cannot open $folder.RVT_metadata for writing - skipping item.\n" ) && return;	
	print RVT_META "## $file follows:\n\n";
	
	# Parse LIBPFF_ITEM until an empty line is found, writing to RVT_META and store wanted keys:
	PARSE_KEYS:
	while( my $line = <LIBPFF_ITEM> ) { # This loop exits as soon as one empty line is found
		if( $line =~ /^$/ ) { last PARSE_KEYS } # this exits the WHILE loop
		print RVT_META $line;
		STORE_KEY:
		foreach my $k ( keys %field_values ) { # Store the key if we want it:
			if( $line =~ /^$k:/ ) {
				$line =~ s/.*\t//; 
				chomp( $line );
				$field_values{$k} = $line;
				last STORE_KEY; # this exits the FOREACH loop
			} # end if
		} # end foreach 
	} # end while

	# InternetHeaders.txt: append to RVT_META
	if( -f "$folder/InternetHeaders.txt" ) {
		print RVT_META "\n\n## InternetHeaders.txt follows:\n\n";
		open (INTERNETHEADERS, "<:encoding(UTF-8)", "$folder/InternetHeaders.txt") or warn ("WARNING: failed to open $folder/InternetHeaders.txt\n");
		while( my $line = <INTERNETHEADERS> ) {
			chomp( $line); # Two chomps attempting to normalize the DOS line ending.
			chomp( $line);
			print RVT_META "$line\n";
		}			
		close (INTERNETHEADERS);
		unlink ("$folder/InternetHeaders.txt") or warn ("WARNING: failed to delete $folder/InternetHeaders.txt\n");
	}

	# Recipients.txt: append to RVT_META and save To, Cc and Bcc (will be in RVT_ITEM).
	my $to = "";
	my $cc = "";
	my $bcc = "";
	if( -f "$folder/Recipients.txt" ) {
		my $string;
		my $previous_line = "";
		print RVT_META "\n\n## Recipients.txt follows:\n\n";
		open (RECIPIENTS, "<:encoding(UTF-8)", "$folder/Recipients.txt") or warn ("WARNING: failed to open $File::Find::dir/Recipients.txt\n");
		while( my $line = <RECIPIENTS> ) {
			print RVT_META $line;
			if( $line =~ /^Recipient type/ ) {
				my $string = $previous_line;
				$string =~ s/.*\t//;
				chomp( $string );
				if( $line =~ /To$/ ) { $to = "$to$string; " }
				elsif( $line =~ /CC$/ ) { $cc = "$cc$string; " }
				elsif( $line =~ /BCC$/ ) { $bcc = "$bcc$string; " }
				else { warn ("WARNING: RVT_parse_pff: Unknown recipient type \"$string\" in $File::Find::dir/Recipients.txt\n") }
			}			
		$previous_line = $line;			
		}
		close (RECIPIENTS); # done parsing Recipients.txt
		unlink ("$folder/Recipients.txt") or warn ("WARNING: failed to delete $folder/Recipients.txt\n");	
	}

	# ConversationIndex.txt: append to RVT_META
	if( -f "$folder/ConversationIndex.txt" ) {
		print RVT_META "\n\n## ConversationIndex.txt follows:\n\n";
		open (CONVERSATIONINDEX, "<:encoding(UTF-8)", "$folder/ConversationIndex.txt") or warn ("WARNING: failed to open $folder/ConversationIndex.txt\n");
		while( my $line = <CONVERSATIONINDEX> ) { print RVT_META $line }			
		close (CONVERSATIONINDEX);
		unlink ("$folder/ConversationIndex.txt") or warn ("WARNING: failed to delete $folder/ConversationIndex.txt\n");
	}

	print RVT_ITEM "<HTML>
<!--#$field_values{'Sender name'}#$field_values{'Subject'}#$field_values{'Flags'}#-->
<HEAD>\n	<TITLE>\n		$field_values{'Subject'}\n	</TITLE>\n	<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n</HEAD>\n<BODY>\n	<TABLE border=1 rules=all frame=box>\n		<tr><td><b>Outlook item</b></td><td>$item_type&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"",basename( $folder) ,".RVT_metadata\" target=\"_blank\">[Headers]</a></td></tr>\n		<tr><td><b>Source</b></td><td>$source</td></tr>\n";
	# Specific treatment to some headers:
	if( $field_values{'Sender email address'} ) { $field_values{'Sender name'} = "$field_values{'Sender name'} ($field_values{'Sender email address'})" }
	undef $field_values{'Sender email address'}; # We don't want this field printed later. Its value is already stored along the 'Sender name'.
	if( $field_values{'Importance'} eq 'Normal' ) { undef $field_values{'Importance'} }
	if( $field_values{'Priority'} eq 'Normal' ) { undef $field_values{'Priority'} }
	if( $field_values{'Flags'} eq '0x00000001 (Read)' ) { undef $field_values{'Flags'} }
	else { $field_values{'Flags'} =~ s/.*Read, (.*)\)/\1/ }
	foreach my $k ( @sortorder ) { # Write headers to RVT_ITEM:
		if( defined( $field_values{$k} ) && defined( $field_names{$item_type}{$k} ) ) {
			print RVT_ITEM "		<tr><td><b>$field_names{$item_type}{$k}</b></td><td>$field_values{$k}</td></tr>\n";
		}
	}
	# Write recipients to RVT_ITEM:
	if( $to ne '' ) { print RVT_ITEM "		<tr><td><b>To</b></td><td>$to</td></tr>\n" }
	if( $cc ne '' ) { print RVT_ITEM "		<tr><td><b>CC</b></td><td>$cc</td></tr>\n" }
	if( $bcc ne '' ) { print RVT_ITEM "		<tr><td><b>BCC</b></td><td>$bcc</td></tr>\n" }
	
	# Attachments:
	if( -d "$folder/Attachments" ) {
		print "    Attachments: $folder/Attachments\n";
		move( "$folder/Attachments", "$folder.attach" );
		print RVT_META "\n\n## Attachment information follows:\n\n";
		our $wanted_depth = "$folder" =~ tr[/][];
		find( \&RVT_sanitize_libpff_attachment, "$folder.attach" );
	}

	# Parse rest of LIBPFF_ITEM writing to RVT_META and RVT_ITEM
	print RVT_ITEM "</TABLE><br>\n";	
	print RVT_META "\n## Rest of $file follows:\n\n";
	while( my $line = <LIBPFF_ITEM> ) { 
		print RVT_ITEM "$line<br>";
		print RVT_META $line;
	}

	# Message.txt: append to RVT_META and RVT_ITEM
	if( -f "$folder/Message.txt" ) {
		print RVT_META "\n\n## Message.txt follows:\n\n";
		open (MESSAGE,  "<:encoding(UTF-8)", "$folder/Message.txt") or warn ("WARNING: failed to open $folder/Message.txt\n");
		while( my $line = <MESSAGE> ) {
			chomp( $line); # Two chomps attempting to normalize the DOS line ending.
			chomp( $line);
			print RVT_META "$line\n";
			print RVT_ITEM "$line<br>\n";
		} 
		close (MESSAGE); # done parsing Message.txt
		unlink ("$folder/Message.txt") or warn ("WARNING: failed to delete $folder/Message.txt\n");
	}
	
	print RVT_ITEM "	</BODY>\n</HTML>\n";
	close( LIBPFF_ITEM );
	close( RVT_ITEM );
	close( RVT_META );
	unlink( "$folder/$file" ) || warn( "WARNING: Cannot delete $folder/file\n" );
	rmdir( $folder ) || warn( "WARNING: Cannot delete $folder\n" );
}


sub RVT_sanitize_libpff_attachment {
	return if ( -d ); # We only want to act on FILES.
	my $item_depth = $File::Find::dir =~ tr[/][];
	our $wanted_depth;
	if( $item_depth == $wanted_depth ) {
		my $string = $File::Find::name;
		print RVT_META "Attachment: $File::Find::name\n";
		chomp( $string );
		$string =~ s/.*\/([^\/]*\/[^\/]*)$/\1/;
		print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">", basename($File::Find::name), "</a></td></tr>\n";
	} elsif( $item_depth eq $wanted_depth+1 && $File::Find::name =~ /.*Message00001.html/ )  {
		my $string = $File::Find::name;
		print RVT_META "Attachment: $File::Find::name\n";
		chomp( $string );
		$string =~ s/.*\/([^\/]*\/[^\/]*\/[^\/]*)$/\1/;
		print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">", basename($File::Find::name), "</a></td></tr>\n";
	}
} # end sub parse_attachment



1;