#!/usr/bin/perl
# 
# Uses gnuplot to represent time values in two modes: values vs time and
# integration of the appearance of the values
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
use Date::Manip;
use File::ReadBackwards;

# gnuplot check
my $grep = `gnuplot -V`;
(($grep =~ /gnuplot (\d)\.(\d)/) && ($1 >= 4) && (($1+$2) >= 6))  or  die "GNUPLOT v4.2 or greater needed on path";


my $_version = '0.2';
my $_args = join(' ', @ARGV);

my %Delta = (   ''       => '+0:0:0:0:0:0',
                'day'    => '+0:0:1:0:0:0',  
                'hour'   => '+0:0:0:1:0:0'
                ) ;

my %mDelta = (  ''       => '-0:0:0:0:0:0',
                'day'    => '-0:0:1:0:0:0',  
                'hour'   => '-0:0:0:1:0:0'
                ) ;


sub usage {

   my $error;
   if ($error = shift(@_)) { print "\nERROR: $error \n\n"; }

   print <<EOF ;

   plot_time.pl version $_version, Copyright (C) 2008 by dervitx
   This is free software distributed under GNU GPL v2 license

   plot_time.pl takes a file with values separated by a delimiter, being one
   of them, a date/time. It works in two possible modes:

   First mode: represents a value in the field -vf as a function of time (-tf)
   Second mode: integrates the appareance of values as a function of time, 
   with a discrete period of -period

   On both modes, it calls gnuplot in order to generate the datafile and the
   graph file (png format).

   perl plot_time.pl [--option=option value]  [filename]

        -tf field       field where data/time values are found
        -vf field       field where values are found
        -interval number
                        graph time interval in YYYYMMDDhh:mm:ss format
                        see 'man Date::Manip' for more format information
                        and examples below
                        the keywords 'first' and 'last' can also be used,
                        and represent the first and last temporal values
        -delimiter character
                        file delimiter. Default is ','
        -sum            represents the appearance of values as a function
                        of time with a period given by -period
        -period number  see -sum. Can be 'day' or 'hour'
        -skiplines=number
                        skips the first lines of the file
        -exclude=regular expression
                        exclude all lines that match this regular expression
        -output=name    output files will be name.data and name.png. Defaults
                        to filename
        filename        if not present, standard input is taken
        help            shows this help


   Examples:

      1) the following command represents the value found on the second field
      as a function of time. Results are found in datafile.csv.data and
      datafile.csv.png

      perl plot_time.pl -tf 1 -vf 2  datafile.csv

      2) same as (1) but only with data of the last month from today

      perl plot_time.pl -tf 1 -vf 2 -interval='today - 1 month' datafile.csv

      3) same as (2) but only with data of the last month from the last
      data of the file
      
      perl plot_tile.pl -tf 1 -vf 2 -interval='last - 1 month' datafile.csv

      4) same as (1) but only with data of 2007

      perl plot_time.pl -tf 1 -vf 2 -interval='2007 + 1 year' datafile.csv

      5) represents the appearance of activity of a timeline on February

      perl plot_time.pl -tf 1 -interval='20080201 20080229' -period='day' \
             -sum timeline.csv

EOF

   exit;
}

GetOptions(
        "skiplines:i"           => \$skiplines,
        "excluderegexpr:s"      => \$excluderegexpr,
        "tf=i"                  => \$tf,        # timefield
        "vf=i"                  => \$vf,        # valuefield
        "interval:s"            => \$interval,
        "delimiter:s"           => \$delimiter,
        "period:s"              => \$period,
        "sum"                   => \$sum,
        "output:s"              => \$output,
        "help"                  => \$help
        );

usage() if $help;
usage('Too many arguments') if ($#ARGV > 0);
usage('No time field (-tf)') if (!$tf);
usage('No value field (-vf)') if (!$vf and !$sum);
usage('No period (-period)') if ($sum and !$period);
$filename = ($ARGV[0])?$ARGV[0]:'-';
$delimiter = ',' unless $delimiter;
$output = $filename if (!$output); 
$vf = $tf if (!$vf);

my ($tmin, $tmax);
my ($datatmin, $datatmax);
my ($graphtmin, $graphtmax);

if ($interval) {
   my @t = split(' ',$interval);
   $tmin = $t[0];
   my $interval = join(' ',@t[1..$#t]);
   if (($tmin eq 'last') or ($tmin eq 'first')) { 
      $tmin = ParseMin($tmin); 
      } else { 
      $tmin = ParseDate($tmin);
      }
   if      ($interval =~ /^\+/) { $tmax = DateCalc($tmin, $interval); 
   } elsif ($interval =~ /^-/)  { $tmax=$tmin; $tmin = DateCalc($tmin, $interval); 
   } elsif (!($tmax=ParseDate($interval)))  { usage(); }
   usage() unless ($tmin and $tmax and ($tmin lt $tmax));
} 


open (TEMP, ">$output.data") or die "FATAL: $!";
open (DATA, "<$filename") or die "FATAL: $!";

my $pult;
my $cc = 0;

print TEMP "# plot_time.pl, version $_version \n";
print TEMP '# arguments: ' . $_args . "\n\n";
while (<DATA>) {
   if ($skiplines) { $skiplines--; next; }
   if ($excluderegexpr) { next if /$excluderegexpr/; }
   chomp;
   my $time = (split($delimiter))[$tf-1];
   my $value = (split($delimiter))[$vf-1];
   if (!$time or !$value) {next;}
   my $ptime = ParseDate($time);
   next unless $ptime;
   if ($tmin and ($ptime lt $tmin)) { next; }
   if ($tmax and ($ptime gt $tmax)) { last; }
   if (!$datatmin) { $datatmin = $ptime; }
   $datatmax = $ptime;
   if (!$sum) { print TEMP "$ptime \t $value \n"; next; }

   # if $sum
   if (!$pult) { $pult = calc_p0( $ptime ); }
   if ( Date_Cmp( DateCalc($pult,$ptime), $Delta{$period}) < 0 ) { $cc++; next; }
   print TEMP "$pult \t $cc \n";
   $cc = 1;
   $pult = calc_p0( $ptime );
}

if ($sum) { print TEMP "$pult \t $cc \n"; }
 
close (DATA,TEMP);


# and now, plot the graph

if ($period and $tmin and $tmax) {
   $graphtmin = calc_p0( $tmin );
   if ( !Date_Cmp($graphtmin, $tmin) ) { $graphtmin = DateCalc($tmin, $mDelta{$period}); }
   $graphtmax = calc_p0( DateCalc($tmax,  $Delta{$period}) );
} else {
   $graphtmin = calc_p0( $datatmin );
   if ( !Date_Cmp($graphtmin, $datatmin) ) { $graphtmin = DateCalc($datatmin, $mDelta{$period}); }
   $graphtmax = calc_p0( DateCalc($datatmax, $Delta{$period}) );
}

open (GNUPLOT, "| gnuplot") or die "FATAL: $!";

my $plot = <<EOF ;

set terminal png
set output "$output.png"
unset key
set xdata time
set format x "%d %b %Hh"
set timefmt "%Y%m%d%H:%M:%S"
set xrange ["$graphtmin":"$graphtmax"]
set yrange [0:]
set xtics border in scale 1,0.5 nomirror rotate by 90
set ytics border in scale 1,0.5 nomirror 
plot "$output.data" using 1:2 lw 2 with impulses

EOF

print GNUPLOT $plot;

close (GNUPLOT);

exit;





sub ParseMin ($) {
   # argument can be 'last' or 'first'
   # if 'first', first date of the file is used
   # if 'last', last date of the file is used

   my $arg = shift(@_);
   if ($filename eq '-') { usage(); }

   my $tdate;

   if ($arg eq 'last') {
      # File::ReadBackwards
      tie (*DATA, 'File::ReadBackwards', $filename) or  die "FATAL: $!";
   }

   if ($arg eq 'first') {
        open (DATA, "<$filename") or die "FATAL: $!";
   }

   return unless DATA;
   for $c (1..100) {     # only looks in the first (or last) lines
      my $l = <DATA>;
      if ($excluderegexpr) { next if $l=~/$excluderegexpr/; }
      my $ldate = (split($delimiter,$l))[$tf-1];
      if (ParseDate($ldate)) { $tdate = ParseDate($ldate); last; }
   }

   close(DATA);
   untie(*DATA);
   return $tdate;
}


sub calc_p0 {

   my $time = shift(@_);
   # $period

   if ($period eq 'day') { 
        $time =~ /^(\d\d\d\d\d\d\d\d)\d\d:\d\d:\d\d/ ;
        return $1 . "00:00:00";
   }

   if ($period eq 'hour') { 
        $time =~ /^(\d\d\d\d\d\d\d\d\d\d):\d\d:\d\d/ ; 
        return $1 . ":00:00";
   }

   return $time;  # do nothing
}
