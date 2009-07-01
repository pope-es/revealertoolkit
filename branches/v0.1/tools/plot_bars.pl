#!/usr/bin/perl
# 
# Uses gnuplot to create histogram (bars) graphs from a data file
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

my $_version = '0.1';
my $_args = join(' ', @ARGV);


sub usage {

   my $error;
   if ($error = shift(@_)) { print "\nERROR: $error \n\n"; }

   print <<EOF ;

   plot_bars.pl version $_version, Copyright (C) 2008 by dervitx
   This is free software distributed under GNU GPL v2 license

   plot_t.pl takes a file with values separated by a delimiter, being one
   of them, a date/time. It works in two possible modes:

   plot_bars.pl takes a file with values separated by a delimiter, and
   represents one of them as a histogram (bars). It accepts xvalues as
   the labels of the columns.

   It creates a data file an calls gnuplot in order to generate the graph 
   file (png format).

   perl plot_bars.pl [--option=option value]  [filename]

        -xf field       field where labels values are found. If not given,
                        numbers are used
        -vf field       field where values are found
        -delimiter character
                        file delimiter. Default is ','
        -yaxis          if 'total', values are plotted as a percentage of the
                        sum of all values
                        if 'max', values are plotted as a perceptage of the 
                        maximum value
                        if not present, absolut values are plotted
        -yaxismin       fixes axis minimum
        -yaxismax       fixes axis maximum. If not present, defaults to the 
                        110% of the maximum value (could cause problems if the
                        origin is far from zero !)
        -skiplines=number
                        skips the first lines of the file
        -exclude=regular expression
                        exclude all lines that match this regular expression
        -output=name    output files will be name.data and name.png. Defaults
                        to filename
        filename        if not present, standard input is taken
        help            shows this help

EOF

   exit;
}

GetOptions(
        "skiplines:i"           => \$skiplines,
        "excluderegexpr:s"      => \$excluderegexpr,
        "xf=i"                  => \$xf,        # x field
        "vf=i"                  => \$vf,        # valuefield
        "delimiter:s"           => \$delimiter,
        "output:s"              => \$output,
        "title:s"               => \$title,
        "yaxis:s"               => \$yaxis,
        "yaxismax:s"            => \$yaxismax,
        "yaxismin:s"            => \$yaxismin,
        "help"                  => \$help
        );

usage() if $help;
usage('Too many arguments') if ($#ARGV > 0);
$vf = 1 if (!$vf);
$filename = ($ARGV[0])?$ARGV[0]:'-';
$delimiter = ',' unless $delimiter;
$output = $filename if (!$output); 

open (TEMP, ">$output.tmpdata") or die "FATAL: $!";
open (DATA, "<$filename") or die "FATAL: $!";

my $totalvalue;     # summatory of $value
my $maxvalue;       # maximum of $value
my $counter;        # number of values

while (<DATA>) {
   if ($skiplines) { $skiplines--; next; }
   if ($excluderegexpr) { next if /$excluderegexpr/; }
   chomp;
   my $xvalue = (split($delimiter))[$xf-1]      if ($xf);
   my $value = (split($delimiter))[$vf-1];
   print TEMP "$xvalue $delimiter $value\n";

   $counter++ ;
   $totalvalue += $value; 
   $maxvalue = ($maxvalue>$value)?$maxvalue:$value ; 
}
my $reference;
if      ($yaxis eq 'total') {   $reference = $totalvalue / 100  ;
} elsif ($yaxis eq 'max') {     $reference = $maxvalue / 100 ;
} else {                        $reference = 1 ; 
}

close (DATA,TEMP);


open (DATA, ">$output.data") or die "FATAL: $!";
open (TEMP, "<$output.tmpdata") or die "FATAL: $!";


print DATA "# plot_bars.pl, version $_version \n";
print DATA '# arguments: ' . $_args . "\n\n";
while (<TEMP>) {
   chomp;
   my $xvalue = '"' . (split($delimiter))[0] .'"'       if ($xf);
   my $value = (split($delimiter))[($xf)?1:0];

   $value = $value / $reference ;
   print DATA "$xvalue $value\n";
}

close (TEMP,DATA);
unlink "$output.tmpdata";

# and now, plot the graph

my $plotstr = ($xf)?'2:xticlabels(1)':'1';
# yrange
if (!$yaxismax) { $yaxismax = $maxvalue * 1.10 ; }
if (!$yaxismin) { $yaxismin = '*'; }
my $yrange = '[' . $yaxismin . ':' . $yaxismax . ']';

open (GNUPLOT, "| ./gnuplot") or die "FATAL: $!";

my $plot = <<EOF ;

set terminal png enhanced font "./Verdana.ttf" 14
set output "$output.png"
unset key
set boxwidth 0.7 relative
set style fill solid 0.8
set ylabel "$title"
set xrange [-1:$counter]
set yrange $yrange
set xtics border in scale 1,0.5 nomirror rotate by 90 
set ytics border in scale 1,0.5 nomirror rotate by 90 
plot '$output.data' using $plotstr with boxes

EOF

print GNUPLOT $plot;

close (GNUPLOT);


exit;
