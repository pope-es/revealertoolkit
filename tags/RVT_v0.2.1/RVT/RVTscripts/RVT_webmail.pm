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


package RVTscripts::RVT_webmail;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_webmail_detection
                        );
       
       
   }


my $RVT_moduleName = "RVT_webmail";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use RVTscripts::RVT_search;
use Data::Dumper;

sub constructor {
   
   $main::RVT_functions{RVT_script_webmail_detection } = "Tries to detect certain types of webmail traces in the disk
 									script webmail detection <disk>";

}




my %RVT_progs = (
	webmails => {
		hotmail => {
			desc => "Hotmail",
			term => "getmsg?msg",
		},
		wanadoo => {
			desc => "Wanadoo",
			term => "mensajes?folder=",
		},
		terra => {
			desc => "Terra",
			term => "terra_inbox_wel.gif,ProxiedItemListMember,ExternalURLProxy",
		},
		yahoo => {
			desc => "Yahoo",
			term => "folderviewmsg,ShowLetter?MsgId=",
		},
		gmail => {
			desc => "Gmail",
			term => "_upro_",
		},
	},
);


sub RVT_script_webmail_detection  {
    # generates a list of the webmail traces present in the image 
    # returns 1 if OK, 0 if errors

    my ( $disk ) = @_;
    
    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
    my $case = RVT_get_casenumber($disk); 
   
   my $morguepath = RVT_get_morguepath($disk);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $stringspath = "$morguepath/output/strings";
	if (! -d "$stringspath" ) { print "ERR: strings are not generated\n\n"; return 0 } ;  
    my $infopath = "$morguepath/output/info";
    mkdir $infopath unless (-e $infopath);
    if (! -d $infopath) { print "ERR: there is no path to the morgue/info!\n\n"; return 0};

    my $searchfile_path = RVT_get_morguepath($case) . '/searches_files';
    if ( ! -d $searchfile_path )  { mkdir $searchfile_path or return 0; }

    open (DEST, ">$infopath/webmails.txt") or die ("ERR: cannot open webmails file for writing");
    my %wm = %{$RVT_progs{webmails}};
    foreach my $w (keys %wm) {
    	print "\t $wm{$w}{desc} webmail detection ... \n";
    	
	    open (BUSQ, ">$searchfile_path/RVT_webmail_$w") or die ("ERR: couldn't create search file");
		print BUSQ "# Search file automaticaly created by RVT\n";
		print BUSQ "# for $wm{$w}{desc} webmail detection\n";
		print BUSQ "# Execute \"script webmail clusters\" for clusters (ibusq) generation\n";
		print BUSQ $wm{$w}{term} ;
	    close (BUSQ);
	    
	    my $r = RVT_script_search_launch ("RVT_webmail_$w", $disk);
	    if (!$r) {  print "ERR:  error launching search\n"; next; }

	    my $f = $wm{$w}{term}; 
	    $f = lc($f);
	    $f =~ s/ /-/g;
        $f = 'busq_' . $f;
	    open (R, "<$morguepath/output/searches/$f") or die "jarl!: $!";    	
		my @f = <R>;
		close R;
		
		print DEST $wm{$w}{desc} . ": " . ($#f+1) . "\n";
		print "\t $wm{$w}{desc} " . ($#f+1) . " times detected\n";
    }

    print "\t webmail detection done\n";
	return 1;	
}




1;  

