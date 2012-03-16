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

   $VERSION     = 2.00;

   @ISA         = qw(Exporter);
   @EXPORT      = qw(   &constructor
   						&RVT_script_parse_autoparse
						&RVT_script_parse_search
						&RVT_script_parse_export
					);
}

my $RVT_moduleName = "RVT_parse";
my $RVT_moduleVersion = "2.0";
my $RVT_moduleAuthor = "Pope";

# Changelog:
# 2.0 - March 2012 - Bigger, better, faster - more!
# 1.0 - Initial release. Messy!

use RVTbase::RVT_core;
use RVTbase::RVT_morgue;
use RVTscripts::RVT_files;
use File::Copy;
use File::Copy::Recursive qw (fcopy dircopy);
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

   $main::RVT_functions{RVT_script_parse_autoparse } = "Parse a disk automagically\n
                                                    script parse autoparse <disk>";
   $main::RVT_functions{RVT_script_parse_search } = "Find parsed files containing keywords from a search file\n
                                                    script parse search <search file> <disk>";
   $main::RVT_functions{RVT_script_parse_export } = "Export search results to disk\n
                                                    script parse export <search file> <disk>";
}


sub RVT_build_filelists {
	our @filelist_bkf;
	our @filelist_evt;
	our @filelist_lnk;
	our @filelist_pdf;
	our @filelist_pff;
	our @filelist_rar;
	our @filelist_text;
	our @filelist_zip;
	if( -f $File::Find::name ) {
		# filelist_bkf:
		if( $File::Find::name =~ /\.bkf$/i ) { push( @filelist_bkf, $File::Find::name ) }
		# filelist_evt:
		elsif( $File::Find::name =~ /\.evt$/i ) { push( @filelist_evt, $File::Find::name ) }
		# filelist_lnk:
		elsif( $File::Find::name =~ /\.lnk$/i ) { push( @filelist_lnk, $File::Find::name ) }
		# filelist_pdf:
		elsif( $File::Find::name =~ /\.pdf$/i ) { push( @filelist_pdf, $File::Find::name ) }
		# filelist_pff:
		elsif( $File::Find::name =~ /\.pst$/i ) { push( @filelist_pff, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.ost$/i ) { push( @filelist_pff, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.pab$/i ) { push( @filelist_pff, $File::Find::name ) }
		# filelist_rar:
		elsif( $File::Find::name =~ /\.rar$/i ) { push( @filelist_rar, $File::Find::name ) }
		# filelist_text:
		elsif( $File::Find::name =~ /\.txt$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.csv$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.eml$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.dbx$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.doc$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.xls$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.ppt$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.pps$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.rtf$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.htm$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.html$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.asp$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.php$/i ) { push( @filelist_text, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.xml$/i ) { push( @filelist_text, $File::Find::name ) }
		# filelist_zip:
		elsif( $File::Find::name =~ /\.zip$/i ) { push( @filelist_zip, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.docx$/i ) { push( @filelist_zip, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.xlsx$/i ) { push( @filelist_zip, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.pptx$/i ) { push( @filelist_zip, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.ppsx$/i ) { push( @filelist_zip, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.odt$/i ) { push( @filelist_zip, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.ods$/i ) { push( @filelist_zip, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.odp$/i ) { push( @filelist_zip, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.odg$/i ) { push( @filelist_zip, $File::Find::name ) }
	}
}


sub RVT_get_all_sources {
	# Traces an object origin, recursively, using RVT metadata.
	# Returns a list containing the filename of the original item, and its parent objects,
	# up to a final (/mnt) path.
	my $file = shift;
	chomp( $file );
	my $source = RVT_get_source( $file );
	if( $source ) {
		return( $file, RVT_get_all_sources( $source ) );
	} else {
		return( $file, 0 );
	}
}



sub RVT_get_best_source { 
	my $file = shift( @_ );
	my $found = 0;
	my @results = ( );
	my @sources = RVT_get_all_sources( $file );
	while( (not $found) && (my $source = shift(@sources)) ) {
		if( $source =~ /.*\/output\/parser\/control\/pff.*/ ) {
			# libpff items are treated differently:
			$source =~ s/(\/[A-Z][a-z]*[0-9]{5}).*/\1/;
			push( @results, "$source.html" );
			push( @results, "$source.RVT_metadata" );
			if( -d "$source.attach" ) { push( @results, "$source.attach" ) }
			$found = 1;
		} elsif( $source =~ /\/mnt\/p0[0-9]\// ) {
			push( @results, "$source" );
			$found = 1;
		}
	}
	return( @results );
}

sub RVT_get_source { 
	my $file = shift;
	my $source = 0;
	my $source_type;
	my $got_source = 0;
	
	if( $file =~ /.*\/mnt\/p[0-9]{2}\// ) { $source_type = 'final'; }
	elsif( $file =~ /.*\/output\/parser\/control\/bkf-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/evt-[0-9]*\/evt-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/lnk-[0-9]*\/lnk-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/pdf-[0-9]*\/pdf-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/pff-[0-9]*/ ) { $source_type = 'special_pff'; }
	elsif( $file =~ /.*\/output\/parser\/control\/rar-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/text\/text-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/zip-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	
	if( $source_type eq 'infolder' ) {
		$file =~ s/(.*\/output\/parser\/control\/[a-z]*-[0-9]*)\/.*/\1\/RVT_metadata/;
		$source_type = 'infile';
	} elsif( $source_type eq 'special_pff' ) {
		if( $file =~ /[0-9]{5}\.attach\/[^\/]*$/ ) { # If an attachment, point its parent.
			$source = $file;
			$source =~ s/([0-9]{5})\.attach\/[^\/]*$/\1.html/;
			$got_source = 1;
		}
		else {
			$file =~ s/(.*\/output\/parser\/control\/pff-[0-9]*)\..*/\1.RVT_metadata/;
			$source_type = 'infile';
		}
	}
	
	if( $source_type eq 'infile' ) {
		if ( ! -e $file ) {print "ERROR $file does not exist!!\n"; } #exit }
		open (FILE, "<:encoding(UTF-8)", $file);	
		my $count = 0;
		while ( $source = <FILE>) {
			if ($source =~ s/# Source file: //) { $got_source = 1; last; }
			if ($count > 5) { last; } ## THIS is the number of lines that will be read when looking for the RVT_Source metadata.
			$count++ ;
		}
		close (FILE);
		if ( $got_source == 0 ) {print "  RVT_get_source: ERROR, SOURCE not found.\n"}
	}
	if( $got_source == 0 || $source_type eq 'final' ) { $source = 0 }	
	
	if( $source ) {
		chomp ($source);
		return( $source );
	} else {
		return 0;
	}
}


sub RVT_get_unique_filename ($$) {
	# Given a folder and a filename, checks that the filename is not already present in
	# that folder. If it is, it returns an alternate filename.
	my ( $file, $mother ) = @_;
	$file = basename( $file );
	my $result;
	if ( -e "$mother/$file" ) {
		my $ext = $file;
		$ext =~ s/.*\.([^.]{1,16})$/\1/;
		my $name = $file;
		$name =~ s/(.*)\.[^.]{1,16}$/\1/;
		my $count=1;
		$result = "$mother/$name RVT_Duplicate_$count.$ext";
		while( -e $result ) {
			$count++;
			$result = "$mother/$name RVT_Duplicate_$count.$ext";
		}
	} else {
		$result = "$mother/$file";
	}
	return $result;
}


sub RVT_parse_everything {
    my ( $disk ) = @_;
    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
	my $parsepath = "$morguepath/output/parser/control";
	my @sources;
	my $file;

	# Build list of not-yet-parsed sources:
	mkpath $parsepath unless (-d $parsepath);
	opendir( my $dir, $parsepath ) or warn "WARNING: cannot open dir $parsepath: $!";
	while( defined( $file = readdir $dir ) ) {
		if( $file ne '.' && $file ne '..' && $file ne 'text' && -d "$parsepath/$file" && not -f "$parsepath/$file/__item_is_parsed.RVT_flag" ) { 
			push( @sources, "$parsepath/$file" );
		}
	}
	closedir( $dir );
	if( not -f "$parsepath/__mnt_is_parsed.RVT_flag" ) {
		push( @sources, "$morguepath/mnt" );
	}

	foreach my $item (@sources) {
		print "Parsing source: $item\n";
		# Parse all known file types:
		our @filelist_bkf = ( );
		our @filelist_evt = ( );
		our @filelist_lnk = ( );
		our @filelist_pdf = ( );
		our @filelist_pff = ( );
		our @filelist_rar = ( );
		our @filelist_zip = ( );
		our @filelist_text = ( );
		
		find( \&RVT_build_filelists, $item );
		RVT_parse_bkf( $item, $disk );
		RVT_parse_evt( $item, $disk );
		RVT_parse_lnk( $item, $disk );
		RVT_parse_pdf( $item, $disk );
		RVT_parse_pff( $item, $disk );
		RVT_parse_rar( $item, $disk );
		RVT_parse_zip( $item, $disk );
		RVT_parse_text( $item, $disk );
		
		# Flag this source as parsed.
		if( $item =~ /.*\/mnt$/ ) { $file = "$parsepath/__mnt_is_parsed.RVT_flag" }
		else { $file = "$item/__item_is_parsed.RVT_flag" }
		open( FLAG, ">:encoding(UTF-8)", $file );
		close( FLAG );
		print " Finished parsing source $item.\n";
	}
	
	return 1;
}


sub RVT_parse_bkf {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);

	printf ("  Parsing BKF files... ");
	our @filelist_bkf;
    foreach my $f ( our @listbkf) {
    	print "\n    $f ";
        my $fpath = RVT_create_folder($opath, 'bkf');
		my $output = `mtftar < "$f" | tar xv -C "$fpath" 2>&1 `;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or warn ("WARNING: cannot create metadata files: $!.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
#        my $command = 'mtftar < "'.$f.'" | tar xv -C '.$fpath;
#        `$command`;
    }

	printf ("done.\n");
    return 1;
}


sub RVT_parse_evt {
	my $EVTPARSE = "evtparse.pl";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing EVT files... ");
	our @filelist_evt;
	if( @filelist_evt ) {
		my $evtpath = RVT_create_folder($opath, 'evt');
		my $fpath = RVT_create_file($evtpath, 'evt', 'txt');
		my $count = $fpath;
		$count =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_evt ) {
			$fpath = "$evtpath/evt-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			print "\n    $f ";
			open (FEVT, "-|", "$EVTPARSE", $f) or die "Error: $!";
			binmode (FEVT, ":encoding(cp1252)") || die "Can't binmode to cp1252 encoding\n";
			open (FOUT, ">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create output file.");
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
			$count++;
		}
	} # end if

	printf ("done.\n");
    return 1;
}


sub RVT_parse_lnk {
	my $LNKPARSE = "lnk-parse-1.0.pl";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing LNK files... ");
	our @filelist_lnk;
	if( @filelist_lnk ) {
		my $lnkpath = RVT_create_folder($opath, 'lnk');
		my $fpath = RVT_create_file($lnkpath, 'lnk', 'txt');
		my $count = $fpath;
		$count =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_lnk ) {
			$fpath = "$lnkpath/lnk-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			print "\n    $f ";
			open (FLNK, "-|", "$LNKPARSE", $f);
			open (FOUT, ">:encoding(UTF-8)", "$fpath") or warn ("WARNING: failed to create output file: $!.");
			print FOUT "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
			while (<FLNK>) { print FOUT $_ }
			close (FLNK);
			close (FOUT);
			$count++;
		}
	}
	printf ("done.\n");
    return 1;
}


sub RVT_parse_pdf {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing PDF files... ");
	our @filelist_pdf;
	if( @filelist_pdf ) {
		my $pdfpath = RVT_create_folder($opath, 'pdf');
		my $fpath = RVT_create_file($pdfpath, 'pdf', 'txt');
		my $count = $fpath;
		$count =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_pdf ) {
			$fpath = "$pdfpath/pdf-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			print "\n    $f ";
			my $output = `pdftotext "$f" - 2>&1`;
			open (META, ">:encoding(UTF-8)", "$fpath") or warn ("WARNING: failed to create output files: $!.");
			print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
			print META $output;
			close (META);
			if( $output =~ /^Error: Incorrect password$/ ) {
				open( REPORT, ">>:encoding(UTF-8)", "$opath/password_protected_files.txt" );
				print REPORT "$f\n";
				close( REPORT );
			}
			$count++;
		}
	}
	printf ("done.\n");
    return 1;
}


sub RVT_parse_pff {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing PFF files (PST, OST, PAB)... ");
	our @filelist_pff;
    foreach my $f (@filelist_pff) {
    	print "\n    $f ";
    	my $fpath = RVT_create_file($opath, 'pff', 'RVT_metadata');    	
        open (META,">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create metadata files."); # XX Lo del encoding habría que hacerlo en muchos otros sitios.
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        $fpath =~ s/.RVT_metadata//; 
        my @args = ('pffexport', '-f', 'text', '-m', 'all', '-q', '-t', "$fpath", $f); # -f text and -m all are in fact default options.
        system(@args);        
        foreach my $mode ('export','orphan','recovered') { finddepth( \&RVT_sanitize_libpff_item, "$fpath.$mode" ) }
    }
	printf ("done.\n");
    return 1;
}


sub RVT_parse_rar {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing RAR files... ");
	our @filelist_rar;
    foreach my $f ( our @filelist_rar ) {
    	print "\n    $f ";
        my $fpath = RVT_create_folder($opath, 'rar');
		my $output = `unrar x -ppassword "$f" "$fpath" 2>&1`;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or warn ("WARNING: cannot create metadata files: $!.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		print META $output;
        close (META);
		if( $output =~ /or wrong password./ ) {
			open( REPORT, ">>:encoding(UTF-8)", "$opath/password_protected_files.txt" );
			print REPORT "$f\n";
			close( REPORT );
		}
    }
	printf ("done.\n");
    return 1;
}


sub RVT_parse_text {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/text';
    mkpath $opath unless (-d $opath);
	my $FSTRINGS = "f-strings";

	printf ("  Parsing text files... ");
	our @filelist_text;	
	my $fpath = RVT_create_file($opath, 'text', 'txt');
	my $count = $fpath;
	$count =~ s/.*-([0-9]*).txt$/\1/;
	foreach my $f (@filelist_text) {
		$fpath = "$opath/text-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
		my $normalized = `echo "$f" | f-strings`;
		chomp ($normalized);

		open (FTEXT, "-|", "$FSTRINGS", "$f") or die ("ERROR: Failed to open input file $f\n");
		open (FOUT, ">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create output files.");
		print FOUT "# BEGIN RVT METADATA\n# Source file: $f\n# Normalized name and path: $normalized\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		while (<FTEXT>){
			print FOUT $_;
		}
		close (FTEXT);
		close (FOUT);
		$count++;
	}
	printf ("done.\n");
    return 1;
}


sub RVT_parse_zip {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing ZIP files (and ODF, OOXML)... ");
	our @filelist_zip;
    foreach my $f ( our @filelist_zip ) {
    	print "\n    $f ";
        my $fpath = RVT_create_folder($opath, 'zip');
		my $output = `unzip -P password "$f" -d "$fpath" 2>&1`;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		print META $output;
        close (META);
		if( $output =~ /incorrect password$/ ) {
			open( REPORT, ">>:encoding(UTF-8)", "$opath/password_protected_files.txt" );
			print REPORT "$f\n";
			close( REPORT );
		}
    }
	printf ("done.\n");
    return 1;
}


sub RVT_sanitize_libpff_attachment {
# WARNING!!! This function is to be called ONLY from within RVT_sanitize_libpff_item.
# File descriptors RVT_META and RVT_ITEM are expected to be open when entering this sub.
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
	### Activities:
	$field_names{'Activity'}{'Creation time'} = "Creation";
	$field_names{'Activity'}{'Modification time'} = "Modification";
	$field_names{'Activity'}{'Flags'} = "Flags";
	$field_names{'Activity'}{'Subject'} = "Subject";
	$field_names{'Activity'}{'Sender name'} = "Creator";
	$field_names{'Activity'}{'Sender email address'} = "Creator e-mail address"; # this label is not used
	$field_names{'Activity'}{'Importance'} = "Importance";
	$field_names{'Activity'}{'Priority'} = "Priority";
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
	$field_names{'Message'}{'Client submit time'} = "Sent";
	$field_names{'Message'}{'Delivery time'} = "Received";
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
	my $source = $folder; $source =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9]).output.parser.control/\1/;
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

	# Specific treatment to some headers:
	if( $field_values{'Sender email address'} ) { $field_values{'Sender name'} = "$field_values{'Sender name'} ($field_values{'Sender email address'})" }
	undef $field_values{'Sender email address'}; # We don't want this field printed later. Its value is already stored along the 'Sender name'.
	if( $field_values{'Importance'} eq 'Normal' ) { undef $field_values{'Importance'} }
	if( $field_values{'Priority'} eq 'Normal' ) { undef $field_values{'Priority'} }
	if( $field_values{'Flags'} eq '0x00000001 (Read)' ) { undef $field_values{'Flags'} }
	else { $field_values{'Flags'} =~ s/.*Read, (.*)\)/\1/ }
	# Write RVT_ITEM:
	print RVT_ITEM "<HTML><!--#$field_values{'Sender name'}#$field_values{'Client submit time'}#$field_values{'Subject'}#$to#$cc#$bcc#$field_values{'Flags'}#-->
<HEAD>\n	<TITLE>\n		$field_values{'Subject'}\n	</TITLE>\n	<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n</HEAD>\n<BODY>\n	<TABLE border=1 rules=all frame=box>\n		<tr><td><b>Outlook item</b></td><td>$item_type&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"",basename( $folder) ,".RVT_metadata\" target=\"_blank\">[Headers]</a></td></tr>\n		<tr><td><b>Source</b></td><td>$source</td></tr>\n";
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


sub RVT_script_parse_autoparse {
	# works at disk level. Supports @disks.
	my $disk = shift( @_ );
	$disk = $main::RVT_level->{tag} unless $disk;
	while( $disk ) {
		my $max_passes = 20;
		if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	
		RVT_images_scan;    
		RVT_mount_assign( $disk );
		for( my $i = 1; $i < $max_passes ; $i++ ) {
			RVT_parse_everything( $disk );
		}
		$disk = shift( @_ );
	}
	return 1;
}


sub RVT_script_parse_export  {
    # Exports results (from script parse search) to disk.
    # takes as arguments:
    #   file with searches: one per line
    #   one or more disks from the morgue (supports @disks)

    my $searchesfilename = shift( @_ );
	my $disk = shift( @_ );
	$disk = $main::RVT_level->{tag} unless $disk;
    while( $disk ) {
		my $string;
		print "\t Exporting search results for $disk\n";
		my $case = RVT_get_casenumber($disk);
		my $diskpath = RVT_get_morguepath($disk);
		my $searchespath = "$diskpath/output/parser/searches/";
		my $exportpath = "$diskpath/output/parser/export/";
		return 0 if (! $diskpath);
		if (! -e $exportpath) { mkdir $exportpath or return 0; }
		
		open (F, "<:encoding(UTF-8)", RVT_get_morguepath($case)."/searches_files/$searchesfilename") or return 0;
		my @searches = grep {!/^\s*#/} <F>;
		close (F);
		
		for $string ( @searches ) { # For each search string...
			chomp $string;
			$string = lc($string);
			print "-- $string\n";
			open (FMATCH, "$searchespath/$string");
			my $opath = "$exportpath/$string";
			mkdir $opath;
			mkdir "$opath/files";
			mkdir "$opath/outlook";
			while (my $file = <FMATCH>) { # For each line of results...
				chomp ( $file );
				$file =~ s/#.*//; # we discard the rest of the sources and re-calculate them:
				my @results = RVT_get_best_source( $file );
				while( my $result = shift( @results ) ) {
					if( $result =~ /.*\/output\/parser\/control\/pff-[0-9]*\..*/ ) { # libpff items are different...
						my $dest = $result;
						$dest =~ s/.*\/output\/parser\/control\/(pff-[0-9]*\..*)/\1/;
						if( -f $result ) {
							fcopy( $result, "$opath/outlook/$dest" );
						} elsif( -d $result ) {
							dircopy( $result, "$opath/outlook/$dest" );
						}
					} else { # Common files
						my $dest = RVT_get_unique_filename( $result, "$opath/files" );
						fcopy( $result, $dest );
						open( REPORT, ">>:encoding(UTF-8)", "$opath/RVT_report.txt" );
						print REPORT "$result -> $dest\n";
						close( REPORT );
					}
				}
			} # end while ... (for each line of results...)
		} # end for each string...
		$disk = shift( @_ );
	} # end while( $disk )
	return 1;
}


sub RVT_script_parse_search  {
    # launches a search over indexed (PARSEd) files writing results (hits) to a file.
    # takes as arguments:
    #   file with searches: one per line
    #   one or more disks from the morgue (supports @disks)

    my $searchesfilename = shift( @_ );
    my $disk = shift( @_ );
	$disk = $main::RVT_level->{tag} unless $disk;
    while( $disk ) {
		my $string;
		print "\t Launching searches for $disk\n";
		my $case = RVT_get_casenumber($disk);
		my $diskpath = RVT_get_morguepath($disk);
		my $parsedfiles = "$diskpath/output/parser/control/text/";
		my $searchespath = "$diskpath/output/parser/searches/";
		return 0 if (! $diskpath);
		return 0 if (! -d $parsedfiles);
		if (! -e $searchespath) { mkdir $searchespath or return 0; }
	
		open (F, "<:encoding(UTF-8)", RVT_get_morguepath($case)."/searches_files/$searchesfilename") or return 0;
		my @searches = grep {!/^\s*#/} <F>;
		close (F);
		
		for $string ( @searches ) {
			chomp $string;
			$string = lc($string);
			print "-- $string\n";
			open (FMATCH, "-|", "grep", "-Hl", $string, $parsedfiles, "-R");
			open (FOUT, ">:encoding(UTF-8)", "$searchespath/$string");
			while (my $file = <FMATCH>) {
				chomp( $file );
				my @sources = RVT_get_all_sources( $file );
				my $line = '';
				while( my $source = shift( @sources) ) {
					$line = "$line$source#";
				}
				print FOUT "$line\n";
			}
			close FMATCH;
			close FOUT;
		}
		$disk = shift( @_ );
	} # end while( $disk )
    return 1;
}


1;