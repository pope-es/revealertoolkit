#!/usr/bin/perl
#
# Converts a separated value file to a latex table
# This script uses guess_csv.pl to guess the data delimiter,
# if not given
# Please, use --help option for more details
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

GetOptions(
        "delimiter:s"           => \$delimiter,
        "firstline"            => \$firstline,
        "longtable"            => \$longtable,
        "float"                => \$float,
        "headers!"              => \$headers,
        "skiplines:i"           => \$skiplines,
        "excluderegexpr:s"      => \$excluderegexpr,
        "help"                  => \$help
        );

usage() if $help;
usage() if ($#ARGV > 0);
$filename = ($ARGV[0])?$ARGV[0]:'-';

sub usage {

   print <<EOF ;

   csv2latex.pl version $_version, Copyright (C) 2008 by dervitx
   This is free software distributed under GNU GPL v2 license

   guess_csv.pl tries to identify the delimiter character of a value
   separated data file, and returns the data ready to be inserted in a
   LaTeX table.

   perl csv2latex.pl  [-lf] [-first] [-(no)headers] [-options=optionvalue]  [filename]

        -delimiter=char uses char as data separator. If not present, this
                        script uses guess_csv.pl to guess it. If not, comma
                        is used
        -firstline      separator is specified in the first line of the file
        -long           longtable environment used instead of tabular
        -float          uses a table environment to float the table
        -noheaders      print no headers, only the data (default)
        -headers        print environment headers
        -skiplines=number
                        skips this number of lines 
        -exclude=regular expression
                        exclude all lines that match this regular expression
        filename        if not present, standard input is taken
        help            shows this help

EOF

   exit;
}


if (!$delimiter and ($filename ne '-') and !$firstline) {
   # TODO check if guess_csv.pl exists in the path
   $delimiter = `perl guess_csv.pl --head=10 --skip=1  $filename`;
   chomp ($delimiter);
}

if (!$delimiter) { $delimiter = ','; }

open (FILE, "<$filename") or die "FATAL: $!";

if ($firstline) {
   $delimiter = <FILE>;
   chomp ($delimiter);
   $delimiter =~ /^.$/ or die "FATAL: I do not find valid delimiter in first line"
}

my $tab;
if ($headers) {
   if ($float and !$longtable) {
      print '\\begin{table}[p]' . "\n";
      $tab = "\t";
   }
   if ($longtable) {
      print '\\begin{longtable}{ xx }' . "\n";
      print ' header1 & header2 & xx \\\\' . "\n";
      print '\\endhead' . "\n";
   } else {   
      print $tab . '\begin{tabular}{ xx }' . "\n";
   }
   $tab .= "\t";
}

while (<FILE>) {
   if ($skiplines) { $skiplines--; next; }
   if ($excluderegexpr) { next if /$excluderegexpr/; }
   chomp;
   my @values = split ($delimiter);
   
   @values = map { escape_latex($_); } @values;

   print $tab . join (' & ', @values) . ' \\\\' . "\n";
}

if ($headers) {
   if ($longtable) {
      print '\\end{longtable}' . "\n";
   } else {
      $tab =~ s/\t//;;
      print $tab . '\\end{tabular}' . "\n";
   }
   if ($float and !$longtable) {
      print '\\end{table}' . "\n";
   }
}


sub escape_latex {
   # escapes special latex characters

   s/\\/\$\\backslash\$/g;
   s/\\/\\\\/g;
   s/&/\\&/g;
   s/_/\\_/g;

   # ... more?
   
   return $_;
}