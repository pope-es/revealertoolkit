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


package RVTscripts::RVT_software;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_software_detection
                        );
       
       
   }


my $RVT_moduleName = "RVT_software";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use Data::Dumper;

sub constructor {
   
   $main::RVT_functions{RVT_script_software_detection } = "Tries to detect certain types of software in the disk
 									script softwarelist detection <disk>";

}




my %RVT_progs = (
	web => {
        	firefox => { 
			desc => "Mozilla Firefox",
			term => "firefox.exe",
		},
        	ie => {
			desc => "Internet Explorer",
			term => "iexplore.exe",
		},
		opera => {
			desc => "Opera",
			term => "opera.exe",
		},
		mozilla => {
			desc => "Mozilla Suite",
			term => "mozilla.exe",
		},
		aol => {
			desc => "AOL Explorer",
			term => "AOLExplorer.exe",
		},
		netscape => {
			desc => "Netscape Browser",
			term => "netscape",
		},
	},
	im => {
		messenger => {
			desc => "MSN Messenger",
			term => "msnmsgr.exe",
		},
		winmsn => {
			desc => "Windows Messenger",
			term => "msmsgs.exe",
		},
		skype => {
			desc => "Skype",
			term => "skype.exe",
			ext => "dbb",
		},
		icq => {
			desc => "ICQ",
			term => "icq",
		},
		yahoomsn => {
			desc => "Yahoo Messenger",
			term => "YahooMessenger.exe",
		},
		aim => {
			desc => "AIM",
			term => "aim.exe",
		},
		gaim => {
			desc => "GAIM",
			term => "gaim",
		},
		talk => {
			desc => "Google Talk",
			term => "googletalk",
		},
	},
	correo => {
		oexpress => {
			desc => "Outlook Express",
			term => "msimn.exe",
		},
		outlook => {
			desc => "MS Outlook",
			term => "outlook.exe",
		},
		notes => {
			desc => "Lotus Notes",
			term => "notes.exe",
		},
		gw => {
			desc => "GroupWise",
			term => "GroupWise",
		},
		mozilla => {
			desc => "Mozilla Suite",
			term => "Mozilla.exe",
		},
		eudora => {
			desc => "Eudora",
			term => "Eudora.exe",
		},
		thunderbird => {
			desc => "Mozilla Thunderbird",
			term => "thunderbird.exe",
		},
		evolution => {
			desc => "Evolution",
			term => "evolution.exe",
		},
	},
	p2p => {
		emule => {
			desc => "eMule",
			term => "emule.exe",
		},
		edk => {
			desc => "eDonkey",
			term => "edonkey.exe",
		},
		overnet => {
			desc => "Overnet",
			term => "overnet.exe",
		},
		bt => {
			desc => "BitTorrent",
			term => "bittorrent.exe",
		},
		kazaa => {
			desc => "Kazaa Lite",
			term => "kazaa",
		},
		napster => {
			desc => "Napster",
			term => "napster",
		},
		morpheus => {
			desc => "Morpheus",
			term => "morpheus",
		},
		imesh => {
			desc => "iMesh",
			term => "imesh.exe",
		},
	},
	grabacion => {
		clonecd => {
			desc => "Clone CD",
			term => "CloneCD.exe",
		},
		clonedvd => {
			desc => "Clone DVD",
			term => "CloneDVD2.exe,CloneDVD.exe" ,
		},
		nero => {
			desc => "Nero Burning Rom",
			term => "nero.exe",
		},
		alcohol => {
			desc => "Alcohol 120%",
			term => "alcohol",
		},
		cdbxp => {
			desc => "CDBurnerXP",
			term => "cdbxp.exe",
		},
	},
	dispositivos => {
		ipaq => {
			desc => "Active Sync (iPaq)",
			term => "ActiveSync",
		},
		pam => {
			desc => "Hot Sync (Palm)",
			term => "HotSync",
		},
		ipod => {
			desc => "iPod Service",
			term => "iPodService.exe",
		},
	},
	irc => {
		mirc => {
			desc => "mIRC",
			term => "mirc.exe",
		},
	},

);		
	


sub RVT_script_software_detection  {
    # generates a list of the software present in the image 
    # returns 1 if OK, 0 if errors

    my ( $disk ) = @_;
    
    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
    
    my $morguepath = RVT_get_morguepath($disk);
    my $imagepath = RVT_get_imagepath($disk);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $timelinespath = "$morguepath/output/timelines";
	if (! -d "$timelinespath" ) { print "ERR: timelines are not generated\n\n"; return 0 } ;  
    my $infopath = "$morguepath/output/info";
    mkdir $infopath unless (-e $infopath);
    if (! -d $infopath) { print "ERR: there is no path to the morgue/info!\n\n"; return 0};

    opendir (DIR, "$timelinespath") or die ("ERR: timelines path not readable");
    my @tlfiles = grep { /^(timeline|itimeline-\d\d)\.csv$/ } readdir(DIR);
    close DIR;
    if (! @tlfiles) { print "ERR: timelines are not generated\n\n"; return 0; }
    
    open (DEST, ">$infopath/programs.txt") or die ("ERR: cannot open programs file for writing");
    
	# generation for every partition 

	for my $i (keys %RVT_progs) {
		next if ($i =~ /webmails/ );
		my $aux=uc("$i");
		print "\n$aux\n\n";
		for my $j (keys %{$RVT_progs{$i}}) {
			my $res=0;
			print "Trying: $RVT_progs{$i}{$j}{'desc'}";
			
			my $term=$RVT_progs{$i}{$j}{'term'};
			$term=~y/,/|/;
			TLFILES: foreach my $t (@tlfiles) { 
				open (F,"$timelinespath/$t");
				while ( my $line=<F> ) { 
					my @lin = split(",",$line);
					if ( $lin[7] =~ /$term/i ) {
						$res=1;
						close (F);
						last TLFILES; 
					}
				}
				close (F);
			}
			
			if ($res) {
				print "  [Found]\n";
				print DEST "$aux: $RVT_progs{$i}{$j}{'desc'} [Found]\n";
				#push(@prog_found, $j);
			} else {
				print "\n";
			}
		}
	}

	close DEST;

    print "\t software detection done\n";
	return 1;
}





1;  

