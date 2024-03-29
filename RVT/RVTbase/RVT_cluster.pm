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
                            &RVT_cluster_extract_raw
                            &RVT_cluster_extract_ascii
                            &RVT_cluster_toinode
                            &RVT_cluster_allocationstatus
                            &RVT_cluster_filename
                            &RVT_get_filenameFromInode
                            &RVT_inode_allocationstatus
                            &RVT_inode_filename
                        );
       
       
   }


my $RVT_moduleName = "RVT_cluster";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use RVTbase::RVT_tsk;
use Data::Dumper;

sub constructor {

   my $grep = `grep -V`;
   
   if (!$grep) {
        RVT_log ('ERR', 'RVT_cluster not loaded (couldn\'t find grep)');
        return;
   }     
   
   $main::RVT_functions{RVT_cluster_generateindex } = "Creates sort of an index for quick cluster-to-inode\n
                                    resolution. Required fot performing searches.\n
                                    cluster generateindex <disk>";
   $main::RVT_functions{RVT_cluster_toinode } = "Prints all the inodes associated with a cluster\n
                            cluster toinode <cluster> <partition>";
   $main::RVT_functions{RVT_cluster_extract_raw } = "Prints the contents of the cluster\n
                            cluster extract <cluster> <partition>";
   $main::RVT_functions{RVT_cluster_extract_ascii } = "Prints the contents of the cluster\n
                            but non-ascii character are translated to '.'\n
                            cluster extract <cluster> <partition>";                            
   $main::RVT_functions{RVT_cluster_allocationstatus } = "Prints cluster allocation status\n
                                    cluster allocationstatus <cluster> <partition>";
   $main::RVT_functions{RVT_cluster_filename } = "Prints filenames associated with cluster\n
                                    cluster filename <inode> <partition>";                                    
   $main::RVT_functions{RVT_inode_allocationstatus } = "Prints inode allocation status\n
                                    inode allocationstatus <inode> <partition>";                                    
   $main::RVT_functions{RVT_inode_filename } = "Prints filenames associated with inode\n
                                    inode filename <inode> <partition>"; 
}



sub RVT_cluster_generateindex {
    # creates the index for cluster-to-inode resolution
    # (ifind could be very slow)
    
    my ( $disk ) = @_;
    
    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log ('ERR', 'that is not a disk'); return 0; }
    
    my $ad = RVT_split_diskname($disk);
    my $morguepath = RVT_get_morguepath($disk);
    my $imagepath = RVT_get_imagepath($disk);
    if (! $morguepath) { RVT_log ('ERR', 'there is no path to the morgue!'); return 0};

    my $searchespath = "$morguepath/output/searches";
    mkdir $searchespath unless (-e $searchespath);
    if (! -d $searchespath) { RVT_log ('ERR', 'there is no path to the morgue/searches!'); return 0};

    
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
        RVT_log ('NOTICE', "index for partition $disk-p$p done");
    }

    RVT_log ('NOTICE', '\t clusters indexes done');
    return 1;
}


sub RVT_get_inodefromcluster {
    # gets the inodes associated with a cluster (or data unit)
    # arguments:
    #   cluster
    #   partition
    # returns an array with the results (one element per inode)

    my ( $cluster, $part ) = @_;
    
    next unless ($cluster =~ /^[0-9\-]+$/);
    $part = $main::RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log ('ERR', 'that is not a partition'); return 0; }

    my $ad = RVT_split_diskname($part);
    my $morguepath = RVT_get_morguepath($part);
    if (! $morguepath) { RVT_log ('ERR', 'there is no path to the morgue!'); return 0};

    my $searchespath = "$morguepath/output/searches";
    if (! -d $searchespath) { RVT_log ('ERR', 'there is no path to the morgue/searches!'); return 0};        
    
    my @r;
    @r = `grep ' $cluster ' $searchespath/cindex-$part | cut -d':' -f1  `;
    @r = map { chomp; $_; } @r;
    
    return \@r;
}


sub RVT_get_cluster {
    # extracts the cluster and return it in an array
    # arguments:
    #   cluster
    #   partition
    
    my ( $cluster, $part ) = @_;
    my @results;

    return unless ($cluster =~ /^[0-9\,]+$/);
    $cluster =~ s/,/ /;
    if (RVT_check_format($part) ne 'partition') { RVT_log( 'ERR', 'that is not a partition'); return 0; }
    
    my $disk = RVT_join_diskname ( 
    		RVT_get_casenumber($part),
    		RVT_get_devicenumber($part),
    		RVT_get_disknumber($part)
    		);
    $part = RVT_get_partitionnumber($part);
        
    my $diskpath = RVT_get_imagepath($disk);
    return 0 unless ($diskpath);
    
    my $p = RVT_tsk_mmls($disk);
    return 0 unless ($p->{p});
    my $offset = $p->{p}{$part}{offset};

    $cluster =~ s/,/ /;
    open (PA,"$main::RVT_cfg->{tsk_path}/blkcat -o $offset $diskpath $cluster | ") || RVT_log ('CRIT', 'Couldn\'t execute blkcat');    
    while ( my $l=<PA> ) { push (@results, $l); };    
    close (PA);
    
    return @results;
}


sub RVT_get_filenameFromInode {

	my ($inode, $part) = @_;

    next unless ($inode =~ /^[0-9\-]+$/);
    $part = $main::RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log('ERR', "$part that is not a partition\n\n"); return 0; }
    
    my $p = RVT_split_diskname( $part );	
	
	my $disk = RVT_join_diskname ($p->{case}, $p->{device}, $p->{disk});
    my $r_ffind = RVT_tsk_ffind ($disk, $p->{partition}, $inode);
    
    return $r_ffind;
}



sub RVT_cluster_extract_raw {
    # extracts the cluster in raw format, that is, without formating, except
    # what your console is going to introduce
    # arguments:
    #   cluster
    #   partition
    
    my ( $cluster, $part ) = @_;
    $part = $main::RVT_level->{tag} unless $part;
    my @results = RVT_get_cluster ($cluster, $part);
    return unless @results;

    print "--------------------------------------------\n";
    print "$part, $cluster \n\n";
    print @results;   
    print "\n\n";

}


sub RVT_cluster_extract_ascii {
    # extracts the cluster, but only ascii values. Other are translated to '.'
    # Lines are 75 character long.
    # arguments:
    #   cluster
    #   partition
    
    my $n = '75';
    my ( $cluster, $part ) = @_;
    $part = $main::RVT_level->{tag} unless $part;    
    my @results = RVT_get_cluster ($cluster, $part);
    return unless @results;

    print "--------------------------------------------\n";
    print "$part, $cluster \n\n";
 
    @results = map {s/[\x00-\x09,\x0B-\x1F,\x7F-\xFF]/./g; $_;} @results;
    foreach my $l (@results) {
        while ( $l =~ /.{1,$n}/g ) { print "$&\n"; }
    }
    print "\n\n";
    
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
    if (RVT_check_format($part) ne 'partition') { RVT_log('ERR', "$part that is not a partition\n\n"); return 0; }
    
    my $p = RVT_split_diskname( $part );
    
    my $disk = RVT_join_diskname ($p->{case}, $p->{device}, $p->{disk});
    
    print "Cluster $cluster: " . RVT_tsk_blkstat ($disk, $p->{partition}, $cluster) . "\n";
}

sub RVT_cluster_filename {

    my ($cluster, $part) = @_;
    
    next unless ($cluster =~ /^[0-9\-]+$/);
    $part = $main::RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log('ERR', "$part that is not a partition\n\n"); return 0; }
    
    my $p = RVT_split_diskname( $part );
    
    my $disk = RVT_join_diskname ($p->{case}, $p->{device}, $p->{disk});
    
    my $i = RVT_get_inodefromcluster ( $cluster,$part );
    
    my $inode;
    foreach $inode (@{$i}) {
    	print "$inode: " . join("\n", @{RVT_get_filenameFromInode($inode, $part)}) . "\n";
    }

    print "\n";
}


sub RVT_inode_allocationstatus {

    my ($inode, $part) = @_;
    
    next unless ($inode =~ /^[0-9\-]+$/);
    $part = $main::RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { RVT_log('ERR', "$part that is not a partition\n\n"); return 0; }
    
    my $p = RVT_split_diskname( $part );
    
    my $disk = RVT_join_diskname ($p->{case}, $p->{device}, $p->{disk});
    my $r_istat = RVT_tsk_istat ($disk, $p->{partition}, $inode);
    print "inode $inode: " . $r_istat->{allocationStatus} . "\n";
}



sub RVT_inode_filename {

	my ($inode, $part) = @_;

	my $r = RVT_get_filenameFromInode($inode, $part);
    print join('\n',@{$r}) . "\n";
}


1;  

