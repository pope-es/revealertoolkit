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


package RVTbase::RVT_cluster;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_cluster_generateindex
                            &RVT_get_inodefromcluster
                            &RVT_cluster_extract
                            &RVT_cluster_toinode
                            &RVT_cluster_allocationstatus
                        );
       
       
   }


my $RVT_moduleName = "RVT_cluster";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use RVTbase::RVT_tsk;
use Data::Dumper;

sub constructor {
   
   $main::RVT_functions{RVT_cluster_generateindex } = "Creates sort of an index for quick cluster-to-inode\n
                                    resolution. Required fot performing searches.\n
                                    cluster generateindex <disk>";
   $main::RVT_functions{RVT_cluster_toinode } = "Prints all the inodes associated with a cluster\n
                            cluster toinode <cluster> <partition>";
   $main::RVT_functions{RVT_cluster_extract } = "Prints the contents of the cluster\n
                            cluster extract <cluster> <partition>";
   $main::RVT_functions{RVT_cluster_allocationstatus } = "Prints cluster allocation status\n
                                    cluster allocationstatus <cluster> <partition>";
   $main::RVT_functions{RVT_inode_allocationstatus } = "Prints inode allocation status\n
                                    inode allocationstatus <cluster> <partition>";                                    

}



sub RVT_cluster_generateindex {
    # creates the index for cluster-to-inode resolution
    # (ifind could be very slow)
    
    my ( $disk ) = @_;
    
    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
    
    my $ad = RVT_split_diskname($disk);
    my $morguepath = RVT_get_morguepath($disk);
    my $imagepath = RVT_get_imagepath($disk);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $searchespath = "$morguepath/output/searches";
    mkdir $searchespath unless (-e $searchespath);
    if (! -d $searchespath) { print "ERR: there is no path to the morgue/searches!\n\n"; return 0};

    
	# generation for every partition 
	
	## TODO:  to check if the loop exists and image_scanall
	## zero sized files generated if not

	my %parts = %{$main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
    
    foreach my $p ( keys %parts ) {
        open (F, ">$searchespath/cindex-$disk-p$p");
        open (ILS, "ils -e /dev/$parts{$p}{loop} |");
        <ILS>; <ILS>; <ILS>; 
        while (<ILS>) {   
           /^(.+?)\|/;
           my $inode = $1;
           print F "$inode:";
           open (ISTAT, "istat /dev/$parts{$p}{loop} $inode |");
           while ( my $sl = <ISTAT> ) {
                next unless $sl =~ /^[0-9 ]+$/;
                chomp $sl;
                print F " $sl ";
           }
           print F "\n";
        }
        print "\t\tindex for partition $disk-p$p done\n";
    }

    print "\t clusters indexes done\n";
    return 1;
}


sub RVT_get_inodefromcluster {
    # gets the inodes associated with a cluster (or data unit)
    # arguments:
    #   cluster
    #   partition
    # returns an array with the results (one element per inode)
    #print "xx\n\n";
    my ( $cluster, $part ) = @_;
    
    next unless ($cluster =~ /^[0-9\-]+$/);
    $part = $main::RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { print "ERR: that is not a partition\n\n"; return 0; }

    my $ad = RVT_split_diskname($part);
    my $morguepath = RVT_get_morguepath($part);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $searchespath = "$morguepath/output/searches";
    if (! -d $searchespath) { print "ERR: there is no path to the morgue/searches!\n\n"; return 0};        
    
    my @r = `grep ' $cluster ' $searchespath/cindex-$part | cut -d':' -f1  `;
    @r = map { chomp; $_; } @r;
    
    return \@r;
}



sub RVT_cluster_extract {
    # extracts the cluster
    # arguments:
    #   cluster
    #   partition
    
    my ( $cluster, $part ) = @_;

    next unless ($cluster =~ /^[0-9\,]+$/);
    $part = $main::RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { print "ERR: that is not a partition\n\n"; return 0; }
    
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

    $cluster =~ s/,/ /;
    print "--------------------------------------------\n";
    print "$main::RVT_cfg->{tsk_path}/blkcat -o $offset $diskpath $cluster | \n\n";
    open (PA,"$main::RVT_cfg->{tsk_path}/blkcat -o $offset $diskpath $cluster | ") || die "$main::RVT_cfg->{tsk_path}/blkcat NOT FOUND";    
    while ( my $l=<PA> ) { print $l; };    
    close (PA);
}



sub RVT_cluster_toinode {
    # prints the inodes associated with a cluster (or data unit)
    # arguments:
    #   cluster
    #   partition
    
    my ( $cluster, $part ) = @_;
     
    my $r = RVT_get_inodefromcluster ( $cluster,$part );

    print "\ninodes:\n\n" . join ("\n",@{$r}) . "\n\n";
}


sub RVT_cluster_allocationstatus {

    my ($cluster, $part) = @_;
    
    next unless ($cluster =~ /^[0-9\-]+$/);
    $part = $main::RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { print "ERR: $part that is not a partition\n\n"; return 0; }
    
    my $p = RVT_split_diskname( $part );
    
    my $disk = RVT_join_diskname ($p->{case}, $p->{device}, $p->{disk});
    
    print "Cluster $cluster: " . RVT_tsk_blkstat ($disk, $p->{partition}, $cluster) . "\n";
}


sub RVT_inode_allocationstatus {

    my ($inode, $part) = @_;
    
    next unless ($inode =~ /^[0-9\-]+$/);
    $part = $main::RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { print "ERR: $part that is not a partition\n\n"; return 0; }
    
    my $p = RVT_split_diskname( $part );
    
    my $disk = RVT_join_diskname ($p->{case}, $p->{device}, $p->{disk});
    my $r_istat = RVT_tsk_istat ($disk, $p->{partition}, $inode);
    print "inode $inode: " . $r_istat->{allocationStatus} . "\n";
}


1;  

