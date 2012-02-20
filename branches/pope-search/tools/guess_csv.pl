#!/usr/bin/perl
#
# gets a separated-value file and tries to guess
# which is the character that separates the values
# Please, use --help option for more details
#
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

use Getopt::Long;

my $_version = '0.2';

my @most_possible = ( ",", "\t", ";", "|", "#" );
my %chars_av;   # $char{ char } = average of appareance
my %chars_sig;  # $char{ char } = average of the dispersion
my $nn = 0;     # line counter



GetOptions(
        "headlines:i"           => \$headlines,
        "skiplines:i"           => \$skiplines,
        "verbose"               => \$verbose,
        "fields"                => \$fields,
        "excluderegexpr:s"      => \$excluderegexpr,
        "help"                  => \$help
        );

usage() if $help;
usage() if ($#ARGV > 0);
$filename = ($ARGV[0])?$ARGV[0]:'-';

sub usage {
   print <<EOF ;

   guess_csv.pl version $_version, Copyright (C) 2008 by dervitx
   This is free software distributed under GNU GPL v2 license

   guess_csv.pl tries to identify the delimiter character of a value
   separated data file, and returns the best guess.

   this script is simple, and gets easily confused if not all the lines
   have the same structure and with short files.

   perl guess_csv.pl [-v] [--option=option value]  [filename]

        -fields         script outputs separator AND number of fields
        -verbose        output contains statistics of the evaluation
        -headlines=number
                        uses only this number of lines for the analysis
        -skiplines=number
                        skips the first lines of the file
        -exclude=regular expression
                        exclude all lines that match this regular expression
        filename        if not present, standard input is taken
        help            shows this help

EOF

   exit;
}


open (FILE, "<$filename") or die "FATAL: $!";
while (<FILE>) {
   if ($skiplines) { $skiplines--; next; }
   if ($excluderegexpr) { next if /$excluderegexpr/; }
   $nn++;
   if ( ($headlines) and ($headlines < $nn) ) { last; }
   chomp; 
   my %line_chars; # counter for the current line

   @chars = split('');
   %line_chars = map { $_ => ++$line_chars{$_} } @chars;

   my %union;
   foreach $u ( (keys(%line_chars), keys(%chars_av)) ) { $union{$u} = 1; }

   foreach $c ( keys %line_chars ) {
        # sumatory for the average
        $chars_av{$c} += $line_chars{$c};
   }

   foreach $c ( keys %union ) {
        # some kind of dispersion
        $chars_sig{$c} =  $chars_sig{$c} + abs(($line_chars{$c}/$chars_av{$c}*$nn-1))  ;
   }

}
close FILE;

my @sorted_keys =  sort { $chars_sig{$a} <=> $chars_sig{$b} } keys %chars_sig ;

#
# now, what happens if we don't have a unic best result?

my @mpr;   # most possible result
if (!$verbose) {
   my $best_sig = $chars_sig{ $sorted_keys[0] };
   for $c ( 0..$#sorted_keys ) {
      if ( $chars_sig{$sorted_keys[$c]} > $best_sig ) { last; }
      @mpr = grep { $_ eq $sorted_keys[$c] } @most_possible;
      if ($mpr[0]) { last; } 
   }
}


#
# printing results

my $numfields;

if ( $verbose ) {
        print "\n guess_csv.pl version $_version\n";
        print " $nn lines evaluated. Five best results presented: \n\n delimiter: average pseudodesviation\n\n" if $verbose;
        foreach $c ( @sorted_keys[0..4] ) { print " $c:  " . ($chars_av{$c}/$nn) . " \t $chars_sig{$c} \n" }
        print "\n";
} elsif ($mpr[0]) {
        if ($fields) { $numfields = "  " . ( int($chars_av{$mpr[0]}/$nn + 0.5) ); }
        print $mpr[0] . $numfields . "\n";
} else {
        if ($fields) { $numfields = "  " . ( int($chars_av{$sorted_keys[0]}/$nn + 0.5) ); }
        print $sorted_keys[0] . $numfields . "\n";
}