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
   $main::RVT_functions{RVT_script_parse_index } = "Creates an index of exported items\n
                                                    script parse index <folder>";
}





##########################################################################
# Subs that need to be modified for new plugins
##########################################################################



sub RVT_build_filelists {

	# Declare (our) file lists:
	our @filelist_bkf;
	our @filelist_eml;
	our @filelist_evt;
	our @filelist_lnk;
	our @filelist_msg;
	our @filelist_pdf;
	our @filelist_pff;
	our @filelist_rar;
	our @filelist_text;
	our @filelist_zip;

	# Populate the file lists with files with certain extensions:
	if( -f $File::Find::name ) {
		# filelist_bkf:
		if( $File::Find::name =~ /\.bkf$/i ) { push( @filelist_bkf, $File::Find::name ) }
		# filelist_eml:
		elsif( $File::Find::name =~ /\.eml$/i ) { push( @filelist_eml, $File::Find::name ) }
		# filelist_evt:
		elsif( $File::Find::name =~ /\.evt$/i ) { push( @filelist_evt, $File::Find::name ) }
		# filelist_lnk:
		elsif( $File::Find::name =~ /\.lnk$/i ) { push( @filelist_lnk, $File::Find::name ) }
		# filelist_msg:
		elsif( $File::Find::name =~ /\.msg$/i ) { push( @filelist_msg, $File::Find::name ) }
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
		our @filelist_bkf = ( );
		our @filelist_eml = ( );
		our @filelist_evt = ( );
		our @filelist_lnk = ( );
		our @filelist_msg = ( );
		our @filelist_pdf = ( );
		our @filelist_pff = ( );
		our @filelist_rar = ( );
		our @filelist_zip = ( );
		our @filelist_text = ( );
		find( \&RVT_build_filelists, $item );

		# Parse all known file types:
		RVT_parse_bkf( $item, $disk );
		RVT_parse_eml( $item, $disk );
		RVT_parse_evt( $item, $disk );
		RVT_parse_lnk( $item, $disk );
		RVT_parse_msg( $item, $disk );
		RVT_parse_pdf( $item, $disk );
		RVT_parse_pff( $item, $disk );
		RVT_parse_rar( $item, $disk );
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
	
		RVT_images_scan;    
		RVT_mount_assign( $disk );
		for( my $i = 1; $i < $max_passes ; $i++ ) {
			RVT_parse_everything( $disk );
		}
		$disk = shift( @_ );
	}
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
						open( REPORT, ">>:encoding(UTF-8)", "$opath/RVT_report.txt" );
						print REPORT "$result -> $dest\n";
						close( REPORT );
					}
				}
			} # end while ... (for each line of results...)
			RVT_script_parse_index( $opath );
		} # end for each string...
		$disk = shift( @_ );
	} # end while( $disk )
	return 1;
}



sub RVT_script_parse_index {
	our $folder_to_index = shift( @_ ); # this parameter is accessed by RVT_index_outlook_item
	if( ! -d $folder_to_index ) {
		warn "ERROR: Not a directory: $folder_to_index ($!)\nOMMITING COMMAND: create index $folder_to_index\n";
		return;
	}
	my $index = "$folder_to_index/RVT_index.html";
	if( -f $index ) { print "WARNING: Overwriting existing index.\n" }
	my $searchterm = basename( $folder_to_index );
	open( RVT_INDEX, ">:encoding(UTF-8)", "$index" ) or warn "WARNING: cannot open $index for writing.\n$!\n";
	print RVT_INDEX "<HTML>
<HEAD>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
<script type=\"text/javascript\">
<!--
// Based on version 1.7 of the script Table_Sort - The following code is Copyright 2007 - 2009 Gennadiy Shvets, distributed under GPL 3.0 - See http://www.allmyscripts.com/Table_Sort/index.html for usage details.
var TSort_Store;
var TSort_All;
function TSort_StoreDef () { this.sorting = []; this.nodes = []; this.rows = []; this.row_clones = []; this.sort_state = []; this.initialized = 0; this.history = []; this.sort_keys = []; this.sort_colors = [ '#FF0000', '#800080', '#0000FF' ]; };
function tsInitOnload () { if (TSort_All == null) tsRegister(); for (var id in TSort_All) { tsSetTable (id); tsInit(); } if	(window.onload_sort_table) window.onload_sort_table(); }
function tsInit() { if	(TSort_Data.push == null) return; var table_id = TSort_Data[0]; var table = document.getElementById(table_id); var thead = table.getElementsByTagName('thead')[0]; if (thead == null) { alert ('Cannot find THEAD tag!'); return; } var tr = thead.getElementsByTagName('tr'); var cols, i, node, len; if (tr.length > 1) { var	cols0 = tr[0].getElementsByTagName('th'); if (cols0.length == 0) cols0 = tr[0].getElementsByTagName('td'); var cols1; var cols1 = tr[1].getElementsByTagName('th'); if	(cols1.length == 0) cols1 = tr[1].getElementsByTagName('td'); cols = new Array (); var j0, j1, n; len = cols0.length; for (j0 = 0, j1 = 0; j0 < len; j0++) { node = cols0[j0]; n = node.colSpan; if	(n > 1) { while (n > 0) { cols.push (cols1[j1++]); n--; } } else { if	(node.rowSpan == 1) j1++; cols.push (node); } } } else { cols = tr[0].getElementsByTagName('th'); if	(cols.length == 0) cols = tr[0].getElementsByTagName('td'); } len = cols.length; for (var i = 0; i < len; i++) { if	(i >= TSort_Data.length - 1) break; node = cols[i]; var sorting = TSort_Data[i + 1].toLowerCase(); if	(sorting == null)  sorting = ''; TSort_Store.sorting.push(sorting); if	((sorting != null)&&(sorting != '')) { node.innerHTML = \"<a href='' onClick=\\\"tsDraw(\" + i + \",'\" + table_id + \"'); return false\\\">\" + node.innerHTML + '</a><b><span id=\"TS_' + i + '_' + table_id + '\"></span></b>'; node.style.cursor = \"pointer\"; } } var tbody = table.getElementsByTagName('tbody')[0]; var rows = tbody.getElementsByTagName('tr'); var date = new Date (); var len, text, a; for (i = 0; i < rows.length; i++) { var row = rows[i]; var cols = row.getElementsByTagName('td'); var row_data = []; for (j = 0; j < cols.length; j++) { text = cols[j].innerHTML.replace(/^\s+/, ''); text = text.replace(/\s+$/, ''); var sorting = TSort_Store.sorting[j]; if	(sorting == 'h') { text = text.replace(/<[^>]+>/g, ''); text = text.toLowerCase(); } else if	(sorting == 's') text = text.toLowerCase(); else if (sorting == 'i') { text = parseInt(text); if	(isNaN(text))	text = 0; } else if (sorting == 'n') { text = text.replace(/(\d)\,(?=\d\d\d)/g, \"$1\"); text = parseInt(text); if	(isNaN(text))	text = 0; } else if (sorting == 'f') { text = parseFloat(text); if	(isNaN(text))	text = 0; } else if (sorting == 'g') { text = text.replace(/(\d)\,(?=\d\d\d)/g, \"$1\"); text = parseFloat(text); if	(isNaN(text))	text = 0; } else if (sorting == 'd') { if	(text.match(/^\d\d\d\d\-\d\d?\-\d\d?(?: \d\d?:\d\d?:\d\d?)?$/)) { a = text.split (/[\s\-:]/); text = (a[3] == null)? Date.UTC(a[0], a[1] - 1, a[2],    0,    0,    0, 0): Date.UTC(a[0], a[1] - 1, a[2], a[3], a[4], a[5], 0); } else text = Date.parse(text); } row_data.push(text); } TSort_Store.rows.push(row_data); var new_row = row.cloneNode(true); new_row.tsort_row_id = i; TSort_Store.row_clones[i] = new_row; } TSort_Store.initialized = 1; if	(TSort_Store.cookie) { var allc = document.cookie; i = allc.indexOf (TSort_Store.cookie + '='); if	(i != -1) { i += TSort_Store.cookie.length + 1; len = allc.indexOf (\";\", i); text = decodeURIComponent (allc.substring (i, (len == -1)? allc.length: len)); TSort_Store.initial = (text == '')? null: text.split(/\s*,\s*/); } } var	initial = TSort_Store.initial; if	(initial != null) { var itype = typeof initial; if	((itype == 'number')||(itype == 'string')) tsDraw(initial); else { for (i = initial.length - 1; i >= 0; i--) tsDraw(initial[i]); } } }
function tsDraw(p_id, p_table) { if	(p_table != null) tsSetTable (p_table); if	((TSort_Store == null)||(TSort_Store.initialized == 0)) return; var i = 0; var sort_keys = TSort_Store.sort_keys; var id; var new_order = ''; if	(p_id != null) { if	(typeof p_id == 'number') id = p_id; else	if	((typeof p_id == 'string')&&(p_id.match(/^\d+[ADU]$/i))) { id = p_id.replace(/^(\d+)[ADU]$/i, \"$1\"); new_order = p_id.replace(/^\d+([ADU])$/i, \"$1\").toUpperCase(); } } if	(id == null) { id = this.tsort_col_id; if	((p_table == null)&&(this.tsort_table_id != null)) tsSetTable (this.tsort_table_id); } var table_id = TSort_Data[0]; var order = TSort_Store.sort_state[id]; if	(new_order == 'U') { if	(order != null) { TSort_Store.sort_state[id] = null; obj = document.getElementById ('TS_' + id + '_' + table_id); if	(obj != null)	obj.innerHTML = ''; } } else if	(new_order != '') { TSort_Store.sort_state[id] = (new_order == 'A')? true: false; sort_keys.unshift(id); i = 1; } else { if	((order == null)||(order == true)) { TSort_Store.sort_state[id] = (order == null)? true: false; sort_keys.unshift(id); i = 1; } else { TSort_Store.sort_state[id] = null; obj = document.getElementById ('TS_' + id + '_' + table_id); if	(obj != null)	obj.innerHTML = ''; } } var len = sort_keys.length; while (i < len) { if	(sort_keys[i] == id) { sort_keys.splice(i, 1); len--; break; } i++; } if	(len > 3) { i = sort_keys.pop(); obj = document.getElementById ('TS_' + i + '_' + table_id); if	(obj != null)	obj.innerHTML = ''; TSort_Store.sort_state[i] = null; } TSort_Store.row_clones.sort(tsSort); var new_tbody = document.createElement('tbody'); var row_clones = TSort_Store.row_clones; len = row_clones.length; var classes = TSort_Store.classes; if	(classes == null) { for (i = 0; i < len; i++) new_tbody.appendChild (row_clones[i].cloneNode(true)); } else { var clone; var j = 0; var cl_len = classes.length; for (i = 0; i < len; i++) { clone = row_clones[i].cloneNode(true); clone.className = classes[j++]; if	(j >= cl_len)  j = 0; new_tbody.appendChild (clone); } } var table = document.getElementById(table_id); var tbody = table.getElementsByTagName('tbody')[0]; table.removeChild(tbody); table.appendChild(new_tbody); var obj, color, icon, state; len = sort_keys.length; var sorting = new Array (); for (i = 0; i < len; i++) { id = sort_keys[i]; obj = document.getElementById ('TS_' + id + '_' + table_id); if	(obj == null)  continue; state = (TSort_Store.sort_state[id])? 0: 1; icon = TSort_Store.icons[state]; obj.innerHTML = (icon.match(/</))? icon: '<font color=\"' + TSort_Store.sort_colors[i] + '\">' + icon + '</font>'; sorting.push(id + ((state)? 'D': 'A')); } if	(TSort_Store.cookie) { var date = new Date(); date.setTime (date.getTime () + 2592000); document.cookie = TSort_Store.cookie + \"=\" + encodeURIComponent (sorting.join(',')) + \"; expires=\" + date.toGMTString () + \"; path=/\"; } }
function tsSort(a, b) { var data_a = TSort_Store.rows[a.tsort_row_id]; var data_b = TSort_Store.rows[b.tsort_row_id]; var sort_keys = TSort_Store.sort_keys; var len = sort_keys.length; var id; var type; var order; var result; for (var i = 0; i < len; i++) { id = sort_keys[i]; type = TSort_Store.sorting[id]; var v_a = data_a[id]; var v_b = data_b[id]; if	(v_a == v_b)  continue; if	((type == 'i')||(type == 'f')||(type == 'd')) result = v_a - v_b; else result = (v_a < v_b)? -1: 1; order = TSort_Store.sort_state[id]; return (order)? result: 0 - result; } return (a.tsort_row_id < b.tsort_row_id)? -1: 1; }
function tsRegister() { if	(TSort_All == null) TSort_All = new Object(); var ts_obj = new TSort_StoreDef(); ts_obj.sort_data = TSort_Data; TSort_Data = null; if	(typeof TSort_Classes != 'undefined') { ts_obj.classes = TSort_Classes; TSort_Classes = null; } if	(typeof TSort_Initial != 'undefined') { ts_obj.initial = TSort_Initial; TSort_Initial = null; } if	(typeof TSort_Cookie != 'undefined') { ts_obj.cookie = TSort_Cookie; TSort_Cookie = null; } if	(typeof TSort_Icons != 'undefined') { ts_obj.icons = TSort_Icons; TSort_Icons = null; } if	(ts_obj.icons == null) ts_obj.icons = new Array (\"\u2193\", \"\u2191\"); TSort_All[ts_obj.sort_data[0]] = ts_obj; }
function	tsSetTable (p_id) { TSort_Store = TSort_All[p_id]; if	(TSort_Store == null) { alert (\"Cannot set table '\" + p_id + \"' - table is not registered\"); return; } TSort_Data = TSort_Store.sort_data; }
if	(window.addEventListener) window.addEventListener(\"load\", tsInitOnload, false); else if (window.attachEvent) window.attachEvent (\"onload\", tsInitOnload); else { if ((window.onload_sort_table == null)&&(window.onload != null)) window.onload_sort_table = window.onload; window.onload = tsInitOnload; }
// End of script code by Gennadiy Shvets
var TSort_Data = new Array ('my_table', '', 's', 'd', 's', 's', 's', 's', 's');
tsRegister();
// -->
</script>
<TITLE>$searchterm</TITLE>
</HEAD>
<BODY>Index of $folder_to_index";

 	if( ( -d "$folder_to_index/files" ) or ( -d "$folder_to_index/outlook" ) ) {
 		# We are indexing an EXPORT folder
 	}
	print RVT_INDEX "<h1>Outlook / e-mail:</h1>
<TABLE id=\"my_table\" border=1 rules=all frame=box>
<THEAD>
<tr><th width=\"1%\">Item</th><th width=\"10%\">From</th><th width=\"10%\">____________Date____________</th><th width=\"10%\">Subject</th><th width=\"10%\">To</th><th width=\"10%\">Cc</th><th width=\"10%\">Bcc</th><th width=\"10%\">Notes</th></tr>
</THEAD>
";
	find( \&RVT_index_outlook_item, "$folder_to_index" );
	print RVT_INDEX "</TABLE>";
	print RVT_INDEX "</BODY>\n</HTML>\n";
	return 1;
}




##########################################################################
# Subs for parsing each file type
##########################################################################



sub RVT_parse_bkf {
    my $folder = shift(@_);
	if( not -d $folder ) { RVT_log ( 'WARNING' , 'parameter is not a directory'); return 0; }
	my $disk = shift(@_);
	$disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
	my $morguepath = RVT_get_morguepath($disk);
    my $opath = RVT_get_morguepath($disk) . '/output/parser/control';
    mkpath $opath unless (-d $opath);

	printf ("  Parsing BKF files...\n");
    foreach my $f ( our @listbkf) {
    	print "    $f\n";
        my $fpath = RVT_create_folder($opath, 'bkf');
		my $output = `mtftar < "$f" | tar xv -C "$fpath" 2>&1 `;
        open (META, ">:encoding(UTF-8)", "$fpath/RVT_metadata") or warn ("WARNING: cannot create metadata files: $!.");
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
    }
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
		my $count = $fpath;
		$count =~ s/.*-([0-9]*).html$/\1/;
		foreach my $f ( our @filelist_eml ) {
			$fpath = "$emlpath/eml-$count.html"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			print "    $f\n";
			
			my $meta = $fpath;
			$meta =~ s/\.html$/.RVT_metadata/;
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
			my $source = $f;
			$source =~ s/^.*\/([0-9]{6}-[0-9]{2}-[0-9]\/.*)/\1/;
			$source =~ s/\/output\/parser\/control//;
			print RVT_ITEM "<HTML><!--#$from#$date#$subject#$to#$cc#$bcc#$flags#-->
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
					my $attachfolder = $fpath;
					$attachfolder =~ s/\.html$/.attach/;
					mkpath( $attachfolder ); # no "or warn..." to avoid that warning if folder already exists.
					open( ATTACH, ">", "$attachfolder/$filename" ) or warn "WARNING: Cannot open file $attachfolder/$filename: $!";
					print ATTACH $part->body;
					close ATTACH;
					my $string = "$attachfolder/$filename";
					print RVT_META "Attachment: $string\n";
					$string =~ s/.*\/([^\/]*\/[^\/]*)$/\1/;
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
		my $count = $fpath;
		$count =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_evt ) {
			$fpath = "$evtpath/evt-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			print "    $f\n";
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
		my $count = $fpath;
		$count =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_lnk ) {
			$fpath = "$lnkpath/lnk-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			print "    $f\n";
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
		my $count = $fpath;
		$count =~ s/.*-([0-9]*).eml$/\1/;
		foreach my $f ( our @filelist_msg ) {
			$fpath = "$msgpath/msg-$count.eml"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			print "    $f\n";
			my $meta = $fpath;
			$meta =~ s/\.eml$/.RVT_metadata/;
			open (META, ">:encoding(UTF-8)", "$meta") or warn ("WARNING: failed to create output file $meta: $!.");
			print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
			close (META);
			open( STDERR, ">>:encoding(UTF-8)", "$meta" ); # Temp redirection of STDERR to RVT_META, to capture output from Email::Outlook::Message.
			my $mail = new Email::Outlook::Message( $f )->to_email_mime->as_string; # Taken from msgconvert.pl by Matijs van Zuijlen (http://www.matijs.net/software/msgconv/)
			close( STDERR ); # End of STDERR redirection.
			open( RVT_ITEM, ">:encoding(UTF-8)", "$fpath" ) or warn ("WARNING: failed to create output file $fpath: $!.");
			print RVT_ITEM $mail;
			close( RVT_ITEM );

			$count++;
		}
	}
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
    
	printf ("  Parsing PDF files...\n");
	if( our @filelist_pdf ) {
		my $pdfpath = RVT_create_folder($opath, 'pdf');
		my $fpath = RVT_create_file($pdfpath, 'pdf', 'txt');
		my $count = $fpath;
		$count =~ s/.*-([0-9]*).txt$/\1/;
		foreach my $f ( our @filelist_pdf ) {
			$fpath = "$pdfpath/pdf-$count.txt"; # This is to avoid calling RVT_create_file thousands of times inside the loop.
			print "    $f\n";
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
    
	printf ("  Parsing PFF files (PST, OST, PAB)...\n");
    foreach my $f ( our @filelist_pff) {
    	print "    $f\n";
    	my $fpath = RVT_create_file($opath, 'pff', 'RVT_metadata');    	
        open (META,">:encoding(UTF-8)", "$fpath") or die ("ERR: failed to create metadata files."); # XX Lo del encoding habría que hacerlo en muchos otros sitios.
        print META "# BEGIN RVT METADATA\n# Source file: $f\n# Parsed by: $RVT_moduleName v$RVT_moduleVersion\n# END RVT METADATA\n";
        close (META);
        $fpath =~ s/.RVT_metadata//; 
        my @args = ('pffexport', '-f', 'text', '-m', 'all', '-q', '-t', "$fpath", $f); # -f text and -m all are in fact default options.
        system(@args);        
        foreach my $mode ('export','orphan','recovered') { finddepth( \&RVT_sanitize_libpff_item, "$fpath.$mode" ) }
    }
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
    
	printf ("  Parsing RAR files...\n");
    foreach my $f ( our @filelist_rar ) {
    	print "    $f\n";
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

	printf ("  Parsing text files...\n");
	my $fpath = RVT_create_file($opath, 'text', 'txt');
	my $count = $fpath;
	$count =~ s/.*-([0-9]*).txt$/\1/;
	foreach my $f (our @filelist_text) {
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
    
	printf ("  Parsing ZIP files (and ODF, OOXML)...\n");
    foreach my $f ( our @filelist_zip ) {
    	print "    $f\n";
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
	elsif( $file =~ /.*\/output\/parser\/control\/bkf-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
	elsif( $file =~ /.*\/output\/parser\/control\/eml-[0-9]*/ ) { $source_type = 'special_eml'; }
	elsif( $file =~ /.*\/output\/parser\/control\/evt-[0-9]*\/evt-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/lnk-[0-9]*\/lnk-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/msg-[0-9]*\/msg-[0-9]*\.eml/ ) { $source_type = 'special_msg'; }
	elsif( $file =~ /.*\/output\/parser\/control\/pdf-[0-9]*\/pdf-[0-9]*\.txt/ ) { $source_type = 'infile'; }
	elsif( $file =~ /.*\/output\/parser\/control\/pff-[0-9]*/ ) { $source_type = 'special_pff'; }
	elsif( $file =~ /.*\/output\/parser\/control\/rar-[0-9]*\/.*/ ) { $source_type = 'infolder'; }
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



sub RVT_index_outlook_item {
# WARNING!!! This function is to be called ONLY from within RVT_create_index.
# $folder_to_index and RVT_INDEX are expected to be initialized.
	return if ( -d ); # We only want to act on FILES.
	our $folder_to_index;
	if( ($File::Find::name =~ /.*\/[A-Z][a-z]+[0-9]{5}.html/) or ($File::Find::name =~ /.*\/eml-[0-9]+.html/) ) {
		open( ITEM, "<:encoding(UTF-8)", $File::Find::name );
		my $line = <ITEM>;
		close ITEM;
		chomp( $line );
		$line =~ s/^[^#]*#//;
		$line =~ s/#-->$//;
		$line =~ s/#/<\/td><td>/g;
		my $item_type;
		if( $File::Find::name =~ /.*\/eml-[0-9]+.html/) { $item_type = 'Message' }
		else {
			$item_type = basename( $File::Find::name );
			$item_type =~ s/[0-9]{5}.*//;
		}
		my $path = $File::Find::name;
		$path =~ s/$folder_to_index\/?//; # make paths relative.	
		print RVT_INDEX "<tr><td><a href=\"file:$path\" target=\"_blank\">$item_type</a><td>$line</td></tr>\n";
	}
	return 1;
}



sub RVT_index_regular_item {
	
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
		print RVT_ITEM "<tr><td><b>Attachment</b></td><td><a href=\"$string\" target=\"_blank\">", basename($File::Find::name), "</a></td></tr>\n";
	} elsif( $item_depth eq $wanted_depth+1 && $File::Find::name =~ /.*Message00001.html/ )  {
		my $string = $File::Find::name;
		print RVT_META "Attachment: $File::Find::name\n";
		chomp( $string );
		$string =~ s/.*\/([^\/]*\/[^\/]*\/[^\/]*)$/\1/;
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
<HEAD>
	<TITLE>
		$field_values{'Subject'}
	</TITLE>
	<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
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





1;