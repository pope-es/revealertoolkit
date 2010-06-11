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


# KNOWN ISSUES:
# We are not logging whether parsing was successful. Code for this in PST module was wrong (it always reported error even when it was OK).



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
                            &RVT_script_parse_zip
                            &RVT_script_parse_rar
                            &RVT_script_parse_pdf
                            &RVT_script_parse_text
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
use Data::Dumper;

sub constructor {
   
   my $pdftotext = `pdftotext -v 2>&1`;
   my $readpst = `readpst -V`;
   my $unzip = `unzip -v`;
   my $unrar = `unrar --help`;
   my $fstrings = `f-strings -h`;
   
   if (!$pdftotext) {
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find pdftotext)');
        return;
   }
   if (!$readpst) {
        RVT_log ('ERR', 'RVT_mail not loaded (couldn\'t find libpst)');
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
        RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find f-strings, please locate in tools directory and copy to /usr/local/bin or somewhere in your path)');
        return;
   }


   $main::RVT_requirements{'readpst'} = $readpst;
   $main::RVT_requirements{'pdftotext'} = $pdftotext;
   $main::RVT_requirements{'unzip'} = $unzip;
   $main::RVT_requirements{'unrar'} = $unrar;
   $main::RVT_requirements{'fstrings'} = $fstrings;

   $main::RVT_functions{RVT_script_parse_pst } = "Parses all PST's found on the partition using libpst\n
                                                    script parse pst <partition>";
   $main::RVT_functions{RVT_script_parse_zip } = "Extracts contents from ZIP, ODT and OOXML files\n
                                                    script parse zip <partition>";
   $main::RVT_functions{RVT_script_parse_rar } = "Extracts contents from RAR archives\n
                                                    script parse rar <partition>";
   $main::RVT_functions{RVT_script_parse_pdf } = "Extracts text from PDFs using pdftotext\n
                                                    script parse pdf <partition>";
   $main::RVT_functions{RVT_script_parse_text } = "Extracts raw text strings from suitable files\n
                                                    script parse text <partition>";
}


# This routine is taken from RVT_mail.pm r102:
sub RVT_script_parse_pst {

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser';
    mkdir $opath unless (-d $opath);
    
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
	if ( ! -e $morguepath.'/mnt/p00/output_parser' ) { 
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/output_parser');
		system (@args);
	}
	printf ("Finished parsing PST files. Updating alloc_files...\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}



sub RVT_script_parse_zip {

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser';
    mkdir $opath unless (-d $opath);
    
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
	my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/output_parser');
	if ( ! -e $morguepath.'/mnt/p00/output_parser' ) { system (@args); }
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
    my $opath = RVT_get_morguepath($disk) . '/output/parser';
    mkdir $opath unless (-d $opath);
    
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
	my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/output_parser');
	if ( ! -e $morguepath.'/mnt/p00/output_parser' ) { system (@args); }
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
    my $opath = RVT_get_morguepath($disk) . '/output/parser';
    mkdir $opath unless (-d $opath);
    
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
	if ( ! -e $morguepath.'/mnt/p00/output_parser' ) { 
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/output_parser');
		system (@args);
	}
	printf ("Finished parsing PDF files. Updating alloc_files...\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}



sub RVT_script_parse_text {

	my $FSTRINGS = "f-strings";

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser';
    mkdir $opath unless (-d $opath);
    
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
	if ( ! -e $morguepath.'/mnt/p00/output_parser' ) { 
		my @args = ('ln', '-s', $opath, $morguepath.'/mnt/p00/output_parser');
		system (@args);
	}
	printf ("Finished parsing files with text strings. Updating alloc_files...\n");
	RVT_script_files_allocfiles($disk);
    return 1;
}



1;  

