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
						&RVT_script_parse_pst
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
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "Pope";

use RVTbase::RVT_core;
use RVTscripts::RVT_files;
use File::Copy;
use File::Path qw(mkpath);
use File::Basename;
use Data::Dumper;
use Date::Manip;

sub constructor {
   
   my $pdftotext = `pdftotext -v 2>&1`;
   my $readpst = `readpst -V`;
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
   if (!$readpst) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find libpst)');
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



   $main::RVT_requirements{'readpst'} = $readpst;
   $main::RVT_requirements{'pdftotext'} = $pdftotext;
   $main::RVT_requirements{'mtftar'} = $mtftar;
   $main::RVT_requirements{'unzip'} = $unzip;
   $main::RVT_requirements{'unrar'} = $unrar;
   $main::RVT_requirements{'fstrings'} = $fstrings;
   $main::RVT_requirements{'lnkparse'} = $lnkparse;
   $main::RVT_requirements{'evtparse'} = $evtparse;

   $main::RVT_functions{RVT_script_parse_pst } = "Parses all PST's found on the partition using libpst\n
                                                    script parse pst <partition>";
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



sub RVT_script_parse_pst {

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/pst';
    mkpath $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    my @filelist = grep {/$repath/} RVT_get_allocfiles('pst$', $disk);
    
    foreach my $f (@filelist) {
        my $fpath = RVT_create_folder($opath, 'pst');
        
        mkdir ("$fpath/contents") or die ("ERR: failed to create output directories.");
        open (META, ">$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
            print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        
        $fpath="$fpath/contents";
        my @args = ('readpst', '-S', '-q', '-cv', '-o', $fpath, $f);
        system(@args);

	# Pope> This is shit. And it works.
		my $command = "find $fpath -type f -regex ".'".*/[0-9]*"'." -exec mv '{}' '{}'.eml \\;";
		system ($command);
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { 
		$opath = RVT_get_morguepath($disk) . '/output/parser/control';
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
		system (@args);
	}
	printf ("Finished parsing PST files. Updating alloc_files...\n");
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
    
    my @listbkf = grep {/$repath/} RVT_get_allocfiles('bkf$', $disk);

    foreach my $f (@listbkf) {
        my $fpath = RVT_create_folder($opath, 'bkf');
        
        mkdir ("$fpath/contents") or die ("ERR: failed to create output directories.");
        open (META, ">$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
            print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        
        $fpath="$fpath/contents";
        my $command = "mtftar < $f | tar xv -C $fpath";
        `$command`;
    }

    if ( ! -e "$morguepath/mnt/p00" ) { mkdir "$morguepath/mnt/p00" or RVT_log('CRIT' , "couldn't create directory $!"); };
	$opath = RVT_get_morguepath($disk) . '/output/parser/control';
	my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/parser');
	if ( ! -e $morguepath.'/mnt/p00/parser' ) { system (@args); }
	printf ("Finished parsing BKF files. Updating alloc_files...\n");
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
    
    my @listzip = grep {/$repath/} RVT_get_allocfiles('zip$', $disk);
    my @listodt = grep {/$repath/} RVT_get_allocfiles('odt$', $disk);
    my @listods = grep {/$repath/} RVT_get_allocfiles('ods$', $disk);
    my @listodp = grep {/$repath/} RVT_get_allocfiles('odp$', $disk);
    my @listodg = grep {/$repath/} RVT_get_allocfiles('odg$', $disk);
    my @listdocx = grep {/$repath/} RVT_get_allocfiles('docx$', $disk);
    my @listxlsx = grep {/$repath/} RVT_get_allocfiles('xlsx$', $disk);
    my @listpptx = grep {/$repath/} RVT_get_allocfiles('pptx$', $disk);
    my @listppsx = grep {/$repath/} RVT_get_allocfiles('ppsx$', $disk);
    my @filelist = (@listzip, @listodt, @listods, @listodp, @listodg, @listdocx, @listxlsx, @listpptx, @listppsx);

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
	printf ("Finished parsing ZIP files(Bonus: and OOXML and ODF). Updating alloc_files...\n");
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
    
    my @filelist = grep {/$repath/} RVT_get_allocfiles('rar$', $disk);

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
	printf ("Finished parsing RAR files. Updating alloc_files...\n");
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
    my @filelist = grep {/$repath/} RVT_get_allocfiles('pdf$', $disk);


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
	printf ("Finished parsing PDF files. Updating alloc_files...\n");
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
    my @filelist = grep {/$repath/} RVT_get_allocfiles('lnk$', $disk);

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
	printf ("Finished parsing LNK files. Updating alloc_files...\n");
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
    my @filelist = grep {/$repath/} RVT_get_allocfiles('evt$', $disk);

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
	printf ("Finished parsing EVT files. Updating alloc_files...\n");
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
    my @listtxt = grep {/$repath/} RVT_get_allocfiles('txt$', $disk);
    my @listcsv = grep {/$repath/} RVT_get_allocfiles('csv$', $disk);
    # emails:
    my @listeml = grep {/$repath/} RVT_get_allocfiles('eml$', $disk);
    my @listdbx = grep {/$repath/} RVT_get_allocfiles('dbx$', $disk);
    # office file types:
    my @listdoc = grep {/$repath/} RVT_get_allocfiles('doc$', $disk);
    my @listppt = grep {/$repath/} RVT_get_allocfiles('ppt$', $disk);
    my @listxls = grep {/$repath/} RVT_get_allocfiles('xls$', $disk);
    my @listrtf = grep {/$repath/} RVT_get_allocfiles('rtf$', $disk);
    # likely to be found in cached webpages:
    my @listhtm = grep {/$repath/} RVT_get_allocfiles('htm$', $disk);
    my @listhtml = grep {/$repath/} RVT_get_allocfiles('html$', $disk);
    my @listphp = grep {/$repath/} RVT_get_allocfiles('php$', $disk);
    my @listasp = grep {/$repath/} RVT_get_allocfiles('asp$', $disk);
    my @listxml = grep {/$repath/} RVT_get_allocfiles('xml$', $disk);

    my @filelist = (@listtxt, @listcsv, @listeml, @listdbx, @listdoc, @listppt, @listxls, @listrtf, @listhtm, @listhtml, @listphp, @listasp, @listxml);

	foreach my $f (@filelist) { 
		my $fpath = RVT_create_file($opath, 'text', 'txt');
		open (FTEXT, "-|", "$FSTRINGS", $f) or die ("ERROR: Failed to open input file $f\n");
		open (FOUT, ">$fpath") or die ("ERR: failed to create output files.");
		print FOUT "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
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
	printf ("Finished parsing files with text strings. Updating alloc_files...\n");
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
#     } else if {
#     
#     } else if {
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
	my $source = 0;
	my $control = 0;
	if ( ! -e $file ) {print "ERROR $file does not exist!!\n"; exit }
	
	# If the file was generated by a one-input-many-output-files plugin (such 
	# as PST, RAR, ZIP), we have to look for metadata in the output directory:
	my $aux = $file;
	$aux =~ s/(.*\/mnt\/p00\/parser\/[a-zA-Z0-9]+\/[a-zA-Z0-9]+-[0-9]+\/).*/\1\/RVT_metadata/;
	if ( -e $aux ) { $file = $aux; }

	open (FILE, $file);	
	while ( $source = <FILE>) {
		if ($source =~ s/# Source file: //) { $control = 1; last; }
	}
	close (FILE);
	if ( $control == 0 ) {print "  RVT_get_source: ERROR, got EOF without finding SOURCE.\n"}
	chomp ($source);
#	print "RVT_get_source: Source of $file is $source\n";
	return $source;
}


1;  

