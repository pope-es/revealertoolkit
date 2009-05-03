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


package RVTscripts::RVT_regripper; 

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_regripper_listmodules
                            &RVT_script_regripper_execmodule
                            &RVT_script_regripper_execallmodules
                        );
   }


my $RVT_moduleName = "RVT_regripper";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use RVTscripts::RVT_timelines;
use Data::Dumper;
use Date::Manip;

sub constructor {
   
   $main::RVT_functions{RVT_script_regripper_listmodules} = 
      "lists all the plugins of RegRipper (rip.pl -l) \n
       script regripper listmodules";
   $main::RVT_functions{RVT_script_regripper_execmodule} = 
      "executes one RegRipper plugin on the partition specified.\n
      the hive type must be specified: takes the last modified one \n
      script regripper execmodule <plugin> <hivetype> <partition>";
   $main::RVT_functions{RVT_script_regripper_execallmodules} = 
      "executes all the RegRipper plugins on all the files that seem\n 
      a registry file. The results are stored at the output/regripper.\n
      If hivetype 'all' is specified, all hivetypes are used\n
      script regripper execmodule <hivetype> <partition>";
   
}


my %rrTypes = { 'sam' => 'SAM$', 
                'system' => 'system$' , 
                'software' => 'software$', 
                'security' => 'security$', 
                'ntuser' => 'NTUSER.DAT$' 
                };

sub RVT_script_regripper_listmodules {

    my @args = ('rip', '-l');
    system(@args) == 0 or print "\nProblem found executing RegRipper (rip.pl -l)\n\n";
    
}


sub RVT_script_regripper_execmodule {
    # execs one regripper module and outputs the result on standard output
    # It looks for the most suitable hive on the partition given
    # (simply, it gets the most recent modified hive)
    #
    # args: $module     (from regripper list)
    #       $hivetype   
    #       $part       (partition)

    my ($module, $hivetype, $part) = @_ ;

    return 0 unless ($rrTypes{$hivetype});

    RVT_fill_level(\$part);
    my $spart = RVT_split_diskname($part);
    return 0 unless ($spart->{partition});
    
    my $disk = RVT_chop_diskname('disk', $part);
 
    my @files = RVT_get_timelinefiles ($rrTypes{$hivetype}, 'm..', $part);
    @files = grep { !/, * / } @files;  # allocated files only
    
    for (my $f=$#files; $f>=0; $f--) {
        my @ff = split(',', $files[$f]);
        my $hivepath = RVT_get_morguepath($disk) . '/mnt/p' . $spart->{partition} . $ff[2];
        my @r = `rip -r "$hivepath" -p $module`;
        next unless @r;
        print "\nfile: $files[$f]\n\n";
        print @r;
        print "\n";
        last unless ($hivetype eq "ntuser");
    } 
}


sub RVT_script_regripper_execallmodules {
    # this command takes *all* the files that look like a hive, 
    # execute all available modules on them, and stores the results
    # in output/regripper folder
    #
    # args: 
    #       $hivetype   
    #       $part       (partition)

    my ($hivetype, $part) = @_ ;

    return 0 unless ($rrTypes{$hivetype} or ($hivetype eq 'all'));
    my @hivetypes;
    if ( $hivetype eq 'all' ) {
        @hivetypes = keys %rrTypes;
    } else {
        @hivetypes = ( $hivetype );
    }

    RVT_fill_level(\$part);
    my $spart = RVT_split_diskname($part);
    return 0 unless ($spart->{partition});
    
    my $disk = RVT_chop_diskname('disk', $part);
    
    my $ofolder = RVT_get_morguepath($disk) . '/output/regripper';
    if ( ! -d $ofolder )  { mkdir ($ofolder) or die "Could not create $ofolder"; }
    
    foreach $hivetype (@hivetypes) {
        my @files = RVT_get_timelinefiles ($rrTypes{$hivetype}, 'm..', $part);
        @files = grep { !/, * / } @files;  # allocated files only
        
        foreach my $f (@files) {
            my @ff = split(',', $f);
            my $hivepath = RVT_get_morguepath($disk) . '/mnt/p' . $spart->{partition} . $ff[2];
            my $opath = RVT_get_morguepath($disk) . '/output/regripper/' . $hivetype . '-' . ParseDate($ff[0]) ;
            my @r = `rip -r "$hivepath" -f $hivetype`;
            next unless @r;
            open (F,">$opath") or die "Could not open $opath";
            print F "$hivepath\n";
            print F @r;
            close F;
            print "regripped: $files[$f]\n";
        } 
    }
}


1;  

