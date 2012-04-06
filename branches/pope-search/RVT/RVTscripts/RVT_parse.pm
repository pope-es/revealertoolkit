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

#
# NOTE FOR DEVELOPERS:
# These are the necessary steps for a new plugin to work:
#
# 1) Write the code for your new plugin (for instance: RVT_parse_bmp). Depending on the
# wanted behavior, you can use any of the existing modules (zip, pdf...) as a template.
#
# 2) In "RVT_build_filelists", declare your file list in block "Declare (our) file lists"
# and populate it in block "Populate the file lists with files with certain extensions".
#
# 3) In RVT_parse_everything, initialize the empty file list in block "Initialize file
# lists", and call your new plugin in block "Parse all known file types".
# 
# 4) Modify RVT_get_source (and optionally RVT_get_best_source) to have them understand
# the output of your new plugin.
# 
# That's all.
#

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
   						&RVT_script_parse_index
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
use Email::MIME; # Needed by RVT_parse_eml
use Email::Outlook::Message; # Needed by RVT_parse_msg
use File::stat; # needed by RVT_index_regular_file
use Time::localtime; # needed by RVT_index_regular_file
use Mail::Transport::Dbx;

sub constructor {

	my $arj = `arj`;
	my $bunzip2 = `bunzip2 -V 2>&1`;
	my $evtparse = `evtparse.pl`;
	my $fstrings = `f-strings -h`;
	my $gunzip = `gunzip -V`;
	my $lnkparse = `lnk-parse-1.0.pl`;
	my $mtftar = `mtftar 2>&1`;
	my $pdftotext = `pdftotext -v 2>&1`;
	my $pffexport = `pffexport -V`;
	my $unrar = `unrar --help`;
	my $unzip = `unzip -v`;
   
	if (!$bunzip2) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find bunzip2)'); return }
	if (!$evtparse) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find Harlan Carvey\'s evtparse.pl, please locate in tools directory and copy to /usr/local/bin or somewhere in your path)'); return }
	if (!$fstrings) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find f-strings, please locate in tools directory, compile (gcc f-strings.c -o f-strings) and copy to /usr/local/bin or somewhere in your path)'); return }
	if (!$gunzip) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find gunzip)'); return }
	if (!$lnkparse) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find Jacob Cunningham\'s lnk-parse-1.0.pl, please locate in tools directory and copy to /usr/local/bin or somewhere in your path)'); return }
	if (!$mtftar) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find mtftar)'); return }
	if (!$pdftotext) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find pdftotext)'); return }
	if (!$pffexport) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find pffexport)'); return }
	if (!$unrar) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find unrar)'); return }
	if (!$unzip) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find unzip)'); return }



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
   $main::RVT_functions{RVT_script_parse_index } = "Creates an index of exported items\n
                                                    script parse index <folder in the filesystem>";
}


##########################################################################
# Subs that need to be modified for new plugins
##########################################################################



sub RVT_build_filelists {

	# Declare (our) file lists:
	our @filelist_arj;
	our @filelist_bkf;
	our @filelist_bz;
	our @filelist_dbx;
	our @filelist_eml;
	our @filelist_evt;
	our @filelist_gz;
	our @filelist_lnk;
	our @filelist_msg;
	our @filelist_pdf;
	our @filelist_pff;
	our @filelist_rar;
	our @filelist_tar;
	our @filelist_text;
	our @filelist_zip;

	# Populate the file lists with files with certain extensions:
	if( -f $File::Find::name ) {
		# filelist_arj:
		if( $File::Find::name =~ /\.arj$/i ) { push( @filelist_arj, $File::Find::name ) }		# ARJ compressed file
		# filelist_bkf:
		if( $File::Find::name =~ /\.bkf$/i ) { push( @filelist_bkf, $File::Find::name ) }		# MS Windows backup
		# filelist_bz:
		elsif( $File::Find::name =~ /\.bz$/i ) { push( @filelist_bz, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.bz2$/i ) { push( @filelist_bz, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.tbz$/i ) { push( @filelist_bz, $File::Find::name ) }		# .tar.bz
		elsif( $File::Find::name =~ /\.tbz2$/i ) { push( @filelist_bz, $File::Find::name ) }	# .tar.bz2
		# filelist_dbx:
		elsif( $File::Find::name =~ /\.dbx$/i ) { push( @filelist_dbx, $File::Find::name ) }
		# filelist_eml:
		elsif( $File::Find::name =~ /\.eml$/i ) { push( @filelist_eml, $File::Find::name ) }
		# filelist_evt:
		elsif( $File::Find::name =~ /\.evt$/i ) { push( @filelist_evt, $File::Find::name ) }
		# filelist_gz:
		elsif( $File::Find::name =~ /\.gz$/i ) { push( @filelist_gz, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.tgz$/i ) { push( @filelist_gz, $File::Find::name ) }		# .tar.gz
		# filelist_lnk:
		elsif( $File::Find::name =~ /\.lnk$/i ) { push( @filelist_lnk, $File::Find::name ) }
		# filelist_msg:
		elsif( $File::Find::name =~ /\.msg$/i ) { push( @filelist_msg, $File::Find::name ) }
		# filelist_pdf:
		elsif( $File::Find::name =~ /\.pdf$/i ) { push( @filelist_pdf, $File::Find::name ) }
		# filelist_pff:
		elsif( $File::Find::name =~ /\.pab$/i ) { push( @filelist_pff, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.pst$/i ) { push( @filelist_pff, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.ost$/i ) { push( @filelist_pff, $File::Find::name ) }
		# filelist_rar:
		elsif( $File::Find::name =~ /\.rar$/i ) { push( @filelist_rar, $File::Find::name ) }
		# filelist_tar:
		elsif( $File::Find::name =~ /\.tar$/i ) { push( @filelist_tar, $File::Find::name ) }
		# filelist_text:
		elsif( $File::Find::name =~ /\.accdb$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Access 2007 database
		elsif( $File::Find::name =~ /\.accde$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Access 2007 "execute-only" database
		elsif( $File::Find::name =~ /\.accdr$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Access 2007 database "runtime"
		elsif( $File::Find::name =~ /\.accdt$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Access 2007 database template
		elsif( $File::Find::name =~ /\.asp$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
		elsif( $File::Find::name =~ /\.bak$/i ) { push( @filelist_text, $File::Find::name ) }	# Typical MS-DOS backup file
		elsif( $File::Find::name =~ /\.bat$/i ) { push( @filelist_text, $File::Find::name ) }	# MS-DOS batch file
		elsif( $File::Find::name =~ /\.cmd$/i ) { push( @filelist_text, $File::Find::name ) }	# MS-DOS batch file
		elsif( $File::Find::name =~ /\.csv$/i ) { push( @filelist_text, $File::Find::name ) }	# CSV, comma-separated values
		elsif( $File::Find::name =~ /\.dbf$/i ) { push( @filelist_text, $File::Find::name ) }	# dBASE
		elsif( $File::Find::name =~ /\.doc$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Word document
		elsif( $File::Find::name =~ /\.fodb$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (database)
		elsif( $File::Find::name =~ /\.fodc$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (chart)
		elsif( $File::Find::name =~ /\.fodf$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (formula)
		elsif( $File::Find::name =~ /\.fodg$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (graphics/drawing)
		elsif( $File::Find::name =~ /\.fodi$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (image)
		elsif( $File::Find::name =~ /\.fodm$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (master document)
		elsif( $File::Find::name =~ /\.fodp$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (presentation)
		elsif( $File::Find::name =~ /\.fods$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (spreadsheet)
		elsif( $File::Find::name =~ /\.fodt$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF flat (text)
		elsif( $File::Find::name =~ /\.fotc$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template flat (chart)
		elsif( $File::Find::name =~ /\.fotf$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template flat (formula)
		elsif( $File::Find::name =~ /\.fotg$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template flat (graphics/drawing)
		elsif( $File::Find::name =~ /\.foth$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template flat (web page)
		elsif( $File::Find::name =~ /\.foti$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template flat (image)
		elsif( $File::Find::name =~ /\.fotp$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template flat (presentation)
		elsif( $File::Find::name =~ /\.fots$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template flat (spreadsheet)
		elsif( $File::Find::name =~ /\.fott$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template flat (text)
		elsif( $File::Find::name =~ /\.htm$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
		elsif( $File::Find::name =~ /\.html$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
		elsif( $File::Find::name =~ /\.json$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
		elsif( $File::Find::name =~ /\.log$/i ) { push( @filelist_text, $File::Find::name ) }	# Log files
		elsif( $File::Find::name =~ /\.mdb$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Access database
		elsif( $File::Find::name =~ /\.nfo$/i ) { push( @filelist_text, $File::Find::name ) }	# Usually text files
		elsif( $File::Find::name =~ /\.php$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
		elsif( $File::Find::name =~ /\.ppt$/i ) { push( @filelist_text, $File::Find::name ) }	# MS PowerPoint presentation
		elsif( $File::Find::name =~ /\.pps$/i ) { push( @filelist_text, $File::Find::name ) }	# MS PowerPoint presentation show
		elsif( $File::Find::name =~ /\.ps1$/i ) { push( @filelist_text, $File::Find::name ) }	# PowerShell
		elsif( $File::Find::name =~ /\.rtf$/i ) { push( @filelist_text, $File::Find::name ) }	# RTF, rich text format
		elsif( $File::Find::name =~ /\.tmp$/i ) { push( @filelist_text, $File::Find::name ) }	# Temporary files, hopefully will contain text strings
		elsif( $File::Find::name =~ /\.txt$/i ) { push( @filelist_text, $File::Find::name ) }	# Text files
		elsif( $File::Find::name =~ /\.uof$/i ) { push( @filelist_text, $File::Find::name ) }	# Unified Office Format -- these are XML
		elsif( $File::Find::name =~ /\.uop$/i ) { push( @filelist_text, $File::Find::name ) }	# Unified Office Format presentation
		elsif( $File::Find::name =~ /\.uos$/i ) { push( @filelist_text, $File::Find::name ) }	# Unified Office Format spreadsheet
		elsif( $File::Find::name =~ /\.uot$/i ) { push( @filelist_text, $File::Find::name ) }	# Unified Office Format text
		elsif( $File::Find::name =~ /\.vbs$/i ) { push( @filelist_text, $File::Find::name ) }	# VisualBasic Script
		elsif( $File::Find::name =~ /\.wpd$/i ) { push( @filelist_text, $File::Find::name ) }	# Corel WordPerfect
		elsif( $File::Find::name =~ /\.xls$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Excel spreadsheet
		elsif( $File::Find::name =~ /\.xlsb$/i ) { push( @filelist_zip, $File::Find::name ) }	# MS Excel 2007 binary workbook
		elsif( $File::Find::name =~ /\.xml$/i ) { push( @filelist_text, $File::Find::name ) }	# XML
		# filelist_zip:
		elsif( $File::Find::name =~ /\.docx$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (text)
		elsif( $File::Find::name =~ /\.docm$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (text, macro-enabled document)
		elsif( $File::Find::name =~ /\.dotm$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML template (text, macro-enabled)
		elsif( $File::Find::name =~ /\.dotx$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML template (text)
		elsif( $File::Find::name =~ /\.odb$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (database)
		elsif( $File::Find::name =~ /\.odc$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (chart)
		elsif( $File::Find::name =~ /\.odf$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (formula)
		elsif( $File::Find::name =~ /\.odg$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (graphics/drawing)
		elsif( $File::Find::name =~ /\.odi$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (image)
		elsif( $File::Find::name =~ /\.odm$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (master document)
		elsif( $File::Find::name =~ /\.odp$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (presentation)
		elsif( $File::Find::name =~ /\.ods$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (spreadsheet)
		elsif( $File::Find::name =~ /\.odt$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF (text)
		elsif( $File::Find::name =~ /\.otc$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template (chart)
		elsif( $File::Find::name =~ /\.otf$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template (formula)
		elsif( $File::Find::name =~ /\.otg$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template (graphics/drawing)
		elsif( $File::Find::name =~ /\.oth$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template (web page)
		elsif( $File::Find::name =~ /\.oti$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template (image)
		elsif( $File::Find::name =~ /\.otp$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template (presentation)
		elsif( $File::Find::name =~ /\.ots$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template (spreadsheet)
		elsif( $File::Find::name =~ /\.ott$/i ) { push( @filelist_zip, $File::Find::name ) }	# ODF template (text)
		elsif( $File::Find::name =~ /\.potx$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML template (presentation)
		elsif( $File::Find::name =~ /\.potm$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML template (presentation, macro-enabled)
		elsif( $File::Find::name =~ /\.ppam$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (PowerPoint 2007 macro-enabled add-in)
		elsif( $File::Find::name =~ /\.pptm$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (presentation, macro-enabled document)
		elsif( $File::Find::name =~ /\.pptx$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (presentation)
		elsif( $File::Find::name =~ /\.ppsx$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (presentation show)
		elsif( $File::Find::name =~ /\.ppsm$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (presentation show, macro-enabled document)
		elsif( $File::Find::name =~ /\.stc$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML template (spreadsheet)
		elsif( $File::Find::name =~ /\.std$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML template (graphics/drawing)
		elsif( $File::Find::name =~ /\.sti$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML template (presentation)
		elsif( $File::Find::name =~ /\.stw$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML template (text)
		elsif( $File::Find::name =~ /\.sxc$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML (spreadsheet)
		elsif( $File::Find::name =~ /\.sxd$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML (graphics/drawing)
		elsif( $File::Find::name =~ /\.sxg$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML (master document)
		elsif( $File::Find::name =~ /\.sxi$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML (presentation)
		elsif( $File::Find::name =~ /\.sxm$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML (formula)
		elsif( $File::Find::name =~ /\.sxw$/i ) { push( @filelist_zip, $File::Find::name ) }	# OpenOffice.org XML (text)
		elsif( $File::Find::name =~ /\.xlam$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (MS Excel 2007 macro-enabled add-in)
		elsif( $File::Find::name =~ /\.xlsx$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (spreadsheet)
		elsif( $File::Find::name =~ /\.xlsm$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML (spreadsheet, macro-enabled document)
		elsif( $File::Find::name =~ /\.xltm$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML template (spreadsheet, macro-enabled)
		elsif( $File::Find::name =~ /\.xltx$/i ) { push( @filelist_zip, $File::Find::name ) }	# OOXML template (spreadsheet)
		elsif( $File::Find::name =~ /\.zip$/i ) { push( @filelist_zip, $File::Find::name ) }	# ZIP files
	}
}



sub RVT_parse_everything {
	# This sub is called from within RVT_script_parse_autoparse

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

		# Initialize file lists:
		our @filelist_arj = ( );
		our @filelist_bkf = ( );
		our @filelist_bz = ( );
		our @filelist_dbx = ( );
		our @filelist_eml = ( );
		our @filelist_evt = ( );
		our @filelist_gz = ( );
		our @filelist_lnk = ( );
		our @filelist_msg = ( );
		our @filelist_pdf = ( );
		our @filelist_pff = ( );
		our @filelist_rar = ( );
		our @filelist_tar = ( );
		our @filelist_zip = ( );
		our @filelist_text = ( );
		find( \&RVT_build_filelists, $item );

		# Parse all known file types:
		RVT_parse_arj( $item, $disk );
		RVT_parse_bkf( $item, $disk );
		RVT_parse_bz( $item, $disk );
		RVT_parse_dbx( $item, $disk );
		RVT_parse_eml( $item, $disk );
		RVT_parse_evt( $item, $disk );
		RVT_parse_gz( $item, $disk );
		RVT_parse_lnk( $item, $disk );
		RVT_parse_msg( $item, $disk );
		RVT_parse_pdf( $item, $disk );
		RVT_parse_pff( $item, $disk );
		RVT_parse_rar( $item, $disk );
		RVT_parse_tar( $item, $disk );
		RVT_parse_zip( $item, $disk );
		RVT_parse_text( $item, $disk );
		
		# Flag source as parsed.
		if( $item =~ /.*\/mnt$/ ) { $file = "$parsepath/__mnt_is_parsed.RVT_flag" }
		else { $file = "$item/__item_is_parsed.RVT_flag" }
		open( FLAG, ">:encoding(UTF-8)", $file );
		close( FLAG );

		print "  Source parsed: $item\n";
	}	
	return 1;
}




##########################################################################
# Exported subs (RVT script commands)
##########################################################################



sub RVT_script_parse_autoparse {
	# works at disk level. Supports @disks.
	my $disk = shift( @_ );
	$disk = $main::RVT_level->{tag} unless $disk;
	while( $disk ) {
		my $max_passes = 20;
		if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
		RVT_images_scan( $disk );
		RVT_mount_assign( $disk );
		for( my $i = 1; $i < $max_passes ; $i++ ) {
			RVT_parse_everything( $disk );
		}
		$disk = shift( @_ );
	}
	RVT_script_parse_export( ":allspecial", $disk );
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
		my $exportpath = "$diskpath/output/parser/export";
		return 0 if (! $diskpath);
		if (! -e $exportpath) { mkdir $exportpath or return 0; }
		
		my @searches = ();
		if( $searchesfilename =~ /^:encrypted$/ ) {
			push( @searches, "rvt_encrypted" );
		} elsif( $searchesfilename =~ /^:malformed$/ ) {
			push( @searches, "rvt_malformed" );
		} elsif( $searchesfilename =~ /^:allspecial$/ ) {
			push( @searches, "rvt_encrypted", "rvt_malformed" );
		} else {
			open (F, "<:encoding(UTF-8)", RVT_get_morguepath($case)."/searches_files/$searchesfilename") or return 0;
			@searches = grep {!/^\s*#/} <F>;
			close (F);
		}
		
		for $string ( @searches ) { # For each search string...
			chomp $string;
			$string = lc($string);
			print "-- $string\n";
			open (FMATCH, "$searchespath/$string");
			my $opath = "$exportpath/$string";
			mkdir $opath;
			mkdir "$opath/files";
			mkdir "$opath/outlook";
			my %copied;
			open( FILEINDEX, ">>:encoding(UTF-8)", "$opath/files/__file_index.RVT_metadata" );
			while (my $file = <FMATCH>) { # For each line of results...
				chomp ( $file );
				$file =~ s/#.*//; # we discard the rest of the sources and re-calculate them:
				my @results = RVT_get_best_source( $file );
				while( my $result = shift( @results ) ) {
					if( ! $copied{$result} ) { # this is to avoid things such as hits in multiple files inside a ZIP archive generating many copies of that ZIP.
						if( ($result =~ /.*\/output\/parser\/control\/pff-[0-9]*\..*/) or ($result =~ /.*\/output\/parser\/control\/eml-[0-9]+\/eml-[0-9].*/) ) { # libpff items are different...
							my $dest = $result;
							$dest =~ s/.*\/output\/parser\/control\/(pff-[0-9]*\..*)/\1/;
							$dest =~ s/.*\/output\/parser\/control\/(eml-[0-9]+\/.*)/\1/;
							if( -f $result ) {
								fcopy( $result, "$opath/outlook/$dest" );
							} elsif( -d $result ) {
								dircopy( $result, "$opath/outlook/$dest" );
							}
						} else { # Common files
							my $dest = RVT_get_unique_filename( $result, "$opath/files" );
							fcopy( $result, $dest );
							print FILEINDEX $result.":".$dest."\n";
							open( ORIGIN, ">:encoding(UTF-8)", "$dest.RVT_metadata" );
							print ORIGIN "$result";
							close ORIGIN;
						}
						$copied{$result} = 1;
					}
				} # end while( my $result = shift( @results ) ) {
			} # end while (my $file = <FMATCH>) { # For each line of results...
			close( FILEINDEX );
			RVT_script_parse_index( $opath );
		} # end for each string...
		$disk = shift( @_ );
	} # end while( $disk )
	return 1;
}



sub RVT_script_parse_index {
	our $folder_to_index = shift( @_ ); # this parameter is accessed by RVT_index_outlook_item
	print "  Creating $folder_to_index/RVT_index.html ... ";
	if( ! -d $folder_to_index ) {
		warn "ERROR: Not a directory: $folder_to_index ($!)\nOMMITING COMMAND: create index $folder_to_index\n";
		return;
	}
	
	my $index_type;
 	if( ( -d "$folder_to_index/files" ) or ( -d "$folder_to_index/outlook" ) ) { $index_type = 'search_results' }
 	else { $index_type = 'misc' }
	
	my $index = "$folder_to_index/RVT_index.html";
	if( -f $index ) { print "WARNING: Overwriting existing index. " }
	
	open( RVT_INDEX, ">:encoding(UTF-8)", "$index" ) or warn "WARNING: cannot open $index for writing.\n$!\n";
	print RVT_INDEX "<HTML>
<HEAD> <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
<style type=\"text/css\">
	tr.row1 td { background:white; }
	tr.row2 td { background:lightgrey; }
	table, tr, td { border: 1px solid grey; font-family:sans-serif; font-size:small; }
	table { border-collapse:collapse; }
	td { padding: 5 px; }
</style>
<script type=\"text/javascript\">
<!--\n// Copyright 2007 - 2010 Gennadiy Shvets\n// The program is distributed under the terms of the GNU General\n// Public License 3.0\n//\n// See http://www.allmyscripts.com/Table_Sort/index.html for usage details.\n\n// Script version 1.8\n\nvar TSort_Store;\nvar TSort_All;\n\nfunction TSort_StoreDef () {\n	this.sorting = [];\n	this.nodes = [];\n	this.rows = [];\n	this.row_clones = [];\n	this.sort_state = [];\n	this.initialized = 0;\n//	this.last_sorted = -1;\n	this.history = [];\n	this.sort_keys = [];\n	this.sort_colors = [ '#FF0000', '#800080', '#0000FF' ];\n};\n\nfunction tsInitOnload ()\n{\n	//	If TSort_All is not initialized - do it now (simulate old behavior)\n	if	(TSort_All == null)\n		tsRegister();\n\n	for (var id in TSort_All)\n	{\n		tsSetTable (id);\n		tsInit();\n	}\n	if	(window.onload_sort_table)\n		window.onload_sort_table();\n}\n\nfunction tsInit()\n{\n\n	if	(TSort_Data.push == null)\n		return;\n	var table_id = TSort_Data[0];\n	var table = document.getElementById(table_id);\n	// Find thead\n	var thead = table.getElementsByTagName('thead')[0];\n	if	(thead == null)\n	{\n		alert ('Cannot find THEAD tag!');\n		return;\n	}\n	var tr = thead.getElementsByTagName('tr');\n	var cols, i, node, len;\n	if	(tr.length > 1)\n	{\n		var	cols0 = tr[0].getElementsByTagName('th');\n		if	(cols0.length == 0)\n			cols0 = tr[0].getElementsByTagName('td');\n		var cols1;\n		var	cols1 = tr[1].getElementsByTagName('th');\n		if	(cols1.length == 0)\n			cols1 = tr[1].getElementsByTagName('td');\n		cols = new Array ();\n		var j0, j1, n;\n		len = cols0.length;\n		for (j0 = 0, j1 = 0; j0 < len; j0++)\n		{\n			node = cols0[j0];\n			n = node.colSpan;\n			if	(n > 1)\n			{\n				while (n > 0)\n				{\n					cols.push (cols1[j1++]);\n					n--;\n				}\n			}\n			else\n			{\n				if	(node.rowSpan == 1)\n					j1++;\n				cols.push (node);\n			}\n		}\n	}\n	else\n	{\n		cols = tr[0].getElementsByTagName('th');\n		if	(cols.length == 0)\n			cols = tr[0].getElementsByTagName('td');\n	}\n	len = cols.length;\n	for (var i = 0; i < len; i++)\n	{\n		if	(i >= TSort_Data.length - 1)\n			break;\n		node = cols[i];\n		var sorting = TSort_Data[i + 1].toLowerCase();\n		if	(sorting == null)  sorting = '';\n		TSort_Store.sorting.push(sorting);\n\n		if	((sorting != null)&&(sorting != ''))\n		{\n//			node.tsort_col_id = i;\n//			node.tsort_table_id = table_id;\n//			node.onclick = tsDraw;\n			node.innerHTML = \"<a href='' onClick=\\\"tsDraw(\" + i + \",'\" +\n				table_id + \"'); return false\\\">\" + node.innerHTML +\n				'</a><b><span id=\"TS_' + i + '_' + table_id + '\"></span></b>';\n			node.style.cursor = \"pointer\";\n		}\n	}\n\n	// Get body data\n	var tbody = table.getElementsByTagName('tbody')[0];\n	if	(tbody == null)	return;\n	// Get TR rows\n	var rows = tbody.getElementsByTagName('tr');\n	var date = new Date ();\n	var len, text, a;\n	for (i = 0; i < rows.length; i++)\n	{\n		var row = rows[i];\n		var cols = row.getElementsByTagName('td');\n		var row_data = [];\n		for (j = 0; j < cols.length; j++)\n		{\n			// Get cell text\n			text = cols[j].innerHTML.replace(/^\\\s+/, '');\n			text = text.replace(/\\\s+\$/, '');\n			var sorting = TSort_Store.sorting[j];\n			if	(sorting == 'h')\n			{\n				text = text.replace(/<[^>]+>/g, '');\n				text = text.toLowerCase();\n			}\n			else if	(sorting == 's')\n				text = text.toLowerCase();\n			else if (sorting == 'i')\n			{\n				text = parseInt(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'n')\n			{\n				text = text.replace(/(\\\d)\\\,(?=\\\d\\\d\\\d)/g, \"\$1\");\n				text = parseInt(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'c')\n			{\n				text = text.replace(/^\\\$/, '');\n				text = text.replace(/(\\\d)\\\,(?=\\\d\\\d\\\d)/g, \"\$1\");\n				text = parseFloat(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'f')\n			{\n				text = parseFloat(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'g')\n			{\n				text = text.replace(/(\\\d)\\\,(?=\\\d\\\d\\\d)/g, \"\$1\");\n				text = parseFloat(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'd')\n			{\n				if	(text.match(/^\\\d\\\d\\\d\\\d\\\-\\\d\\\d?\\\-\\\d\\\d?(?: \\\d\\\d?:\\\d\\\d?:\\\d\\\d?)?\$/))\n				{\n					a = text.split (/[\\\s\\\-:]/);\n					text = (a[3] == null)?\n						Date.UTC(a[0], a[1] - 1, a[2],    0,    0,    0, 0):\n						Date.UTC(a[0], a[1] - 1, a[2], a[3], a[4], a[5], 0);\n				}\n				else\n					text = Date.parse(text);\n			}\n			row_data.push(text);\n		}\n		TSort_Store.rows.push(row_data);\n		// Save a reference to the TR element\n		var new_row = row.cloneNode(true);\n		new_row.tsort_row_id = i;\n		TSort_Store.row_clones[i] = new_row;\n	}\n	TSort_Store.initialized = 1;\n\n	if	(TSort_Store.cookie)\n	{\n		var allc = document.cookie;\n		i = allc.indexOf (TSort_Store.cookie + '=');\n		if	(i != -1)\n		{\n			i += TSort_Store.cookie.length + 1;\n			len = allc.indexOf (\";\", i);\n			text = decodeURIComponent (allc.substring (i, (len == -1)?\n				allc.length: len));\n			TSort_Store.initial = (text == '')? null: text.split(/\\\s*,\\\s*/);\n		}\n	}\n\n	var	initial = TSort_Store.initial;\n	if	(initial != null)\n	{\n		var itype = typeof initial;\n		if	((itype == 'number')||(itype == 'string'))\n			tsDraw(initial);\n		else\n		{\n			for (i = initial.length - 1; i >= 0; i--)\n				tsDraw(initial[i]);\n		}\n	}\n}\n\nfunction tsDraw(p_id, p_table)\n{\n	if	(p_table != null)\n		tsSetTable (p_table);\n\n	if	((TSort_Store == null)||(TSort_Store.initialized == 0))\n		return;\n\n	var i = 0;\n	var sort_keys = TSort_Store.sort_keys;\n	var id;\n	var new_order = '';\n	if	(p_id != null)\n	{\n		if	(typeof p_id == 'number')\n			id = p_id;\n		else	if	((typeof p_id == 'string')&&(p_id.match(/^\\\d+[ADU]\$/i)))\n		{\n			id = p_id.replace(/^(\\\d+)[ADU]\$/i, \"\$1\");\n			new_order = p_id.replace(/^\\\d+([ADU])\$/i, \"\$1\").toUpperCase();\n		}\n	}\n	if	(id == null)\n	{\n		id = this.tsort_col_id;\n		if	((p_table == null)&&(this.tsort_table_id != null))\n			tsSetTable (this.tsort_table_id);\n	}\n	var table_id = TSort_Data[0];\n\n	var order = TSort_Store.sort_state[id];\n	if	(new_order == 'U')\n	{\n		if	(order != null)\n		{\n			TSort_Store.sort_state[id] = null;\n			obj = document.getElementById ('TS_' + id + '_' + table_id);\n			if	(obj != null)	obj.innerHTML = '';\n		}\n	}\n	else if	(new_order != '')\n	{\n		TSort_Store.sort_state[id] = (new_order == 'A')? true: false;\n		//	Add column number to the sort keys array\n		sort_keys.unshift(id);\n		i = 1;\n	}\n	else\n	{\n		if	((order == null)||(order == true))\n		{\n			TSort_Store.sort_state[id] = (order == null)? true: false;\n			//	Add column number to the sort keys array\n			sort_keys.unshift(id);\n			i = 1;\n		}\n		else\n		{\n			TSort_Store.sort_state[id] = null;\n			obj = document.getElementById ('TS_' + id + '_' + table_id);\n			if	(obj != null)	obj.innerHTML = '';\n		}\n	}\n\n	var len = sort_keys.length;\n	//	This will either remove the column completely from the sort_keys\n	//	array (i = 0) or remove duplicate column number if present (i = 1).\n	while (i < len)\n	{\n		if	(sort_keys[i] == id)\n		{\n			sort_keys.splice(i, 1);\n			len--;\n			break;\n		}\n		i++;\n	}\n	if	(len > 3)\n	{\n		i = sort_keys.pop();\n		obj = document.getElementById ('TS_' + i + '_' + table_id);\n		if	(obj != null)	obj.innerHTML = '';\n		TSort_Store.sort_state[i] = null;\n	}\n\n	// Sort the rows\n	TSort_Store.row_clones.sort(tsSort);\n\n	// Save the currently selected order\n	var new_tbody = document.createElement('tbody');\n	var row_clones = TSort_Store.row_clones;\n	len = row_clones.length;\n	var classes = TSort_Store.classes;\n	if	(classes == null)\n	{\n		for (i = 0; i < len; i++)\n			new_tbody.appendChild (row_clones[i].cloneNode(true));\n	}\n	else\n	{\n		var clone;\n		var j = 0;\n		var cl_len = classes.length;\n		for (i = 0; i < len; i++)\n		{\n			clone = row_clones[i].cloneNode(true);\n			clone.className = classes[j++];\n			if	(j >= cl_len)  j = 0;\n			new_tbody.appendChild (clone);\n		}\n	}\n\n	// Replace table body\n	var table = document.getElementById(table_id);\n	var tbody = table.getElementsByTagName('tbody')[0];\n	table.removeChild(tbody);\n	table.appendChild(new_tbody);\n\n	var obj, color, icon, state;\n	len = sort_keys.length;\n	var sorting = new Array ();\n	for (i = 0; i < len; i++)\n	{\n		id = sort_keys[i];\n		obj = document.getElementById ('TS_' + id + '_' + table_id);\n		if	(obj == null)  continue;\n		state = (TSort_Store.sort_state[id])? 0: 1;\n		icon = TSort_Store.icons[state];\n		obj.innerHTML = (icon.match(/</))? icon:\n			'<font color=\"' + TSort_Store.sort_colors[i] + '\">' + icon + '</font>';\n		sorting.push(id + ((state)? 'D': 'A'));\n	}\n\n	if	(TSort_Store.cookie)\n	{\n		//	Store the contents of \"sorting\" array into a cookie for 30 days\n		var date = new Date();\n		date.setTime (date.getTime () + 2592000);\n		document.cookie = TSort_Store.cookie + \"=\" +\n			encodeURIComponent (sorting.join(',')) + \"; expires=\" +\n			date.toGMTString () + \"; path=/\";\n	}\n}\n\nfunction tsSort(a, b)\n{\n	var data_a = TSort_Store.rows[a.tsort_row_id];\n	var data_b = TSort_Store.rows[b.tsort_row_id];\n	var sort_keys = TSort_Store.sort_keys;\n	var len = sort_keys.length;\n	var id;\n	var type;\n	var order;\n	var result;\n	for (var i = 0; i < len; i++)\n	{\n		id = sort_keys[i];\n		type = TSort_Store.sorting[id];\n\n		var v_a = data_a[id];\n		var v_b = data_b[id];\n		if	(v_a == v_b)  continue;\n		if	((type == 'i')||(type == 'f')||(type == 'd'))\n			result = v_a - v_b;\n		else\n			result = (v_a < v_b)? -1: 1;\n		order = TSort_Store.sort_state[id];\n		return (order)? result: 0 - result;\n	}\n\n	return (a.tsort_row_id < b.tsort_row_id)? -1: 1;\n}\n\nfunction tsRegister()\n{\n	if	(TSort_All == null)\n		TSort_All = new Object();\n\n	var ts_obj = new TSort_StoreDef();\n	ts_obj.sort_data = TSort_Data;\n	TSort_Data = null;\n	if	(typeof TSort_Classes != 'undefined')\n	{\n		ts_obj.classes = TSort_Classes;\n		TSort_Classes = null;\n	}\n	if	(typeof TSort_Initial != 'undefined')\n	{\n		ts_obj.initial = TSort_Initial;\n		TSort_Initial = null;\n	}\n	if	(typeof TSort_Cookie != 'undefined')\n	{\n		ts_obj.cookie = TSort_Cookie;\n		TSort_Cookie = null;\n	}\n	if	(typeof TSort_Icons != 'undefined')\n	{\n		ts_obj.icons = TSort_Icons;\n		TSort_Icons = null;\n	}\n	if	(ts_obj.icons == null)\n		ts_obj.icons = new Array (\"\\u2193\", \"\\u2191\");\n\n	if	(ts_obj.sort_data != null)\n		TSort_All[ts_obj.sort_data[0]] = ts_obj;\n}\n\nfunction	tsSetTable (p_id)\n{\n	TSort_Store = TSort_All[p_id];\n	if	(TSort_Store == null)\n	{\n		alert (\"Cannot set table '\" + p_id + \"' - table is not registered\");\n		return;\n	}\n	TSort_Data = TSort_Store.sort_data;\n}\n\nif	(window.addEventListener)\n	window.addEventListener(\"load\", tsInitOnload, false);\nelse if (window.attachEvent)\n	window.attachEvent (\"onload\", tsInitOnload);\nelse\n{\n	if  ((window.onload_sort_table == null)&&(window.onload != null))\n		window.onload_sort_table = window.onload;\n	// Assign new onload function\n	window.onload = tsInitOnload;\n}\n// End of code by Gennadiy Shvets\n// -->\n</script>";

	our $buffer_index_regular = '';
	our $count_regular = 0;
	if( -d "$folder_to_index/files" ) { find( \&RVT_index_regular_file, "$folder_to_index/files" ) }
	if( $count_regular ) {
		print RVT_INDEX "<script type=\"text/javascript\">
<!--
var TSort_Data = new Array ('table_regular', 'h', 's', 's', 'i', 'd', 'd', 's');
var TSort_Classes = new Array ('row1', 'row2');
var TSort_Initial = 0;
tsRegister();
// -->
</script>";
	}

	our $buffer_index_outlook = '';
	our $count_outlook = 0;
	if( -d "$folder_to_index/outlook" ) { find( \&RVT_index_outlook_item, "$folder_to_index/outlook" ) }
	elsif( ! -d "$folder_to_index/files" ) {
		# This is not a normal export folder (no files/, no outlook/ ?). Index all outlook items in here.
		find( \&RVT_index_outlook_item, "$folder_to_index" )
	}
	if( $count_outlook ) {
		print RVT_INDEX "<script type=\"text/javascript\">
<!--
var TSort_Data = new Array ('table_outlook', 'h', 's', 'd', 's', 's', 's', 's', 's', 's');
var TSort_Classes = new Array ('row1', 'row2');
var TSort_Initial = 2;
tsRegister();
// -->
</script>";
	}
	(my $ref = $folder_to_index) =~ s/^.*\/([0-9]{6}-[0-9]{2}-[0-9])\/.*\/([^\/]*)$/\1 \2/;
	print RVT_INDEX "<TITLE>Index: $ref</TITLE>\n</HEAD>\n<BODY><h3>Index: $ref</h3>\n";  # Index of $folder_to_index";
	
	if( $count_regular ) {
		print RVT_INDEX "<h3>Regular files: $count_regular items</h3>
<TABLE id=\"table_regular\" border=1 rules=all frame=box>
<THEAD>
<tr><th>File name</th><th>ext</th><th>Path</th><th>Size</th><th>Last modified</th><th>Last accessed</th><th>Remarks</th><th>Remarks</th></tr>
</THEAD>
$buffer_index_regular
</TABLE>
";
	}
	
	if( $count_outlook ) {
		print RVT_INDEX "<h3>Outlook / e-mail: $count_outlook items</h3>
<TABLE id=\"table_outlook\">
<THEAD>
<tr><th>&nbsp;Item&nbsp;</th><th>&nbsp;From&nbsp;</th><th>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Date&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</th><th>&nbsp;Subject&nbsp;</th><th>&nbsp;To&nbsp;</th><th>&nbsp;Cc&nbsp;</th><th>&nbsp;BCc&nbsp;</th><th>&nbsp;Remarks&nbsp;</th><th>&nbsp;Attachments&nbsp;</th></tr>
</THEAD>
$buffer_index_outlook
</TABLE>
";
	}

	print RVT_INDEX "</BODY>\n</HTML>\n";
	print "Done.\n";
	return 1;
}




##########################################################################
# Subs for parsing each file type
##########################################################################



sub RVT_parse_arj {
	my $ARJ = "arj";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);

	printf ("  Parsing ARJ files...\n");
    foreach my $f ( our @filelist_arj) {
    	print "    $f\n";
        my $fpath = RVT_create_folder($opath, 'arj');
		my $output = `$ARJ x -y "$f" "$fpath" 2>&1 `;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or warn ("WARNING: cannot create metadata files: $!.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        print META $output;
        close (META);
		if( $output =~ /File is password encrypted/ ) {
			( my $reportpath = $opath ) =~ s/\/control$/\/searches/;
			if( ! -d $reportpath ) { mkdir $reportpath };
			open( REPORT, ">>:encoding(UTF-8)", "$reportpath/rvt_encrypted" );
			print REPORT "$f\n";
			close( REPORT );
		}
    }
    return 1;
}



sub RVT_parse_bkf {
	my $MTFTAR = "mtftar";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);

	printf ("  Parsing BKF files...\n");
    foreach my $f ( our @filelist_bkf) {
    	print "    $f\n";
        my $fpath = RVT_create_folder($opath, 'bkf');
		my $output = `$MTFTAR < "$f" | tar x -C "$fpath" 2>&1 `;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or warn ("WARNING: cannot create metadata files: $!.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        print META $output;
        close (META);
    }
    return 1;
}



sub RVT_parse_bz {
	my $BUNZIP2 = "bunzip2";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing bzip / bzip2 files...\n");
    foreach my $f ( our @filelist_bz ) {
    	print "    $f\n";
        my $fpath = RVT_create_folder($opath, 'bz');
        my $basename = basename( $f );
        my $target = $basename;
        if( $basename =~ /\.bz2?$/ ) { $target =~ s/\.bz2?$// }
        elsif( $basename =~ /\.tbz2?$/ ) { $target =~ s/\.tbz2?$/.tar/ }
        #else {  }

        my $output = `cat "$f" | $BUNZIP2 > "$fpath/$target" `;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		print META $output;
        close (META);
    }
    return 1;
}



sub RVT_parse_dbx {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing DBX files...\n");
    foreach my $f ( our @filelist_dbx) {
    	next if $f =~ /Folders.dbx$/;
    	print "    $f\n";
    	my $dbxpath = RVT_create_folder($opath, 'dbx');
    	my $meta = "$dbxpath/RVT_metadata";
        open (META,">:encoding(UTF-8)", "$meta") or die ("ERR: failed to create metadata files."); # XX Lo del encoding habría que hacerlo en muchos otros sitios.
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);

        my $fpath = RVT_create_file($dbxpath, 'dbx', 'eml');
		(my $count = $fpath) =~ s/.*-([0-9]*).eml$/\1/;
		# Code taken from dbx2eml by Colin Moller - http://code.google.com/p/dbx2eml
		my $dbx = eval { Mail::Transport::Dbx->new("$f") };
	    if( $@ ) { warn "$@: $!\n"; next }

		if ( $dbx->emails ) {
			for my $eml ($dbx->emails) {
				$fpath = "$dbxpath/dbx-$count.eml"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
				open( EML, ">:encoding(UTF-8)", $fpath );
				print EML $eml->header."\n\n".$eml->body;
				close EML;
				$count++;
			}
		} else {
	        for my $sub ($dbx->subfolders) {
				if (my $d = $sub->dbx) {
					for my $eml ($d->emails) {
						$fpath = "$dbxpath/dbx-$count.eml"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
						open( EML, ">:encoding(UTF-8)", $fpath );
						print EML $eml->header."\n\n".$eml->body;
						close EML;
						$count++;
					}
				}
     	   }
		}

    } # end foreach my $f ( our @filelist_dbx )
    return 1;
}



sub RVT_parse_eml {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing EML files...\n");
	if( our @filelist_eml ) {
		my $emlpath = RVT_create_folder($opath, 'eml');
		my $fpath = RVT_create_file($emlpath, 'eml', 'html');
		( my $count = $fpath ) =~ s/.*-([0-9]*).html$/\1/;
		foreach my $f ( our @filelist_eml ) {
			print "    $f\n";
			$fpath = "$emlpath/eml-$count.html"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			( my $meta = $fpath ) =~ s/\.html$/.RVT_metadata/;
			
			open( RVT_ITEM, ">:encoding(UTF-8)", "$fpath") or warn "WARNING: cannot open file $fpath: $!\n";
			open( RVT_META, ">:encoding(UTF-8)", "$meta") or warn "WARNING: cannot open file $meta: $!\n";
			print RVT_META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";

			open( EML_ITEM, "<:encoding(UTF-8)", "$f" ) or warn "WARNING: cannot open file $f: $!\n";
			my $message = '';
			my $i_am_in_headers = 1;
			while( my $line = <EML_ITEM> ) { # Read eml. Write headers to RVT_META.
				$line =~ s/\r\n/\n/; # to handle DOS line endings.
				$message = $message.$line;
				if( $i_am_in_headers ) { 
					print RVT_META $line;
					if( $line =~ /^$/ ) { $i_am_in_headers = 0 }
				}
			}
			close( EML_ITEM );
			my $obj = Email::MIME->new($message);

			# Print object headers to RVT_META:
#			foreach my $k ( $obj->header_names ) { print RVT_META "$k: ".$obj->header($k)."\n" }

			my $from = $obj->header('From');
			my $to = $obj->header('To');
			my $cc = $obj->header('Cc');
			my $bcc = $obj->header('Bcc');
			my $subject = $obj->header('Subject');
			my $date = $obj->header('Date');
			my $flags = '';
			if( $obj->content_type =~ /^multipart\/mixed/ ) { $flags = 'Has attachments' }
#print "================================================================\nMENSAJE\n";
#print "From: $from\n";
#print "Subject: $subject\n";
#print "Debug:\n".$obj->debug_structure."\n";
			# Write RVT_ITEM:
			$from =~ s/</&lt;/g; $from =~ s/>/&gt;/g;
			$to =~ s/</&lt;/g; $to =~ s/>/&gt;/g;
			$cc =~ s/</&lt;/g; $cc =~ s/>/&gt;/g;
			$bcc =~ s/</&lt;/g; $bcc =~ s/>/&gt;/g;
			( my $source = $f ) =~ s/^.*\/([0-9]{6}-[0-9]{2}-[0-9]\/.*)/\1/;
			$source =~ s/\/output\/parser\/control//;
			my $index_line = "<!--_XX_RVT_DELIM_".$from."_XX_RVT_DELIM_".$date."_XX_RVT_DELIM_".$subject."_XX_RVT_DELIM_".$to."_XX_RVT_DELIM_".$cc."_XX_RVT_DELIM_".$bcc."_XX_RVT_DELIM_".$flags."_XX_RVT_DELIM_-->";
			$index_line =~ s/#//g;
			$index_line =~ s/_XX_RVT_DELIM_/#/g;
			print RVT_ITEM "<HTML>$index_line
<HEAD>
	<TITLE>
		$subject
	</TITLE>
	<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
</HEAD>
<BODY>
	<TABLE border=1 rules=all frame=box>
		<tr><td><b>Item</b></td><td>e-mail message&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"",basename( $meta) ,"\" target=\"_blank\">[Headers]</a></td></tr>
		<tr><td><b>Source</b></td><td>$source</td></tr>
";
			if( $date ne '' ) {print RVT_ITEM "		<tr><td><b>Sent</b></td><td>$date</td></tr>\n" }
			if( $from ne '' ) {print RVT_ITEM "		<tr><td><b>From</b></td><td>$from</td></tr>\n" }
			if( $subject ne '' ) {print RVT_ITEM "		<tr><td><b>Subject</b></td><td>$subject</td></tr>\n" }
			if( $to ne '' ) { print RVT_ITEM "		<tr><td><b>To</b></td><td>$to</td></tr>\n" }
			if( $cc ne '' ) { print RVT_ITEM "		<tr><td><b>CC</b></td><td>$cc</td></tr>\n" }
			if( $bcc ne '' ) { print RVT_ITEM "		<tr><td><b>BCC</b></td><td>$bcc</td></tr>\n" }			
			
			my $msgbody = 0; # we will set this when we reach the first TEXT part.
			my @parts = ( );
			if( $obj->content_type =~ /^multipart\/alternative/ ) {
				# This is to handle messages which consist only of a multipart/alt block.
				# Its content is the body in different formats.
				my @alternatives = $obj->parts;
				my $plain = 0;
				my $html = 0;
				my $rtf = 0;
				foreach my $alt ( @alternatives ) {
					if( ($alt->content_type =~ /^text\/plain/) && (! $plain) ) { $plain = $alt }
					elsif( ($alt->content_type =~ /^text\/html/) && (! $html) ) { $html = $alt }
					elsif( ($alt->content_type =~ /^application\/rtf/) && (! $rtf) ) { $rtf = $alt }
				}
				if( $html ) { push( @parts, $html ) }
				elsif( $plain ) { push( @parts, $plain ) }
				elsif( $rtf ) { push( @parts, $rtf ) }
				else { push( @parts, @alternatives ) } # fallback resource
			} else { @parts = $obj->parts } # These are all Email::MIME objects too.

			while( my $part = shift(@parts) ) {
#print "-- Part:\n";
				my $ctype = $part->content_type;
				my $filename = $part->filename;
#print "  Content-type: $ctype\n";				
				my $is_attach = 0;				
				if( $ctype =~ /^multipart\/alternative/ ) {
					# This code does its best at delivering the content in HTML, text, or RTF (in that order).
					# If it does not know what to do, it will pass all the objects back to the parts queue and
					# they will (most probably) be treated as unnamed attachments.
					my @alternatives = $part->parts;
					my $plain = 0;
					my $html = 0;
					my $rtf = 0;
					foreach my $alt ( @alternatives ) {
						if( ($alt->content_type =~ /^text\/plain/) && (! $plain) ) { $plain = $alt }
						elsif( ($alt->content_type =~ /^text\/html/) && (! $html) ) { $html = $alt }
						elsif( ($alt->content_type =~ /^application\/rtf/) && (! $rtf) ) { $rtf = $alt }
					}
					if( $html ) { push( @parts, $html ) }
					elsif( $plain ) { push( @parts, $plain ) }
					elsif( $rtf ) { push( @parts, $rtf ) }
					else { push( @parts, @alternatives ) } # fallback resource
				} elsif( $ctype =~ /^multipart/ ) { push( @parts, $part->parts ) }
				elsif( $filename ) { $is_attach = 1 }
				elsif( ($ctype =~ /^text\//) && (! $msgbody) ) {
					# This must be the message body
#print "  This seems to be the message body.\n";
					if( $ctype =~ /^text\/plain/ ) {
						$msgbody = $part->body;
						$msgbody =~ s/\n/<br>\n/g;
					}
					elsif( $ctype =~ /^text\/html/ ) { $msgbody = $part->body }
					else {
					# XX_Fixme: Parse RTF instead of pasting as-is. However, we should never get here
					# because a text/plain or text/html alternative should be found.
						$msgbody = $part->body;
					}
				} else {
					# We will treat it as an attachment.
					$filename = $part->invent_filename;
					# Adjustments for certain extensions:
					if( $ctype =~ /.*\/rtf$/ ) { $filename =~ s/\.dat/.rtf/ }
					elsif( $ctype =~ /^text\/html/ ) { $filename =~ s/\.dat/.html/ }
					$is_attach = 1;
				}
				
				# Attachments:
				if( $is_attach ) {
#print "  Attachment: $filename\n";
					( my $attachfolder = $fpath ) =~ s/\.html$/.attach/;
					mkpath( $attachfolder ); # no "or warn..." to avoid that warning if folder already exists.
					open( ATTACH, ">", "$attachfolder/$filename" ) or warn "WARNING: Cannot open file $attachfolder/$filename: $!";
					print ATTACH $part->body;
					close ATTACH;
					my $string = "$attachfolder/$filename";
					print RVT_META "Attachment: $string\n";
					$string =~ s/.*\/([^\/]*\/[^\/]*)$/\1/;
					$string =~ s/#/%23/g;
					print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">$filename</a></td></tr>\n";
				}
				
			} # end while( $part=shift(@parts) )
			print RVT_ITEM "</TABLE><br>\n";
			
			print RVT_ITEM $msgbody;
			print RVT_ITEM "	</BODY>\n</HTML>\n";
			close( RVT_ITEM );
			close( RVT_META );
			$count++;
		}
	}
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
    
	printf ("  Parsing EVT files...\n");
	if( our @filelist_evt ) {
		my $evtpath = RVT_create_folder($opath, 'evt');
		my $fpath = RVT_create_file($evtpath, 'evt', 'txt');
		( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_evt ) {
			print "    $f\n";
			$fpath = "$evtpath/evt-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
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
    return 1;
}



sub RVT_parse_gz {
	my $GUNZIP = "gunzip";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing GZ files...\n");
    foreach my $f ( our @filelist_gz ) {
    	print "    $f\n";
        my $fpath = RVT_create_folder($opath, 'gz');
        my $basename = basename( $f );
        my $target = $basename;
        if( $basename =~ /\.gz$/ ) { $target =~ s/\.gz$// }
        elsif( $basename =~ /\.tgz$/ ) { $target =~ s/\.tgz$/.tar/ }
        #else {  }

        my $output = `cat "$f" | $GUNZIP > "$fpath/$target" `;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		print META $output;
        close (META);
    }
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
    
	printf ("  Parsing LNK files...\n");
	if( our @filelist_lnk ) {
		my $lnkpath = RVT_create_folder($opath, 'lnk');
		my $fpath = RVT_create_file($lnkpath, 'lnk', 'txt');
		( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_lnk ) {
			print "    $f\n";
			$fpath = "$lnkpath/lnk-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			open (FLNK, "-|", "$LNKPARSE", $f);
			open (FOUT, ">:encoding(UTF-8)", "$fpath") or warn ("WARNING: failed to create output file: $!.");
			print FOUT "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
			while (<FLNK>) { print FOUT $_ }
			close (FLNK);
			close (FOUT);
			$count++;
		}
	}
    return 1;
}



sub RVT_parse_msg {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing MSG files...\n");
	if( our @filelist_msg ) {
		my $msgpath = RVT_create_folder($opath, 'msg');
		my $fpath = RVT_create_file($msgpath, 'msg', 'eml');
		( my $count = $fpath ) =~ s/.*-([0-9]*).eml$/\1/;
		foreach my $f ( our @filelist_msg ) {
			print "    $f\n";
			$fpath = "$msgpath/msg-$count.eml"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			( my $meta = $fpath ) =~ s/\.eml$/.RVT_metadata/;

			open (META, ">:encoding(UTF-8)", "$meta") or warn ("WARNING: failed to create output file $meta: $!.");
			print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
			close (META);
			
			# Temp redirection of STDERR to RVT_META, to capture output from Email::Outlook::Message.
			open( STDERR, ">>:encoding(UTF-8)", "$meta" ); 
			my $mail = eval { new Email::Outlook::Message( $f )->to_email_mime->as_string; }; # Taken from msgconvert.pl by Matijs van Zuijlen (http://www.matijs.net/software/msgconv/);
			warn $@ if $@;
			close( STDERR ); # End of STDERR redirection.

			if( $mail ) {
				open( RVT_ITEM, ">:encoding(UTF-8)", "$fpath" ) or warn ("WARNING: failed to create output file $fpath: $!.");
				print RVT_ITEM $mail;
				close( RVT_ITEM );
			} else { 
				( my $reportpath = $opath ) =~ s/\/control$/\/searches/;
				if( ! -d $reportpath ) { mkdir $reportpath };
				open( REPORT, ">>:encoding(UTF-8)", "$reportpath/rvt_malformed" );
				print REPORT "$f\n";
				close( REPORT );
			}

			$count++;
		}
	}
    return 1;
}



sub RVT_parse_pdf {
	my $PDFTOTEXT = "pdftotext";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing PDF files...\n");
	if( our @filelist_pdf ) {
		my $pdfpath = RVT_create_folder($opath, 'pdf');
		my $fpath = RVT_create_file($pdfpath, 'pdf', 'txt');
		( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_pdf ) {
			print "    $f\n";
			$fpath = "$pdfpath/pdf-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			my $output = `$PDFTOTEXT "$f" - 2>&1`;
			open (META, ">:encoding(UTF-8)", "$fpath") or warn ("WARNING: failed to create output files: $!.");
			print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
			print META $output;
			close (META);
			if( $output =~ /^Error: Incorrect password$/ ) {
				( my $reportpath = $opath ) =~ s/\/control$/\/searches/;
				if( ! -d $reportpath ) { mkdir $reportpath };
				open( REPORT, ">>:encoding(UTF-8)", "$reportpath/rvt_encrypted" );
				print REPORT "$f\n";
				close( REPORT );
			}
			$count++;
		}
	}
    return 1;
}



sub RVT_parse_pff {
	my $PFFEXPORT = "pffexport";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing PFF files (PST, OST, PAB)...\n");
    foreach my $f ( our @filelist_pff) {
    	print "    $f\n";
    	my $fpath = RVT_create_file($opath, 'pff', 'RVT_metadata');    	
        open (META,">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create metadata files."); # XX Lo del encoding habría que hacerlo en muchos otros sitios.
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        $fpath =~ s/.RVT_metadata//; 
        my @args = ("$PFFEXPORT", '-f', 'text', '-m', 'all', '-q', '-t', "$fpath", $f); # -f text and -m all are in fact default options.
        system(@args);        
        foreach my $mode ('export','orphan','recovered') { finddepth( \&RVT_sanitize_libpff_item, "$fpath.$mode" ) }
    }
    return 1;
}



sub RVT_parse_rar {
	my $UNRAR = "unrar";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing RAR files...\n");
    foreach my $f ( our @filelist_rar ) {
    	print "    $f\n";
        my $fpath = RVT_create_folder($opath, 'rar');
		my $output = `$UNRAR x -ppassword "$f" "$fpath" 2>&1`;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or warn ("WARNING: cannot create metadata files: $!.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		print META $output;
        close (META);
		if( $output =~ /or wrong password./ ) {
			( my $reportpath = $opath ) =~ s/\/control$/\/searches/;
			if( ! -d $reportpath ) { mkdir $reportpath };
			open( REPORT, ">>:encoding(UTF-8)", "$reportpath/rvt_encrypted" );
			print REPORT "$f\n";
			close( REPORT );
		}
    }
    return 1;
}



sub RVT_parse_tar {
	my $TAR = "tar";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);

	printf ("  Parsing TAR files...\n");
    foreach my $f ( our @filelist_tar) {
    	print "    $f\n";
        my $fpath = RVT_create_folder($opath, 'tar');
		my $output = `$TAR xf "$f" -C "$fpath" 2>&1 `;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or warn ("WARNING: cannot create metadata files: $!.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        print META $output;
        close (META);
    }
    return 1;
}



sub RVT_parse_text {
	my $FSTRINGS = "f-strings";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/text';
    mkpath $opath unless (-d $opath);

	printf ("  Parsing text files...\n");
	my $fpath = RVT_create_file($opath, 'text', 'txt');
	( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
	foreach my $f (our @filelist_text) {
		$fpath = "$opath/text-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
		my $normalized = `echo "$f" | $FSTRINGS`;
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
    return 1;
}



sub RVT_parse_zip {
	my $UNZIP = "unzip";
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("  Parsing ZIP files (and ODF, OOXML)...\n");
    foreach my $f ( our @filelist_zip ) {
    	print "    $f\n";
        my $fpath = RVT_create_folder($opath, 'zip');
		my $output = `$UNZIP -P password "$f" -d "$fpath" 2>&1`;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or die ("ERR: failed to create metadata files.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
		print META $output;
        close (META);
		if( $output =~ /incorrect password$/ ) {
			( my $reportpath = $opath ) =~ s/\/control$/\/searches/;
			if( ! -d $reportpath ) { mkdir $reportpath };
			open( REPORT, ">>:encoding(UTF-8)", "$reportpath/rvt_encrypted" );
			print REPORT "$f\n";
			close( REPORT );
		}
    }
    return 1;
}






##########################################################################
# Other stuff
##########################################################################



sub RVT_get_all_sources {
	# Traces an object origin, recursively, using RVT metadata.
	# Returns a list containing the filename of the original item, and its parent objects,
	# up to a final (/mnt) path.
	my $file = shift;
	chomp( $file );
	my $source = RVT_get_source( $file );
	if( $source ) { return( $file, RVT_get_all_sources( $source ) ) }
	else { return( $file, 0 ) }
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
		} elsif( $source =~ /.*\/output\/parser\/control\/eml-[0-9]+\/.*/ ) {
			# The results of the EML parser are also treated differently:
			$source =~ s/(\/eml-[0-9]+\/eml-[0-9]+).*/\1/;
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
	elsif( $file =~ /.*\/output\/parser\/control\/arj-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/bkf-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/bz-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/dbx-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/eml-[0-9]*/ ) { $source_type = 'special_eml'; }
	elsif( $file =~ /.*\/output\/parser\/control\/evt-[0-9]*\/evt-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/gz-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/lnk-[0-9]*\/lnk-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/msg-[0-9]*\/msg-[0-9]*\.eml/ ) { $source_type = 'special_msg'; }
	elsif( $file =~ /.*\/output\/parser\/control\/pdf-[0-9]*\/pdf-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/pff-[0-9]*/ ) { $source_type = 'special_pff'; }
	elsif( $file =~ /.*\/output\/parser\/control\/rar-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/tar-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/text\/text-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/zip-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	else { warn "WARNING: RVT_get_source called on unknown source type: $file\n" }
	
	if( $source_type eq 'infolder' ) {
		$file =~ s/(.*\/output\/parser\/control\/[a-z]*-[0-9]*)\/.*/\1\/RVT_metadata/;
		$source_type = 'infile';
	} elsif( $source_type eq 'special_pff' ) {
		if( $file =~ /[0-9]{5}\.attach\/[^\/]*$/ ) { # If an attachment, point its parent.
			$source = $file;
			$source =~ s/([0-9]{5})\.attach\/[^\/]*$/\1.html/;
			$got_source = 1;
		} else { # Point to RVT_META on top pst-XX folder, which indicates the source.
			$file =~ s/(.*\/output\/parser\/control\/pff-[0-9]*)\..*/\1.RVT_metadata/;
			$source_type = 'infile';
		}
	} elsif( $source_type eq 'special_eml' ) {
		if( $file =~ /eml-[0-9]+\.attach\/[^\/]*$/ ) { # If an attachment, point its parent.
			$source = $file;
			$source =~ s/(eml-[0-9]+)\.attach\/[^\/]*$/\1.html/;
			$got_source = 1;
		} else { # Point to the RVT_META for this particular EML, which indicates the source.
			$file =~ s/(.*\/output\/parser\/control\/eml-[0-9]+\/eml-[0-9]+)\..*/\1.RVT_metadata/;
			$source_type = 'infile';
		}
	} elsif( $source_type eq 'special_msg' ) {
		$file =~ s/\.eml$/.RVT_metadata/;
		$source_type = 'infile';
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
	} else { return 0 }
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
		$result = "$mother/$name DUPL_$count.$ext";
		while( -e $result ) {
			$count++;
			$result = "$mother/$name DUPL_$count.$ext";
		}
	} else { $result = "$mother/$file" }
	return $result;
}



sub RVT_index_outlook_item {
# WARNING!!! This function is to be called ONLY from within RVT_create_index.
# $folder_to_index, $buffer_index_outlook and $count_outlook are expected to be initialized.
	return if ( -d ); # We only want to act on FILES.
	return if ( $File::Find::dir =~ /.*\.attach.*/ ); # messages attached to other messages are not indexed. Their parent messages will be.
	# however i dunno if EMLs are totally being well parsed
	our $folder_to_index;
	our $count_outlook;
	our $buffer_index_outlook;
	if( ($File::Find::name =~ /.*\/[A-Z][a-z]+[0-9]{5}.html/) or ($File::Find::name =~ /.*\/eml-[0-9]+.html/) ) {
		open( ITEM, "<:encoding(UTF-8)", $File::Find::name );
		my $line = <ITEM>;
		close ITEM;
		chomp( $line );
		$line =~ s/^[^#]*#//; # Remove the part up to the first sharp: <HTML><!--#
		$line =~ s/#-->$//; # Remove the comment tag at the end of the line.
		$line =~ s/^([^#]*#.* [0-9]{2}:[0-9]{2}):[0-9]{2} [^#]*(#.*)$/\1\2/; # remove seconds and TZ from date field.
		$line =~ s/([^#]{60})[^#]{10}[^#]*#/\1<i><u>\(...\)<\/i><\/u>#/g; # shorten fields longer than 70 characters.
		$line =~ s/#/<\/td><td>/g; # Change sharps (#) for TD delimiters.
		my $item_type;
		if( $File::Find::name =~ /.*\/eml-[0-9]+.html/) { $item_type = 'Message' }
		else {
			$item_type = basename( $File::Find::name );
			$item_type =~ s/[0-9]{5}.*//;
		}
		( my $path = $File::Find::name ) =~ s/$folder_to_index\/?//; # make paths relative.
		(my $attachpath = $File::Find::name) =~ s/\.html$/.attach/;
		our $attachments = '';
		find( \&RVT_index_outlook_attachments, $attachpath );
		$buffer_index_outlook = $buffer_index_outlook."<tr><td><a href=\"file:$path\" target=\"_blank\">$item_type</a><td>$line</td><td>$attachments</td></tr>\n";
		$count_outlook++;
	}
	return 1;
}



sub RVT_index_outlook_attachments {
# WARNING!!! This function is to be called ONLY from within RVT_index_outlook_item
# $attachments is expected to be initialized.
	
	our $attachments;
	if( -f $File::Find::name ) { $attachments = $attachments."[".basename($File::Find::name)."] " }
	return 1;
}



sub RVT_index_regular_file {
# WARNING!!! This function is to be called ONLY from within RVT_create_index.
# $folder_to_index, $buffer_index_regular and $count_regular are expected to be initialized.
	return if ( -d ); # We only want to act on FILES.
	return if ( $File::Find::name =~ /.*\.RVT_metadata$/ );
	our $folder_to_index;
	our $count_regular;
	our $buffer_index_regular;

	( my $link = $File::Find::name ) =~ s/$folder_to_index\/?//; # make paths relative.
	( my $basename = basename($File::Find::name) ) =~ s/(.*)\.[^.]{1,16}$/\1/;
	( my $ext = uc(basename($File::Find::name)) ) =~ s/.*\.([^.]{1,16})$/.\1/;
	
	open( SOURCE, "<:encoding(UTF-8)", $File::Find::name.".RVT_metadata" );
	my $original = <SOURCE>;
	close SOURCE;
	( my $folder = $original ) =~ s/^.*\/([0-9]{6}-[0-9]{2}-[0-9]\/mnt\/p[0-9]{2}\/.*$)/\1/;
	my $size = stat($original)->size;
	my $atime = ctime( stat($original)->atime );
	my $mtime = ctime( stat($original)->mtime );

	$buffer_index_regular = $buffer_index_regular."<tr><td><a href=\"file:$link\" target=\"_blank\">$basename</a></td><td>$ext</td><td>$folder</td><td>$size</td><td>$mtime</td><td>$atime</td><td></td></tr>\n";
	$count_regular++;
	return 1;
}



sub RVT_sanitize_libpff_attachment {
# WARNING!!! This function is to be called ONLY from within RVT_sanitize_libpff_item.
# File descriptors RVT_META and RVT_ITEM are expected to be open when entering this sub,
# and $wanted_depth is expected to be correctly set.
	return if ( -d ); # We only want to act on FILES.
	my $item_depth = $File::Find::dir =~ tr[/][];
	our $wanted_depth;
	if( $item_depth == $wanted_depth ) {
		my $string = $File::Find::name;
		print RVT_META "Attachment: $File::Find::name\n";
		chomp( $string );
		$string =~ s/.*\/([^\/]*\/[^\/]*)$/\1/;
		$string =~ s/#/%23/g;
		print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">", basename($File::Find::name), "</a></td></tr>\n";
	} elsif( $item_depth eq $wanted_depth+1 && $File::Find::name =~ /.*Message00001.html/ )  {
		my $string = $File::Find::name;
		print RVT_META "Attachment: $File::Find::name\n";
		chomp( $string );
		$string =~ s/.*\/([^\/]*\/[^\/]*\/[^\/]*)$/\1/;
		$string =~ s/#/%23/g;
		print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">", basename($File::Find::name), "</a></td></tr>\n";
	}
	return 1;
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
	( my $source = $folder ) =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9]).output.parser.control/\1/;
	( my $item_type = basename($folder) ) =~ s/[0-9]{5}//;
	( my $file = basename($folder) ) =~ s/[0-9]{5}/.txt/;
	if( $item_type eq 'Message' ) { $file =~ s/Message/OutlookHeaders/ }
	return if( $item_type eq 'Attachment' ); # Folders like Attachment00001 must not be treated directly by us; instead they will be treated during the sub parse_attachment of their parent directory.
	return if( $item_type eq 'Folder' ); # Folders like Folder00001 are likely to be found in recovered structures, but they are not "by themselves" items to be analyzed. Note that the normal items (Message, Contact...) inside WILL be analyzed normally.
	if( exists $field_names{$item_type} ) { print "Item: $item_type ($source)\n" }
	else {
		warn "WARNING: Skipping unknown item type $item_type ($source)\n";
		return
	}
	
	open( LIBPFF_ITEM, "<:encoding(UTF-8)", "$folder/$file" ) or warn( "WARNING: Cannot open $folder/$file for reading - skipping item.\n" ) && return;
	open( RVT_ITEM, ">:encoding(UTF-8)", "$folder.html" ) or warn( "WARNING: Cannot open $folder.txt for writing - skipping item.\n" ) && return;
	open( RVT_META, ">:encoding(UTF-8)", "$folder.RVT_metadata" ) or warn( "WARNING: Cannot open $folder.RVT_metadata for writing - skipping item.\n" ) && return;	
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
	else {
		$field_values{'Flags'} =~ s/.*Read, (.*)\)/\1/; # Remove 'read' dflag
		$field_values{'Flags'} =~ s/.*\((.*)\)/\1/;
	}
	# Write RVT_ITEM:
	my $index_line = "<!--_XX_RVT_DELIM_".$field_values{'Sender name'}."_XX_RVT_DELIM_".$field_values{'Client submit time'}."_XX_RVT_DELIM_".$field_values{'Subject'}."_XX_RVT_DELIM_".$to."_XX_RVT_DELIM_".$cc."_XX_RVT_DELIM_".$bcc."_XX_RVT_DELIM_".$field_values{'Flags'}."_XX_RVT_DELIM_-->";
	$index_line =~ s/#//g;
	$index_line =~ s/_XX_RVT_DELIM_/#/g;
	print RVT_ITEM "<HTML>$index_line
<HEAD><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
	<style type=\"text/css\">
		table, tr, td { border: 1px solid grey; font-family:sans-serif; font-size:small; }
		table { border-collapse:collapse; }
		td { padding: 5 px; }
	</style>
	<TITLE>
		$field_values{'Subject'}
	</TITLE>
</HEAD>
<BODY>
	<TABLE border=1 rules=all frame=box>
		<tr><td><b>Item</b></td><td>Outlook item ($item_type)&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"",basename( $folder) ,".RVT_metadata\" target=\"_blank\">[Headers]</a></td></tr>
		<tr><td><b>Source</b></td><td>$source</td></tr>
";
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
	print RVT_META "\n## Rest of $file (if any) follows:\n\n";
	while( my $line = <LIBPFF_ITEM> ) { 
		print RVT_ITEM "$line<br>";
		print RVT_META $line;
	}

	# Message.txt: append to RVT_ITEM
	if( -f "$folder/Message.txt" ) {
		print RVT_META "\n\n## Message.txt follows:\n\n";
		open (MESSAGE,  "<:encoding(UTF-8)", "$folder/Message.txt") or warn ("WARNING: failed to open $folder/Message.txt\n");
		while( my $line = <MESSAGE> ) {
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





1;