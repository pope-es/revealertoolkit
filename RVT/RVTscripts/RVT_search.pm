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


package RVTscripts::RVT_search;  

use strict;
#use warnings;

   BEGIN {
       use Exporter   ();
       our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

       $VERSION     = 1.00;

       @ISA         = qw(Exporter);
       @EXPORT      = qw(   &constructor
                            &RVT_script_search_quickcount
                            &RVT_script_search_launch
                            &RVT_script_search_clusterlist
                            &RVT_script_search_clusters
                            &RVT_script_search_file_edit
                            &RVT_script_search_file_list
                            &RVT_script_search_file_delete
                            &RVT_script_search_file_show
                            &RVT_script_strings_generate
                        );
       
       
   }


my $RVT_moduleName = "RVT_search";
my $RVT_moduleVersion = "1.0";
my $RVT_moduleAuthor = "dervitx";

use RVTbase::RVT_core;
use RVTbase::RVT_cluster;
use RVTbase::RVT_tsk;
use RVTbase::RVT_morgue;
use Data::Dumper;

sub constructor {

   my @req = ('dd', 'wc', 'tr', 'vim', 'cut', 'grep', 'tee');
   
   foreach my $req ( @req ) {
        $main::RVT_requirements{ $req } = `$req --version`;
        next if ($main::RVT_requirements{ $req });
        RVT_log('CRIT', "$req not properly installed");
   }
   
   $main::RVT_functions{RVT_script_search_quickcount } = "Launch a quick search in a case or in an image \n
                                script search quickcount <name:regular expression>  <image> ";
   $main::RVT_functions{RVT_script_search_launch } = "Launch a search in a case or in an image \n
                                script search launch <search file> <image or case> <image or case> ...";
   $main::RVT_functions{RVT_script_search_clusterlist } = "Builds a list of clusters and file paths that matches a previous\n
                                    search \n
                                    script search clusterlist <search file> <image>";
   $main::RVT_functions{RVT_script_search_clusters } = "Extract the clusters matched in a previous search\n
                                script search clusters <search file> <image>";
   $main::RVT_functions{RVT_script_search_file_edit } = "Invokes VIM in order to create or edit a new file with searches\n
                                script search file edit <case> <file name>";
   $main::RVT_functions{RVT_script_search_file_list } = "Lists all the files with searches\n
                                script search file edit <case>";
   $main::RVT_functions{RVT_script_search_file_delete } = "delete a file with searches\n
                                script search file edit <case> <file name>";
   $main::RVT_functions{RVT_script_search_file_show } = "shows the content of a file with searches\n
                                script search file edit <case> <file name>";
                                
   $main::RVT_functions{RVT_script_strings_generate } = "Generates strings for all partitions of a disk \n
 									script strings generate <disk>"; 									

}





sub RVT_script_strings_generate  {
    # generates strings from an image
    # returns 1 if OK, 0 if errors

    my ( $disk ) = @_;
    
    $disk = $main::RVT_level->{tag} unless $disk;
    if (RVT_check_format($disk) ne 'disk') { RVT_log('ERR', "that is not a disk"); return 0; }
    
    my $ad = RVT_split_diskname($disk);
    my $morguepath = RVT_get_morguepath($disk);
    my $imagepath = RVT_get_imagepath($disk);
    if (! $morguepath) { RVT_log('ERR', "there is no path to the morgue!"); return 0};

    my $stringspath = "$morguepath/output/strings";
    mkdir $stringspath unless (-e $stringspath);
    if (! -d $stringspath) { RVT_log('ERR', "there is no path to the morgue/strings!"); return 0};

    
	# generation for every partition 

	my %parts = %{$main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{partition}};
	my $sectorsize = $main::RVT_cases->{case}{$ad->{case}}{device}{$ad->{device}}{disk}{$ad->{disk}}{sectorsize};
    
    foreach my $p ( keys %parts ) {
    	my $strcnt;
    	if ($p and $sectorsize) { $strcnt = " count=" . ($parts{$p}{size}/$sectorsize) . " "; }
    	# glups...
    	
    	print "\t generating ASCII for $disk-p$p ...\n";
    	my $cmd = "/bin/dd if=" . $imagepath 
    		. " skip=" .  $parts{$p}{osects} . "$strcnt bs=512 2> /dev/null | "
    		. "$main::RVT_cfg->{tsk_path}/srch_strings -a -t d | tr /A-Z/ /a-z/ > " 
    		. "$stringspath/strings-$disk-$p.asc";
    	`$cmd`;

    	print "\t generating UNICODE for $disk-p$p ...\n";
    	my $cmd = "/bin/dd if=" . $imagepath 
    		. " skip=" .  $parts{$p}{osects} . "$strcnt bs=512 2> /dev/null | "
    		. "$main::RVT_cfg->{tsk_path}/srch_strings -a -t d  -e l | tr /A-Z/ /a-z/ > " 
    		. "$stringspath/strings-$disk-$p.uni";
    	`$cmd`;
    }

	print "\t strings done\n";
	return 1;
}




sub RVT_script_search_file_edit  {
    # takes a case and a file name and creates a file
    # in morgue/case-code/searches_files
    
    my $filename = shift (@_);
    my $case = shift;
    RVT_fill_level(\$case);
    $case = RVT_get_casenumber($case);
    return 0 unless ($case);
    return 0 unless ($filename);
    
    $filename =~ s/[\. \\\/]/-/g;
    
    my $searchfile_path = RVT_get_morguepath($case) . '/searches_files';
    if ( ! -d $searchfile_path )  { mkdir $searchfile_path or return 0; }
    
    system ('vim', $searchfile_path . '/' . $filename);

#    return 0 if ($? == -1);
#    return 1;
}

sub RVT_script_search_file_delete  {
    # takes a case and a file name and deletes that
    # file from the morgue/case-code/searches_files

    my $filename = shift (@_);
    my $case = shift;
    RVT_fill_level(\$case);
    $case = RVT_get_casenumber($case);
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
    
    my $case = shift;
    RVT_fill_level(\$case);
    $case = RVT_get_casenumber($case);
    return 0 unless ($case);
    
    my $searchfile_path = RVT_get_morguepath($case) . '/searches_files';
    if ( ! -d $searchfile_path )  { RVT_log('ERR', "No existe la carpeta $searchfile_path"); return 0; }    
    
    opendir (DIR, $searchfile_path) or return 0;
    my @f = sort grep { -f "$searchfile_path/$_" } readdir (DIR);
    closedir (DIR);
    
    print "\nFicheros de bœsqueda:\n";
    foreach my $f ( @f ) { 
        my $wc = `wc -l $searchfile_path/$f | cut -d" " -f 1`;
        chomp $wc;
        print "\t$f\t( $wc l’neas) \n" ; 
    }
    print "\n";
}

sub RVT_script_search_file_show  {
    # takes a case and a file name and opens a file
    # in morgue/case-code/searches_files
    
    my $filename = shift (@_);
    my $case = shift;
    RVT_fill_level(\$case);
    $case = RVT_get_casenumber($case);
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
	
	$disk = $main::RVT_level->{tag} unless $disk;
	
	# special matches supported:
	if ($re eq 'emails') { $name=$re; $re = '[a-z0-9._-]{2,25}@[a-z0-9.-]{3,35}\\.[a-z]{2,8}';	}
	if ($re eq 'accounts') { $name=$re; $re = '[0-9]{4}[-.\\s]+[0-9]{4}[-.\\s]+[0-9]{2}[-.\\s]+[0-9]{10}';	}
	if ($re eq 'ips') { $name=$re; $re = '[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}'; }
	if ($re eq 'phones') { $name=$re; $re = '([0-9]{2,3}[\\s\\.\\-])?[0-9]{2,3}[\\s\\.\\-][0-9]{2,3}[\\s\\.\\-][0-9]{2,3}'; }
	
	$re = lc ($re);
	if (!$name) {
		if ( $re !~ /^(\w+):(.*)$/ ) { RVT_log('ERR', "correct format is <name:regular expression>  or to use a special name"); return 0; }
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
    if (! -d $infopath) { RVT_log('ERR', "there is no path to the morgue/info!"); return 0};

    opendir (DIR, "$stringspath") or RVT_log('CRIT', "strings path not readable");
    my @strfiles = grep { /^strings/ } readdir(DIR);
    close DIR;
    if (! @strfiles) { RVT_log('ERR', "strings are not generated"); return 0; }	

	print "\t Begining to count for $name: \n\n";

	my %results;
	foreach my $s (@strfiles) {
		open (STR, "<$stringspath/$s") or RVT_log('CRIT', "unable to open string file: $!");
		while (my $l=<STR>) {
			next if ($l !~ /$re/); 
			$results{$&} = $results{$&} + 1;
		}
		close STR;
	}
	
	open (R, ">$infopath/count_$name.txt") or RVT_log('CRIT', "unable to open count file: $!");
	foreach my $k ( sort {$results{$a} <=> $results{$b}} keys %results) {
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
    
    $disk = $main::RVT_level->{tag} unless $disk;
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

#    return 1;
}


sub RVT_script_search_clusterlist {
    # extract cluster lists from a search
    # takes as arguments:
    #   file with searches
    #   disk

    my ( $searchesfilename, $ndisk ) = @_;

	$ndisk = $main::RVT_level->{tag} unless $ndisk;
   
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
            $l =~ /^.+?-\d{6}-\d{1,2}-\d{1,2}(\.dd)?-(\d{1,2})\.(asc|uni):\s*(\d+) /;
        
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
	                       $main::RVT_cases->{case}{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{clustersize} );
    	    my $loopdev = $main::RVT_cases->{case}{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{loop};
    	
    	    my $inodes = RVT_get_inodefromcluster( $du, "$ndisk-p$part" );
    	    foreach my $inode (@{$inodes}) {
    	        my $r_istat = RVT_tsk_istat ($ndisk, $part, $inode);
                my $path = `ffind /dev/$loopdev $inode`; 
                chomp $path;
                print $chandler "$du:$inode:".$r_istat->{allocationStatus}.":$path\n";
                print $phandler "$path (". $r_istat->{allocationStatus} .")\n";     
            }
        }
        close (BF);
        for my $f (keys %fnh) { close($fnh{$f}); }
    }    
     
    

    return 1;    
}


sub RVT_script_search_clusters  {
    # extract clusters from a search
    # takes as arguments:
    #   file with searches: one for line
    #   disk from the morgue
    # returns 1 if OK, 0 if errors

    my ( $searchesfilename, $ndisk ) = @_;

	$ndisk = $main::RVT_level->{tag} unless $ndisk;
   
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
    RVT_images_scan('all');
    
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
            $l =~ /^.+?-\d{6}-\d{1,2}-\d{1,2}(\.dd)?-(\d{1,2})\.(asc|uni):\s*(\d+) /;
        
            my $part = $2;
            my $offset = $4;
            my $fn = "$searchespath/i$f-$part";
            if (! defined($fnh{$fn})) {
       	        open ( $fnh{$fn}, ">$fn" ) or die "FATAL: $!";
            }
            my $fhandler = $fnh{$fn};

	        # cluster and allocation status
	        my $du = int( $offset /
	                      $main::RVT_cases->{case}{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{clustersize} );
    	    my $allocstat = RVT_tsk_blkstat ($ndisk, $part, $du);
    	    
 	        # strings line
       	    $l =~ /[^ ]+(.*)$/;
            my $string = $1;

            print $fhandler 	"\n\n\n---------------------------\n" .
            			$offset .":" .
            			$du .":" .
            			$allocstat .":" .
            			$string ."\n\n\n";
            
            # gets the cluster and prints it
       
            my $dd_command =    "dd" . 
                        " if=/dev/" .   $main::RVT_cases->{case}{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{loop} .
                        " bs=" .   $main::RVT_cases->{case}{$adisk->{case}}{device}{$adisk->{device}}{disk}{$adisk->{disk}}{partition}{$part}{clustersize} . 
                        " skip=" . $du .
                        " count=1 2> /dev/null |";
            open (DD, $dd_command) or RVT_log('CRIT', "unable to extract cluster (is image mounted?): $!");
            while (<DD>) { print $fhandler $_; }
            close (DD);
            
        }
        close (BF);
    }    
     
    for my $fn (keys %fnh) { close($fnh{$fn}); }

#    return 1;      
}    
   


1;  

