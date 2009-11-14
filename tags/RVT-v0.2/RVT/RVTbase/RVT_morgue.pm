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


package RVTbase::RVT_morgue;  

use strict;
#use warnings;
use XML::Simple;
use Date::Manip;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_case_list
                            &RVT_images_list
                            &RVT_losetup_list
                            &RVT_losetup_delete
                            &RVT_losetup_assign
                            &RVT_losetup_recheck
                            &RVT_mount_list
                            &RVT_mount_delete
                            &RVT_mount_assign
                            &RVT_mount_recheck
                            &RVT_images_scanall
                            &RVT_images_loadconfig
                            &RVT_images_partition_table
                            &RVT_images_partition_info
                        );
   }


my $RVT_moduleName = "RVT_morgue";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use RVTbase::RVT_tsk;
use Data::Dumper;

sub constructor {
   
   my @req = ('sudo', 'mount', 'umount');
   
   foreach my $req ( @req ) {
        $main::RVT_requirements{ $req } = `$req -V`;
        next if ($main::RVT_requirements{ $req });
        RVT_log('CRIT', "$req not found");
        die;
   }
   
   $main::RVT_functions{RVT_case_list } = "Cases in the morgue\n\t--size (-s)\twith sizes";
   $main::RVT_functions{RVT_images_list } = "Images in the morgue\n\t--size (-s)\twith sizes";
   $main::RVT_functions{RVT_losetup_list } = "List loop devices and assigned partition (if any)";
   $main::RVT_functions{RVT_losetup_delete } = "RVT_losetup_delete <case>\n
                                 Deassign partitions from loop devices";
   $main::RVT_functions{RVT_losetup_assign } = "RVT_losetup_assign <case> \n
                                Assign partitions to the next free loop device";
   $main::RVT_functions{RVT_losetup_recheck } = "Recheck all loop associations";
   $main::RVT_functions{RVT_mount_list } = "List mounted partitions (if any)";
   $main::RVT_functions{RVT_mount_delete } = "RVT_mount_delete <case>\n
                                 Umount partitions from loop devices";
   $main::RVT_functions{RVT_mount_assign } = "RVT_mount_assign <case> \n
                                Mount partitions to the next free loop device";
   $main::RVT_functions{RVT_mount_recheck } = "Recheck all mount associations";
   $main::RVT_functions{RVT_images_scanall } = "Scan the whole morgue for cases";
   $main::RVT_functions{RVT_images_loadconfig } = "Loads the morgue config from XML file";
   $main::RVT_functions{RVT_images_partition_table } = "List partitions with information from the partition table \n
                                image partition_table <case-device-disk>";
   $main::RVT_functions{RVT_images_partition_info } = "Gets some info from the filesystem of the partition\n
                                image partition info <case-device-disk> <partition>";   

}





#######################################################################
#
#  Morgue management functions
#
#######################################################################




sub RVT_case_list {
   
    my $bsize = shift(@_);
    my $filename;
  
    print "Cases in the morgue: \n";
    for my $morgue ( @{$main::RVT_cfg->{paths}[0]{morgues}} ) { 
	    # lists cases in morgue
	    opendir( MORGUE, $morgue) or RVT_log ('CRIT' , "couldn't open morgue: $!");
	    
	    while (defined(my $f=readdir(MORGUE))) {
		next unless ($f=~/^(\d{6})-(\w+)$/ && -d $morgue . "/" . $f);
		my $case = $1;
		my $code = $2;
		my $size;
		if ($bsize eq '-s' or $bsize eq '--size') { $size = " (" . RVT_du("$morgue/$f") .")"; }
		print "\t$case '$code'$size:\n";
		opendir (CASE, $morgue . "/$f");
		while (defined(my $ff=readdir(CASE))) {
		    print "\t\t$ff\n" if ($ff=~/^$case-\d\d/ && -d $morgue . "/$f/$ff");  }
		closedir(CASE);
	      }
	      closedir( MORGUE );
    }
    print "\n";
}

sub RVT_images_list {

    my $bsize = shift(@_);
    my $filename;
    
    print "Images in the morgue: \n";
    for my $images ( @{$main::RVT_cfg->{paths}[0]{images}} )  {
	    # lists images in morgue
	    opendir( IMAGES, $images) or RVT_log ('CRIT' , "couldn't open morgue: $!");
	    
	    while (defined(my $f=readdir(IMAGES))) {
		next unless ($f=~/^(\d{6})-(\w+)$/ && -d $images . "/" . $f);
		my $case = $1;
		my $code = $2;
		my $size;
		if ($bsize eq '-s' or $bsize eq '--size') { $size = " (" . RVT_du("$images/$f") .")"; }
		print "\t$case '$code'$size:\n";
		opendir (CASE, $images . "/$f");
		while (defined(my $ff=readdir(CASE))) {
		    print "\t\t$ff\n" if ($ff=~/^$case-\d\d-\d\d?\.dd$/ && -e $images . "/$f/$ff");  }
		closedir(CASE);
	    }
	    closedir( MORGUE );
    }
    print "\n";
}


sub RVT_images_partition_table   {
    # takes disk and prints a list of the partitions
    
    my $disk = shift(@_);
    $disk = $main::RVT_level->{tag} unless $disk;

    my $part = RVT_tsk_mmls($disk);

    if (!$part) { RVT_log('ERR', 'Partition expected'); return; }

    print "\n";
    for my $dd ( keys %{$part} ) {
        my $size = int($part->{$dd}{length} * 512 / 1048576) +1 ; # 1024^3
        print "\t$dd:\t$size MB\t" . $part->{$dd}{description} . "\n";
    }
    print "\n";

}


sub RVT_images_partition_info  {
    # takes $disk and $partition
    
    my $partition = shift(@_);

	$partition = $main::RVT_level->{tag} unless $partition;
	
    my $p = RVT_tsk_fsstat ($partition);
    
    if (!$p) { RVT_log('ERR', 'Partition expected'); return; }

    print "\nInfo for partition $partition:\n\n";
    print "Filesystem:\t" . $p->{filesystem};
    print "\nCluster size:\t" . $p->{clustersize};
    print "\nSector size:\t" . $p->{sectorsize};
    print "\nOffset:\t\t" . $p->{offset} . " sectors ( " . ($p->{offset}*$p->{sectorsize}) . " bytes )";
    print "\n\n";
}



sub RVT_losetup_list {

    my @loopdev;
    opendir (DEV, '/dev') or RVT_log('CRIT', "FATAL: couldn't open /dev: $!");
    while (defined(my $d=readdir(DEV))) { push(@loopdev, $d) if ($d=~/^loop\d{1,3}$/ && -b "/dev/$d"); }
    closedir (DEV);
    
    print "Loop devices: \n";
    for my $images ( @{$main::RVT_cfg->{paths}[0]{images}} )  {
	    for my $d (@loopdev) {
		my $r = `sudo losetup /dev/$d 2> /dev/null`;   # TODO glups!
		my $rr = '\/dev\/'.$d.': \S* \(' . $images . '\/\d{6}-\w+\/(\d{6}-\d\d-\d\d?\.dd)\)\D+(\d+)$'; 
		next unless ($r=~/$rr/);
		print "\t$d\t$1\t$2\n";
	    }
    }
}



sub RVT_mount_list {

   print "Mounted partitions: \n";
   open ( MOUNT, 'mount | grep "ro,loop=" |' ) or RVT_log('CRIT', "couldn't execute mount: $!");
   while (my $l=<MOUNT>) {
   	$l=~/.*\/([^\/]+) on .*(loop=\/dev\/loop\d+).+(offset=\d+)/;
	print "\t$1\t$2\t$3\n";
   }
   close MOUNT;
   print "\n";
}



sub RVT_losetup_recheck {

    # loop devices
    my @loopdev;
    opendir (DEV, '/dev') or RVT_log('CRIT', "FATAL: couldn't open /dev: $!");
    while (defined(my $d=readdir(DEV))) { push(@loopdev, $d) if ($d=~/^loop\d{1,3}$/ && -b "/dev/$d"); }
    closedir (DEV);

    # removing losetup data from $main::RVT_cases
    for my $case (keys %{$main::RVT_cases->{case}}) {
       for my $device (keys %{$main::RVT_cases->{case}{$case}{device}}) {
          for my $disk (keys %{$main::RVT_cases->{case}{$case}{device}{$device}{disk}}) {
            for my $partition (keys %{$main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}}) {
                   $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$partition}{loop} = '';
            }
          }
       }
    }
    
    # created losetups
    for my $d (@loopdev) { 
        my $r = `sudo losetup /dev/$d 2> /dev/null`;   # TODO glups!
        #my $imagepath =  $main::RVT_cases->{$case}{imagepath};
        #$imagepath =~ s/\//\\\//g;
        next unless ($r=~/^\/dev\/$d: \S* \(.*\/\d{6}-\w+\/(\d{6})-(\d\d)-(\d\d?)\.dd\)\D+(\d+)/ );
        for my $partition (keys %{$main::RVT_cases->{case}{$1}{device}{$2}{disk}{$3}{partition}}) {
             if ($main::RVT_cases->{case}{$1}{device}{$2}{disk}{$3}{partition}{$partition}{obytes} == $4) {
                $main::RVT_cases->{case}{$1}{device}{$2}{disk}{$3}{partition}{$partition}{loop} = $d;
             } 
        }        
    }

}





sub RVT_losetup_delete  {

    my $object = shift(@_);
    my ($case, $device, $disk, $part);

	RVT_fill_level(\$object);
	return 0 unless ($object);
	my @parts = RVT_exploit_diskname ('partition', $object);
	return 0 unless (@parts);
	
	foreach my $p (@parts) {
        my $r = RVT_split_diskname($p);
        $case = $r->{case};
        $device = $r->{device};
        $disk = $r->{disk};
        $part = $r->{partition};
        
        my @args = ("sudo", "losetup", "-d", 
       "/dev/$main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$part}{loop}", );
        print "\n" . join (" ", @args) . "\n";
        system(@args) == 0 or  RVT_log ('ERR', "losetup failed: $?\n");
    }
    RVT_losetup_recheck;
}



sub RVT_losetup_assign  {

    my $object = shift(@_);
    my ($case, $device, $disk, $part);

	RVT_fill_level(\$object);
	return 0 unless ($object);
	my @parts = RVT_exploit_diskname ('partition', $object);
	return 0 unless (@parts);
	
	foreach my $p (@parts) {
        my $r = RVT_split_diskname($p);
        $case = $r->{case};
        $device = $r->{device};
        $disk = $r->{disk};
        $part = $r->{partition};
        
        my @args = ("sudo", "losetup", "-f", 
        $main::RVT_cases->{case}{$case}{imagepath}."/$case-$main::RVT_cases->{case}{$case}{code}/$case-$device-$disk.dd", 
        "-o $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$part}{obytes}" );
        print "\n" . join (" ", @args) . "\n";
        system(@args) == 0 or  RVT_log ('ERR', "losetup failed: $?");
    }
    RVT_losetup_recheck;
}



sub RVT_mount_delete () {

    my $object = shift(@_);
    my ($case, $device, $disk, $part);

	RVT_fill_level(\$object);
	return 0 unless ($object);
	my @parts = RVT_exploit_diskname ('partition', $object);
	return 0 unless (@parts);
	
	foreach my $p (@parts) {
        my $r = RVT_split_diskname($p);
        $case = $r->{case};
        $device = $r->{device};
        $disk = $r->{disk};
        $part = $r->{partition};
    
        my $pmnt = $main::RVT_cases->{case}{$case}{morguepath}."/$case-" 
            . $main::RVT_cases->{case}{$case}{code} 
            . "/$case-$device-$disk/mnt";  
        my $ppart = "$pmnt/p$part";
        my @args = ("sudo", "umount", $ppart);
        print "\n" . join (" ", @args) . "\n";
        system(@args) == 0 or RVT_log ('ERR', "umount $case-$device-$disk-p$part failed: $?");
    }
    RVT_losetup_recheck;
}




sub RVT_mount_assign () {

    my $object = shift(@_);
    my ($case, $device, $disk, $part);

	RVT_fill_level(\$object);
	return 0 unless ($object);
	my @parts = RVT_exploit_diskname ('partition', $object);
	return 0 unless (@parts);
	
	foreach my $p (@parts) {
        my $r = RVT_split_diskname($p);
        $case = $r->{case};
        $device = $r->{device};
        $disk = $r->{disk};
        $part = $r->{partition};
    
        my $pmnt = $main::RVT_cases->{case}{$case}{morguepath}."/$case-" 
            . $main::RVT_cases->{case}{$case}{code} 
            . "/$case-$device-$disk/mnt";  
    
        if ( ! -d $pmnt ) { mkdir($pmnt) or RVT_log('CRIT' , "couldn't create directory $!"); }
        my $ppart = "$pmnt/p$part"; 
        if (! -d $ppart ) { mkdir ($ppart) or RVT_log('CRIT' , "couldn't create directory $!"); }
        
        my @args = ("sudo", "mount",  
        $main::RVT_cases->{case}{$case}{imagepath}."/$case-$main::RVT_cases->{case}{$case}{code}/$case-$device-$disk.dd",
        $ppart,
        "-o", "ro,loop,iocharset=utf8,offset=$main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$part}{obytes},umask=$main::RVT_cfg->{mount_umask},gid=$main::RVT_cfg->{mount_gid}" );
        print "\n" . join (" ", @args) . "\n";
        system(@args) == 0 or  RVT_log ('ERR', "mount $case-$device-$disk-p$part failed: $?");
    }
    RVT_losetup_recheck;
}


sub RVT_images_loadconfig {

    my $lockFile = $main::RVT_cfg->{morgueInfoXML} . ".lock";
    my $cc = 0;
    while ( -e $lockFile ) { sleep 1; if (++$cc > 5) { RVT_log('CRIT', 'Waited 5 seconds for unlocking of morgue info xml file') } }
    return 0 unless ( -e $main::RVT_cfg->{morgueInfoXML} );

    $main::RVT_cases = {};
    $main::RVT_cases = eval { XMLin( $main::RVT_cfg->{morgueInfoXML}, ForceArray => 1 ) };

    if ($@) {
        RVT_log('ERR', 'failed to import XML morgue configuration');
        return 0;
    };
    
    RVT_log ('INFO', "Morgue XML configuration loaded. Last updated: ".$main::RVT_cases->{thisConfig}[0]{updated});
    RVT_log ('INFO', "Run 'images scanall' command to update");
}


sub RVT_images_scanall {

  my $lockFile = $main::RVT_cfg->{morgueInfoXML} . ".lock";
  my $cc = 0;
  while ( -e $lockFile ) { sleep 1; if (++$cc > 5) { RVT_log('CRIT', 'Waited 5 seconds for unlocking of morgue info xml file') } }
  open (LOCK, ">$lockFile") or die "JARL! could not create lock file";
  close LOCK;

  print "Scanning morgues. Please wait ...\n\n";

  $main::RVT_cases = {};
  $main::RVT_cases->{thisConfig}[0]{updated} = ParseDate ("today");
  for my $images ( @{$main::RVT_cfg->{paths}[0]{images}} )  {

    opendir( IMAGES, $images) or RVT_log ('CRIT', "couldn't open morgue: $!");
     
    while (defined(my $f=readdir(IMAGES))) {
        next unless ($f=~/^(\d{6})-(\w+)$/ && -d $images . "/" . $f);
        my $case = $1;
        my $code = $2;
        $main::RVT_cases->{case}{$case}{code} = $code;
	    $main::RVT_cases->{case}{$case}{imagepath}=$images;
       
        # images
	    opendir (CASE, $images . "/$f") or die "FATAL: jarl $!";
        while (defined(my $img=readdir(CASE))) {
            my $imgpath = $images . "/$f/$img";
            next unless ($img=~/^$case-(\d\d)-(\d\d?)\.dd$/ && -e $imgpath);  
            my $device = $1;
            my $disk = $2;
            
            open(PA,"mmls $imgpath 2>/dev/null|") || RVT_log ('CRIT', "couldn't execute mmls");
            while (my $line=<PA>) {
                if ( $line =~ /Units are in (\d+)-byte sectors/) 
                    { $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{sectorsize}=$1; }
                next unless ( $line =~ /(\d\d):\s*..:..\s*(\d+)\s*\d+\s*(\d+)\s*(.+)$/)  ;  
                my ($pnum, $pstart, $plength, $pdesc) = ($1, $2, $3, $4);
                next if ($pdesc =~ /Extended/);
                $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{type}=$pdesc;
                $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{osects}=$pstart;
                $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{obytes}=
                    $pstart * $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{sectorsize};
                $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{size}=
                    $plength * $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{sectorsize};
                    
                # filesystem information
                
                #print "$case-$device-$disk-p$pnum\n";
                my $fsstat = RVT_tsk_fsstat ("$case-$device-$disk-p$pnum");
                next unless ($fsstat);
                $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{filesystem} = $fsstat->{filesystem};
                $main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{clustersize} = $fsstat->{clustersize};
                
            }
            close(PA);
        }
        closedir(CASE);

	    # morgue
  	    for my $morgue ( @{$main::RVT_cfg->{paths}[0]{morgues}} )  {
	    	next unless ( -d "$morgue/$case-$code" );  
	    	$main::RVT_cases->{case}{$case}{morguepath}=$morgue; 
	    	 
	    }
    }
    closedir( MORGUE ); 
  }
  
  RVT_losetup_recheck;
  
  open (my $XMLFile, ">" . $main::RVT_cfg->{morgueInfoXML}) or RVT_log('CRIT', "could not create XML file");
  XMLout($main::RVT_cases, Rootname => "RVTmorgueInfo", OutputFile => $XMLFile);
  close XMLFile;
  
  unlink($lockFile) or die RVT_log('CRIT', "could not delete lock file");
  
}


1;  

