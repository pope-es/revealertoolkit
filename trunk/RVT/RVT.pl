#!/usr/bin/perl
#
#  Revealer Tools Shell
#
#    Copyright (C) 2008 Jose Navarro a.k.a. Dervitx
#
#    Acknowledgements:
#     - INCIDE (Investigacion Digital S.L., www.incide.es)
#       where developers and testers work
#     - Manu Ginés aka xkulio 
#       creator of the original Chanchullos Revealer
#     - Generalitat de Catalunya
#       for partial funding of the project
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


use Data::Dumper;
use Getopt::Long;


my $RVT_version = '0.1.1';

GetOptions(
        "batch:s"				=> \$RVT_batchmode,
        "shell"				=> \$RVT_shellmode 
        );

if (defined($RVT_batchmode) and !$RVT_batchmode) { $RVT_batchmode = '-'; }
if (!$RVT_batchmode and !$RVT_shellmode) { $RVT_shellmode = 1; }


#######################################################################
#
#  general variables
#
#######################################################################

my $RVT_paths = {
    morgues => ['/media/morgue', '/media/datos']    ,
    images => ['/media/morgue/imagenes', '/media/datos/imagenes']  ,
    tmp => '/tmp'
};

my $RVT_tsk_path='/usr/bin';

# mount options
my $RVT_umask = '007';
my $RVT_gid = '1010';

my $RVT_loglevel = '0';   # logs everything

my $RVT_level;   		# current case, device, disk or partition
						# see structure details at RVT_set_level function


# $RVT_cases->{100xxx}
#               {code}
#		        {imagepath}
#		        {morguepath}
#               {device}{}
#                       {code}
#                       {disk}{}
#                            {sectorsize}
#                            {partition}{}
#                                   {type}
#                                   {osects}  offset in sectors
#                                   {obytes}  offset in bytes
#                                   {size}
#                                   {loop}
#									{clustersize}

my $RVT_cases;   

my %RVT_functions = (
 'RVT_test' => "test",
 
 'RVT_case_list' => "Cases in the morgue\n\t--size (-s)\twith sizes",
 
 
 'RVT_images_list' => "Images in the morgue\n\t--size (-s)\twith sizes",
 'RVT_losetup_list' => "List loop devices and assigned partition (if any)",
 'RVT_losetup_delete' => "RVT_losetup_delete <case>\n
                                 Deassign partitions from loop devices",
 'RVT_losetup_assign' => "RVT_losetup_assign <case> \n
                                Assign partitions to the next free loop device",
 'RVT_losetup_recheck' => 'Recheck all loop associations',
 'RVT_mount_list' => "List mounted partitions (if any)",
 'RVT_mount_delete' => "RVT_mount_delete <case>\n
                                 Umount partitions from loop devices",
 'RVT_mount_assign' => "RVT_mount_assign <case> \n
                                Mount partitions to the next free loop device",
 'RVT_mount_recheck' => 'Recheck all mount associations',
 
 'RVT_images_scanall' => 'Scan the whole morgue for cases',
 
 'RVT_info_list' => 'List the morgues',
 
 'RVT_set_level' => 'Sets working level a case, device, disk or partition',
 
 'RVT_cluster_generateindex' => "Creates sort of an index for quick cluster-to-inode\n
                                    resolution. Required fot performing searches.",
 
 'RVT_cluster_toinode' => "Prints all the inodes associated with a cluster\n
                            cluster toinode <cluster> <partition>",
 
 'RVT_cluster_allocationstatus' => "Prints cluster allocation status\n
                                    cluster allocationstatus <cluster> <partition>", 
 
 'RVT_script_search_quickcount' => "Launch a quick search in a case or in an image \n
                                script search quickcount <name:regular expression>  <image> ",
 'RVT_script_search_launch' => "Launch a search in a case or in an image \n
                                script search launch <search file> <image or case> <image or case> ...",
 'RVT_script_search_clusterlist' => "Builds a list of clusters and file paths that matches a previous\n
                                    search \n
                                    script search clusterlist <search file> <image>",                               
 'RVT_script_search_clusters' => "Extract the clusters matched in a previous search\n
                                script search clusters <search file> <image>", 
 'RVT_script_search_file_edit' => "Invokes VIM in order to create or edit a new file with searches\n
                                script search file edit <case> <file name>",
 'RVT_script_search_file_list' => "Lists all the files with searches\n
                                script search file edit <case>",
 'RVT_script_search_file_delete' => "delete a file with searches\n
                                script search file edit <case> <file name>", 
 'RVT_script_search_file_show' => "shows the content of a file with searches\n
                                script search file edit <case> <file name>",                                 
 'RVT_images_partition_table' => "List partitions with information from the partition table \n
                                image partition_table <case-device-disk>",
 'RVT_images_partition_info' => "Gets some info from the filesystem of the partition\n
                                image partition info <case-device-disk> <partition>", 
 'RVT_script_strings_generate' => "Generates strings for all partitions of a disk \n
 									script strings generate <disk>",
 'RVT_script_timelines_generate' => "Generates timelines for all partitions of a disk \n
 									script timelines generate <disk>",
 'RVT_script_software_detection' => "Tries to detect certain types of software in the disk
 									script softwarelist detection <disk>",
 'RVT_script_webmail_detection' => "Tries to detect certain types of webmail traces in the disk
 									script webmail detection <disk>",
 );
		
	

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
		
		
#######################################################################
#
#  main
#
#######################################################################		
		
		
print "Scanning morgues. Please wait ...\n\n";
RVT_log ('ACT', 'Iniciando RVT (v$RVT_version)');

RVT_images_scanall();
RVT_shell(); 
exit;




#######################################################################
#
#  general functions
#
#######################################################################


sub RVT_test {

    print "args: " . join(',',@_) . "\n";

}

my $log_fd;  # static local vars in perl??
sub RVT_log {
	# logs RVT activity/Users/jose/Desktop/scripts/plot_bars.pl
	
	my $type = shift(@_);
	if (!grep(/$type/, ('ERR', 'WRN', 'ACT', 'INF'))) { return; };
	my $message = shift(@_);
	chomp ($message);
	
	unless ($log_fd) {
		open ($log_fd, '>RVT.log') or die "FATAL: $!";
	}
	
	my @tt = caller(1);	
	print $log_fd gmtime(time) ." GMT, $type, $tt[3], $message \n";
}



sub RVT_du {

   my $path = shift(@_);

   my $r = `du -sh $path`;   # glups!
   my @r = split('\s+',$r);

   return $r[0];
}


sub RVT_charge_file ($$) {
   # receives a reference to an array, and a path to a filename
   # then, reads the contents of the file into de array
   # but removes all the lines that begin with '\s+#'
   # returns 1 if OK, 0 if errors

    my ($filename, $array) = @_;

    open (FILE, $filename) or return 0;
    @{$array} = grep {!/^\s+#/} <FILE>;
    return 1;

};



sub RVT_set_level ($) {
        my $new = shift(@_);
        if (!$new) {
                $RVT_level = {};
                return 1;
        }

        my $new_format = RVT_check_format($new);
        if (!$new_format or $new_format eq "case code") {
                $new_format = RVT_check_format($RVT_level->{tag} .'-'. $new);
                $new = $RVT_level->{tag} .'-'. $new;
        }
        if (!$new_format or $new_format eq "case code") { return 0; }

        $RVT_level->{tag}       = $new;
        $RVT_level->{type}      = $new_format;
        $RVT_level->{case}      = RVT_get_casenumber ($new);
        $RVT_level->{device}    = RVT_get_devicenumber ($new);
        $RVT_level->{disk}      = RVT_get_disknumber ($new);
        $RVT_level->{partition} = RVT_get_partitionnumber ($new);

        print "\n new format: $RVT_level->{type}\n";
        return 1;
}



sub RVT_get_casenumber ($) {
    # takes a case number, case code, device, disk or partition
    # checks the format of the case number or
    # reverse-resolves the case code
    # and returns the case number
    # return 0 in other case
    
    my $value = shift;
    if ($value =~ /^(\d{6})/) { 
        $value = $1; 
        return $value if ($RVT_cases->{$value});
        return 0;
    }
    
    for ( keys %{$RVT_cases} ) { if ($RVT_cases->{$_}{code} eq $value) {return $_;} }
    
    return 0;
}

sub RVT_get_devicenumber ($) {
    # takes  100ccc-DD-... format and returns DD
    # also takes  casecode-devicecode-...
    
    my $value = shift;
    my ($c, $d) = split('-', $value);
    $c = RVT_get_casenumber($c);
    
    if ($d and ($d !~ /\d\d/)) {
        # maybe is a code, so let's resolve it
        
        for ( keys %{$RVT_cases->{$c}{device}} ) {
            if ( $RVT_cases->{$c}{device}{$_}{code} eq $d ) {$d = $_;}
        }
    }
    
    $value = join ('-', $c, $d);
    $value =~ /^\d{6}-(\d{2})/;
    return $1 if ($1);
    return 0;
}

sub RVT_get_disknumber ($) {
    # takes  100ccc-DD-dd format and returns dd
    # also takes casecode-devicecode-dd...
    
    my $value = shift;
    my ($c, $d, $disk) = split('-', $value);
    $c = RVT_get_casenumber($c);
    $d = RVT_get_devicenumber("$c-$d");
    
    $value = join ('-', $c, $d, $disk);
    $value =~ /^\d{6}-\d{2}-(\d{1,2})/;
    return $1 if ($1);
    return 0;
}

sub RVT_get_partitionnumber ($) {
    # guess ...
    
    my $value = shift;
    my ($c, $d, $disk, $part) = split('-', $value);
    $c = RVT_get_casenumber($c);
    $d = RVT_get_devicenumber("$c-$d");
    
    $value = join ('-', $c, $d, $disk, $part);
    $value =~ /^\d{6}-\d{2}-\d{1,2}-p(\d{2})/;
    return $1 if ($1);
    return 0;
}

sub RVT_split_diskname ($) {
    # takes 100ccc-DD-dd-pPP format and returns an array:
    #   (100ccc,DD,dd,PP)
    # accepts '100ccc' and '100ccc-DD' and '100ccc-DD-dd' and '100ccc-DD-dd-pPP'
    
    my $d = shift;
    my $r; 
    $r = {
    		    case   => 	RVT_get_casenumber($d), 
                device => 	RVT_get_devicenumber($d),
                disk   => 	RVT_get_disknumber($d),
                partition => 	RVT_get_partitionnumber($d)
    };

    
    return $r;
}

sub RVT_join_diskname ($$$) {
    # takes 100ccc, DD and dd and returns the string '100ccc-DD-dd'
    # in fact, it does not check arguments' syntaxis, so:
    # takes x, y and z and returns "x-y-z", like a join('-')
    
    return join('-', @_);
}

sub RVT_expand_object ($) {
    # takes a image object (case, device or disk) and returns a variable
    # with this structure
    #  $r->{case}{}{device}{}{disk}{}   like $RVT_cases

    my $v = shift;
    my $case;
    my $r;

    # if there is not a case, return 0
    my $v_split = RVT_split_diskname($v);
    return 0 unless $v_split->{case};
    $case = $v_split->{case};

    # fills devices
    if ($v_split->{device}) {
        $r->{$case}{device}{$v_split->{device}}{v} = 1;
    } else {
        foreach my $dev ( keys %{$RVT_cases->{$case}{device}} ) {
            $r->{$case}{device}{$dev}{v} = 1;
        }
    }
    
    # fills disks
    if ($v_split->{disk} and $v_split->{device}) {
        $r->{$case}{device}{$v_split->{device}}{disk}{$v_split->{disk}} = 1;
    } else {
        foreach my $dev ( keys %{$r->{$case}{device}} ) {
            foreach my $disk ( keys %{$RVT_cases->{$case}{device}{$dev}{disk}} ) {
                $r->{$case}{device}{$dev}{disk}{$disk} = 1;
            }           
        }
    }

    return $r;
}




sub RVT_get_imagelist ($) {
    # takes a case number
    # and returns a list of images in the morgue in that case

    my $case = shift;
    my @result;
    
    foreach my $dev ( keys %{$RVT_cases->{$case}{device}} ) {
        for ( keys %{$RVT_cases->{$case}{device}{$dev}{disk}} ) {
            push (@result, $_);
        }
    }
    
    return @result;
}

sub RVT_check_format ($)  {
    # checks the format of $. Returns:
    # 'case number' 100258
    # 'case code'   nova
    # 'device'      100258-01
    # 'disk'        100258-01-1
    # 'partition'   100258-01-1-p01

    my $thing = shift;
    
    return 'case number'    if $thing =~ /^\d{6}$/;
    return 'device'         if $thing =~ /^\d{6}-\d{2}$/;
    return 'disk'           if $thing =~ /^\d{6}-\d{2}-\d{1,2}$/;
    return 'partition'      if $thing =~ /^\d{6}-\d{2}-\d{1,2}-p\d{2}$/;
    return 'case code'      if $thing =~ /^[a-z ]+$/;
}


sub RVT_get_morguepath ($) {
    # checks if a case or disk is in the morgue
    # returns the path if OK, 0 if not present or error
    
    my $thing = shift;    
    my $type = RVT_check_format($thing);
    my $case = RVT_get_casenumber($thing);
    my $device = RVT_get_devicenumber($thing);
    my $disk = RVT_get_disknumber($thing);
    $disk = RVT_join_diskname ($case, $device, $disk);
    return 0 if (!$case);
 
    if ($type eq 'case number' or $type eq 'case code') {
        for my $morgue ( @{$RVT_paths->{morgues}} ) { 
            return "$morgue/$case-" . $RVT_cases->{$case}{code} 
                if (-d "$morgue/$case-" . $RVT_cases->{$case}{code});
        }
    }
    
    if ($disk) {
        for my $morgue ( @{$RVT_paths->{morgues}} ) { 
            return "$morgue/$case-" . $RVT_cases->{$case}{code} . "/$disk" 
                if (-d "$morgue/$case-" . $RVT_cases->{$case}{code} . "/$disk");
        }
    }    
    
    return 0;
}        


sub RVT_get_imagepath ($) {
    # checks if a case or disk has image path in the morgue
    # returns the path if OK, 0 if not present or error
    
    my $thing = shift;
    my $type = RVT_check_format($thing);
    my $case = RVT_get_casenumber($thing);
    my $device = RVT_get_devicenumber($thing);
    my $disk = RVT_get_disknumber($thing);
    $disk = RVT_join_diskname ($case, $device, $disk);
    return 0 if (!$case);
 
    if ($type eq 'case number' or $type eq 'case code') {
        for my $morgue ( @{$RVT_paths->{images}} ) { 
            return "$morgue/$case-" . $RVT_cases->{$case}{code} 
                if (-d "$morgue/$case-" . $RVT_cases->{$case}{code});
        }
    }
    
    if ($disk) {
        for my $morgue ( @{$RVT_paths->{images}} ) { 
            return "$morgue/$case-" . $RVT_cases->{$case}{code} . "/$disk.dd" 
                if (-e "$morgue/$case-" . $RVT_cases->{$case}{code} . "/$disk.dd");
        }
    }    
    
    return 0;
}      


sub RVT_check_imageexists ($) {
    # checks if a disk has a image in the morgue
    # returns 1 if OK, 0 for anything else
    
    my $thing = shift;
    
    my $case = RVT_get_casenumber($thing);
    my $device = RVT_get_devicenumber($thing);
    my $disk = RVT_get_devicenumber($thing);
    
    return 1 if ($RVT_cases->{$case}{device}{$device}{disk}{$disk});
    return 0;
}


sub RVT_log  {
    # logs second argument as indicated by the first, which can be:
    # 'w'  warning
    # '...
    # or a combination, like 'wls' (warning + log + screen)

}



sub RVT_fill_level {

   my ($case, $device, $disk, $partition) = @_;

   $$case = $RVT_level->{case} unless $$case;
   $$device = $RVT_level->{device} unless $$device;
   $$disk = $RVT_level->{disk} unless $$disk;
   $$partition = $RVT_level->{partition} unless $$partition;
   
}


sub RVT_chop_level {
	# TODO
	# gets a case, device, disk or partition
	# and chops to the specified level
	# f.ex.  RVT_chop_level('100101-01-1', 'case') = 100101	
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
    
    open(MMLS,"$RVT_tsk_path/mmls $diskpath 2>/dev/null|") || die "$RVT_tsk_path/mmls NOT FOUND";
	
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
    
    open (MMLS,"$RVT_tsk_path/fsstat $diskpath 2> /dev/null |") || die "$RVT_tsk_path/fsstat NOT FOUND";
    
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

    open (FSSTAT,"$RVT_tsk_path/fsstat -o $offset $diskpath  2> /dev/null |") || die "$RVT_tsk_path/fsstat NOT FOUND";
    
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
    return $results;
}


sub RVT_tsk_datastat ($$$) {
    # takes a disk, a partition and a dataunit, 
    # and gives the allocation status
    
    my ( $disk,$part,$du ) = @_;
    
    my $diskpath = RVT_get_imagepath($disk);
    return 0 unless ($diskpath);
    
    my $p = RVT_tsk_mmls($disk);
    return 0 unless ($p);
    my $offset = $p->{$part}{offset};

    open (PA,"$RVT_tsk_path/datastat -o $offset $diskpath $du | grep Allocated |") || die "$RVT_tsk_path/datastat NOT FOUND";    
    my $allocation = <PA>; 
    chomp $allocation;
    close (PA);
    
    return $allocation;
}



#######################################################################
#
#  Script functions
#
#######################################################################

sub RVT_cluster_generateindex {
    # creates the index for cluster-to-inode resolution
    # (ifind could be very slow)
    
    my ( $disk ) = @_;
    
    $disk = $RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
    
    my $ad = RVT_split_diskname($disk);
    my $morguepath = RVT_get_morguepath($disk);
    my $imagepath = RVT_get_imagepath($disk);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $searchespath = "$morguepath/output/searches";
    mkdir $searchespath unless (-e $searchespath);
    if (! -d $searchespath) { print "ERR: there is no path to the morgue/searches!\n\n"; return 0};

    
	# generation for every partition 

	my %parts = %{$RVT_cases->{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
    
    foreach my $p ( keys %parts ) {
        open (F, ">$searchespath/cindex-$disk-p$p");
        open (ILS, "ils -e /dev/$parts{$p}{loop} |");
        <ILS>; <ILS>; <ILS>; 
        while (<ILS>) {   
           /^(.+?)\|/;
           my $inode = $1;
           print F "$inode:";
           open (ISTAT, "istat /dev/$parts{$p}{loop} $inode |");
           while ( $sl = <ISTAT> ) {
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
    
    my ( $cluster, $part ) = @_;
    
    next unless ($cluster =~ /^[0-9\-]+$/);
    $part = $RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { print "ERR: that is not a partition\n\n"; return 0; }

    my $ad = RVT_split_diskname($part);
    my $morguepath = RVT_get_morguepath($part);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $searchespath = "$morguepath/output/searches";
    if (! -d $searchespath) { print "ERR: there is no path to the morgue/searches!\n\n"; return 0};        
    
    my @r = `grep $cluster $searchespath/cindex-$part | cut -d':' -f1 `;
    @r = map { chomp; $_; } @r;
    foreach my $kk (@r) { print "-$kk-";}
    
    return \@r;
}


sub RVT_cluster_toinode {
    # prints the inodes associated with a cluster (or data unit)
    # arguments:
    #   cluster
    #   partition
    
    my ( $cluster, $part ) = @_;
     
    my $r = RVT_get_inodefromcluster ( $cluster,$part );

    print @{$r};
}


sub RVT_cluster_allocationstatus {

    my ($cluster, $part) = @_;
    
    next unless ($cluster =~ /^[0-9\-]+$/);
    $part = $RVT_level->{tag} unless $part;
    if (RVT_check_format($part) ne 'partition') { print "ERR: $part that is not a partition\n\n"; return 0; }
    
    my $p = RVT_split_diskname( $part );
    
    my $disk = RVT_join_diskname ($p->{case}, $p->{device}, $p->{disk});
    
    print "Cluster $cluster: " . RVT_tsk_datastat ($disk, $p->{partition}, $cluster) . "\n";
}


sub RVT_script_search_file_edit  {
    # takes a case and a file name and creates a file
    # in morgue/case-code/searches_files
    
    my $filename = shift (@_);
    my $case = RVT_get_casenumber(shift (@_));
    
	RVT_fill_level(\$case);
	
    return 0 unless ($case);
    return 0 unless ($filename);
    
    $filename =~ s/[\. \\\/]/-/g;
    
    my $searchfile_path = RVT_get_morguepath($case) . '/searches_files';
    if ( ! -d $searchfile_path )  { mkdir $searchfile_path or return 0; }
    
    system ('vim', $searchfile_path . '/' . $filename);

    return 0 if ($? == -1);
    return 1;
}

sub RVT_script_search_file_delete  {
    # takes a case and a file name and deletes that
    # file from the morgue/case-code/searches_files

    my $filename = shift (@_);
    my $case = RVT_get_casenumber(shift (@_));
    
	RVT_fill_level(\$case);
    
    return 0 unless ($case);
    return 0 unless ($filename);
    
    $filename =~ s/[\. \\\/]/-/g;
    
    my $searchfile_path = RVT_get_morguepath($case) . '/searches_files';
    if ( ! -d $searchfile_path )  { return 0; }    
    
    return unlink ($searchfile_path . '/' . $filename);
}

sub RVT_script_search_file_list {
    # takes a case and a file name and list the 
    # files from the morgue/case-code/searches_files
    
    my $case = RVT_get_casenumber(shift (@_));
    
	RVT_fill_level(\$case);
	
    return 0 unless ($case);
    
    my $searchfile_path = RVT_get_morguepath($case) . '/searches_files';
    if ( ! -d $searchfile_path )  { print "No existe la carpeta searches_file\n\n"; return 0; }    
    
    opendir (DIR, $searchfile_path) or return 0;
    @f = sort grep { -f "$searchfile_path/$_" } readdir (DIR);
    closedir (DIR);
    
    print "\nFicheros de búsqueda:\n";
    foreach $f ( @f ) { 
        my $wc = `wc -l $searchfile_path/$f | cut -d" " -f 1`;
        chomp $wc;
        print "\t$f\t( $wc líneas) \n" ; 
    }
    print "\n";
}

sub RVT_script_search_file_show  {
    # takes a case and a file name and opens a file
    # in morgue/case-code/searches_files
    
    my $filename = shift (@_);
    my $case = RVT_get_casenumber(shift (@_));

	RVT_fill_level(\$case);
    
    return 0 unless ($case);
    return 0 unless ($filename);
    
    $filename =~ s/[\. \\\/]/-/g;
    
    my $searchfile_path = RVT_get_morguepath($case) . '/searches_files';
    return 0 unless (-f $searchfile_path . "/$filename");
    
    print "\n";
    open (FICH, "<$searchfile_path/$filename") or return 0;
    while (<FICH>) { chomp; print "\t$_\n"; }
    close (FICH);

}


sub RVT_script_search_quickcount {
	# searches a regular expression, counts the results
	# and present them
	# useful to know how many emails adresses or bank 
	# accounts are present in the image
	# name:re

	my ($re, $disk) = @_;
	my $name;
	
	$disk = $RVT_level->{tag} unless $disk;
	
	# special matches supported:
	if ($re eq 'emails') { $name=$re; $re = '[a-z0-9._-]{2,25}@[a-z0-9.-]{3,35}\\.[a-z]{2,8}';	}
	if ($re eq 'accounts') { $name=$re; $re = '[0-9]{4}[-.\\s]+[0-9]{4}[-.\\s]+[0-9]{2}[-.\\s]+[0-9]{10}';	}
	if ($re eq 'ips') { $name=$re; $re = '[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}'; }
	if ($re eq 'phones') { $name=$re; $re = '([0-9]{2,3}[\\s\\.\\-])?[0-9]{2,3}[\\s\\.\\-][0-9]{2,3}[\\s\\.\\-][0-9]{2,3}'; }
	
	$re = lc ($re);
	if (!$name) {
		if ( $re !~ /^(\w+):(.*)$/ ) { print "ERR:  correct format is   <name:regular expression> \n or to use a special name\n\n"; return 0; }
		$name = $1;
		$re = $2;
	}
	
	return 0 unless ($re and $disk);

    my $case = RVT_get_casenumber($disk);
    my $morguepath = RVT_get_morguepath($disk);
    my $stringspath = "$morguepath/output/strings";

    return 0 if (! $morguepath);
    return 0 if (! -d $stringspath);
    my $infopath = "$morguepath/output/info";
    mkdir $infopath unless (-e $infopath);
    if (! -d $infopath) { print "ERR: there is no path to the morgue/info!\n\n"; return 0};

    opendir (DIR, "$stringspath") or die ("ERR: strings path not readable");
    my @strfiles = grep { /^strings/ } readdir(DIR);
    close DIR;
    if (! @strfiles) { print "ERR: strings are not generated\n\n"; return 0; }	

	print "\t Begining to count for $name: \n\n";

	my %results;
	foreach $s (@strfiles) {
		open (STR, "<$stringspath/$s") or die "jarl! $!";
		while (my $l=<STR>) {
			next if ($l !~ /$re/); 
			$results{$&} = $results{$&} + 1;
		}
		close STR;
	}
	
	open (R, ">$infopath/count_$name.txt") or die "jarl! $!";
	foreach $k ( sort {$results{$a} <=> $results{$b}} keys %results) {
		print R "$results{$k}\t$k\n";
		print  "\t $results{$k}\t$k\n";
	} 
	close R;
	
	print "\n\t quick count search done\n\n";
	return 1;
}



sub RVT_script_search_launch  {
    # launches a search over a serie of images or cases
    # takes as arguments:
    #   file with searches: one for line
    #   disk from the morgue
    # returns 1 if OK, 0 if errors

    my ( $searchesfilename, $disk ) = @_;
    
    $disk = $RVT_level->{tag} unless $disk;
    print "\t launching $disk\n";
    my $case = RVT_get_casenumber($disk);
    my $diskpath = RVT_get_morguepath($disk);
    my $stringspath = "$diskpath/output/strings";
    my $searchespath = "$diskpath/output/searches";
    return 0 if (! $diskpath);
    return 0 if (! -d $stringspath);

    open (F, "<".RVT_get_morguepath($case)."/searches_files/$searchesfilename") or return 0;
    my @searches = grep {!/^\s*#/} <F>;
    close (F);
    
    if (! -e $searchespath) { mkdir $searchespath or return 0; }
    print "\n\nLaunching searches:\n\n";
    
    for $b ( @searches ) {
        chomp $b;
	$b = lc($b);
        print "-- $b\n";
        my $f = $b;
        $f =~ s/ /-/g;
        $f = 'busq_' . $f;
        `grep -H "$b" $stringspath/*strings* | tee $searchespath/$f`; #*/ 
    }

    return 1;
}


sub RVT_script_search_clusterlist {
    # extract cluster lists from a search
    # takes as arguments:
    #   file with searches
    #   disk

    my ( $searchesfilename, $ndisk ) = @_;

	$ndisk = $RVT_level->{tag} unless $ndisk;
   
    my $adisk = RVT_split_diskname($ndisk);
    my $diskpath = RVT_get_morguepath($ndisk);
    my $stringspath = "$diskpath/output/strings";
    my $searchespath = "$diskpath/output/searches";
    #return 0 if (! $disk);
    return 0 if (! $diskpath);
    return 0 if (! -d $stringspath);
    return 0 if (! -d $searchespath);
   
    open (F, "<".RVT_get_morguepath($adisk->{case})."/searches_files/$searchesfilename") or return 0;
    my @searches = grep {!/^\s*#/} <F>;
    close (F);
    
    my %fnh;  # $fnh {$searchespath/$f-$part} = filehandler for writing in the file
              # one for every busq-partition couple (with results)
    
    print "Creating cluster lists:\n\n";
    
    for $b (@searches) {
        
        chomp $b;
        print "-- $b\n";
        my $f = $b;
        $f =~ s/ /-/g;
        $f = 'busq_' . $f;
        
        open (BF, "<$searchespath/$f") or return 0;
        while (my $l=<BF>) {
            $l =~ /^.+-\d{6}-\d{1,2}-\d{1,2}(\.dd)?-(\d{1,2})\.(asc|uni):\s*(\d+) /;
        
            my $part = $2;
            my $offset = $4;
            my $cfn = "$searchespath/c$f-$part";
            my $pfn = "$searchespath/p$f-$part";
            if (! defined($fnh{$cfn})) {
       	        open ( $fnh{$cfn}, "|sort -nu > $cfn" ) or die "FATAL: $!";
       	        open ( $fnh{$pfn}, "|sort -u  > $pfn" ) or die "FATAL: $!";
            }
            my $chandler = $fnh{$cfn};
            my $phandler = $fnh{$pfn};

	        # cluster and allocation status
	        my $du = int( $offset /
	                       $RVT_cases->{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{clustersize} );
    	    my $allocstat = RVT_tsk_datastat ($ndisk, $part, $du);
    	    my $loopdev = $RVT_cases->{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{loop};
    	    
    	    my $inodes = RVT_get_inodefromcluster( $du, "$ndisk-p$part" );
    	    foreach my $inode (@{$inodes}) {
    	        print "ffind /dev/$loopdev $inode\n";
                my $path = `ffind /dev/$loopdev $inode`; 
                chomp $path;
                print $chandler "$du:$allocstat:$inode:$path\n";
                print $phandler "$path";     
            }
        }
        close (BF);
    }    
     
    for $f (keys %fnh) { close($fnh{$f}); }

    return 1;    
}


sub RVT_script_search_clusters  {
    # extract clusters from a search
    # takes as arguments:
    #   file with searches: one for line
    #   disk from the morgue
    # returns 1 if OK, 0 if errors

    my ( $searchesfilename, $ndisk ) = @_;

	$ndisk = $RVT_level->{tag} unless $ndisk;
   
    my $adisk = RVT_split_diskname($ndisk);
    my $diskpath = RVT_get_morguepath($ndisk);
    my $stringspath = "$diskpath/output/strings";
    my $searchespath = "$diskpath/output/searches";
    #return 0 if (! $disk);
    return 0 if (! $diskpath);
    return 0 if (! -d $stringspath);
    return 0 if (! -d $searchespath);
   
    open (F, "<".RVT_get_morguepath($adisk->{case})."/searches_files/$searchesfilename") or return 0;
    my @searches = grep {!/^\s*#/} <F>;
    close (F);
    
    print "\n\nScanning morgues ...\n";
    RVT_images_scanall();
    
    my %fnh;  # $fnh {$searchespath/$f-$part} = filehandler for writing in the file
              # one for every busq-partition couple (with results)
    
    print "Extracting clusters:\n\n";
    
    for $b (@searches) {
        
        chomp $b;
        print "-- $b\n";
        my $f = $b;
        $f =~ s/ /-/g;
        $f = 'busq_' . $f;
        
        open (BF, "<$searchespath/$f") or return 0;
        while (my $l=<BF>) {
            $l =~ /^.+-\d{6}-\d{1,2}-\d{1,2}(\.dd)?-(\d{1,2})\.(asc|uni):\s*(\d+) /;
        
            my $part = $2;
            my $offset = $4;
            my $fn = "$searchespath/i$f-$part";
            if (! defined($fnh{$fn})) {
       	        open ( $fnh{$fn}, ">$fn" ) or die "FATAL: $!";
            }
            my $fhandler = $fnh{$fn};

	        # cluster and allocation status
	        my $du = int( $offset /
	                      $RVT_cases->{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{clustersize} );
    	    my $allocstat = RVT_tsk_datastat ($ndisk, $part, $du);
    	    
 	        # strings line
       	    $l =~ /[^ ]+(.*)$/;
            $string = $1;

            print $fhandler 	"\n\n\n---------------------------\n" .
            			$offset .":" .
            			$du .":" .
            			$allocstat .":" .
            			$string ."\n\n\n";
            
            # gets the cluster and prints it
       
            my $dd_command =    "dd" . 
                        " if=/dev/" .   $RVT_cases->{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{loop} .
                        " bs=" .   $RVT_cases->{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{clustersize} . 
                        " skip=" . $du .
                        " count=1 2> /dev/null |";
            open (DD, $dd_command) or die "FATAL: image is mounted? $!\n";
            while (<DD>) { print $fhandler $_; }
            close (DD);
            
        }
        close (BF);
    }    
     
    for $fn (keys %fnh) { close($fnh{$fn}); }

    return 1;      
}    
   


sub RVT_script_strings_generate  {
    # generates strings from an image
    # returns 1 if OK, 0 if errors

    my ( $disk ) = @_;
    
    $disk = $RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
    
    my $ad = RVT_split_diskname($disk);
    my $morguepath = RVT_get_morguepath($disk);
    my $imagepath = RVT_get_imagepath($disk);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $stringspath = "$morguepath/output/strings";
    mkdir $stringspath unless (-e $stringspath);
    if (! -d $stringspath) { print "ERR: there is no path to the morgue/strings!\n\n"; return 0};

    
	# generation for every partition 

	my %parts = %{$RVT_cases->{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
	my $sectorsize = $RVT_cases->{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{sectorsize};
    
    foreach my $p ( keys %parts ) {
    	my $strcnt;
    	if ($p and $sectorsize) { $strcnt = " count=" . ($parts{$p}{size}/$sectorsize) . " "; }
    	# glups...
    	
    	print "\t generating ASCII for $disk-p$p ...\n";
    	my $cmd = "/bin/dd if=" . $imagepath 
    		. " skip=" .  $parts{$p}{osects} . "$strcnt bs=512 2> /dev/null | "
    		. "/usr/bin/strings -a -t d | tr /A-Z/ /a-z/ > " 
    		. "$stringspath/strings-$disk-$p.asc";
    	`$cmd`;

    	print "\t generating UNICODE for $disk-p$p ...\n";
    	my $cmd = "/bin/dd if=" . $imagepath 
    		. " skip=" .  $parts{$p}{osects} . "$strcnt bs=512 2> /dev/null | "
    		. "/usr/bin/strings -a -t d  -e l | tr /A-Z/ /a-z/ > " 
    		. "$stringspath/strings-$disk-$p.uni";
    	`$cmd`;
    }

	print "\t strings done\n";
	return 1;
}




sub RVT_script_timelines_generate  {
    # generates timelines from an image
    # returns 1 if OK, 0 if errors

    my ( $disk ) = @_;
    
    $disk = $RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { print "ERR: that is not a disk\n\n"; return 0; }
    
    my $ad = RVT_split_diskname($disk);
    my $morguepath = RVT_get_morguepath($disk);
    my $imagepath = RVT_get_imagepath($disk);
    if (! $morguepath) { print "ERR: there is no path to the morgue!\n\n"; return 0};

    my $timelinespath = "$morguepath/output/timelines";
    mkdir $timelinespath unless (-e $timelinespath);
    if (! -d $timelinespath) { print "ERR: there is no path to the morgue/timelines!\n\n"; return 0};
	mkdir "$timelinespath/temp" unless ( -d "$timelinespath/temp" );
    
	# generation for every partition 

	my %parts = %{$RVT_cases->{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
	my $sectorsize = $RVT_cases->{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{sectorsize};
    
    foreach my $p ( keys %parts ) {
		# glups ...
		print  "\t Generando ficheros intermedios para $disk-p$p ... \n";
		
    	my $cmd = "/usr/bin/fls -s 0 -m \"$p/\" -r -o " . $parts{$p}{osects} . "@" . $sectorsize .
    		" -i raw $imagepath >> $timelinespath/temp/body ";
    	`$cmd`;
    	
    	my $cmd = "/usr/bin/ils -s 0 -e -m -o " . $parts{$p}{osects} . "@" . $sectorsize .
    		" -i raw $imagepath > $timelinespath/temp/ibody-$p ";
    	`$cmd`;
    }
    
    print  "\t Generando timelines para $disk ... \n";	
    my $cmd = "/usr/bin/mactime -b $timelinespath/temp/body -d -i hour $timelinespath/timeline-hour.sum > "
    	. "$timelinespath/timeline.csv";
    `$cmd`;
    my $cmd = "/usr/bin/mactime -b $timelinespath/temp/body -i day $timelinespath/timeline-day.sum > "
    	. "$timelinespath/timeline.txt";
    `$cmd`;
   
    foreach my $p ( keys %parts ) {
		# glups ...
		print  "\t Generando itimeline para $disk-p$p ... \n";
		    	
		open (IDEST,">$timelinespath/itimeline-$p.csv");
		open (PA,"/usr/bin/mactime -b $timelinespath/temp/ibody-$p -d -i day $timelinespath/itimeline-day-$p.sum |");
		<PA>;  # header
		while ( my $line=<PA> ) { 
			chop($line);
			my @line = split(",", $line);
			my $inode = $line[6];
			my $filename = `/usr/bin/ffind -o $parts{$p}{osects}@$sectorsize -i raw $imagepath $inode`;
			chop($filename);	
			print IDEST join(",",@line[0..6]) . ",$filename\n";
		}
		close (PA);
		close(IDEST);    	
    } 
    
    print "\t timelines done\n";
    return 1;
}




sub RVT_script_software_detection  {
    # generates a list of the software present in the image 
    # returns 1 if OK, 0 if errors

    my ( $disk ) = @_;
    
    $disk = $RVT_level->{tag} unless $disk;
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
			
			$term=$RVT_progs{$i}{$j}{'term'};
			$term=~y/,/|/;
			TLFILES: foreach my $t (@tlfiles) { 
				open (F,"$timelinespath/$t");
				while ( $line=<F> ) { 
					@lin = split(",",$line);
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
				push(@prog_found, $j);
			} else {
				print "\n";
			}
		}
	}

	close DEST;

    print "\t software detection done\n";
	return 1;
}





sub RVT_script_webmail_detection  {
    # generates a list of the webmail traces present in the image 
    # returns 1 if OK, 0 if errors

    my ( $disk ) = @_;
    
    $disk = $RVT_level->{tag} unless $disk;
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
    foreach $w (keys %wm) {
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


#######################################################################
#
#  Image functions
#
#######################################################################


sub RVT_images_partition_table   {
    # takes disk and prints a list of the partitions
    
    my $disk = shift(@_);
    $disk = $RVT_level->{tag} unless $disk;

    my $part = RVT_tsk_mmls($disk);

    if (!$part) { print "\n\nI don't know what is this\n\n"; return; }

    print "\n";
    for my $dd ( keys %{$part} ) {
        my $size = int($part->{$dd}{length} * 512 / 1048576) +1 ; # 1024^3
        print "\t$dd:\t$size MB\t" . $part->{$dd}{description} . "\n";
    }
    print "\n";

}


#######################################################################
#
#  Partition functions
#
#######################################################################

sub RVT_images_partition_info  {
    # takes $disk and $partition
    
    my $partition = shift(@_);

	$partition = $RVT_level->{tag} unless $partition;
	

    my $p = RVT_tsk_fsstat ($partition);
    
    if (!$p) { print "\n\nI don't know what is this\n\n"; return; }

    print "\nInfo for partition $disk - $partition:\n\n";
    print "Filesystem:\t" . $p->{filesystem};
    print "\nCluster size:\t" . $p->{clustersize};
    print "\nSector size:\t" . $p->{sectorsize};
    print "\nOffset:\t\t" . $p->{offset} . " sectors ( " . ($p->{offset}*$p->{sectorsize}) . " bytes )";
    print "\n\n";
}







#######################################################################
#
#  Morgue functions
#
#######################################################################


sub RVT_case_list {
   
    my $bsize = shift(@_);
    my $filename;
  
    print "Cases in the morgue: \n";
    for my $morgue ( @{$RVT_paths->{morgues}} ) { 
	    # lists cases in morgue
	    opendir( MORGUE, $morgue) or die "FATAL: couldn't open morgue: $!";
	    
	    while (defined($f=readdir(MORGUE))) {
		next unless ($f=~/^(\d{6})-(\w+)$/ && -d $morgue . "/" . $f);
		my $case = $1;
		my $code = $2;
		my $size;
		if ($bsize eq '-s' or $bsize eq '--size') { $size = " (" . RVT_du("$morgue/$f") .")"; }
		print "\t$case '$code'$size:\n";
		opendir (CASE, $morgue . "/$f");
		while (defined($ff=readdir(CASE))) {
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
    for my $images ( @{$RVT_paths->{images}} )  {
	    # lists images in morgue
	    opendir( IMAGES, $images) or die "FATAL: couldn't open morgue: $!";
	    
	    while (defined($f=readdir(IMAGES))) {
		next unless ($f=~/^(\d{6})-(\w+)$/ && -d $images . "/" . $f);
		my $case = $1;
		my $code = $2;
		my $size;
		if ($bsize eq '-s' or $bsize eq '--size') { $size = " (" . RVT_du("$images/$f") .")"; }
		print "\t$case '$code'$size:\n";
		opendir (CASE, $images . "/$f");
		while (defined($ff=readdir(CASE))) {
		    print "\t\t$ff\n" if ($ff=~/^$case-\d\d-\d\d?\.dd$/ && -f $images . "/$f/$ff");  }
		closedir(CASE);
	    }
	    closedir( MORGUE );
    }
    print "\n";
}



sub RVT_losetup_list {

    my @loopdev;
    opendir (DEV, '/dev') or die "FATAL: couldn't open /dev: $!";
    while (defined($d=readdir(DEV))) { push(@loopdev, $d) if ($d=~/^loop\d{1,3}$/ && -b "/dev/$d"); }
    closedir (DEV);
    
    print "Loop devices: \n";
    for my $images ( @{$RVT_paths->{images}} )  {
	    for $d (@loopdev) {
		my $r = `sudo losetup /dev/$d 2> /dev/null`;   # TODO glups!
		my $rr = '\/dev\/'.$d.': \S* \(' . $images . '\/\d{6}-\w+\/(\d{6}-\d\d-\d\d?\.dd)\)\D+(\d+)$'; 
		next unless ($r=~/$rr/);
		print "\t$d\t$1\t$2\n";
	    }
    }
}



sub RVT_mount_list {

   print "Mounted partitions: \n";
   open ( MOUNT, 'mount | grep "ro,loop=" |' ) or die "FATAL: couldn't execute mount: $!";
   while (my $l=<MOUNT>) {
   	$l=~/.*\/([^\/]+) on .*(loop=\/dev\/loop\d+).+(offset=\d+)/;
	print "\t$1\t$2\t$3\n";
   }
   close MOUNT;
   print "\n";
}



sub RVT_losetup_delete { 

    my $object = shift(@_);
    my ($case, $device, $disk);

	RVT_fill_level(\$object);
	my $type = RVT_check_format($object);
	return 0 unless ($type == 'disk');

    my $r = RVT_split_diskname($object);
    $case = $r->{case};
    $device = $r->{device};
    $disk = $r->{disk};
    
    for my $partition (keys %{$RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}}) {
        my @args = ("sudo", "losetup", "-d", 
       "/dev/$RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$partition}{loop}", );
        system(@args) == 0 or die "losetup failed: $?";
    }
     
    RVT_losetup_recheck;
} 


sub RVT_losetup_assign () {

    my $object = shift(@_);
    my ($case, $device, $disk);

	RVT_fill_level(\$object);
	my $type = RVT_check_format($object);
	return 0 unless ($type == 'disk');

    my $r = RVT_split_diskname($object);
    $case = $r->{case};
    $device = $r->{device};
    $disk = $r->{disk};
    
    for my $partition (keys %{$RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}}) {
      my @args = ("sudo", "losetup", "-f", 
        $RVT_cases->{$case}{imagepath}."/$case-$RVT_cases->{$case}{code}/$case-$device-$disk.dd", 
        "-o $RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$partition}{obytes}" );
      print "\n" . join (" ", @args) . "\n";
      system(@args) == 0 or die "losetup failed: $?"; 
	}

    RVT_losetup_recheck;
}


sub RVT_mount_delete () {

    my $object = shift(@_);
    my ($case, $device, $disk);

	RVT_fill_level(\$object);
	my $type = RVT_check_format($object);
	return 0 unless ($type == 'disk');

    my $r = RVT_split_diskname($object);
    $case = $r->{case};
    $device = $r->{device};
    $disk = $r->{disk};
    
    my $pmnt = $RVT_cases->{$case}{morguepath}."/$case-" 
    . $RVT_cases->{$case}{code} 
    . "/$case-$device-$disk/mnt";
    for my $partition (keys %{$RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}}) {
        my $ppart = "$pmnt/p$partition"; 
        my @args = ("sudo", "umount", $ppart);
        print "\n" . join (" ", @args) . "\n";
        system(@args) == 0 or  print "--> ERROR: umount $case-$device-$disk-$partition failed: $?\n";
	}

    RVT_losetup_recheck;
}


sub RVT_mount_assign () {

    my $object = shift(@_);
    my ($case, $device, $disk);

	RVT_fill_level(\$object);
	my $type = RVT_check_format($object);
	return 0 unless ($type == 'disk');

    my $r = RVT_split_diskname($object);
    $case = $r->{case};
    $device = $r->{device};
    $disk = $r->{disk};
	
	my $pmnt = $RVT_cases->{$case}{morguepath}."/$case-" 
	    . $RVT_cases->{$case}{code} 
	    . "/$case-$device-$disk/mnt";
	if ( ! -d $pmnt ) { mkdir($pmnt) or die "JARL! no puedo hacer un directorio: $!\n"; }
    for my $partition (keys %{$RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}}) {
	    my $ppart = "$pmnt/p$partition"; 
	    if (! -d $ppart ) { mkdir ($ppart) or die "JARL! no puedo hacer un directorio: $!\n"; }
        my @args = ("sudo", "mount",  
        $RVT_cases->{$case}{imagepath}."/$case-$RVT_cases->{$case}{code}/$case-$device-$disk.dd",
	    $ppart,
        "-o", "ro,loop,iocharset=utf8,offset=$RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$partition}{obytes},umask=$RVT_umask,gid=$RVT_gid" );
        print "\n" . join (" ", @args) . "\n";
        system(@args) == 0 or  print "--> ERROR: mount $case-$device-$disk-$partition failed: $?\n";
	}

    RVT_losetup_recheck;
}




sub RVT_losetup_recheck {

    # loop devices
    my @loopdev;
    opendir (DEV, '/dev') or die "FATAL: couldn't open /dev: $!";
    while (defined($d=readdir(DEV))) { push(@loopdev, $d) if ($d=~/^loop\d{1,3}$/ && -b "/dev/$d"); }
    closedir (DEV);

    # removing losetup data from $RVT_cases
    for my $case (keys %$RVT_cases) {
       for my $device (keys %{$RVT_cases->{$case}{device}}) {
          for my $disk (keys %{$RVT_cases->{$case}{device}{$device}{disk}}) {
            for my $partition (keys %{$RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}}) {
                   $RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$partition}{loop} = '';
            }
          }
       }
    }
    
    # created losetups
    for $d (@loopdev) { 
        my $r = `sudo losetup /dev/$d 2> /dev/null`;   # TODO glups!
        my $imagepath =  $RVT_cases->{$case}{imagepath};
        $imagepath =~ s/\//\\\//g;
        next unless ($r=~/^\/dev\/$d: \S* \(.*\/\d{6}-\w+\/(\d{6})-(\d\d)-(\d\d?)\.dd\)\D+(\d+)/ );
        for my $partition (keys %{$RVT_cases->{$1}{device}{$2}{disk}{$3}{partition}}) {
             if ($RVT_cases->{$1}{device}{$2}{disk}{$3}{partition}{$partition}{obytes} == $4) {
                $RVT_cases->{$1}{device}{$2}{disk}{$3}{partition}{$partition}{loop} = $d;
             } 
        }        
    }

}

sub RVT_images_scanall {

  $RVT_cases = {};
  for my $images ( @{$RVT_paths->{images}} )  {

    opendir( IMAGES, $images) or die "FATAL: couldn't open morgue: $!";
    
    
    while (defined($f=readdir(IMAGES))) {
        next unless ($f=~/^(\d{6})-(\w+)$/ && -d $images . "/" . $f);
        my $case = $1;
        my $code = $2;
        $RVT_cases->{$case}{code} = $code;
	    $RVT_cases->{$case}{imagepath}=$images;
       
        # images
	    opendir (CASE, $images . "/$f") or die "FATAL: jarl $!";
        while (defined($img=readdir(CASE))) {
            $imgpath = $images . "/$f/$img";
            next unless ($img=~/^$case-(\d\d)-(\d\d?)\.dd$/ && -f $imgpath);  
            my $device = $1;
            my $disk = $2;
            open(PA,"mmls $imgpath 2>/dev/null|") || die "FATAL: mmls NOT FOUND";
            while (my $line=<PA>) {
                if ( $line =~ /Units are in (\d+)-byte sectors/) 
                    { $RVT_cases->{$case}{device}{$device}{disk}{$disk}{sectorsize}=$1; }
                next unless ( $line =~ /(\d\d):\s*..:..\s*(\d+)\s*\d+\s*(\d+)\s*(.+)$/)  ;  
                my ($pnum, $pstart, $plength, $pdesc) = ($1, $2, $3, $4);
                next if ($pdesc =~ /Extended/);
                $RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{type}=$pdesc;
                $RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{osects}=$pstart;
                $RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{obytes}=
                    $pstart * $RVT_cases->{$case}{device}{$device}{disk}{$disk}{sectorsize};
                $RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{size}=
                    $plength * $RVT_cases->{$case}{device}{$device}{disk}{$disk}{sectorsize};
                    
                # filesystem information
                
                my $fsstat = RVT_tsk_fsstat ("$case-$device-$disk-p$pnum");
                next unless ($fsstat);
                $RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{filesystem} = $fsstat->{filesystem};
                $RVT_cases->{$case}{device}{$device}{disk}{$disk}{partition}{$pnum}{clustersize} = $fsstat->{clustersize};
                
            }
            close(PA);
        }
        closedir(CASE);

	    # morgue
  	    for my $morgue ( @{$RVT_paths->{morgues}} )  {
	    	next unless ( -d "$morgue/$case-$code" );  
	    	$RVT_cases->{$case}{morguepath}=$morgue; 
	    	 
	    }
    }
    closedir( MORGUE ); 
  }
  RVT_losetup_recheck;
}


sub RVT_info_list {

   my $bsize = shift(@_);

   print "\n\tList of morgues:\n";
   for $m (@{$RVT_paths->{morgues}}) { 
	if ($bsize eq '-s' or $bsize eq '--size') { $size = " (" . RVT_du($m) .")"; }
   	print "\t\t$m $size\n"; 
   }

   print "\n\n\tList of morgues of images:\n";
   for $m (@{$RVT_paths->{images}}) { 
	if ($bsize eq '-s' or $bsize eq '--size') { $size = " (" . RVT_du($m) .")"; }
   	print "\t\t$m $size\n"; 
   }

   print "\n";
}





#######################################################################
#
#  Shell functions
#
#######################################################################




sub RVT_shell_help {

    my $command = shift(@_);
    $command = RVT_shell_function_build($command);
    
    if (RVT_shell_isfunction($command)) {
        print "? \n$command:\n";
        print $RVT_functions{$command} . "\n\n";
    } else {
        my @results = grep (/^$command/, keys %RVT_functions);
        my @ss = split ('_', $command);
        %results = map { 
                            my @t = split('_',$_);
                            my $t = ($#t == $#ss)?join('_',@t[0..$#ss]):join('_',@t[0..$#ss+1]);
                            $t  => 1
                       } @results;
        
        for $r (sort keys %results) { print "? $r\n"; }
    }
}

sub RVT_shell_function_build {
    my $command = shift(@_);
    $command =~ s/\?.*$//;
    $command =~ s/^\s*//;
    $command =~ s/\s*$//;
    $command =~ s/\s{2,}/ /g;
    $command = lc($command);
    
    $command =~s/\s/_/g;
    $command = 'RVT_' . $command;
    return $command;
}

sub RVT_shell_function_unbuild {
	my $command = shift(@_);
	$command =~ s/^RVT_//;
	$command =~ s/_/ /g;
	return $command;
}

sub RVT_shell_isfunction {
    my $command = shift(@_);
    if ( (grep (/^$command$/, keys %RVT_functions)) ) { return 1; }
    return 0;
}


sub RVT_shell_function_exec ($$) {

    my ($command, $cmdgrp) = @_;

    $command =~ s/^\s*//;

    my @c = split(/\s+/, $command);

    for (my $cc=0; $cc<=$#c; $cc++ ) {
        my $fun = 'RVT_' . join('_',@c[0..$cc]);
        if ( $RVT_functions{ $fun } ) {
            
            # expanding @disks
            # now, only works with last argument
            my @disks;
            if (($c[$#c] eq '@disks') and $RVT_level->{tag} ) {
                my $r = RVT_expand_object ($RVT_level->{tag});
                my $tcase = $RVT_level->{case};
                foreach my $dev ( keys %{$r->{$tcase}{device}} ) {
                    foreach my $disk ( keys %{$r->{$tcase}{device}{$dev}{disk}} ) {
                        push (@disks,  RVT_join_diskname( $tcase, $dev, $disk ));
                    }
                }
            } else {
                # puts one element in @disks just to execute the command
                # ... yes, this is a chunk of ugly code...
                @disks[0] = ($#c == $cc)?'':$c[$#c];
            }
            
            foreach my $disk ( @disks ) {
                #print "\nexecuting: $fun " . join(" ",@c[$cc+1..$#c-1], $disk) . "\n\n";
                eval {
                    &{$fun}( @c[$cc+1..$#c-1], $disk );
                };
                if ($@) { print "\n\n--> ERROR:  the command exited with errors: \n$@\n\n"; }
            }
            return 0;
        }
    }

    # $command is not a command. Maybe is a part...
    $command = 'RVT_' . join('_',@c);
    if ( grep { /^$command\_/ || /^$command$/ } keys(%RVT_functions) ) {
        return join(' ',@c);
    }

    return 0;
}



sub RVT_getcommand {
	
	my ($cmdgrp, $cmdhist) = @_;
	my $cmd = '';

	system "stty", '-icanon', 'eol', '001';

	while () {
		 my $k = getc();
         if (ord($k) == 27 ) {
                next unless ord(getc()) == 91;
                next unless ord(getc()) == 65;
                $cmd = $cmdhist;
                print "\r                                                                              \r";
                RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp, $cmd);
                next;
         }
		 if (ord($k) == 127) {
		 	chop $cmd;
			print "\r                                                                              \r";
			RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp, $cmd);
			next;
		 }
		 if (ord($k) == 27 ) { 
		 	$cmd = ""; 
			RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp, $cmd);
		 	next; 
		 }
		 if ($k eq "\t") {
		 	$cmd =~ s/\s+$//;
		 	$cmd =~ s/^\s+//;
		 	$cmd =~ s/\s{2,}/ /;
		 	my $cb = RVT_shell_function_build($cmdgrp . ' ' . $cmd);
		 	my @cbm = grep {/^$cb/} keys %RVT_functions;
		 	@cbm = map { RVT_shell_function_unbuild($_) } @cbm;
			my %cbm = map { s/($cmdgrp ?$cmd ?\w*) ?.*?$/$1/; $_ => $_  } @cbm;
			@cbm = keys %cbm;
			print "\n";
			if ($#cbm != -1) {
		 		$cmd =  $cbm[0] ;
		 		foreach my $tmp ( sort @cbm ) { 
					while ( ($tmp !~ /^$cmd/ ) and $cmd ) {
						chop $cmd; 
					} 
					print "\t" . $tmp . "\n";
				}
				$cmd =~ s/^$cmdgrp//;
		 	}

		 	RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp, $cmd);
		 	next;
 		 }
		 
		 $cmd .= $k;  
		 if ($k eq "\n") {last;};  
	}
	
    system "stty", 'icanon', 'eol', '^@';
    return $cmd;
}


sub RVT_shell_prompt {
  
   my ($level, $cmdgrp, $cmd, $preffix) = @_;

   print "$preffix RVT $level $cmdgrp> $cmd";

}

sub RVT_shell {

    print "\n\nWelcome to Revealer Tools Shell (v$RVT_version):\n\n";
    my ($cmdgrp, $command, $cmdhist);

    if ($RVT_batchmode) {
    	open (BATCH, "<$RVT_batchmode") or die "FATAL: $!";
    }

    RVT_shell_prompt ($RVT_level->{tag});
    while () {
        if ($RVT_shellmode) { $command = RVT_getcommand($cmdgrp, $cmdhist); }
	if ($RVT_batchmode) { return unless ($command=<BATCH>); print $command;  }

        chomp $command;
        $cmdhist = $command if $command;
        last if ($command =~ /quit$/);
        if ( $command =~ /^\s*r(e|et|etu|etur|eturn)?/ ) {
                $cmdgrp =~ s/^(.*?) *\S*$/$1/;
                next;
        }
        if ($command =~ /\?/) { RVT_shell_help("$cmdgrp $command"); next; }
        my $exec_result = RVT_shell_function_exec("$cmdgrp $command", $cmdgrp);
        $cmdgrp = $exec_result if $exec_result;
    } continue { RVT_shell_prompt ($RVT_level->{tag}, $cmdgrp); }

    if ($RVT_batchmode) { close(BATCH); }

    print "\n\nBye!\n";
}









