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


package RVTbase::RVT_info;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_info_list
                            &RVT_info_debug_dumprvtcases
                            &RVT_info_debug_dumpmorguexml
                            &RVT_info_debug_dumprvtcfg
                        );
       
       
   }


my $RVT_moduleName = "RVT_info";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use Data::Dumper;
use XML::Simple;

sub constructor {
   
      $main::RVT_functions{RVT_info_list} =  'List the morgues';
      $main::RVT_functions{RVT_info_debug_dumprvtcases} =  'print Dumper($main::RVT_cases)';
      $main::RVT_functions{RVT_info_debug_dumpmorguexml} =  'print XMLout($main::RVT_cases, Rootname => "RVTmorgueInfo");';
      $main::RVT_functions{RVT_info_debug_dumprvtcfg} =  'print Dumper($main::RVT_cfg)';

}


sub RVT_info_list {

   my $size;
   my $bsize = shift(@_);

   print "\n\tList of morgues:\n";
   for my $m (@{$main::RVT_cfg->{paths}[0]{morgues}}) { 
	if ($bsize eq '-s' or $bsize eq '--size') { $size = " (" . RVT_du($m) .")"; }
   	print "\t\t$m $size\n"; 
   }

   print "\n\n\tList of morgues of images:\n";
   for my $m (@{$main::RVT_cfg->{paths}[0]{images}}) { 
	if ($bsize eq '-s' or $bsize eq '--size') { $size = " (" . RVT_du($m) .")"; }
   	print "\t\t$m $size\n"; 
   }

   print "\n";
}

sub RVT_info_debug_dumprvtcases {  print Dumper($main::RVT_cases); print "\n"; }

sub RVT_info_debug_dumpmorguexml { print XMLout($main::RVT_cases, Rootname => "RVTmorgueInfo"); } 

sub RVT_info_debug_dumprvtcfg { print Dumper($main::RVT_cfg); print "\n"; }  

1;  

