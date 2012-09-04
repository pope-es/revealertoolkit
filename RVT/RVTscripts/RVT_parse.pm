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
# wanted behavior, you can use any of the existing modules (lnk, evt, pdf...) as a template.
#
# 2) In "RVT_build_filelists", DECLARE your file list in block "Declare (our) file lists"
# and POPULATE it in block "Populate the file lists with files with certain extensions".
#
# 3) In RVT_parse_everything, INITIALIZE the empty file list in block "Initialize file
# lists", and CALL your new plugin in block "Parse all known file types".
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
						&RVT_script_parse_sexport
   						&RVT_script_parse_index_keyword
   						&RVT_script_parse_index_disk
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
use File::Path qw(mkpath rmtree);
use File::Basename;
use File::Find;
use Data::Dumper;
use Date::Manip;
use Mail::Transport::Dbx; # needed by RVT_parse_dbx
use Email::MIME; # Needed by RVT_parse_eml
use Encode qw(encode_utf8); # Needed by RVT_parse_eml
use Mail::Mbox::MessageParser; # needed by RVT_parse_mbox
use Email::Outlook::Message; # Needed by RVT_parse_msg
use Time::localtime; # needed by RVT_index_regular_file
use File::stat; # needed by RVT_index_regular_file

sub constructor {

	my $evtparse = `evtparse.pl`;
	my $exiftool = `exiftool -ver`;
	my $fstrings = `f-strings -h`;
	my $lnkparse = `lnk-parse-1.0.pl`;
	my $mtftar = `mtftar 2>&1`;
	my $pdftotext = `pdftotext -v 2>&1`;
	my $pffexport = `pffexport -V`;
	my $sqlite = `sqlite3 -version`;
	my $tar = `tar --version`;
	my $tsk_recover = `tsk_recover -V`;
	my $z7 = `7z`; # would Perl support a variable called $7z ?
   
	if (!$evtparse) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find Harlan Carvey\'s evtparse.pl, please locate in tools directory and copy to /usr/local/bin or somewhere in your path)'); return }
	if (!$exiftool) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find exiftool)'); return }
	if (!$fstrings) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find f-strings, please locate in tools directory, compile (gcc f-strings.c -o f-strings) and copy to /usr/local/bin or somewhere in your path)'); return }
	if (!$lnkparse) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find Jacob Cunningham\'s lnk-parse-1.0.pl, please locate in tools directory and copy to /usr/local/bin or somewhere in your path)'); return }
	if (!$mtftar) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find mtftar)'); return }
	if (!$pdftotext) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find pdftotext)'); return }
	if (!$pffexport) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find pffexport)'); return }
	if (!$sqlite) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find sqlite)'); return }
	if (!$tar) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find tar)'); return }
	if (!$tsk_recover) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find tsk_recover)'); return }
	if (!$z7) { RVT_log ('ERR', 'RVT_parse not loaded (couldn\'t find 7z)'); return }

   $main::RVT_requirements{'evtparse'} = $evtparse;
   $main::RVT_requirements{'exiftool'} = $exiftool;
   $main::RVT_requirements{'fstrings'} = $fstrings;
   $main::RVT_requirements{'lnkparse'} = $lnkparse;
   $main::RVT_requirements{'mtftar'} = $mtftar;
   $main::RVT_requirements{'pdftotext'} = $pdftotext;
   $main::RVT_requirements{'pffexport'} = $pffexport;
   $main::RVT_requirements{'sqlite'} = $sqlite;
   $main::RVT_requirements{'tar'} = $tar;
   $main::RVT_requirements{'tsk_recover'} = $tsk_recover;
   $main::RVT_requirements{'7z'} = $z7;

   $main::RVT_functions{RVT_script_parse_autoparse } = "Parse a disk automagically\n
                                                    script parse autoparse <disk>";
   $main::RVT_functions{RVT_script_parse_search } = "Find parsed files containing keywords from a search file\n
                                                    script parse search <search file> <disk>";
   $main::RVT_functions{RVT_script_parse_export } = "Export search results to disk\n
                                                    script parse export <search file> <disk>";
   $main::RVT_functions{RVT_script_parse_sexport } = "Launches parse_SEarch and parse_EXPORT at once\n
                                                    script parse sexport <search file> <disk>";
   $main::RVT_functions{RVT_script_parse_index_keyword } = "Creates RVT_keyword_index.html for a folder containing the exportation of a
given keyword, such as (...)/111111-11-1/output/parser/export/my_keyword
Use with \"folder/*\" to act on its subfolders: script parse index keyword (...)/export/*\n
                                                    script parse index keyword <folder>";
   $main::RVT_functions{RVT_script_parse_index_disk } = "Creates RVT_disk_index.html for a folder containing exportation results of a
given disk, such as (...)/111111-11-1/output/parser/export
Can be used with \"folder/*\" to act on its subfolders, although RVT's default directory
hierarchy does not have a folder where this would be useful.\n
                                                    script parse index disk <folder>";
}


##########################################################################
# Subs that need to be modified for new plugins
##########################################################################



sub RVT_build_filelists () {

	# Declare (our) file lists:
	our @filelist_bkf;
	our @filelist_compressed;
	our @filelist_dbx;
	our @filelist_eml;
	our @filelist_evt;
	our @filelist_graphics;
	our @filelist_lnk;
	our @filelist_mbox;
	our @filelist_msg;
	our @filelist_pdf;
	our @filelist_pff;
	our @filelist_sqlite;
	our @filelist_text;
	our @filelist_undelete;

	# Populate the file lists with files with certain extensions.
	if( -f $File::Find::name ) {
# filelist_bkf:
		if( $File::Find::name =~ /\.bkf$/i ) { push( @filelist_bkf, $File::Find::name ) }		# MS Windows backup
# filelist_compressed - fs images are also pushed to @filelist_undelete
		elsif( $File::Find::name =~ /\.arj$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ARJ compressed file
		elsif( $File::Find::name =~ /\.bz$/i ) { push( @filelist_compressed, $File::Find::name ) }		# bzip file
		elsif( $File::Find::name =~ /\.bzip$/i ) { push( @filelist_compressed, $File::Find::name ) }	# bzip file
		elsif( $File::Find::name =~ /\.bzip2$/i ) { push( @filelist_compressed, $File::Find::name ) }	# bzip2 file
		elsif( $File::Find::name =~ /\.bz2$/i ) { push( @filelist_compressed, $File::Find::name ) }		# bzip2 file
		elsif( $File::Find::name =~ /\.cab$/i ) { push( @filelist_compressed, $File::Find::name ) }		# MS cabinet file
		elsif( $File::Find::name =~ /\.cgz$/i ) { push( @filelist_compressed, $File::Find::name ) }		# .cpio.gz
		elsif( $File::Find::name =~ /\.cpio$/i ) { push( @filelist_compressed, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.dd$/i ) {	# UNIX dd raw image
			push( @filelist_compressed, $File::Find::name );
			push( @filelist_undelete, $File::Find::name );
		}		
		elsif( $File::Find::name =~ /\.dmg$/i ) { push( @filelist_compressed, $File::Find::name ) }		# MacOS Disk iMaGe
		elsif( $File::Find::name =~ /\.docx$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (text)
		elsif( $File::Find::name =~ /\.docm$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (text, macro-enabled document)
		elsif( $File::Find::name =~ /\.dotm$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML template (text, macro-enabled)
		elsif( $File::Find::name =~ /\.dotx$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML template (text)
		elsif( $File::Find::name =~ /\.fat$/i ) {	# FAT filesystems extracted by 7z from other archives (such as .dd).
			push( @filelist_compressed, $File::Find::name );
			push( @filelist_undelete, $File::Find::name );
		}
		elsif( $File::Find::name =~ /\.gz$/i ) { push( @filelist_compressed, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.gzip$/i ) { push( @filelist_compressed, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.hfs$/i ) { # HFS filesystems contained within DMG images extracted with 7z.
			push( @filelist_compressed, $File::Find::name );
			push( @filelist_undelete, $File::Find::name );
		}
		elsif( $File::Find::name =~ /\.iso$/i ) {	# ISO 9660 filesystems
			push( @filelist_compressed, $File::Find::name );
			push( @filelist_undelete, $File::Find::name );
		}
		elsif( $File::Find::name =~ /\.jar$/i ) { push( @filelist_compressed, $File::Find::name ) }		# Java ARchive
		elsif( $File::Find::name =~ /\.keynote$/i ) { push( @filelist_compressed, $File::Find::name ) }	# Apple iWork presentation (Keynote document)
		elsif( $File::Find::name =~ /\.lha$/i ) { push( @filelist_compressed, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.lzh$/i ) { push( @filelist_compressed, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.ntfs$/i ) { # NTFS filesystems extracted by 7z from other archives (such as .dd).
			push( @filelist_compressed, $File::Find::name );
			push( @filelist_undelete, $File::Find::name );
		}
		elsif( $File::Find::name =~ /\.numbers$/i ) { push( @filelist_compressed, $File::Find::name ) }	# Apple iWork spreadsheet (Numbers document)
		elsif( $File::Find::name =~ /\.odb$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (database)
		elsif( $File::Find::name =~ /\.odc$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (chart)
		elsif( $File::Find::name =~ /\.odf$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (formula)
		elsif( $File::Find::name =~ /\.odg$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (graphics/drawing)
		elsif( $File::Find::name =~ /\.odi$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (image)
		elsif( $File::Find::name =~ /\.odm$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (master document)
		elsif( $File::Find::name =~ /\.odp$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (presentation)
		elsif( $File::Find::name =~ /\.ods$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (spreadsheet)
		elsif( $File::Find::name =~ /\.odt$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF (text)
		elsif( $File::Find::name =~ /\.otc$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF template (chart)
		elsif( $File::Find::name =~ /\.otf$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF template (formula)
		elsif( $File::Find::name =~ /\.otg$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF template (graphics/drawing)
		elsif( $File::Find::name =~ /\.oth$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF template (web page)
		elsif( $File::Find::name =~ /\.oti$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF template (image)
		elsif( $File::Find::name =~ /\.otp$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF template (presentation)
		elsif( $File::Find::name =~ /\.ots$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF template (spreadsheet)
		elsif( $File::Find::name =~ /\.ott$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ODF template (text)
		elsif( $File::Find::name =~ /\.pages$/i ) { push( @filelist_compressed, $File::Find::name ) }	# Apple iWork text (Pages document)
		elsif( $File::Find::name =~ /\.potx$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML template (presentation)
		elsif( $File::Find::name =~ /\.potm$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML template (presentation, macro-enabled)
		elsif( $File::Find::name =~ /\.ppam$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (PowerPoint 2007 macro-enabled add-in)
		elsif( $File::Find::name =~ /\.pptm$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (presentation, macro-enabled document)
		elsif( $File::Find::name =~ /\.pptx$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (presentation)
		elsif( $File::Find::name =~ /\.ppsx$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (presentation show)
		elsif( $File::Find::name =~ /\.ppsm$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (presentation show, macro-enabled document)
		elsif( $File::Find::name =~ /\.rar$/i ) { push( @filelist_compressed, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.rpm$/i ) { push( @filelist_compressed, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.stc$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML template (spreadsheet)
		elsif( $File::Find::name =~ /\.std$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML template (graphics/drawing)
		elsif( $File::Find::name =~ /\.sti$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML template (presentation)
		elsif( $File::Find::name =~ /\.stw$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML template (text)
		elsif( $File::Find::name =~ /\.sxc$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML (spreadsheet)
		elsif( $File::Find::name =~ /\.sxd$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML (graphics/drawing)
		elsif( $File::Find::name =~ /\.sxg$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML (master document)
		elsif( $File::Find::name =~ /\.sxi$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML (presentation)
		elsif( $File::Find::name =~ /\.sxm$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML (formula)
		elsif( $File::Find::name =~ /\.sxw$/i ) { push( @filelist_compressed, $File::Find::name ) }		# OpenOffice.org XML (text)
		elsif( $File::Find::name =~ /\.tar$/i ) { push( @filelist_compressed, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.tbz$/i ) { push( @filelist_compressed, $File::Find::name ) }		# .tar.bz
		elsif( $File::Find::name =~ /\.tbz2$/i ) { push( @filelist_compressed, $File::Find::name ) }	# .tar.bz2
		elsif( $File::Find::name =~ /\.tgz$/i ) { push( @filelist_compressed, $File::Find::name ) }		# .tar.gz
		elsif( $File::Find::name =~ /\.xlam$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (MS Excel 2007 macro-enabled add-in)
		elsif( $File::Find::name =~ /\.xlsx$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (spreadsheet)
		elsif( $File::Find::name =~ /\.xlsm$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML (spreadsheet, macro-enabled document)
		elsif( $File::Find::name =~ /\.xltm$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML template (spreadsheet, macro-enabled)
		elsif( $File::Find::name =~ /\.xltx$/i ) { push( @filelist_compressed, $File::Find::name ) }	# OOXML template (spreadsheet)
		elsif( $File::Find::name =~ /\.zip$/i ) { push( @filelist_compressed, $File::Find::name ) }		# ZIP files
		elsif( $File::Find::name =~ /\.xz$/i ) { push( @filelist_compressed, $File::Find::name ) }		# no idea but 7z handles it :)
		elsif( $File::Find::name =~ /\.7z$/i ) { push( @filelist_compressed, $File::Find::name ) }
# filelist_dbx:
		elsif( $File::Find::name =~ /\.dbx$/i ) { push( @filelist_dbx, $File::Find::name ) }
# filelist_eml:
		elsif( $File::Find::name =~ /\.eml$/i ) { push( @filelist_eml, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.emlx$/i ) { push( @filelist_eml, $File::Find::name ) }
# filelist_evt:
		elsif( $File::Find::name =~ /\.evt$/i ) { push( @filelist_evt, $File::Find::name ) }
# filelist_graphics:
		elsif( $File::Find::name =~ /\.gif$/i ) { push( @filelist_graphics, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.jpg$/i ) { push( @filelist_graphics, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.png$/i ) { push( @filelist_graphics, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.psd$/i ) { push( @filelist_graphics, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.tif$/i ) { push( @filelist_graphics, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.tiff$/i ) { push( @filelist_graphics, $File::Find::name ) }
# filelist_lnk:
		elsif( $File::Find::name =~ /\.lnk$/i ) { push( @filelist_lnk, $File::Find::name ) }
# filelist_mbox:
		elsif( $File::Find::name =~ /\.mbox$/i ) { push( @filelist_mbox, $File::Find::name ) } # warning, not the same!
		elsif( $File::Find::name =~ /\/mbox$/i ) { push( @filelist_mbox, $File::Find::name ) } # warning, not the same!
# filelist_msg:
		elsif( $File::Find::name =~ /\.msg$/i ) { push( @filelist_msg, $File::Find::name ) }
# filelist_pdf:
		elsif( $File::Find::name =~ /\.pdf$/i ) { push( @filelist_pdf, $File::Find::name ) }
# filelist_pff:
		elsif( $File::Find::name =~ /\.pab$/i ) { push( @filelist_pff, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.pst$/i ) { push( @filelist_pff, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.ost$/i ) { push( @filelist_pff, $File::Find::name ) }
# filelist_sqlite:
		elsif( $File::Find::name =~ /\.db$/i ) { push( @filelist_sqlite, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.sqlite$/i ) { push( @filelist_sqlite, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.sqlitedb$/i ) { push( @filelist_sqlite, $File::Find::name ) }
		elsif( $File::Find::name =~ /\.sqlite3$/i ) { push( @filelist_sqlite, $File::Find::name ) }
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
		elsif( $File::Find::name =~ /\.fodb$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (database)
		elsif( $File::Find::name =~ /\.fodc$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (chart)
		elsif( $File::Find::name =~ /\.fodf$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (formula)
		elsif( $File::Find::name =~ /\.fodg$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (graphics/drawing)
		elsif( $File::Find::name =~ /\.fodi$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (image)
		elsif( $File::Find::name =~ /\.fodm$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (master document)
		elsif( $File::Find::name =~ /\.fodp$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (presentation)
		elsif( $File::Find::name =~ /\.fods$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (spreadsheet)
		elsif( $File::Find::name =~ /\.fodt$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF flat (text)
		elsif( $File::Find::name =~ /\.fotc$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF template flat (chart)
		elsif( $File::Find::name =~ /\.fotf$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF template flat (formula)
		elsif( $File::Find::name =~ /\.fotg$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF template flat (graphics/drawing)
		elsif( $File::Find::name =~ /\.foth$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF template flat (web page)
		elsif( $File::Find::name =~ /\.foti$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF template flat (image)
		elsif( $File::Find::name =~ /\.fotp$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF template flat (presentation)
		elsif( $File::Find::name =~ /\.fots$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF template flat (spreadsheet)
		elsif( $File::Find::name =~ /\.fott$/i ) { push( @filelist_text, $File::Find::name ) }	# ODF template flat (text)
		elsif( $File::Find::name =~ /\.htm$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
		elsif( $File::Find::name =~ /\.html$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
		elsif( $File::Find::name =~ /\.ini$/i ) { push( @filelist_text, $File::Find::name ) }	# Typical text-based configuration file
		elsif( $File::Find::name =~ /\.json$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
		elsif( $File::Find::name =~ /\.jsp$/i ) { push( @filelist_text, $File::Find::name ) }	# Likely to be found in browser caches
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
		elsif( $File::Find::name =~ /\.xlsb$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Excel 2007 binary workbook
		elsif( $File::Find::name =~ /\.xml$/i ) { push( @filelist_text, $File::Find::name ) }	# XML
# These go through the text plugin as well, but we need a better way to treat them (browsing by chunks would be nice):
#		elsif( $File::Find::name =~ /\/hiberfil\.sys$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Windows virtual memory
#		elsif( $File::Find::name =~ /\/pagefile\.sys$/i ) { push( @filelist_text, $File::Find::name ) }	# MS Windows virtual memory
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
	if( not -f "$parsepath/__mnt_is_parsed.RVT_flag" ) { push( @sources, "$morguepath/mnt" ) }

	foreach my $item (@sources) {
		my $fancyname = RVT_shorten_fs_path( $item );
		print "Source: $fancyname\n";
		print "Parsing: ";

		# Initialize file lists:
		our @filelist_bkf = ( );
		our @filelist_compressed = ( );
		our @filelist_dbx = ( );
		our @filelist_eml = ( );
		our @filelist_evt = ( );
		our @filelist_graphics = ( );
		our @filelist_lnk = ( );
		our @filelist_mbox = ( );
		our @filelist_msg = ( );
		our @filelist_pdf = ( );
		our @filelist_pff = ( );
		our @filelist_sqlite = ( );
		our @filelist_text = ( );
		our @filelist_undelete = ( );

		# Populate them:
		find( \&RVT_build_filelists, $item );
		if( $item =~ /.*\/mnt$/ ) { # Special case (we push the image file itself):
			if( my $image = RVT_get_imagepath( $disk ) ) { push( @filelist_undelete, $image ) }
		}

		# Parse all known file types:
		RVT_parse_bkf( $disk );
		RVT_parse_compressed( $disk );
		RVT_parse_dbx( $disk );
		RVT_parse_eml( $disk );
		RVT_parse_evt( $disk );
		RVT_parse_graphics( $disk );
		RVT_parse_lnk( $disk );
		RVT_parse_mbox( $disk );
		RVT_parse_msg( $disk );
		RVT_parse_pdf( $disk );
		RVT_parse_pff( $disk );
		RVT_parse_sqlite( $disk );
		RVT_parse_text( $disk );
		RVT_parse_undelete( $disk );
		
		# Flag source as parsed.
		if( $item =~ /.*\/mnt$/ ) { $file = "$parsepath/__mnt_is_parsed.RVT_flag" }
		else { $file = "$item/__item_is_parsed.RVT_flag" }
		open( FLAG, ">:encoding(UTF-8)", $file );
		close( FLAG );

		print "Done\n\n";
	}	
	return 1;
}




##########################################################################
# Exported subs (RVT script commands)
##########################################################################



sub RVT_script_parse_autoparse {
	# Works at DISK LEVEL. Supports @disks.

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
		my $diskpath = RVT_get_morguepath($disk);
		RVT_script_parse_index_keyword("$diskpath/output/parser/control");
		RVT_script_parse_export( ":reports", $disk );
		$disk = shift( @_ );
	}
	return 1;
}



sub RVT_script_parse_search  {
    # launches a search over PARSEd files writing results (atomic hits) to a file.
    # Arguments:
    # - File with searches: one per line (this file can be created with "script search file...")
    # - One or more disks from the morgue (supports @disks)

    my $searchesfilename = shift( @_ );
    my $disk = shift( @_ );
	$disk = $main::RVT_level->{tag} unless $disk;
    while( $disk ) {
		my $string;
		print "\t Launching searches for $disk\n";
		my $case = RVT_get_casenumber($disk);
		my $diskpath = RVT_get_morguepath($disk);
		my $parsedfiles = "$diskpath/output/parser/control/text";
		my $searchespath = "$diskpath/output/parser/searches";
		return 0 if (! $diskpath);
		return 0 if (! -d $parsedfiles);
		if (! -e $searchespath) { mkdir $searchespath or return 0; }
	
		open (F, "<:encoding(UTF-8)", RVT_get_morguepath($case)."/searches_files/$searchesfilename") or return 0;
		my @searches = grep {!/^\s*#/} <F>;
		close (F);
		
		for $string ( @searches ) {
			chomp $string;
			$string = lc($string);
			if( grep( /:::intersect:::/, $string ) ) { # intersection search ("AND" operator)
				my @parms = split( ":::", $string );
				if( (scalar(@parms) < 4 ) or ($parms[1] != "intersect") ) {
					print "WARNING: Skipping malformed search. Keyword \"INTERSECT\" appears at wrong position: $string\n";
					open( FMATCH, "<", "/dev/null" );
					open( FOUT, ">", "/dev/null" );				
				} else {
					my $searchName = shift( @parms );
					shift( @parms ); # "intersect" - we checked that before.
					print "-- INTERSECT: $searchName ==> ".join( ":::", @parms )." ";
					if( -e "$searchespath/$searchName" ) { print "(WARNING: overwriting) "; }
					print "..... ";
					open (FOUT, ">:encoding(UTF-8)", "$searchespath/$searchName");
					my $regexp = shift( @parms );
					open (FMATCH, "-|", "grep", "-EHl", $regexp, $parsedfiles, "-R");
					my @fmatch = ();
					while( my $item = <FMATCH> ) {
						chomp( $item );
						push(@fmatch, $item );
					}
					close FMATCH; # at this point, @fmatch contains items that match the first search term.
					while( $regexp = shift(@parms) ) { # Perform necessary ANDs
						open (FMATCH, "-|", "grep", "-EHl", $regexp, @fmatch, "-R");
						@fmatch = ();
						while( my $item = <FMATCH> ) {
							chomp( $item );
							push(@fmatch, $item );
						}
						close FMATCH;
					}
					my $hits = 0;
					while (my $file = shift(@fmatch) ) {
						chomp( $file );
						my @sources = RVT_get_all_sources( $file, $disk );
						my $line = '';
						while( my $source = shift( @sources) ) {
							$line = "$line$source#";
						}
						print FOUT "$line\n";
						$hits++;
					}
					close FOUT;
					print "$hits atomic hits.\n";
				}
			} elsif( grep( /:::/, $string ) ) { # Regexp search
				(my $regexp = $string) =~ s/^.*::://;
				(my $searchName = $string) =~ s/:::.*$//;
				print "-- REGEXP: $searchName ==> $regexp ";
				if( -e "$searchespath/$searchName" ) { print "(WARNING: overwriting) "; }
				print "..... ";
				open (FMATCH, "-|", "grep", "-EHl", $regexp, $parsedfiles, "-R");
				open (FOUT, ">:encoding(UTF-8)", "$searchespath/$searchName");
				my $hits = 0;
				while (my $file = <FMATCH>) {
					chomp( $file );
					my @sources = RVT_get_all_sources( $file, $disk );
					my $line = '';
					while( my $source = shift( @sources) ) {
						$line = "$line$source#";
					}
					print FOUT "$line\n";
					$hits++;
				}
				close FMATCH;
				close FOUT;
				print "$hits atomic hits.\n";
			} else { # Regular search
				print "-- LITERAL: $string ";
				if( -e "$searchespath/$string" ) { print "(WARNING: overwriting) "; }
				print "..... ";
				open (FMATCH, "-|", "grep", "-Hl", $string, $parsedfiles, "-R");
				open (FOUT, ">:encoding(UTF-8)", "$searchespath/$string");
				my $hits = 0;
				while (my $file = <FMATCH>) {
					chomp( $file );
					my @sources = RVT_get_all_sources( $file, $disk );
					my $line = '';
					while( my $source = shift( @sources) ) {
						$line = "$line$source#";
					}
					print FOUT "$line\n";
					$hits++;
				}
				close FMATCH;
				close FOUT;
				print "$hits atomic hits.\n";
			}
		} # end for $string ( @searches )
		print "\n";
		$disk = shift( @_ );
	} # end while( $disk )
    return 1;
}



sub RVT_script_parse_export  {
    # Exports results (from script parse search) to disk.
    # Arguments:
    # - File with searches: one per line
    # - One or more disks from the morgue (supports @disks)

    my $searchesfilename = shift( @_ );
	my $disk = shift( @_ );
	$disk = $main::RVT_level->{tag} unless $disk;
    while( $disk ) {
		my $string;
		print "\t Exporting search results for $disk\n";
		my $case = RVT_get_casenumber($disk);
		my $diskpath = RVT_get_morguepath($disk);
		my $searchespath = "$diskpath/output/parser/searches";
		my $exportpath = "$diskpath/output/parser/export";
		return 0 if (! $diskpath);
		if (! -e $exportpath) { mkdir $exportpath or return 0; }
		
		my @searches = ();
		if( $searchesfilename =~ /^:encrypted$/ ) {
			push( @searches, "_RVT_encrypted" );
		} elsif( $searchesfilename =~ /^:malformed$/ ) {
			push( @searches, "_RVT_malformed" );
		} elsif( $searchesfilename =~ /^:graphics$/ ) {
			push( @searches, "_RVT_graphics" );
		} elsif( $searchesfilename =~ /^:reports$/ ) {
			push( @searches, "_RVT_encrypted", "_RVT_malformed", "_RVT_graphics" );
		} else {
			open (F, "<:encoding(UTF-8)", RVT_get_morguepath($case)."/searches_files/$searchesfilename") or return 0;
			@searches = grep {!/^\s*#/} <F>;
			close (F);
		}
		
		for $string ( @searches ) { # For each search string...
			chomp $string;
			$string = lc($string) unless ($string =~ /^_RVT_/);
			
			my $searchTerm;
			if( grep( /:::intersect:::/, $string ) ) {	# intersection search ("AND" operator)
				my @parms = split( ":::", $string );
				if( (scalar(@parms) < 4 ) or ($parms[1] != "intersect") ) {
					print "WARNING: Skipping malformed search. Keyword \"INTERSECT\" appears at wrong position: $string\n";
					open( FMATCH, "<", "/dev/null" );
					open( FOUT, ">", "/dev/null" );				
				} else {
					$string = shift( @parms );
					shift( @parms ); # "intersect" - we checked that before.
					print "-- INTERSECT: $string ==> ".join( ":::", @parms )." ";
					$searchTerm = "INTERSECT: " . join( ":::", @parms ). "\n";
				}
			} elsif( grep( /:::/, $string ) ) {	# Regexp search (or INTERSECT search, same for us at this point)
				(my $regexp = $string) =~ s/^.*::://;
				$string =~ s/:::.*$//;
				print "-- REGEXP: $string ==> $regexp ";
				$searchTerm = "REGEXP: $regexp\n";
			} else {						# Regular search
				print "-- LITERAL: $string ";
				$searchTerm = "LITERAL: $string\n";
			}

			open (FMATCH, "$searchespath/$string") || print "(ERROR: cannot open) ";
			my $opath = "$exportpath/$string";
			if ( -e $opath ) {
				print "(WARNING: overwriting) ";
				rmtree( $opath );
			}
			print "..... ";
			mkdir $opath;
			mkdir "$opath/files";
			mkdir "$opath/email";
			
			open( SEARCHTERM, ">>:encoding(UTF-8)", "$opath/__search_term.RVT_metadata" );
			print SEARCHTERM $searchTerm;
			close SEARCHTERM;
			
			open( FILEINDEX, ">>:encoding(UTF-8)", "$opath/files/__file_index.RVT_metadata" );
			my %copied;
			my $hits = 0;
			while (my $file = <FMATCH>) { # For each line of results...
				chomp ( $file );
				$file =~ s/#.*//; # we discard the rest of the sources and re-calculate them:
				my @results = RVT_get_best_source( $file, $disk );
				while( my $result = shift( @results ) ) {
					if( ! $copied{$result} ) { # this is to avoid things such as hits in multiple files inside a ZIP archive generating many copies of that ZIP.
						if( ($result =~ /.*\/output\/parser\/control\/pff-[0-9]*\..*/) or ($result =~ /.*\/output\/parser\/control\/eml-[0-9]+\/eml-[0-9].*/) ) { # libpff items are different...
							my $dest = $result;
							$dest =~ s/.*\/output\/parser\/control\/(pff-[0-9]*\..*)/\1/;
							$dest =~ s/.*\/output\/parser\/control\/(eml-[0-9]+\/.*)/\1/;
							if( -f $result ) {
								fcopy( $result, "$opath/email/$dest" );
							} elsif( -d $result ) {
								dircopy( $result, "$opath/email/$dest" );
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
				$hits++;
			} # end while (my $file = <FMATCH>) { # For each line of results...
			close( FILEINDEX );
			print "$hits atomic hits.\n";
			RVT_script_parse_index_keyword( $opath );
		} # end for each string...
		print "\n";
		sleep 1;
		RVT_script_parse_index_disk( RVT_get_morguepath($disk)."/output/parser/export" );
		$disk = shift( @_ );
	} # end while( $disk )
	return 1;
}



sub RVT_script_parse_sexport  {
	# SEarch + EXPORT
	# Takes any arguments that are valid for RVT_script_parse_search and RVT_script_parse_export
	
	# XX_RVT_FIXME: habría que cambiar las primeras líneas, las formas de coger argumentos etc, para q sean como en search y en export. Es importante 
	# esto: 
#    my $searchesfilename = shift( @_ );
#	my $disk = shift( @_ );
#	$disk = $main::RVT_level->{tag} unless $disk;
	# y luego hacer como en las otras: while disk tatata.... esto permitiría estando en "set level 100101", hacer "parse export bla @disks". (ahora hay q decir: parse export bla 100101@disks, aunque tengas el level seteado)
	
	my @args = @_;
	RVT_script_parse_search( @args );
	RVT_script_parse_export( @args );
}



sub RVT_script_parse_index_keyword ($) {
	# For a given folder, creates RVT_keyword_index.html.
	# For folders with EXPORTed search results, the index differentiates between regular files, and email items.
	# For other folders, it creates an index of e-mail items (both from PFF and from [mbox|msg|dbx]->eml).
	
	our $folder_to_index = join(" ", @_ ); # this parameter is accessed by RVT_index_email_item and probably some other stuff :)
	
	if( $folder_to_index =~ /^.*\/\*$/ ) { # if folder is 'whatever/*', index its subfolders:
		(my $mother = $folder_to_index) =~ s/\/\*$//;
		if( ! -d $mother ) {
			warn "ERROR: Not a directory: $mother ($!)\nOMMITING COMMAND: script parse index keyword $folder_to_index\n";
			return;
		}
		opendir my($dh), $mother or warn "WARNING: cannot open $mother: $!";
		my @dir_entries = readdir $dh;
		closedir $dh;
		
		foreach my $dir_entry ( @dir_entries ) {
			if ( (-d "$mother/$dir_entry") and not ($dir_entry =~ /^\.\.?$/) ) {
				print "$mother/$dir_entry\n";
				RVT_script_parse_index_keyword ( "$mother/$dir_entry" )
			}
		}		
	} else { ####################### Create index for normal folders
		if( ! -d $folder_to_index ) {
			warn "ERROR: Not a directory: $folder_to_index ($!)\nOMMITING COMMAND: script parse index keyword $folder_to_index\n";
			return;
		}
		my $index_type;
		if( ( -d "$folder_to_index/files" ) or ( -d "$folder_to_index/email" ) ) { $index_type = 'search_results' }
		else { $index_type = 'misc' }		
		my $index = "$folder_to_index/RVT_keyword_index.html";
		print "  Creating RVT_index ";	
		if( -f $index ) { print "(WARNING: overwriting) " }
		print "..... ";
		
		open( RVT_KEYWORD_INDEX, ">:encoding(UTF-8)", "$index" ) or warn "WARNING: cannot open $index for writing.\n$!\n";
		print RVT_KEYWORD_INDEX "<HTML>
<HEAD> <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
<style type=\"text/css\">
	tr.row1 td { background:white; }
	tr.row2 td { background:lightgrey; }
	table, tr, td { border: 1px solid grey; font-family:sans-serif; font-size:small; }
	table { border-collapse:collapse; }
	th, td { padding: 5 px; }
</style>
<script type=\"text/javascript\">
	<!--\n// Copyright 2007 - 2010 Gennadiy Shvets\n// The program is distributed under the terms of the GNU General\n// Public License 3.0\n//\n// See http://www.allmyscripts.com/Table_Sort/index.html for usage details.\n\n// Script version 1.8\n\nvar TSort_Store;\nvar TSort_All;\n\nfunction TSort_StoreDef () {\n	this.sorting = [];\n	this.nodes = [];\n	this.rows = [];\n	this.row_clones = [];\n	this.sort_state = [];\n	this.initialized = 0;\n//	this.last_sorted = -1;\n	this.history = [];\n	this.sort_keys = [];\n	this.sort_colors = [ '#FF0000', '#800080', '#0000FF' ];\n};\n\nfunction tsInitOnload ()\n{\n	//	If TSort_All is not initialized - do it now (simulate old behavior)\n	if	(TSort_All == null)\n		tsRegister();\n\n	for (var id in TSort_All)\n	{\n		tsSetTable (id);\n		tsInit();\n	}\n	if	(window.onload_sort_table)\n		window.onload_sort_table();\n}\n\nfunction tsInit()\n{\n\n	if	(TSort_Data.push == null)\n		return;\n	var table_id = TSort_Data[0];\n	var table = document.getElementById(table_id);\n	// Find thead\n	var thead = table.getElementsByTagName('thead')[0];\n	if	(thead == null)\n	{\n		alert ('Cannot find THEAD tag!');\n		return;\n	}\n	var tr = thead.getElementsByTagName('tr');\n	var cols, i, node, len;\n	if	(tr.length > 1)\n	{\n		var	cols0 = tr[0].getElementsByTagName('th');\n		if	(cols0.length == 0)\n			cols0 = tr[0].getElementsByTagName('td');\n		var cols1;\n		var	cols1 = tr[1].getElementsByTagName('th');\n		if	(cols1.length == 0)\n			cols1 = tr[1].getElementsByTagName('td');\n		cols = new Array ();\n		var j0, j1, n;\n		len = cols0.length;\n		for (j0 = 0, j1 = 0; j0 < len; j0++)\n		{\n			node = cols0[j0];\n			n = node.colSpan;\n			if	(n > 1)\n			{\n				while (n > 0)\n				{\n					cols.push (cols1[j1++]);\n					n--;\n				}\n			}\n			else\n			{\n				if	(node.rowSpan == 1)\n					j1++;\n				cols.push (node);\n			}\n		}\n	}\n	else\n	{\n		cols = tr[0].getElementsByTagName('th');\n		if	(cols.length == 0)\n			cols = tr[0].getElementsByTagName('td');\n	}\n	len = cols.length;\n	for (var i = 0; i < len; i++)\n	{\n		if	(i >= TSort_Data.length - 1)\n			break;\n		node = cols[i];\n		var sorting = TSort_Data[i + 1].toLowerCase();\n		if	(sorting == null)  sorting = '';\n		TSort_Store.sorting.push(sorting);\n\n		if	((sorting != null)&&(sorting != ''))\n		{\n//			node.tsort_col_id = i;\n//			node.tsort_table_id = table_id;\n//			node.onclick = tsDraw;\n			node.innerHTML = \"<a href='' onClick=\\\"tsDraw(\" + i + \",'\" +\n				table_id + \"'); return false\\\">\" + node.innerHTML +\n				'</a><b><span id=\"TS_' + i + '_' + table_id + '\"></span></b>';\n			node.style.cursor = \"pointer\";\n		}\n	}\n\n	// Get body data\n	var tbody = table.getElementsByTagName('tbody')[0];\n	if	(tbody == null)	return;\n	// Get TR rows\n	var rows = tbody.getElementsByTagName('tr');\n	var date = new Date ();\n	var len, text, a;\n	for (i = 0; i < rows.length; i++)\n	{\n		var row = rows[i];\n		var cols = row.getElementsByTagName('td');\n		var row_data = [];\n		for (j = 0; j < cols.length; j++)\n		{\n			// Get cell text\n			text = cols[j].innerHTML.replace(/^\\\s+/, '');\n			text = text.replace(/\\\s+\$/, '');\n			var sorting = TSort_Store.sorting[j];\n			if	(sorting == 'h')\n			{\n				text = text.replace(/<[^>]+>/g, '');\n				text = text.toLowerCase();\n			}\n			else if	(sorting == 's')\n				text = text.toLowerCase();\n			else if (sorting == 'i')\n			{\n				text = parseInt(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'n')\n			{\n				text = text.replace(/(\\\d)\\\,(?=\\\d\\\d\\\d)/g, \"\$1\");\n				text = parseInt(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'c')\n			{\n				text = text.replace(/^\\\$/, '');\n				text = text.replace(/(\\\d)\\\,(?=\\\d\\\d\\\d)/g, \"\$1\");\n				text = parseFloat(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'f')\n			{\n				text = parseFloat(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'g')\n			{\n				text = text.replace(/(\\\d)\\\,(?=\\\d\\\d\\\d)/g, \"\$1\");\n				text = parseFloat(text);\n				if	(isNaN(text))	text = 0;\n			}\n			else if (sorting == 'd')\n			{\n				if	(text.match(/^\\\d\\\d\\\d\\\d\\\-\\\d\\\d?\\\-\\\d\\\d?(?: \\\d\\\d?:\\\d\\\d?:\\\d\\\d?)?\$/))\n				{\n					a = text.split (/[\\\s\\\-:]/);\n					text = (a[3] == null)?\n						Date.UTC(a[0], a[1] - 1, a[2],    0,    0,    0, 0):\n						Date.UTC(a[0], a[1] - 1, a[2], a[3], a[4], a[5], 0);\n				}\n				else\n					text = Date.parse(text);\n			}\n			row_data.push(text);\n		}\n		TSort_Store.rows.push(row_data);\n		// Save a reference to the TR element\n		var new_row = row.cloneNode(true);\n		new_row.tsort_row_id = i;\n		TSort_Store.row_clones[i] = new_row;\n	}\n	TSort_Store.initialized = 1;\n\n	if	(TSort_Store.cookie)\n	{\n		var allc = document.cookie;\n		i = allc.indexOf (TSort_Store.cookie + '=');\n		if	(i != -1)\n		{\n			i += TSort_Store.cookie.length + 1;\n			len = allc.indexOf (\";\", i);\n			text = decodeURIComponent (allc.substring (i, (len == -1)?\n				allc.length: len));\n			TSort_Store.initial = (text == '')? null: text.split(/\\\s*,\\\s*/);\n		}\n	}\n\n	var	initial = TSort_Store.initial;\n	if	(initial != null)\n	{\n		var itype = typeof initial;\n		if	((itype == 'number')||(itype == 'string'))\n			tsDraw(initial);\n		else\n		{\n			for (i = initial.length - 1; i >= 0; i--)\n				tsDraw(initial[i]);\n		}\n	}\n}\n\nfunction tsDraw(p_id, p_table)\n{\n	if	(p_table != null)\n		tsSetTable (p_table);\n\n	if	((TSort_Store == null)||(TSort_Store.initialized == 0))\n		return;\n\n	var i = 0;\n	var sort_keys = TSort_Store.sort_keys;\n	var id;\n	var new_order = '';\n	if	(p_id != null)\n	{\n		if	(typeof p_id == 'number')\n			id = p_id;\n		else	if	((typeof p_id == 'string')&&(p_id.match(/^\\\d+[ADU]\$/i)))\n		{\n			id = p_id.replace(/^(\\\d+)[ADU]\$/i, \"\$1\");\n			new_order = p_id.replace(/^\\\d+([ADU])\$/i, \"\$1\").toUpperCase();\n		}\n	}\n	if	(id == null)\n	{\n		id = this.tsort_col_id;\n		if	((p_table == null)&&(this.tsort_table_id != null))\n			tsSetTable (this.tsort_table_id);\n	}\n	var table_id = TSort_Data[0];\n\n	var order = TSort_Store.sort_state[id];\n	if	(new_order == 'U')\n	{\n		if	(order != null)\n		{\n			TSort_Store.sort_state[id] = null;\n			obj = document.getElementById ('TS_' + id + '_' + table_id);\n			if	(obj != null)	obj.innerHTML = '';\n		}\n	}\n	else if	(new_order != '')\n	{\n		TSort_Store.sort_state[id] = (new_order == 'A')? true: false;\n		//	Add column number to the sort keys array\n		sort_keys.unshift(id);\n		i = 1;\n	}\n	else\n	{\n		if	((order == null)||(order == true))\n		{\n			TSort_Store.sort_state[id] = (order == null)? true: false;\n			//	Add column number to the sort keys array\n			sort_keys.unshift(id);\n			i = 1;\n		}\n		else\n		{\n			TSort_Store.sort_state[id] = null;\n			obj = document.getElementById ('TS_' + id + '_' + table_id);\n			if	(obj != null)	obj.innerHTML = '';\n		}\n	}\n\n	var len = sort_keys.length;\n	//	This will either remove the column completely from the sort_keys\n	//	array (i = 0) or remove duplicate column number if present (i = 1).\n	while (i < len)\n	{\n		if	(sort_keys[i] == id)\n		{\n			sort_keys.splice(i, 1);\n			len--;\n			break;\n		}\n		i++;\n	}\n	if	(len > 3)\n	{\n		i = sort_keys.pop();\n		obj = document.getElementById ('TS_' + i + '_' + table_id);\n		if	(obj != null)	obj.innerHTML = '';\n		TSort_Store.sort_state[i] = null;\n	}\n\n	// Sort the rows\n	TSort_Store.row_clones.sort(tsSort);\n\n	// Save the currently selected order\n	var new_tbody = document.createElement('tbody');\n	var row_clones = TSort_Store.row_clones;\n	len = row_clones.length;\n	var classes = TSort_Store.classes;\n	if	(classes == null)\n	{\n		for (i = 0; i < len; i++)\n			new_tbody.appendChild (row_clones[i].cloneNode(true));\n	}\n	else\n	{\n		var clone;\n		var j = 0;\n		var cl_len = classes.length;\n		for (i = 0; i < len; i++)\n		{\n			clone = row_clones[i].cloneNode(true);\n			clone.className = classes[j++];\n			if	(j >= cl_len)  j = 0;\n			new_tbody.appendChild (clone);\n		}\n	}\n\n	// Replace table body\n	var table = document.getElementById(table_id);\n	var tbody = table.getElementsByTagName('tbody')[0];\n	table.removeChild(tbody);\n	table.appendChild(new_tbody);\n\n	var obj, color, icon, state;\n	len = sort_keys.length;\n	var sorting = new Array ();\n	for (i = 0; i < len; i++)\n	{\n		id = sort_keys[i];\n		obj = document.getElementById ('TS_' + id + '_' + table_id);\n		if	(obj == null)  continue;\n		state = (TSort_Store.sort_state[id])? 0: 1;\n		icon = TSort_Store.icons[state];\n		obj.innerHTML = (icon.match(/</))? icon:\n			'<font color=\"' + TSort_Store.sort_colors[i] + '\">' + icon + '</font>';\n		sorting.push(id + ((state)? 'D': 'A'));\n	}\n\n	if	(TSort_Store.cookie)\n	{\n		//	Store the contents of \"sorting\" array into a cookie for 30 days\n		var date = new Date();\n		date.setTime (date.getTime () + 2592000);\n		document.cookie = TSort_Store.cookie + \"=\" +\n			encodeURIComponent (sorting.join(',')) + \"; expires=\" +\n			date.toGMTString () + \"; path=/\";\n	}\n}\n\nfunction tsSort(a, b)\n{\n	var data_a = TSort_Store.rows[a.tsort_row_id];\n	var data_b = TSort_Store.rows[b.tsort_row_id];\n	var sort_keys = TSort_Store.sort_keys;\n	var len = sort_keys.length;\n	var id;\n	var type;\n	var order;\n	var result;\n	for (var i = 0; i < len; i++)\n	{\n		id = sort_keys[i];\n		type = TSort_Store.sorting[id];\n\n		var v_a = data_a[id];\n		var v_b = data_b[id];\n		if	(v_a == v_b)  continue;\n		if	((type == 'i')||(type == 'f')||(type == 'd'))\n			result = v_a - v_b;\n		else\n			result = (v_a < v_b)? -1: 1;\n		order = TSort_Store.sort_state[id];\n		return (order)? result: 0 - result;\n	}\n\n	return (a.tsort_row_id < b.tsort_row_id)? -1: 1;\n}\n\nfunction tsRegister()\n{\n	if	(TSort_All == null)\n		TSort_All = new Object();\n\n	var ts_obj = new TSort_StoreDef();\n	ts_obj.sort_data = TSort_Data;\n	TSort_Data = null;\n	if	(typeof TSort_Classes != 'undefined')\n	{\n		ts_obj.classes = TSort_Classes;\n		TSort_Classes = null;\n	}\n	if	(typeof TSort_Initial != 'undefined')\n	{\n		ts_obj.initial = TSort_Initial;\n		TSort_Initial = null;\n	}\n	if	(typeof TSort_Cookie != 'undefined')\n	{\n		ts_obj.cookie = TSort_Cookie;\n		TSort_Cookie = null;\n	}\n	if	(typeof TSort_Icons != 'undefined')\n	{\n		ts_obj.icons = TSort_Icons;\n		TSort_Icons = null;\n	}\n	if	(ts_obj.icons == null)\n		ts_obj.icons = new Array (\"\\u2193\", \"\\u2191\");\n\n	if	(ts_obj.sort_data != null)\n		TSort_All[ts_obj.sort_data[0]] = ts_obj;\n}\n\nfunction	tsSetTable (p_id)\n{\n	TSort_Store = TSort_All[p_id];\n	if	(TSort_Store == null)\n	{\n		alert (\"Cannot set table '\" + p_id + \"' - table is not registered\");\n		return;\n	}\n	TSort_Data = TSort_Store.sort_data;\n}\n\nif	(window.addEventListener)\n	window.addEventListener(\"load\", tsInitOnload, false);\nelse if (window.attachEvent)\n	window.attachEvent (\"onload\", tsInitOnload);\nelse\n{\n	if  ((window.onload_sort_table == null)&&(window.onload != null))\n		window.onload_sort_table = window.onload;\n	// Assign new onload function\n	window.onload = tsInitOnload;\n}\n// End of code by Gennadiy Shvets\n// -->\n</script>";
	
		our $buffer_index_regular = '';
		our $count_regular = 0;
		if( -d "$folder_to_index/files" ) { find( \&RVT_index_regular_file, "$folder_to_index/files" ) }
		if( $count_regular ) {
			print RVT_KEYWORD_INDEX "<script type=\"text/javascript\">
	<!--
	var TSort_Data = new Array ('table_regular', 'h', 's', 's', 'i', 'd', 'd', 's');
	var TSort_Classes = new Array ('row1', 'row2');
	var TSort_Initial = 0;
	tsRegister();
	// -->
</script>";
		}
	
		our $buffer_index_email = '';
		our $count_email = 0;
		our $count_attach = 0;
		if( -d "$folder_to_index/email" ) { find( \&RVT_index_email_item, "$folder_to_index/email" ) }
		elsif( ! -d "$folder_to_index/files" ) {
			# This is not a normal export folder (no files/, no email/ ?). Index all email items in here.
			find( \&RVT_index_email_item, "$folder_to_index" )
		}
		if( $count_email ) {
			print RVT_KEYWORD_INDEX "<script type=\"text/javascript\">
	<!--
	var TSort_Data = new Array ('table_email', 'h', 'd', 's', 's', 's', 's', 's', 's', 'h');
	var TSort_Classes = new Array ('row1', 'row2');
	var TSort_Initial = 1;
	tsRegister();
	// -->
	</script>";
		}
		(my $ref = $folder_to_index) =~ s/^.*\/([0-9]{6}-[0-9]{2}-[0-9])\/.*\/([^\/]*)$/\1 \2/;
		print RVT_KEYWORD_INDEX "<TITLE>Index: $ref</TITLE>\n</HEAD>\n<BODY><h3>Index: $ref</h3>\n";  # Index of $folder_to_index";
		
		if( $count_regular ) {
			print RVT_KEYWORD_INDEX "<h3>Regular files: $count_regular items</h3>
	<TABLE id=\"table_regular\" border=1 rules=all frame=box>
	<THEAD>
	<tr><th>File name</th><th>ext</th><th>Path</th><th>Size</th><th>Last modified</th><th>Last accessed</th><th>Remarks</th></tr>
	</THEAD>
	$buffer_index_regular
	</TABLE>
	";
		}
		
		if( $count_email ) {
			print RVT_KEYWORD_INDEX "<h3>e-mail, calendar, contacts...: $count_email items</h3>
	<TABLE id=\"table_email\">
	<THEAD>
	<tr><th>&nbsp;Item&nbsp;</th><th>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Date&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</th><th>&nbsp;From&nbsp;</th><th>&nbsp;Subject&nbsp;</th><th>&nbsp;To&nbsp;</th><th>&nbsp;Cc&nbsp;</th><th>&nbsp;BCc&nbsp;</th><th>&nbsp;Remarks&nbsp;</th><th>&nbsp;Attachments&nbsp;</th></tr>
	</THEAD>
	$buffer_index_email
	</TABLE>
	";
		}
		
		open( SEARCHTERM, "<:encoding(UTF-8)", "$folder_to_index/__search_term.RVT_metadata" );
		my $searchTerm = <SEARCHTERM>;
		close SEARCHTERM;
		chomp $searchTerm;
		$searchTerm =~ s/#//;
		
		print RVT_KEYWORD_INDEX "</BODY>\n<!--#". basename( $folder_to_index) ."#$searchTerm#$count_regular#$count_email#$count_attach#-->\n</HTML>\n";
		my $total = $count_regular + $count_email;
		print "done. $total entries";
		if ( $total ) {
			print ": ";
			if ( $count_regular ) { print "$count_regular regular files" }
			if ( $count_regular && $count_email ) { print " + " }
			if ( $count_email ) { print "$count_email e-mail items (with $count_attach attachments)" }
		}
		print ".\n";
		return 1;
	}
}



sub RVT_script_parse_index_disk ($) {
	# Creates an index for all searches in a given folder, usually (...)/output/parser/export.
	# We should expand this to accept as a parameter a disk (100xxx-xx-x) and act on its output/parser/export.
	
	our $folder_to_index = join(" ", @_ );

	if( $folder_to_index =~ /^.*\/\*$/ ) { # if folder is 'whatever/*', index its subfolders:
		(my $mother = $folder_to_index) =~ s/\/\*$//;
		if( ! -d $mother ) {
			warn "ERROR: Not a directory: $mother ($!)\nOMMITING COMMAND: script parse index $folder_to_index\n";
			return;
		}
		opendir my($dh), $mother or warn "WARNING: cannot open $mother: $!";
		my @dir_entries = readdir $dh;
		closedir $dh;
		
		foreach my $dir_entry ( @dir_entries ) {
			if ( (-d "$mother/$dir_entry") and not ($dir_entry =~ /^\.\.?$/) ) {
				print "$mother/$dir_entry\n";
				RVT_script_parse_index_disk ( "$mother/$dir_entry" )
			}
		}		
	} else { ####################### Create index for normal folders	
		if( ! -d $folder_to_index ) {
			warn "ERROR: Not a directory: $folder_to_index ($!)\nOMMITING COMMAND: script parse indexdisk $folder_to_index\n";
			return;
		}
		print "  Creating RVT_disk_index.html ";
		if( -f "$folder_to_index/RVT_disk_index.html" ) { print "(WARNING: overwriting) " }
		print "..... ";
		opendir my($dh), $folder_to_index or warn "WARNING: cannot open $folder_to_index: $!";
		my @dir_entries = sort( readdir $dh );
		closedir $dh;
	
		(my $ref = $folder_to_index) =~ s/^.*\/([0-9]{6}-[0-9]{2}-[0-9])\/.*$/\1/;
		open ( RVT_DISK_INDEX, ">:encoding(UTF-8)", "$folder_to_index/RVT_disk_index.html" );
		print RVT_DISK_INDEX "<HTML>
	<HEAD> <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
	<style type=\"text/css\">
		table, tr, td { border: 1px solid grey; font-family:sans-serif; font-size:small; }
		table { border-collapse:collapse; }
		th, td { padding: 5 px; }
		tr:nth-child(2n+1) { background:lightgrey; }
	</style>
	<TITLE>Disk: $ref</TITLE>
	</HEAD>
	<BODY>
	<H3>Disk: $ref</H3>
	<TABLE border=1 rules=all frame=box>
	<THEAD>
	<tr><th>Search</th><th>Regular files</th><th colspan=\"2\">e-mail, calendar, contacts...</th></tr>
	</THEAD>
	";
	
		foreach my $dir_entry ( @dir_entries ) {
#print "dir_entry: $dir_entry\n";
			open( RVT_KEYWORD_INDEX, "<:encoding(UTF-8)", "$folder_to_index/$dir_entry/RVT_keyword_index.html" );
			my $line = "";
			my $possible;
			while( $possible = <RVT_KEYWORD_INDEX> ) { # Get the last line starting with a comment.
				if ( $possible =~ /^<!--/ ) { $line = $possible; }
			}
#print "last possible: $possible\nline: $line\n";
			close RVT_KEYWORD_INDEX;
			if ( $line ) { # Note that dir_entries without a /RVT_keyword_index.html will produce no output, thus we skip arbitrary items that may be in this directory, such as .DS_Store files (or the HTML file we are creating, itself).
				my @fields = split( "#", $line );
				print RVT_DISK_INDEX "	<tr><td><a title=\"".RVT_sanitize_html_string($fields[2])."\" href=\"".RVT_sanitize_http_link("$fields[1]/RVT_keyword_index.html")."\"target=\"blank\">".RVT_sanitize_html_string($fields[1])."</a></td><td align=\"right\">$fields[3]</td><td align=\"right\">$fields[4] items</td><td align=\"right\">";
				if ( $fields[4] ) {
					if ( $fields[5] ) { print RVT_DISK_INDEX "with $fields[5] attachments" }
					else { print RVT_DISK_INDEX "with no attachments" }
				}
				print RVT_DISK_INDEX "</td></tr>\n";
			}
		}
		
		print RVT_DISK_INDEX "</TABLE>\n</BODY>\n</HTML>\n";
		close RVT_DISK_INDEX;
		print "done.\n";
	}
	return 1;
}



##########################################################################
# Subs for parsing each file type
##########################################################################



sub RVT_parse_bkf {
	my $MTFTAR = "mtftar";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);

	printf ("BKF... ");
	
	if( our @filelist_bkf ) {
		print "\n";
		foreach my $f ( our @filelist_bkf ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			my $fpath = RVT_create_folder($opath, 'bkf');
			(my $escaped = $f) =~ s/`/\\`/g;
			my $output = `$MTFTAR < "$escaped" | tar x -C "$fpath" 2>&1 `;
			open (META, ">:encoding(UTF-8)", "$fpath/__RVT_metadata.txt") or warn ("WARNING: cannot create metadata files: $!.");
			print META "# RVT SRC: $f\n";
			print META $output;
			close (META);
		}
	}
    return 1;
}



sub RVT_parse_compressed {
	my $Z7 = "7z";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("Compressed... ");
	if( our @filelist_compressed ) {
		print "\n";
		foreach my $f ( our @filelist_compressed ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			my $fpath = RVT_create_folder($opath, 'compressed');
			(my $escaped = $f) =~ s/`/\\`/g;
			my $output = `$Z7 x -o"$fpath" -pPASSWORD -y "$escaped" 2>&1`;
			my $chmod = `/bin/chmod -R ug+rwX "$fpath"`;
			open (RVT_META, ">:encoding(UTF-8)", "$fpath/__RVT_metadata.txt") or die ("ERR: failed to create metadata files.");
			print RVT_META "# RVT SRC: $f\n";
			print RVT_META $output;
			if( ($output =~ /Wrong password/) or ($output =~ /EncryptionInfo/) or ($output =~ /Unsupported Method/) ) { RVT_report( "encrypted", $f, $disk ) }
			if( $output =~ /Error: Can not open file as archive/ ) { RVT_report( "malformed", $f, $disk ) }
			if( $f =~ /.*\.(docm|docx|dotm|dotx|keynote|numbers|odb|odc|odf|odg|odi|odm|odp|ods|odt|otc|otf|otg|oth|oti|otp|ots|ott|pages|potx|potm|ppam|pptm|pptx|ppsx|ppsm|stc|std|sti|stw|sxc|sxd|sxg|sxi|sxm|sxw|xlam|xlsx|xlsm|xltm|xltx)$/i ) { # ODF documents
				finddepth( \&RVT_sanitize_compressed_office, $fpath );
			}			
			close (RVT_META);
		}
	}
    return 1;
}



sub RVT_parse_dbx {
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("DBX... ");
	if( our @filelist_dbx ) {
		print "\n";
		foreach my $f ( our @filelist_dbx) {
			next if $f =~ /Folders.dbx$/; # XX_RVT_FIXME: Folders.dbx somehow seems to crash our code :-?
			print "  ".RVT_shorten_fs_path( $f )."\n";
			my $dbxpath = RVT_create_folder($opath, 'dbx');
			my $meta = "$dbxpath/RVT_metadata";
			open (META,">:encoding(UTF-8)", "$meta") or die ("ERR: failed to create metadata files.");
			print META "# RVT SRC: $f\n";
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
	}
    return 1;
}



sub RVT_parse_eml {
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("EML... ");
	if( our @filelist_eml ) {
		print "\n";
		my $emlpath = RVT_create_folder($opath, 'eml');
		my $fpath = RVT_create_file($emlpath, 'eml', 'html');
		( my $count = $fpath ) =~ s/.*-([0-9]*).html$/\1/;
		foreach my $f ( our @filelist_eml ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			$fpath = "$emlpath/eml-$count.html"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			( my $meta = $fpath ) =~ s/\.html$/.RVT_metadata/;
			open( RVT_ITEM, ">:encoding(UTF-8)", "$fpath") or warn "WARNING: cannot open file $fpath: $!\n";
			my $headers = '';
			open( EML_ITEM, "<:encoding(UTF-8)", "$f" ) or warn "WARNING: cannot open file $f: $!\n";
			my $message = '';
			my $i_am_in_headers = 1;
			while( my $line = <EML_ITEM> ) { # Read eml. Write headers to RVT_META.
				$line =~ s/\r\n/\n/; # to handle DOS line endings.
				$message = $message.$line;
				if( $i_am_in_headers ) { 
					$headers = $headers . $line;
					if( $line =~ /^$/ ) { $i_am_in_headers = 0 }
				}
			}
			close( EML_ITEM );
			my $obj = Email::MIME->new(encode_utf8($message)); # encode_utf8 to avoid croaking with some EMLX containing multibyte characters.
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
			$source =~ s/\/output\/parser\/control\// /;
			my $index_line = "<!--_XX_RVT_DELIM_".$date."_XX_RVT_DELIM_".$from."_XX_RVT_DELIM_".$subject."_XX_RVT_DELIM_".$to."_XX_RVT_DELIM_".$cc."_XX_RVT_DELIM_".$bcc."_XX_RVT_DELIM_".$flags."_XX_RVT_DELIM_-->";
			$index_line =~ s/#//g;
			$index_line =~ s/_XX_RVT_DELIM_/#/g;
			print RVT_ITEM "<HTML>$index_line
<!-- 
# RVT SRC: $f
-->
<HEAD>
	<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
	<style type=\"text/css\">
		table,tr,td{border:1px solid; font-family:sans-serif; font-size:small;border-collapse:collapse;padding:5px;}
		pre{font-size:12px;}
	</style>
	<title>
		$subject
	</title>
	<script language=\"JavaScript\" type=\"text/javascript\">
		<!--
		function sizeTbl(h) {
		  var tbl = document.getElementById('tbl');
		  tbl.style.display = h;
		}
		function doKey(\$k) {
			if ( ((\$k>64) && (\$k<91))   ||   ((\$k>96) && (\$k<123)) ) {
				var tbl = document.getElementById('tbl');
				tbl.style.display = 'block';
			}
		}
		// -->
	</script> 
</HEAD>
<BODY onKeyPress=\"doKey(window.event.keyCode)\">
	<TABLE border=1>
		<tr><td><b>Item</b></td><td>e-mail item (Message) - <a href=\"javascript:sizeTbl('block')\">Metadata</a></td></tr>
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
#my $debug = $obj->debug_structure;
#print "$debug";
			if( $obj->content_type =~ /^multipart\// ) { @parts = $obj->parts } # These are all Email::MIME objects too.
			elsif( ! $obj->content_type ) { # Typical in no-MIME emails: plaintext bodies without specifying content type.
				$obj->content_type_set ( 'text/plain' );
#print "I set this new content type: ". $obj->content_type ."\n";
				@parts = $obj;
			} else { @parts = $obj->parts } # Fallback resource
			my $attach_info = "";
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
					else { RVT_report( "malformed", $f, $disk ) }
				} elsif( $ctype =~ /^multipart\/signed/ ) {
					# Signed messages generated by RVT_parse_msg seem to have some improperly formatted parts ("GPG signed mail is not processed correctly" - see http://cpan.uwinnipeg.ca/htdocs/Email-Outlook-Message/Email/Outlook/Message.pm.html).
					# This is a workaround. Probably the e-mail body will be displayed as an attachment called "smime.txt" and special characters will not be correctly encoded; other than that, the content can be found normally via text searches.
					$filename =~ s/\.p7m$/.txt/;
					$is_attach = 1;
				} elsif( $ctype =~ /^multipart/ ) { push( @parts, $part->parts ) }
				elsif( $filename ) { $is_attach = 1 }
				elsif( ($ctype =~ /^text\//) && (! $msgbody) ) {
					# This must be the message body
#print "  This seems to be the message body.\n";
					if( $ctype =~ /^text\/plain/ ) {
						$msgbody = $part->body;
						$msgbody =~ s/\n/<br>\n/g;
					} elsif( $ctype =~ /^text\/html/ ) { $msgbody = $part->body }
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
					elsif( $ctype =~ /^text\/plain/ ) { $filename =~ s/\.dat/.txt/ }
					$is_attach = 1;
#print "$ctype $filename\n";
				}
				
				# Attachments:
				if( $is_attach ) { # RVT_XX_FIXME: Many attachments with the same name and in the same message (can that happen?) could overwrite each other. We should check that out.
#print "  Attachment: $filename\n";
					( my $attachfolder = $fpath ) =~ s/\.html$/.attach/;
					mkpath( $attachfolder ); # no "or warn..." to avoid that warning if folder already exists.
					$filename =~ s/[\/\\]//g; # Forbidden characters in the filesystem will be ignored.
					open( ATTACH, ">", "$attachfolder/$filename" ) or warn "WARNING: Cannot open file $attachfolder/$filename: $!";
					print ATTACH $part->body;
					close ATTACH;
					my $string = "$attachfolder/$filename";
					my $size = -s $string;
					$string =~ s/.*\/([^\/]*\/[^\/]*)$/\1/;
					$string = RVT_sanitize_http_link( $string );
					print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">$filename</a> ($size bytes)</td></tr>\n";
					( my $short = $string ) =~ s/.*\/output\/parser\/control\///;
					$attach_info = $attach_info . "Attachment: $short ($size bytes)\n";
				}
				
			} # end while( $part=shift(@parts) )
			print RVT_ITEM "</TABLE><br>\n";
			print RVT_ITEM "<DIV id=tbl name=tbl style=\"overflow:hidden;display:none\">
<TABLE border=1 >
<TR><TD><a href=\"javascript:sizeTbl('none')\">[X]</a> <b>METADATA:</b><br><br>
<PRE>
$headers
</PRE>";
			if ( $attach_info ) { print RVT_ITEM "<B>Attachment information:</B>
<PRE>
$attach_info
</PRE>";				
			}
			print RVT_ITEM "</TD></TR>
</TABLE>
</DIV><br><br>
";

			print RVT_ITEM $msgbody;
			print RVT_ITEM "	</BODY>\n</HTML>\n";
			close( RVT_ITEM );
			$count++;
		}
	}
    return 1;
}



sub RVT_parse_evt {
	my $EVTPARSE = "evtparse.pl";
	my $FSTRINGS = "f-strings";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("EVT... ");
	if( our @filelist_evt ) {
		print "\n";
		my $evtpath = RVT_create_folder($opath, 'evt');
		my $fpath = RVT_create_file($evtpath, 'evt', 'txt');
		( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_evt ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			$fpath = "$evtpath/evt-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			open (FEVT, "-|", "$EVTPARSE", $f) or die "Error: $!";
			binmode (FEVT, ":encoding(cp1252)") || die "Can't binmode to cp1252 encoding\n";
			open (FOUT, ">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create output file.");
			print FOUT "# RVT SRC: $f\n";
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



sub RVT_parse_graphics {
	my $EXIFTOOL = "exiftool";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("Graphics... ");
	if( our @filelist_graphics ) {
		print "\n";
		my $graphicspath = RVT_create_folder($opath, 'graphics');
		my $fpath = RVT_create_file($graphicspath, 'graphics', 'txt');
		( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_graphics ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			$fpath = "$graphicspath/graphics-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			open (EXIF, "-|", "$EXIFTOOL", "$f");
			open (FOUT, ">:encoding(UTF-8)", "$fpath") or warn ("WARNING: failed to create output file: $!.");
			print FOUT "# RVT SRC: $f\n";
			while (<EXIF>) { print FOUT $_ }
			close (FOUT);
			$count++;
			RVT_report( "graphics", $f, $disk);
		}
	}
    return 1;
}



sub RVT_parse_lnk {
	my $LNKPARSE = "lnk-parse-1.0.pl";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("LNK... ");
	if( our @filelist_lnk ) {
		print "\n";
		my $lnkpath = RVT_create_folder($opath, 'lnk');
		my $fpath = RVT_create_file($lnkpath, 'lnk', 'txt');
		( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_lnk ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			$fpath = "$lnkpath/lnk-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			open (FLNK, "-|", "$LNKPARSE", $f);
			open (FOUT, ">:encoding(UTF-8)", "$fpath") or warn ("WARNING: failed to create output file: $!.");
			print FOUT "# RVT SRC: $f\n";
			while (<FLNK>) { print FOUT $_ }
			close (FLNK);
			close (FOUT);
			$count++;
		}
	}
    return 1;
}



sub RVT_parse_mbox {
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("MBOX... ");
	if( our @filelist_mbox ) {
		print "\n";
		foreach my $f ( our @filelist_mbox) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			my $mboxpath = RVT_create_folder($opath, 'mbox');
			my $meta = "$mboxpath/__RVT_metadata.txt";
			open (META,">:encoding(UTF-8)", "$meta") or die ("ERR: failed to create metadata files."); # XX Lo del encoding habría que hacerlo en muchos otros sitios.
			print META "# RVT SRC: $f\n";
			
			Mail::Mbox::MessageParser::SETUP_CACHE( { 'file_name' => '/tmp/RVT_mbox_cache' } );
			my $fh = new FileHandle($f);
			my $folder_reader = new Mail::Mbox::MessageParser( {
				'file_name' => $f,
				'file_handle' => $fh,
				'enable_cache' => 1,
				'enable_grep' => 1,
			} );
			warn $folder_reader unless ref $folder_reader;
			print META $folder_reader->prologue;
			
			my $fpath = RVT_create_file($mboxpath, 'mbox', 'eml');
			(my $count = $fpath) =~ s/.*-([0-9]*).eml$/\1/;
			# This is the main loop. It's executed once for each email:
			while(!$folder_reader->end_of_file()) {
				$fpath = "$mboxpath/mbox-$count.eml"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
				my $email = $folder_reader->read_next_email();
				open( EML, ">:encoding(UTF-8)", $fpath );
				print EML $$email;
				close EML;
				$count++;
			}
			close (META);
		} # end foreach my $f ( our @filelist_mbox )
	}
    return 1;
}



sub RVT_parse_msg {
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("MSG... ");
	if( our @filelist_msg ) {
		print "\n";
		my $msgpath = RVT_create_folder($opath, 'msg');
		my $fpath = RVT_create_file($msgpath, 'msg', 'eml');
		( my $count = $fpath ) =~ s/.*-([0-9]*).eml$/\1/;
		foreach my $f ( our @filelist_msg ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			$fpath = "$msgpath/msg-$count.eml"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			( my $meta = $fpath ) =~ s/\.eml$/.RVT_metadata/;

			open (RVT_META, ">:encoding(UTF-8)", "$meta") or warn ("WARNING: failed to create output file $meta: $!.");
			print RVT_META "# RVT SRC: $f\n";
			
			# Temp redirection of STDERR to RVT_META, to capture output from Email::Outlook::Message.
			open( STDERR, ">>:encoding(UTF-8)", "$meta" ); 
			my $mail = eval { new Email::Outlook::Message( $f )->to_email_mime->as_string; }; # Taken from msgconvert.pl by Matijs van Zuijlen (http://www.matijs.net/software/msgconv/);
			warn $@ if $@;
			close( STDERR ); # End of STDERR redirection.

			if( $mail ) {
				open( RVT_ITEM, ">:encoding(UTF-8)", "$fpath" ) or warn ("WARNING: failed to create output file $fpath: $!.");
				print RVT_ITEM $mail;
				close( RVT_ITEM );
			} else { RVT_report( "malformed", $f, $disk ) }
			close (RVT_META);
			$count++;
		}
	}
    return 1;
}



sub RVT_parse_pdf {
	my $PDFTOTEXT = "pdftotext";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("PDF... ");
	if( our @filelist_pdf ) {
		print "\n";
		my $pdfpath = RVT_create_folder($opath, 'pdf');
		my $fpath = RVT_create_file($pdfpath, 'pdf', 'txt');
		( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_pdf ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			$fpath = "$pdfpath/pdf-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			(my $escaped = $f) =~ s/`/\\`/g;
			my $output = `$PDFTOTEXT "$escaped" - 2>&1`;
			open (RVT_META, ">:encoding(UTF-8)", "$fpath") or warn ("WARNING: failed to create output files: $!.");
			print RVT_META "# RVT SRC: $f\n";
			print RVT_META $output;
			if( $output =~ /^Error: Incorrect password$/ ) { RVT_report( "encrypted", $f, $disk ) }
			close (RVT_META);
			$count++;
		}
	}
    return 1;
}



sub RVT_parse_pff {
	my $PFFEXPORT = "pffexport";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("PFF... ");
	if( our @filelist_pff ) {
		print "\n";
		foreach my $f ( our @filelist_pff) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			my $fpath = RVT_create_file($opath, 'pff', 'RVT_metadata');    	
			open (META,">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create metadata files."); # XX Lo del encoding habría que hacerlo en muchos otros sitios.
			print META "# RVT SRC: $f\n";
			close (META);
			$fpath =~ s/.RVT_metadata//; 
			my @args = ("$PFFEXPORT", '-f', 'text', '-m', 'all', '-q', '-t', "$fpath", $f); # -f text and -m all are in fact default options.
			system(@args);        
			foreach my $mode ('export','orphan','recovered') { finddepth( \&RVT_sanitize_libpff_item, "$fpath.$mode" ) }
		}
	}
    return 1;
}



sub RVT_parse_sqlite {
	my $SQLITE = "sqlite3";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("SQLite... ");
	if( our @filelist_sqlite ) {
		print "\n";
		my $sqlitepath = RVT_create_folder($opath, 'sqlite');
		my $fpath = RVT_create_file($sqlitepath, 'sqlite', 'txt');
		( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_sqlite ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			$fpath = "$sqlitepath/sqlite-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			(my $escaped = $f) =~ s/`/\\`/g;
			my $output = `echo ".dump" | sqlite3 -batch "$escaped"`;
			open (FOUT, ">:encoding(UTF-8)", "$fpath") or warn ("WARNING: failed to create output file: $!.");
			print FOUT "# RVT SRC: $f\n";
			print FOUT $output;
			close FOUT;
			$count++;
		}
	}
    return 1;
}



sub RVT_parse_text {
	my $FSTRINGS = "f-strings";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control/text';
    mkpath $opath unless (-d $opath);

	printf ("Text... ");
	my $fpath = RVT_create_file($opath, 'text', 'txt');
	( my $count = $fpath ) =~ s/.*-([0-9]*).txt$/\1/;
	if( our @filelist_text ) {
		print "\n";
		foreach my $f (our @filelist_text) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			$fpath = "$opath/text-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			(my $escaped = $f) =~ s/`/\\`/g;
			my $normalized = `echo "$escaped" | $FSTRINGS`;
			chomp ($normalized);	
			open (FTEXT, "-|", "$FSTRINGS", "$f") or die ("ERROR: Failed to open input file $f\n");
			open (FOUT, ">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create output files.");
			print FOUT "# RVT SRC: $f\n# $normalized\n";
			while (<FTEXT>){
				print FOUT $_;
			}
			close (FTEXT);
			close (FOUT);
			$count++;
		}
	}
    return 1;
}



sub RVT_parse_undelete {
	my $TSK_RECOVER = "tsk_recover";
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);
    
	printf ("Undeletion... ");
	if( our @filelist_undelete ) {
		print "\n";
		foreach my $f ( our @filelist_undelete ) {
			print "  ".RVT_shorten_fs_path( $f )."\n";
			my $fpath = RVT_create_folder($opath, 'undelete');
			mkpath $fpath;
			(my $escaped = $f) =~ s/`/\\`/g;
			my $output = `$TSK_RECOVER "$escaped" "$fpath" 2>&1`;
			open (META, ">:encoding(UTF-8)", "$fpath/__RVT_metadata.txt") or die ("ERR: failed to create metadata files.");
			print META "# RVT SRC: $f\n";
			print META $output;
			close (META);
		}
	}
    return 1;
}




##########################################################################
# Other stuff
##########################################################################




sub RVT_get_all_sources ($$) { # parameters: ( $file, $disk )
	# For a given object generated by RVT_parse, trace its source recursively using RVT_metadata.
	# Returns a list containing the filenames of the original (requested) item and its parent objects,
	# up to a final path (which is usually a file in mnt/ or, for undeleted items, the .dd image itself).
	my $file = shift( @_ );
	my $disk = shift( @_ );

	chomp( $file );
	my $source = RVT_get_source( $file, $disk );
	if( $source ) { return( $file, RVT_get_all_sources( $source, $disk ) ) }
	else { return( $file, 0 ) }
}



sub RVT_get_best_source ($$) { # parameters: ( $file, $disk )
	# Given an object generated by RVT_parse, trace all of its source and decide which item
	# is more suitable to be delivered for the EXPORTed results.
	my $file = shift( @_ );
	my $disk = shift( @_ );

	my $found = 0;
	my @results = ( );
	my @sources = RVT_get_all_sources( $file, $disk );
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
		} elsif( $source =~ /^.*\/output\/parser\/control\/undelete-[0-9]+\/.*$/ ) {
			# For undeleted files, do NOT deliver its source (the whole filesystem), just the undeleted file itself.
			push( @results, "$source" );
			$found = 1;
		} elsif( $source =~ /\/mnt\/p0[0-9]\// ) {
			push( @results, "$source" );
			$found = 1;
		}
	}
	return( @results );
}



sub RVT_get_source  ($$) { # parameters: ( $file, $disk )
	# Returns the immediate source (parent) of an object generated by RVT_parse,
	# using the data stored in RVT_metadata structures.
	my $file = shift( @_ );
	my $disk = shift( @_ );
	
	my $source = 0;
	my $source_type;
	my $got_source = 0;
	
	if( $file =~ /.*\/mnt\/p[0-9]{2}\// ) { $source_type = 'final'; }
	elsif( $file eq RVT_get_imagepath($disk) ) { $source_type = 'final'; }
	elsif( $file =~ /.*\/output\/parser\/control\/bkf-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/compressed-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/dbx-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/eml-[0-9]*/ ) { $source_type = 'special_eml'; }
	elsif( $file =~ /.*\/output\/parser\/control\/evt-[0-9]*\/evt-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/graphics-[0-9]*\/graphics-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/lnk-[0-9]*\/lnk-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/mbox-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/msg-[0-9]*\/msg-[0-9]*\.eml/ ) { $source_type = 'special_msg'; }
	elsif( $file =~ /.*\/output\/parser\/control\/pdf-[0-9]*\/pdf-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/pff-[0-9]*/ ) { $source_type = 'special_pff'; }
	elsif( $file =~ /.*\/output\/parser\/control\/sqlite-[0-9]*\/sqlite-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/text\/text-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/undelete-[0-9]*/ ) { $source_type = 'infolder'; }
	else { warn "WARNING: RVT_get_source called on unknown source type: $file\n" }
	
	if( $source_type eq 'infolder' ) {
		$file =~ s/(.*\/output\/parser\/control\/[a-z]*-[0-9]*)\/.*/\1\/RVT_metadata/;
		if( ! -f $file ) { $file =~ s/(.*\/output\/parser\/control\/[a-z]*-[0-9]*)\/.*/\1\/__RVT_metadata.txt/; }
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
		} else { # Look inside the HTML of this particular EML, which indicates the source.
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
			if ($source =~ s/# RVT SRC: //) { $got_source = 1; last; }
			if ($count > 2) { last; } # This limits the number of lines that will be read when looking for the source.
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



sub RVT_index_email_item () {
# WARNING!!! This function is to be called ONLY from within RVT_create_index.
# $folder_to_index, $buffer_index_email and $count_email are expected to be initialized.
	return if ( -d ); # We only want to act on FILES.
	return if ( $File::Find::dir =~ /.*\.attach.*/ ); # messages attached to other messages are not indexed. Their parent messages will be.
	# however i dunno if EMLs are totally being well parsed
	our $folder_to_index;
	our $count_email;
	our $buffer_index_email;
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
		my $quoted_folder = quotemeta ($folder_to_index);
		( my $path = $File::Find::name ) =~ s/$quoted_folder\/?//; # make paths relative.
		$path = RVT_sanitize_http_link( $path );
		(my $attachpath = $File::Find::name) =~ s/\.html$/.attach/;
		our $attachments = '';
		find( \&RVT_index_email_attachment, $attachpath );
		$buffer_index_email = $buffer_index_email."<tr><td><a href=\"$path\" target=\"_blank\">$item_type</a><td>$line</td><td nowrap>$attachments</td></tr>\n";
		$count_email++;
	}
	return 1;
}



sub RVT_index_email_attachment () {
# WARNING!!! This function is to be called ONLY from within RVT_index_email_item
# $attachments, $folder_to_index and $count_attach are expected to be initialized.
	
	our $attachments;
	our $folder_to_index;
	our $count_attach;
	if( -f $File::Find::name ) {
		my $quoted_folder = quotemeta ($folder_to_index);
		(my $link = $File::Find::name) =~ s/$quoted_folder\/?//;
		$link = RVT_sanitize_http_link( $link );
		$attachments = $attachments ."&gt;<a href=\"$link\" target=\"_blank\">". basename($File::Find::name) ."</a><br>";
		$count_attach++;
	}
	return 1;
}



sub RVT_index_regular_file () {
# WARNING!!! This function is to be called ONLY from within RVT_create_index.
# $folder_to_index, $buffer_index_regular and $count_regular are expected to be initialized.
	return if ( -d ); # We only want to act on FILES.
	return if ( $File::Find::name =~ /.*\.RVT_metadata$/ );
	our $folder_to_index;
	our $count_regular;
	our $buffer_index_regular;
	my $quoted_folder = quotemeta ($folder_to_index);
	( my $link = $File::Find::name ) =~ s/$quoted_folder\/?//; # make paths relative.
	$link = RVT_sanitize_http_link( $link );
	( my $ext = uc(basename($File::Find::name)) ) =~ s/.*\.([^.]{1,16})$/.\1/;
	
	open( SOURCE, "<:encoding(UTF-8)", $File::Find::name.".RVT_metadata" );
	my $original = <SOURCE>;
	close SOURCE;
	my $folder = RVT_shorten_fs_path( dirname($original) );
	my $size = stat($original)->size;
	my $atime = ctime( stat($original)->atime );
	my $mtime = ctime( stat($original)->mtime );
	my $remarks;
	if( $original =~ /$.*\/[0-9]{6}-[0-9]{2}-[0-9]\/output\/parser\/control\/undelete-[0-9]+\/.*$/ ) {
		# Ye olde deleted files, for they deserve special treatment :)
		$remarks = "Deleted; $remarks";
		$atime = "unknown (XX_RVT_FIXME)";
		$mtime = "unknown (XX_RVT_FIXME)";
	}

	$buffer_index_regular = $buffer_index_regular."<tr><td><a href=\"$link\" target=\"_blank\">".basename($File::Find::name)."</a></td><td>$ext</td><td>$folder</td><td align=right>$size</td><td align=right>$mtime</td><td align=right>$atime</td><td>$remarks</td></tr>\n";
	$count_regular++;
	return 1;
}



sub RVT_sanitize_compressed_office () {
# WARNING!!! This function is to be called ONLY from within RVT_parse_compressed.
# File descriptor RVT_META is expected to be open.
	if ( -f $File::Find::name ) {
		if ( $File::Find::name =~ /.*\.(xml|rels|rdf)$/i ) {
			open ( FILE, "<:encoding(UTF-8)", $File::Find::name );
			while ( my $line = <FILE> ) { print RVT_META $line }
			close FILE;
			unlink $File::Find::name;
		}
	} elsif ( -d $File::Find::name ) {
		rmdir $File::Find::name; # will fail if not empty, it's OK.
	}
	return 1;
}



sub RVT_sanitize_http_link ($) {
	# For creating <a href> links.
	my ( $parm ) = @_;
	$parm =~ s/%/%25/g;
	$parm =~ s/#/%23/g;
	$parm =~ s/\?/%3f/g;
	$parm =~ s/\\/%5c/g;
	return $parm;
}



sub RVT_sanitize_html_string ($) {
	# For writing text inside HTML.
	my ( $parm ) = @_;
	$parm =~ s/</&lt;/g;
	$parm =~ s/>/&gt;/g;
	return $parm;
}



sub RVT_sanitize_libpff_attachment () {
# WARNING!!! This function is to be called ONLY from within RVT_sanitize_libpff_item.
# File descriptor RVT_ITEM is expected to be open when entering this sub,
# and $wanted_depth and $headers are expected to be correctly set.
	return if ( -d ); # We only want to act on FILES.
	my $item_depth = $File::Find::dir =~ tr[/][];
	our $wanted_depth;
	our $headers;
	if( $item_depth == $wanted_depth ) {
		( my $short = $File::Find::name ) =~ s/.*\/output\/parser\/control\///;
		my $size = -s $File::Find::name;
		$headers = $headers . "Attachment: $short ($size bytes)\n";
		my $string = $File::Find::name;
		chomp( $string );
		$string =~ s/.*\/([^\/]*\/[^\/]*)$/\1/;
		$string = RVT_sanitize_http_link( $string );
		print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">", basename($File::Find::name), "</a> ($size bytes)</td></tr>\n";
	} elsif( $item_depth eq $wanted_depth+1 && $File::Find::name =~ /.*[A-Z[a-z]*00001.html/ )  {
		( my $short = $File::Find::name ) =~ s/.*\/output\/parser\/control\///;
		my $size = -s $File::Find::name;
		$headers = $headers . "Attachment: $short ($size bytes)\n"; # computing the SIZE is more complicated in this case.
		my $string = $File::Find::name;
		chomp( $string );
		$string =~ s/.*\/([^\/]*\/[^\/]*\/[^\/]*)$/\1/;
		$string = RVT_sanitize_http_link( $string );
		print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">", basename($File::Find::name), "</a></td></tr>\n"; # computing the SIZE is more complicated in this case.
	}
	return 1;
}



sub RVT_sanitize_libpff_item () {
	
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
	( my $source = $folder ) =~ s/^.*([0-9]{6}-[0-9]{2}-[0-9])\/output\/parser\/control\//\1 /;
	( my $item_type = basename($folder) ) =~ s/[0-9]{5}//;
	( my $file = basename($folder) ) =~ s/[0-9]{5}/.txt/;
	if( $item_type eq 'Message' ) { $file =~ s/Message/OutlookHeaders/ }
	return if( $item_type eq 'Attachment' ); # Folders like Attachment00001 must not be treated directly by us; instead they will be treated during the sub parse_attachment of their parent directory.
	return if( $item_type eq 'Folder' ); # Folders like Folder00001 are likely to be found in recovered structures, but they are not "by themselves" items to be analyzed. Note that the normal items (Message, Contact...) inside WILL be analyzed normally.
	if( exists $field_names{$item_type} ) { } # print "Item: $item_type ($source)\n" }
	else {
# XX aquí, además, habría que reportar a MALFORMED:
		warn "WARNING: Skipping unknown item type $item_type ($source)\n";
		return
	}
	
	open( LIBPFF_ITEM, "<:encoding(UTF-8)", "$folder/$file" ) or warn( "WARNING: Cannot open $folder/$file for reading - skipping item.\n" ) && return;
	open( RVT_ITEM, ">:encoding(UTF-8)", "$folder.html" ) or warn( "WARNING: Cannot open $folder.txt for writing - skipping item.\n" ) && return;
	our $headers = "";
	$headers = $headers . "<b>$file</b>\n<pre>\n";
	
	# Parse LIBPFF_ITEM until an empty line is found, writing to RVT_META and store wanted keys:
	PARSE_KEYS:
	while( my $line = <LIBPFF_ITEM> ) { # This loop exits as soon as one empty line is found
		if( $line =~ /^$/ ) { last PARSE_KEYS } # this exits the WHILE loop
		$headers = $headers . $line;
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
	$headers = $headers . "</pre>\n";

	# InternetHeaders.txt: append to RVT_META
	if( -f "$folder/InternetHeaders.txt" ) {
		$headers = $headers . "\n<b>Internet headers:</b>\n<pre>\n";
		open (INTERNETHEADERS, "<:encoding(UTF-8)", "$folder/InternetHeaders.txt") or warn ("WARNING: failed to open $folder/InternetHeaders.txt\n");
		while( my $line = <INTERNETHEADERS> ) {
			chomp( $line); # Two chomps attempting to normalize the DOS line ending.
			chomp( $line);
			$headers = $headers . "$line\n";
		}			
		$headers = $headers . "</pre>\n";
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
		$headers = $headers . "\n<b>Recipients:</b>\n<pre>\n";
		open (RECIPIENTS, "<:encoding(UTF-8)", "$folder/Recipients.txt") or warn ("WARNING: failed to open $File::Find::dir/Recipients.txt\n");
		while( my $line = <RECIPIENTS> ) {
			$headers = $headers . $line;
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
		$headers = $headers . "</pre>\n";
		close (RECIPIENTS); # done parsing Recipients.txt
		unlink ("$folder/Recipients.txt") or warn ("WARNING: failed to delete $folder/Recipients.txt\n");	
	}

	# ConversationIndex.txt: append to RVT_META
	if( -f "$folder/ConversationIndex.txt" ) {
		$headers = $headers . "\n<b>Conversation index:</b>\n<pre>\n";
		open ( CONVERSATIONINDEX, "<:encoding(UTF-8)", "$folder/ConversationIndex.txt") or warn ("WARNING: failed to open $folder/ConversationIndex.txt\n");
		while ( my $line = <CONVERSATIONINDEX> ) { $headers = $headers . $line }
		$headers = $headers . "</pre>\n";
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
	( my $shortdate = $field_values{'Client submit time'} ) =~ s/\.[0-9]{9}//;
	my $index_line = "<!--_XX_RVT_DELIM_".$shortdate."_XX_RVT_DELIM_".$field_values{'Sender name'}."_XX_RVT_DELIM_".$field_values{'Subject'}."_XX_RVT_DELIM_".$to."_XX_RVT_DELIM_".$cc."_XX_RVT_DELIM_".$bcc."_XX_RVT_DELIM_".$field_values{'Flags'}."_XX_RVT_DELIM_-->";
	$index_line =~ s/#//g;
	$index_line =~ s/_XX_RVT_DELIM_/#/g;
	print RVT_ITEM "<HTML>$index_line
<HEAD>
	<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
	<style type=\"text/css\">
		table,tr,td{border:1px solid; font-family:sans-serif; font-size:small;border-collapse:collapse;padding:5px;}
		pre{font-size:12px;}
	</style>
	<title>
		$field_values{'Subject'}
	</title>
	<script language=\"JavaScript\" type=\"text/javascript\">
		<!--
		function sizeTbl(h) {
		  var tbl = document.getElementById('tbl');
		  tbl.style.display = h;
		}
		function doKey(\$k) {
			if ( ((\$k>64) && (\$k<91))   ||   ((\$k>96) && (\$k<123)) ) {
				var tbl = document.getElementById('tbl');
				tbl.style.display = 'block';
			}
		}
		// -->
	</script> 
</HEAD>
<BODY onKeyPress=\"doKey(window.event.keyCode)\">
	<TABLE border=1>
		<tr><td><b>Item</b></td><td>e-mail item ($item_type) - <a href=\"javascript:sizeTbl('block')\">Metadata</a></td></tr>
		<tr><td><b>Source</b></td><td>$source</td></tr>
";
	foreach my $k ( @sortorder ) { # Write desired headers to RVT_ITEM:
		if( defined( $field_values{$k} ) && defined( $field_names{$item_type}{$k} ) ) {
			if ( $k =~ /.* time:.*/ ) { $field_values{$k} =~ s/\.[0-9]{9}// }
			print RVT_ITEM "		<tr><td><b>$field_names{$item_type}{$k}</b></td><td>$field_values{$k}</td></tr>\n";
		}
	}
	# Write recipients to RVT_ITEM:
	if( $to ne '' ) { print RVT_ITEM "		<tr><td><b>To</b></td><td>$to</td></tr>\n" }
	if( $cc ne '' ) { print RVT_ITEM "		<tr><td><b>CC</b></td><td>$cc</td></tr>\n" }
	if( $bcc ne '' ) { print RVT_ITEM "		<tr><td><b>BCC</b></td><td>$bcc</td></tr>\n" }
	
	# Attachments:
	if( -d "$folder/Attachments" ) {
		move( "$folder/Attachments", "$folder.attach" );
		$headers = $headers . "\n<b>Attachment information:</b>\n<pre>\n";
		our $wanted_depth = "$folder" =~ tr[/][];
		find( \&RVT_sanitize_libpff_attachment, "$folder.attach" );
		$headers = $headers . "</pre>\n";
	}

	# Parse rest of LIBPFF_ITEM writing to RVT_META and RVT_ITEM
	print RVT_ITEM "</TABLE><br>\n";	
	$headers = $headers . "\n<b>Rest of $file (if any):</b>\n<pre>";
	while( my $line = <LIBPFF_ITEM> ) { 
		print RVT_ITEM "$line<br>";
		$headers = $headers . $line;
	}
	$headers = $headers . "</pre>\n";

	# Write RVT_META section inside RVT_ITEM:
	print RVT_ITEM "<DIV id=tbl name=tbl style=\"overflow:hidden;display:none\">
<TABLE border=1 >
<TR><TD><a href=\"javascript:sizeTbl('none')\">[X]</a> <b>METADATA:</b><br><br>
$headers
</TD></TR>
</TABLE>
</DIV><br><br>
";

	# Message.txt: append to RVT_ITEM
	if( -f "$folder/Message.txt" ) {
		open (MESSAGE,  "<:encoding(UTF-8)", "$folder/Message.txt") or warn ("WARNING: failed to open $folder/Message.txt\n");
		while( my $line = <MESSAGE> ) {
			chomp( $line);
			print RVT_ITEM "$line<br>\n";
		} 
		close (MESSAGE); # done parsing Message.txt
		unlink ("$folder/Message.txt") or warn ("WARNING: failed to delete $folder/Message.txt\n");
	} elsif( -f "$folder/Message.html" ) {
		open (MESSAGE,  "<:encoding(UTF-8)", "$folder/Message.html") or warn ("WARNING: failed to open $folder/Message.html\n");
		while( my $line = <MESSAGE> ) {
			print RVT_ITEM "$line";
		} 
		close (MESSAGE); # done parsing Message.html
		unlink ("$folder/Message.html") or warn ("WARNING: failed to delete $folder/Message.html\n");
	} elsif( -f "$folder/Message.rtf" ) {
		open (MESSAGE,  "<:encoding(UTF-8)", "$folder/Message.rtf") or warn ("WARNING: failed to open $folder/Message.rtf\n");
		while( my $line = <MESSAGE> ) {
			chomp( $line);
			print RVT_ITEM "$line<br>\n";
		} 
		close (MESSAGE); # done parsing Message.rtf
		unlink ("$folder/Message.rtf") or warn ("WARNING: failed to delete $folder/Message.rtf\n");
	}
	
	print RVT_ITEM "	</BODY>\n</HTML>\n";
	close( LIBPFF_ITEM );
	close( RVT_ITEM );
	unlink( "$folder/$file" ) || warn( "WARNING: Cannot delete $folder/file\n" );
	rmdir( $folder ) || warn( "WARNING: Cannot delete $folder\n" );
}




sub RVT_shorten_fs_path ($) {
	# Shorten a file name to fit it on screen.
	my $parm = shift( @_ );
	$parm =~ s/^.*\/([0-9]{6}-[0-9]{2}-[0-9]\/.*)/\1/;
	$parm =~ s/\/output\/parser\/control\// /;	
	return $parm;
}



sub RVT_report ($$$) {
# WARNING: RVT_META is expected to be an open fd.
	# Logs a given item to a given report.
	# Standard reports: encrypted, malformed.
	my ( $report, $file, $disk ) = @_;

	my $reportpath = RVT_get_morguepath($disk) . '/output/parser/searches';
	if( ! -d $reportpath ) { mkdir $reportpath };
	open( REPORT, ">>:encoding(UTF-8)", "$reportpath/_RVT_$report" );
	print REPORT "$file\n";
	close( REPORT );
	if( $report =~ /^encrypted$/ ) {
		print "   * Item seems encrypted or password-protected. Reported.\n";
		print RVT_META "# Item seems encrypted or password-protected. Reported.\n" or warn "WARNING: cannot log to RVT_META (is it open?): $!";
	} elsif( $report =~ /^malformed$/ ) {
		print "   * Item possibly malformed. Reported.\n";
		print RVT_META "# Item possibly malformed. Reported.\n" or warn "WARNING: cannot log to RVT_META (is it open?): $!";
	} elsif( $report =~ /^graphics$/ ) { # print nothing (no on-screen feedback, just report it)
	} else {
		print "   * Item added to report _RVT_$report.\n";
		print RVT_META "# Item added to report _RVT_$report.\n" or warn "WARNING: cannot log to RVT_META (is it open?): $!";
	}
	
	return 1;
}



1;