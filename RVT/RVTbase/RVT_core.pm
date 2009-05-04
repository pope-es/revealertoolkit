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


package RVTbase::RVT_core;  

use strict;
#use warnings;
use Data::Dumper;
use Sys::Syslog;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_log
                            &RVT_du
                            &RVT_check_format 
                            &RVT_get_morguepath
                            &RVT_get_casenumber
                            &RVT_get_devicenumber
                            &RVT_get_disknumber
                            &RVT_get_partitionnumber
                            &RVT_split_diskname
                            &RVT_join_diskname
                            &RVT_chop_diskname
                            &RVT_expand_object
                            &RVT_get_imagelist
                            &RVT_get_imagepath
                            &RVT_check_imageexists
                            &RVT_log
                            &RVT_fill_level
                            &RVT_exploit_diskname
                            &RVT_create_folder
                        );
       
       
   }


my $RVT_moduleName = "RVT_core";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

sub constructor {

    # nothing to do... yet

}


#######################################################################
#
#  core RVT functions
#
#######################################################################


sub RVT_log ($$) {
	# logs RVT activity/Users/jose/Desktop/scripts/plot_bars.pl
	
	my $type = shift(@_);
	if (!grep(/$type/, (    'EMERG', # - system is unusable
                            'ALERT', # - action must be taken immediately
                            'CRIT',  # - critical conditions
                            'ERR',   # - error conditions
                            'WARNING', # - warning conditions
                            'NOTICE', # - normal, but significant, condition
                            'INFO', # - informational message
                            'DEBUG' ) # - debug-level message
	                    )) { return; };                   
	
	my $message = shift(@_);
	chomp ($message);
	
	my $remoteSub = $@{caller(1)}[3];
	my $remotePackage = $@{caller(1)}[0];
	my $message = join ( ' ',  
	                $type,
	                $main::RVT_user."@".$main::RVT_remoteIP,
	                $message );
	
	syslog ('LOG_' . $type, $message );
}


sub RVT_du {

   my $path = shift(@_);

   my $r = `du -sh $path`;   # glups!
   my @r = split('\s+',$r);

   return $r[0];
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




sub RVT_get_casenumber ($) {
    # takes a case number, case code, device, disk or partition
    # checks the format of the case number or
    # reverse-resolves the case code
    # and returns the case number
    # return 0 in other case
    
    my $value = shift;
    if ($value =~ /^(\d{6})/) { 
        $value = $1; 
        return $value if ($main::RVT_cases->{case}{$value});
        return 0;
    }
    for ( keys %{$main::RVT_cases->{case}} ) { if ($main::RVT_cases->{case}{$_}{code} eq $value) {return $_;} }
    
    return 0;
}

sub RVT_get_devicenumber ($) {
    # takes  100ccc-DD-... format and returns DD
    # also takes  casecode-devicecode-...
    
    my $value = shift;
    my ($c, $d);
    ($c, $d) = split('-', $value);
    $c = RVT_get_casenumber($c);
    
    # TODO: codenames in devices
    #if ($d and ($d !~ /\d\d/)) {
        # maybe is a code, so let's resolve it
        
    #    for ( keys %{$main::RVT_cases->{case}{$c}{device}} ) {
    #        if ( $main::RVT_cases->{case}{$c}{device}{$_}{code} eq $d ) {$d = $_;}
    #    }
    #}
    

    return $d if (($c) && ($d =~ /^\d{2}$/));

    return 0;
}

sub RVT_get_disknumber ($) {
    # takes  100ccc-DD-dd format and returns dd
    # also takes casecode-devicecode-dd...
    
    my $value = shift;
    my ($c, $d, $disk) = split('-', $value);
    $c = RVT_get_casenumber($c);
    $d = RVT_get_devicenumber("$c-$d");
    
    return $disk if ($c && $d && ($disk =~ /^\d+$/) );

    return 0;
}

sub RVT_get_partitionnumber ($) {
    # guess ...
    
    my $value = shift;
    my ($c, $d, $disk, $part) = split('-', $value);
    $c = RVT_get_casenumber($c);
    $d = RVT_get_devicenumber("$c-$d");
    $disk = RVT_get_disknumber("$c-$d-$disk");
    
    $part =~ s/p//g;
    return $part if ($c && $d && $disk && ($part =~ /^\d{2}$/) );
    
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

sub RVT_chop_diskname ($$) {
    # takes a case, device, disk or partition name and chops it to the
    # desired level (also case, device, disk or partition). Returns 0 on
    # error
    # args: 
    #       level (case, device, disk or partition)
    #       name to be chopped

    my ($level, $name) = @_;
    
    return 0 unless ( $level =~ /^(case|device|disk|partition)$/ );
    my $n = RVT_split_diskname($name);

    my $r;
    $r  = $n->{case};
    $r .= "-" .$n->{device}      if ( ($n->{device})    && ($level =~ /^(device|disk|partition)$/));
    $r .= "-" . $n->{disk}       if ( ($n->{disk})      && ($level =~ /^(disk|partition)$/));
    $r .= "-p" . $n->{partition} if ( ($n->{partition}) && ($level =~ /^(partition)$/));

    return $r;
}

sub RVT_join_diskname  {
    # takes 100ccc, DD and dd and returns the string '100ccc-DD-dd'
    # in fact, it does not check arguments' syntaxis, so:
    # takes x, y and z and returns "x-y-z", like a join('-')
    
    my $r = shift;
    
    while (my $a = shift ) {
        $r .= "-" . $a if ($a);
    }
    
    return $r;   
}


sub RVT_exploit_diskname ($$) {
    # exploits the object to the given level. For example, given "partition 100101-01"
    # returns all the partitions of all the disks of all the devices of 100101-01
    # arg:
    #       exploit level
    #       diskname
    
    my ($level, $name) = @_;
    my (@cases, @devs, @disks, @parts);
  
    return 0 unless ( $level =~ /^(case|device|disk|partition)$/ );
    my $type = RVT_check_format($name); 
    return 0 unless ($type =~ /^(case number|device|disk|partition)$/ );
    my $n = RVT_split_diskname($name);
    
    # exploit case level
    unshift (@cases, $n->{case});
    return @cases if ($level eq 'case');
    
    # exploit device level
    if ($n->{device}) {
        unshift (@devs, RVT_chop_diskname('device',$name));
    } else {
        foreach my $cc (@cases) {
            foreach my $dd ( keys %{$main::RVT_cases->{case}{$cc}{device}} ) 
                { unshift (@devs, "$cc-$dd"); }
        }        
    }
    return @devs if ($level eq 'device');

    
    # exploit disk level
    if ($n->{disk}) {
        unshift (@disks, RVT_chop_diskname('disk',$name));
    } else {    
        foreach my $dd (@devs) {
            my $nn = RVT_split_diskname($dd);
            foreach my $ii ( keys %{$main::RVT_cases->{case}{$nn->{case}}{device}{$nn->{device}}{disk}} )
                { unshift (@disks, "$dd-$ii"); }
        }
    }       
    return @disks if ($level eq 'disk');
    
    # exploit partition level
    if ($n->{partition}) {
        unshift (@parts, $name);
    } else {     
        foreach my $ii (@disks) {
            my $nn = RVT_split_diskname($ii);
            foreach my $pp ( keys %{$main::RVT_cases->{case}{$nn->{case}}{device}{$nn->{device}}{disk}{$nn->{disk}}{partition}} )
                { unshift (@parts, "$ii-p$pp"); }        
        }
    }  
    return @parts if ($level eq 'partition');   
    
    return 0;
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
        for my $morgue ( @{$main::RVT_cfg->{paths}[0]{morgues}} ) { 
            return "$morgue/$case-" . $main::RVT_cases->{case}{$case}{code} 
                if (-d "$morgue/$case-" . $main::RVT_cases->{case}{$case}{code});
        }
    }
    
    if ($disk) {
        for my $morgue ( @{$main::RVT_cfg->{paths}[0]{morgues}} ) { 
            return "$morgue/$case-" . $main::RVT_cases->{case}{$case}{code} . "/$disk" 
                if (-d "$morgue/$case-" . $main::RVT_cases->{case}{$case}{code} . "/$disk");
        }
    }    
    
    return 0;
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
        foreach my $dev ( keys %{$main::RVT_cases->{case}{$case}{device}} ) {
            $r->{$case}{device}{$dev}{v} = 1;
        }
    }
    
    # fills disks
    if ($v_split->{disk} and $v_split->{device}) {
        $r->{$case}{device}{$v_split->{device}}{disk}{$v_split->{disk}} = 1;
    } else {
        foreach my $dev ( keys %{$r->{$case}{device}} ) {
            foreach my $disk ( keys %{$main::RVT_cases->{case}{$case}{device}{$dev}{disk}} ) {
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
    
    foreach my $dev ( keys %{$main::RVT_cases->{case}{$case}{device}} ) {
        for ( keys %{$main::RVT_cases->{case}{$case}{device}{$dev}{disk}} ) {
            push (@result, $_);
        }
    }
    
    return @result;
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
        for my $morgue ( @{$main::RVT_cfg->{paths}[0]{images}} ) { 
            return "$morgue/$case-" . $main::RVT_cases->{case}{$case}{code} 
                if (-d "$morgue/$case-" . $main::RVT_cases->{case}{$case}{code});
        }
    }
    
    if ($disk) {
        for my $morgue ( @{$main::RVT_cfg->{paths}[0]{images}} ) { 
            return "$morgue/$case-" . $main::RVT_cases->{case}{$case}{code} . "/$disk.dd" 
                if (-e "$morgue/$case-" . $main::RVT_cases->{case}{$case}{code} . "/$disk.dd");
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
    
    return 1 if ($main::RVT_cases->{case}{$case}{device}{$device}{disk}{$disk});
    return 0;
}




sub RVT_fill_level {
    # fills the given object ($obj) with info from level

   my $obj = shift;
   my $r = RVT_split_diskname($$obj);
   my ($case, $device, $disk, $partition) = (
        $r->{case},
        $r->{device},
        $r->{disk},
        $r->{partition}
        );

   $case = $main::RVT_level->{case} unless $case;
   $device = $main::RVT_level->{device} unless $device;
   $disk = $main::RVT_level->{disk} unless $disk;
   $partition = 'p' . $main::RVT_level->{partition} 
                    if ( !($partition) && ($main::RVT_level->{partition})) ;
   $partition = 'p' . $partition if ($partition);
   
   $$obj = RVT_join_diskname ($case, $device, $disk, $partition);
}


sub RVT_create_folder ($$) {
    # given a folder, creates a new folder inside with a name with a given
    # prefix. If a folder exists, creates other with a consecutive number
    
    # args:     mother folder in which create a new one
    #           prefix
    
    my ($mother, $prefix) = @_;
    
    return unless (-d $mother);
    return unless ($prefix =~ /^[A-Za-z0-9]+$/);
    
    my $n = 1;
    $n++ while (-d "$mother/$prefix-$n");
    mkdir ("$mother/$prefix-$n") or return;
    
    return "$mother/$prefix-$n";
}


1; 

