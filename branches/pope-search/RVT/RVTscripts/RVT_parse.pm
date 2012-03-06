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
#        my $fpath = RVT_create_folder($opath, 'pst');
    	my $fpath = RVT_create_file($opath, 'pff', 'RVT_metadata');
    	
        open (META, ">$fpath") or die ("ERR: failed to create metadata files.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        $fpath =~ s/.RVT_metadata//; 
        my @args = ('pffexport', '-f', 'text', '-m', 'all', '-q', '-t', "$fpath", $f); # -f text and -m all are in fact default options.
        system(@args);
        
        # Code for cleaning libpff's mess:
        
        foreach my $mode ('export','orphan','recovered') {
			find( \&pff_cleaner,"$fpath.$mode");
		}
        
        
        
        
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
	foreach my $f (@filelist) { 
		my $fpath = RVT_create_file($opath, 'text', 'txt');
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
	}

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
#	use encoding "utf-8";
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
#	use encoding "utf-8";
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
#	use encoding "utf-8";
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
#	use encoding "utf-8";
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






sub pff_cleaner {
#	my $string, $line, $previous_line;
#	my $from_name, $from_addr, $to, $cc, $bcc, $date, $date_sent, $subject, $importance, $priority, $flags;
		

	if ( $File::Find::name =~ /\/Contact[0-9]{5}\/Contact.txt$/ ) {
		################################################################################
		# This is the code for parsing libpff's CONTACTS
		
		print ("Contact: $File::Find::name\n");
		
		my $from_name = "";
		my $from_addr = "";
		my $date = "";
		my $subject = "";
		my $importance = "";
		my $priority = "";
		my $flags = "";
		
		open (SOURCE, "<$File::Find::name") or warn ("WARNING: failed to open $File::Find::name\n");
		open (RVT_TARGET, ">$File::Find::dir.txt") or die ("ERR: failed to create: $File::Find::dir.txt\n");
		open (RVT_META, ">$File::Find::dir.RVT_metadata") or die ("ERR: failed to create: $File::Find::dir.RVT_metadata\n");
		print RVT_META "Source: $File::Find::name\n";
		
		########## Read Contact.txt, writing to RVT_metadata and RVT_TARGET.
		while( my $line = <SOURCE> ) {
			print RVT_META $line;	# BEWARE! After this point in the loop, we modify $line
			if( $line =~ /^Creation time:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $date = $line;
			} elsif( $line =~ /^Subject:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $subject = $line;
			} elsif( $line =~ /^Sender name:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $from_name = $line;
			} elsif( $line =~ /^Sender email address:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $from_addr = $line;
			} elsif( $line =~ /^Importance:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $importance = $line;
			} elsif( $line =~ /^Priority:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $priority = $line;
			} elsif( $line =~ /^Flags:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $flags = $line;
			} elsif( $line =~ /^Contact:/ ) {
				my $string = $File::Find::dir;
				$string =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9]).output.parser.control.pff/\1/;
				print RVT_TARGET "Source: $string\nCreator: $from_name, $from_addr\nCreation time: $date\nContact: $subject\n";
				if( $importance ne 'Normal' ) { print RVT_TARGET "Importance: $importance\n" }
				if( ( $priority ne '' ) && ( $priority ne 'Normal' ) ) { print RVT_TARGET "Priority: $priority\n" }
				if( $flags ne '0x00000001 (Read)' ) { print RVT_TARGET "Flags: $flags\n" }
				print RVT_TARGET "\n";
				print RVT_TARGET $line; # This line was already written to RVT_META
				while( $line = <SOURCE> ) {
					print RVT_TARGET $line;
					print RVT_META $line;
				}
			} 			 # $line is taunted, keep an eye on that.			
		}
		close (SOURCE);
		########## Done with Contact.txt.

		close (RVT_META);
		close (RVT_TARGET);
		unlink ($File::Find::name) or warn ("WARNING: failed to delete $File::Find::name\n");
		rmdir ($File::Find::dir) or warn ("WARNING: failed to delete $File::Find::dir\n");

	} elsif ( $File::Find::name =~ /\/Meeting[0-9]{5}\/Meeting.txt$/ ) {
		################################################################################
		# This is the code for parsing libpff's MEETINGS

		print ("Meeting: $File::Find::name\n");

		my $from_name = "";
		my $from_addr = "";
		my $date = "";
		my $subject = "";
		my $importance = "";
		my $priority = "";
		my $flags = "";
		
		open (SOURCE, "<$File::Find::name") or warn ("WARNING: failed to open $File::Find::name\n");
		open (RVT_TARGET, ">$File::Find::dir.txt") or die ("ERR: failed to create: $File::Find::dir.txt\n");
		open (RVT_META, ">$File::Find::dir.RVT_metadata") or die ("ERR: failed to create: $File::Find::dir.RVT_metadata\n");
		print RVT_META "Source: $File::Find::name\n";
		
		########## Read Meeting.txt, writing to RVT_metadata and RVT_TARGET.
		while( my $line = <SOURCE> ) {
			print RVT_META $line;	# BEWARE! After this point in the loop, we modify $line
			if( $line =~ /^Client submit time:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $date = $line;
			} elsif( $line =~ /^Subject:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $subject = $line;
			} elsif( $line =~ /^Sender name:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $from_name = $line;
			} elsif( $line =~ /^Sender email address:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $from_addr = $line;
			} elsif( $line =~ /^Importance:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $importance = $line;
			} elsif( $line =~ /^Priority:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $priority = $line;
			} elsif( $line =~ /^Flags:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $flags = $line;
			} elsif( $line =~ /^Meeting:/ ) {
				my $string = $File::Find::dir;
				$string =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9]).output.parser.control.pff/\1/;
				print RVT_TARGET "Source: $string\nCreator: $from_name, $from_addr\nCreation time: $date\nSubject: $subject\n";
				if( $importance ne 'Normal' ) { print RVT_TARGET "Importance: $importance\n" }
				if( $priority ne 'Normal' ) { print RVT_TARGET "Priority: $priority\n" }
				if( $flags ne '0x00000001 (Read)' ) { print RVT_TARGET "Flags: $flags\n" }
				print RVT_TARGET "\n";
				print RVT_TARGET $line; # This line was already written to RVT_META
				while( $line = <SOURCE> ) {
					print RVT_TARGET $line;
					print RVT_META $line;
				}
			} 			 # $line is taunted, keep an eye on that.			
		}
		close (SOURCE);
		########## Done with Meeting.txt.

		close (RVT_META);
		close (RVT_TARGET);
		unlink ($File::Find::name) or warn ("WARNING: failed to delete $File::Find::name\n");
		rmdir ($File::Find::dir) or warn ("WARNING: failed to delete $File::Find::dir\n");
	} elsif ( $File::Find::name =~ /\/Note[0-9]{5}\/Note.txt$/ ) {
		################################################################################
		# This is the code for parsing libpff's NOTES

		print ("Note: $File::Find::name\n");

		my $date = "";
		my $subject = "";
		my $importance = "";
		my $priority = "";
		my $flags = "";
		
		open (SOURCE, "<$File::Find::name") or warn ("WARNING: failed to open $File::Find::name\n");
		open (RVT_TARGET, ">$File::Find::dir.txt") or die ("ERR: failed to create: $File::Find::dir.txt\n");
		open (RVT_META, ">$File::Find::dir.RVT_metadata") or die ("ERR: failed to create: $File::Find::dir.RVT_metadata\n");
		print RVT_META "Source: $File::Find::name\n";
		
		########## Read Note.txt, writing to RVT_metadata and RVT_TARGET.
		while( my $line = <SOURCE> ) {
			print RVT_META $line;	# BEWARE! After this point in the loop, we modify $line
			if( $line =~ /^Client submit time:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $date = $line;
			} elsif( $line =~ /^Subject:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $subject = $line;
			} elsif( $line =~ /^Importance:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $importance = $line;
			} elsif( $line =~ /^Priority:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $priority = $line;
			} elsif( $line =~ /^Flags:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $flags = $line;
			} elsif( $line =~ /^Note:/ ) {
				my $string = $File::Find::dir;
				$string =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9]).output.parser.control.pff/\1/;
				print RVT_TARGET "Source: $string\nCreation time: $date\nSubject: $subject\n";
				if( $importance ne 'Normal' ) { print RVT_TARGET "Importance: $importance\n" }
				if( $priority ne 'Normal' ) { print RVT_TARGET "Priority: $priority\n" }
				if( $flags ne '0x00000001 (Read)' ) { print RVT_TARGET "Flags: $flags\n" }
				print RVT_TARGET "\n";
				print RVT_TARGET $line; # This line was already written to RVT_META
				while( $line = <SOURCE> ) {
					print RVT_TARGET $line;
					print RVT_META $line;
				}
			} 			 # $line is taunted, keep an eye on that.			
		}
		close (SOURCE);
		########## Done with Note.txt.

		close (RVT_META);
		close (RVT_TARGET);
		unlink ($File::Find::name) or warn ("WARNING: failed to delete $File::Find::name\n");
		rmdir ($File::Find::dir) or warn ("WARNING: failed to delete $File::Find::dir\n");

	} elsif ( $File::Find::name =~ /\/Appointment[0-9]{5}\/Appointment.txt$/ ) {
		################################################################################
		# This is the code for parsing libpff's APPOINTMENTS

		print ("Appointment: $File::Find::name\n");

		my $from_name = "";
		my $from_addr = "";
		my $to = "";
		my $cc = "";
		my $bcc = "";
		my $date = "";
		my $subject = "";
		my $importance = "";
		my $priority = "";
		my $flags = "";
		
		########## Parse Recipients.txt for To, CC and BCC.
		open (RECIPIENTS, "<$File::Find::dir/Recipients.txt") or warn ("WARNING: failed to open $File::Find::dir/Recipients.txt\n");
		my $previous_line = "";
		while( my $line = <RECIPIENTS> ) {
			if( $line =~ /^Recipient type/ ) {
				my $string = $previous_line;
				$string =~ s/.*\t//;
				chomp( $string );
				if( $line =~ /To$/ ) {
					$to = "$to$string; ";
				} elsif( $line =~ /CC$/ ) {
					$cc = "$cc$string; ";
				} elsif( $line =~ /BCC$/ ) {
					$bcc = "$bcc$string; ";
				} else {
				warn ("WARNING: RVT_parse_pff: Unknown recipient type \"$string\" in $File::Find::dir/Recipients.txt\n");
				}
			}			
		$previous_line = $line;			
		}
		close (RECIPIENTS);
		########## Finished parsing Recipients.txt

		open (SOURCE, "<$File::Find::name") or warn ("WARNING: failed to open $File::Find::name\n");
		open (RVT_TARGET, ">$File::Find::dir.txt") or die ("ERR: failed to create: $File::Find::dir.txt\n");
		open (RVT_META, ">$File::Find::dir.RVT_metadata") or die ("ERR: failed to create: $File::Find::dir.RVT_metadata\n");
		print RVT_META "Source: $File::Find::name\n";
		
		########## Read Appointment.txt, writing to RVT_metadata and RVT_TARGET.
		while( my $line = <SOURCE> ) {
			print RVT_META $line;	# BEWARE! After this point in the loop, we modify $line
			if( $line =~ /^Client submit time:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $date = $line;
			} elsif( $line =~ /^Subject:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $subject = $line;
			} elsif( $line =~ /^Sender name:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $from_name = $line;
			} elsif( $line =~ /^Sender email address:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $from_addr = $line;
			} elsif( $line =~ /^Importance:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $importance = $line;
			} elsif( $line =~ /^Priority:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $priority = $line;
			} elsif( $line =~ /^Flags:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				my $flags = $line;
			} elsif( $line =~ /^Appointment:/ ) {
				my $string = $File::Find::dir;
				$string =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9]).output.parser.control.pff/\1/;
				print RVT_TARGET "Source: $string\nCreator: $from_name, $from_addr\nCreation time: $date\nSubject: $subject\n";
				if( $importance ne 'Normal' ) { print RVT_TARGET "Importance: $importance\n" }
				if( $priority ne 'Normal' ) { print RVT_TARGET "Priority: $priority\n" }
				if( $to ) { print RVT_TARGET "To: $to\n" }
				if( $cc ) { print RVT_TARGET "CC: $cc\n" }
				if( $bcc ) { print RVT_TARGET "BCC: $bcc\n" }
				if( $flags ne '0x00000001 (Read)' ) { print RVT_TARGET "Flags: $flags\n" }
				print RVT_TARGET "\n";
				print RVT_TARGET $line; # This line was already written to RVT_META
				while( my $line = <SOURCE> ) {
					print RVT_TARGET $line;
					print RVT_META $line;
				}
			} 			 # $line is taunted, keep an eye on that.			
		}
		close (SOURCE);
		########## Done with Appointment.txt.

		close (RVT_META);
		close (RVT_TARGET);
		unlink ($File::Find::name) or warn ("WARNING: failed to delete $File::Find::name\n");
		unlink ("$File::Find::dir/Recipients.txt") or warn ("WARNING: failed to delete $File::Find::dir/Recipients.txt\n");
		rmdir ($File::Find::dir) or warn ("WARNING: failed to delete $File::Find::dir\n");
	} elsif ( $File::Find::name =~ /\/Message[0-9]{5}\/OutlookHeaders.txt$/ ) {
		################################################################################
		# This is the code for parsing libpff's MESSAGES
		print("Message: $File::Find::name\n");
		
		my $from_name = "";
		my $from_addr = "";
		my $to = "";
		my $cc = "";
		my $bcc = "";
		my $date = "";
		my $date_sent = "";
		my $subject = "";
		my $importance = "";
		my $priority = "";
		my $flags = "";
		
		open (RVT_TARGET, ">$File::Find::dir.html") or die ("ERR: failed to create: $File::Find::dir.html\n");
		open (RVT_META, ">$File::Find::dir.RVT_metadata") or die ("ERR: failed to create: $File::Find::dir.RVT_metadata\n");
		print RVT_META "Source: $File::Find::name\n";
		
		########## Append OutlookHeaders.txt to RVT_META and save some variables.
		open (SOURCE, "<$File::Find::name") or warn ("WARNING: failed to open $File::Find::name\n");
		print RVT_META "## OutlookHeaders.txt follows:\n\n";
		while( my $line = <SOURCE> ) {
			print RVT_META $line;	# BEWARE! After this point in the loop, we modify $line
			if( $line =~ /^Delivery time:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				$date = $line;
			} elsif( $line =~ /^Client submit time:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				$date_sent = $line;
			} elsif( $line =~ /^Subject:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				$subject = $line;
			} elsif( $line =~ /^Sender name:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				$from_name = $line;
			} elsif( $line =~ /^Sender email address:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				$from_addr = $line;
			} elsif( $line =~ /^Importance:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				$importance = $line;
			} elsif( $line =~ /^Priority:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				$priority = $line;
			} elsif( $line =~ /^Flags:/ ) {
				$line =~ s/.*\t//;
				chomp( $line );
				$flags = $line;
			} # BEWARE $line may be taunted till the end of the WHILE.
		} # end of the WHILE.
		close (SOURCE); ########## Done with OutlookHeaders.txt.
		unlink ("$File::Find::name") or warn ("WARNING: failed to delete $File::Find::name\n");

		if( -f "$File::Find::dir/InternetHeaders.txt" ) {
			########## Append InternetHeaders.txt to RVT_META
			print RVT_META "## InternetHeaders.txt follows:\n\n";
			open (INTERNETHEADERS, "<$File::Find::dir/InternetHeaders.txt") or warn ("WARNING: failed to open $File::Find::dir/InternetHeaders.txt\n");
			while( my $line = <INTERNETHEADERS> ) { print RVT_META $line }			
			close (INTERNETHEADERS); # done parsing InternetHeaders.txt
			unlink ("$File::Find::dir/InternetHeaders.txt") or warn ("WARNING: failed to delete $File::Find::dir/InternetHeaders.txt\n");
		} else { print RVT_META "## There is no InternetHeaders.txt\n\n" }

		if( -f "$File::Find::dir/Recipients.txt" ) {
			########## Append Recipients.txt to RVT_META __AND__ save To, CC and BCC
			print RVT_META "## Recipients.txt follows:\n\n";
			open (RECIPIENTS, "<$File::Find::dir/Recipients.txt") or warn ("WARNING: failed to open $File::Find::dir/Recipients.txt\n");
			my $previous_line = '';
			while( my $line = <RECIPIENTS> ) {
				print RVT_META $line;
				if( $line =~ /^Recipient type/ ) {
					my $string = $previous_line;
					$string =~ s/.*\t//;
					chomp( $string );
					if( $line =~ /To$/ ) {
						$to = "$to$string; ";
					} elsif( $line =~ /CC$/ ) {
						$cc = "$cc$string; ";
					} elsif( $line =~ /BCC$/ ) {
						$bcc = "$bcc$string; ";
					} else { warn ("WARNING: RVT_parse_pff: Unknown recipient type \"$string\" in $File::Find::dir/Recipients.txt\n") }
				}			
			$previous_line = $line;			
			}
			close (RECIPIENTS); # done parsing Recipients.txt
			unlink ("$File::Find::dir/Recipients.txt") or warn ("WARNING: failed to delete $File::Find::dir/Recipients.txt\n");
		} else { print RVT_META "## There is no Recipients.txt\n\n" }

		if( -f "$File::Find::dir/ConversationIndex.txt" ) {
			########## Append ConversationIndex.txt to RVT_META
			print RVT_META "## ConversationIndex.txt follows:\n\n";
			open (CONVERSATIONINDEX, "<$File::Find::dir/ConversationIndex.txt") or warn ("WARNING: failed to open $File::Find::dir/ConversationIndex.txt\n");
			while( my $line = <CONVERSATIONINDEX> ) { print RVT_META $line }			
			close (CONVERSATIONINDEX); # done parsing ConversationIndex.txt
			unlink ("$File::Find::dir/ConversationIndex.txt") or warn ("WARNING: failed to delete $File::Find::dir/ConversationIndex.txt\n");
		} else { print RVT_META "## There is no ConversationIndex.txt\n\n" }

		########## Write base RVT_TARGET:
		print RVT_TARGET "<HTML><!--#$from_name ($from_addr)#$date#$subject#$to#$cc#$bcc#$flags#-->\n";	
		my $string = $File::Find::dir;
		$string =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9]).output.parser.control.pff/\1/;
 		print RVT_TARGET "<HEAD>\n<TITLE>$subject</TITLE>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n</HEAD>\n<BODY>\n<TABLE border=1 rules=all frame=box>\n<tr><td><b>Source</b></td><td>$string&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"",basename($File::Find::dir),".RVT_metadata\">Headers</a></td></tr>\n<tr><td><b>From</b></td><td>$from_name, $from_addr</td></tr>\n<tr><td><b>Sent</b></td><td>$date_sent</td></tr>\n<tr><td><b>Received</b></td><td>$date</td></tr>\n<tr><td><b>Subject</b></td><td>$subject</td></tr>\n";
		if( ( $importance) && ($importance ne 'Normal') ) { print RVT_TARGET "<tr><td><b>Importance</b></td><td>$importance</td></tr>\n" }
		if( ( $priority ) && ( $priority ne 'Normal') ) { print RVT_TARGET "<tr><td><b>Priority</b></td><td>$priority</td></tr>\n" }
		if( $to ) { print RVT_TARGET "<tr><td><b>To</b></td><td>$to</td></tr>\n" }
		if( $cc ) { print RVT_TARGET "<tr><td><b>CC</b></td><td>$cc</td></tr>\n" }
		if( $bcc ) { print RVT_TARGET "<tr><td><b>BCC</b></td><td>$bcc</td></tr>\n" }
		if( $flags ne '0x00000001 (Read)' ) {
			$flags =~ s/.*Read, (.*)\)/\1/;
			print RVT_TARGET "<tr><td><b>Remarks</b></td><td>$flags</td></tr>\n"
		}
		
		########## Write part of RVT_TARGET about attachments (if there are any)
		if( -d "$File::Find::dir/Attachments" ) {
			print "Attachments: $File::Find::dir/Attachments\n";
			print RVT_META "\n\n## Attachment information follows:\n";
			sub attachment {
				if ( -f ) { # only do this for actual files - omitir the directory entry for "Attachments/"
					my $string = $File::Find::name;
					print RVT_META "Attachment: $File::Find::name\n";
					chomp( $string );
					$string =~ s/\/Attachments\// /;
					move( "$File::Find::name", "$string" );
					print RVT_TARGET "<tr><td><b>Attachment</b></td><td><a href=\"", basename($string)  ,"\">", basename($File::Find::name), "</a></td></tr>\n";
				} # end if -f
			} # end sub
			find( \&attachment, "$File::Find::dir/Attachments" );
			rmdir ("$File::Find::dir/Attachments") or warn ("WARNING: failed to delete $File::Find::dir/Attachments\n");
		} # end if -d ....Attachments
		print RVT_TARGET "</TABLE>\n";

 		if( -f "$File::Find::dir/Message.txt" ) {
 			########## Append Message.txt to RVT_META and RVT_TARGET
 			print RVT_META "## Message.txt follows:\n\n";
 			open (MESSAGE, "<$File::Find::dir/Message.txt") or warn ("WARNING: failed to open $File::Find::dir/Message.txt\n");
			while( my $line = <MESSAGE> ) {
				print RVT_META $line;
				chomp( $line );
				print RVT_TARGET "$line<br>\n";
			} 
 			close (MESSAGE); # done parsing Message.txt
 			unlink ("$File::Find::dir/Message.txt") or warn ("WARNING: failed to delete $File::Find::dir/Message.txt\n");
 		} else {
 			print RVT_META "## There is no Message.txt\n\n";
 			print RVT_TARGET "<i>Empty message</i>\n";
 		}
 		
		print RVT_TARGET "</HTML>\n";
		close (RVT_TARGET);
		close (RVT_META);
		rmdir ("$File::Find::dir") or warn ("WARNING: failed to delete $File::Find::dir\n");

#		unlink ($File::Find::name) or warn ("WARNING: failed to delete $File::Find::name\n");
#		unlink ("$File::Find::dir/Recipients.txt") or warn ("WARNING: failed to delete $File::Find::dir/Recipients.txt\n");
#		rmdir ($File::Find::dir) or warn ("WARNING: failed to delete $File::Find::dir\n");

		
		
	} else { ################################################################## No match
	print "(other): $File::Find::name\n";
	}
}






1;  

