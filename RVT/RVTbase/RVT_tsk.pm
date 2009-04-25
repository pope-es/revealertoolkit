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


package RVTbase::RVT_tsk;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_tsk_mmls
                            &RVT_tsk_fsstat
                            &RVT_tsk_blkstat
                            &RVT_tsk_istat
                        );
       
       
   }


my $RVT_moduleName = "RVT_tsk";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use Data::Dumper;

sub constructor {
   

}


#######################################################################
#
#  The SleuthKit functions
#
#######################################################################


sub RVT_tsk_mmls ($) {
    # takes a disk
    # returns a reference   $results->{dd} 
    #                                {description}
    #                                {offset}
    #                                {length}
    #   where dd is the partition number as mmls returns it

    my $disk = shift;
    my $diskpath = RVT_get_imagepath($disk);
    return 0 unless ($diskpath);
    my $results;
    
    open(MMLS,"$main::RVT_cfg->{tsk_path}/mmls $diskpath 2>/dev/null|") || die "$main::RVT_cfg->{tsk_path}/mmls NOT FOUND";
	
	while ( my $l = <MMLS> ) {
	    chomp($l);
	    next unless ( $l =~ /^..:\s*0+.*/ && $l !~ /Extended/ );
	    $l =~ /([0-9]{1,2}):\s*..:..\s*([0-9]*)\s*([0-9]*)\s*([0-9]*)\s*(.*)$/;
	    $results->{$1}{description} = $5;
	    $results->{$1}{offset} = $2;
	    $results->{$1}{length} = $4;
	}

    close(MMLS);

    return $results if ($results);
    
    open (MMLS,"$main::RVT_cfg->{tsk_path}/fsstat $diskpath 2> /dev/null |") || die "$main::RVT_cfg->{tsk_path}/fsstat NOT FOUND";
    
    while ( my $l  = <MMLS> ) {
        chomp ($l);
        next unless ( $l =~ /File System Type Label: (.*)$/ );
        $results->{0}{description} = $1;
        $results->{0}{offset} = 0;
        close (MMLS);
        return $results;
    }
    
    return 0;
}


sub RVT_tsk_fsstat ($) {
    # takes a partition and gives, from tsk's fsstat:
    #   - sector size
    #   - cluster size
    #   - filesystem type

    my $part = shift(@_);
    
    my $disk = RVT_join_diskname ( 
    		RVT_get_casenumber($part),
    		RVT_get_devicenumber($part),
    		RVT_get_disknumber($part)
    		);
    $part = RVT_get_partitionnumber($part);
    
    my $diskpath = RVT_get_imagepath($disk);
    return 0 unless ($diskpath);
    
    my $p = RVT_tsk_mmls($disk);
    return 0 unless ($p);
    my $offset = $p->{$part}{offset};
    
    #print  "$RVT_cfg->{tsk_path}/fsstat -o $offset $diskpath  2> /dev/null | \n";
    open (FSSTAT,"$main::RVT_cfg->{tsk_path}/fsstat -o $offset $diskpath  2> /dev/null |") || die "$main::RVT_cfg->{tsk_path}/fsstat NOT FOUND";
    
    my $results;
    $results->{partition} = $part;
    $results->{offset} = $offset;
    while ( my $l  = <FSSTAT> ) {
        chomp ($l);
        
        SWITCH: {
        
            $l=~/^File System Type: (.*)$/  && do { $results->{filesystem} = $1; last SWITCH; };
            $l=~/^Sector Size: (.*)$/       && do { $results->{sectorsize} = $1; last SWITCH; };
	        $l=~/^Cluster Size: (.*)$/      && do { $results->{clustersize} = $1; last SWITCH; };
	        $l=~/^Version: (.*)$/           && do { $results->{version} = $1; last SWITCH; };
        }
    }  
    
    close (FSSTAT);
    
    ## in TSK, in FAT filesystems, data units are considered as disk units
    ## See TSK documentation for more information
    ## http://wiki.sleuthkit.org/index.php?title=FAT_Implementation_Notes
    if ( $results->{filesystem} =~ /FAT/ ) {
        $results->{clustersize} = $results->{sectorsize};
    }
    
    return $results;
}


sub RVT_tsk_blkstat ($$$) {
    # takes a disk, a partition and a dataunit, 
    # and gives the allocation status
    
    my ( $disk,$part,$du ) = @_;
    
    my $diskpath = RVT_get_imagepath($disk);
    return 0 unless ($diskpath);
    
    my $p = RVT_tsk_mmls($disk);
    return 0 unless ($p);
    my $offset = $p->{$part}{offset};

    open (PA,"$main::RVT_cfg->{tsk_path}/blkstat -o $offset $diskpath $du | grep Allocated |") || die "$main::RVT_cfg->{tsk_path}/blkstat NOT FOUND";    
    my $allocation = <PA>; 
    chomp $allocation;
    close (PA);
    
    return $allocation;
}


sub RVT_tsk_istat ($$$) {
    # takes a disk, a partition and an inode, 
    # and gives information
    
    my ( $disk,$part,$inode ) = @_;
    
    my $diskpath = RVT_get_imagepath($disk);
    return 0 unless ($diskpath);
    
    my $p = RVT_tsk_mmls($disk);
    return 0 unless ($p);
    my $offset = $p->{$part}{offset};

    open (PA,"$main::RVT_cfg->{tsk_path}/istat -o $offset $diskpath $inode | ") || die "$main::RVT_cfg->{tsk_path}/istat NOT FOUND";    
    my @istatOutput = <PA>;
    close (PA);
    
    my $results;
    
    my @rr = grep { /Allocated/ } @istatOutput;
    @rr = map { chomp; $_; } @rr;
    $results->{allocationStatus} = $rr[0];
    
    return $results;
}


1;  

