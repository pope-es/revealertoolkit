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


package RVTscripts::RVT_mail;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_mail_parsepsts
                        );
       
       
   }


my $RVT_moduleName = "RVT_mail";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use RVTscripts::RVT_files;
use Data::Dumper;

sub constructor {
   
   my $readpst = `readpst -V`;
   
   if (!$readpst) {
        RVT_log ('ERR', 'RVT_mail not loaded (couldn\'t find libpst)');
        return;
   }
   
   $main::RVT_requirements{'readpst'} = $readpst;
   
   $main::RVT_functions{RVT_script_mail_parsepsts } = "Parses all PST's found on the partition using libpst\n
                                                    script mail parsepsts <partition>";
}



sub RVT_script_mail_parsepsts {

    my $part = shift(@_);
    
    $part = RVT_fill_level{$part} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ( 'WARNING' , 'that is not a partition'); return 0; }
    
    my $disk = RVT_chop_diskname('disk', $part);
    my $opath = RVT_get_morguepath($disk) . '/output/mail';
    mkdir $opath unless (-d $opath);
    
    my $sdisk = RVT_split_diskname($part);
    my $repath = RVT_get_morguepath($disk) . '/mnt/p' . $sdisk->{partition};    
    my @pstlist = grep {/$repath/} RVT_get_allocfiles('pst$', $disk);
    
    foreach my $f (@pstlist) {
        my $fpath = RVT_create_folder($opath, 'pst');
        
        mkdir ("$fpath/contents") or die ("ERR: failed to create output directories.");
        open (META, ">$fpath/RVT_metadata.txt") or die ("ERR: failed to create metadata files.");
            print META "Source file: $f\n";
            print META "Parsed by RVT module $RVT_moduleName version $RVT_moduleVersion\n";
        close (META);
        
        $fpath="$fpath/contents";
        my @args = ('readpst', '-S', '-q', '-cv', '-o', $fpath, $f);
        if (system (@args)) {
            RVT_log ('NOTICE', "PST parsed: $f\n");
        } else {
            RVT_log ('ERR', "Error encountered while parsing $f\n");
        }
    }
    
    return 1;
}


1;  

