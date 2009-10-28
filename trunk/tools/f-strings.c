/*
#
#  Revealer Tools - f-strings
#
#    Copyright (C) 2009 Jose Navarro a.k.a. Dervitx
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
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#ifdef HAVE_FOPEN64
typedef off64_t file_off;
#define file_open(s,m) fopen64(s, m)
#define file_tell(f) ftello64(f)
#else
typedef off_t file_off;
#define file_open(s,m) fopen(s, m)
#define file_tell(f) ftello(f)
#endif

void print_usage ()  {
    printf ("\n");
    printf ("  Revealer Tools, forensic strings, 09-2009\n");
    printf ("  USAGE:  f-strings  [-t] [-n <number>] [-f]  <file>\n");
    printf ("\n");
    printf ("  -t             Print the location of the string in base 10\n");
    printf ("  -n <number>    Locate & print any sequence of printable characters\n");
    printf ("                 of at least <number> characters (default 4)\n");
    printf ("  -h             Display this information\n");
    printf ("\n");
    printf ("  f-strings get a file and prints at stdout all printable characters\n");
    printf ("  like binutils' strings function, BUT:\n");
    printf ("    - convert all that 'seems' latin1, UTF-8 and UTF-16, little endian\n");
    printf ("      to plain ASCII\n"); 
    printf ("    - translates some special characters. For example, accented a's are translated\n");
    printf ("      to the ASCII character 'a'. All vowels, plus spanish and catalan special\n"); 
    printf ("      characters are translated\n");    
    printf ("    - lowercases all printable characters\n");    
    printf ("\n");
    printf ("  known issues:\n");
    printf ("    - only one file at each execution\n");
    printf ("    - offset is printed only in base 10, so argument -t do not \n");
    printf ("      accept subarguments, and '-t' is equivalent to '-t d' of\n");
    printf ("      binutils' strings\n");
    printf ("    - \\x00 characters are ignored, so in a hard disk full of zeros\n");
    printf ("      with 'Hey ' at the begining and 'Ho' at the end, f-strings will\n");
    printf ("      extract the string 'Hey Ho'\n");
    printf ("\n");
    printf ("  more information at http://code.google.com/p/revealertoolkit/\n");
    printf ("\n");
}


int main(int argc, char **argv) {

    int print_offset = 0;
    int print_filename = 0;
    int strmin = 4;
    int copt;
    char * filename;

    while ((copt = getopt (argc, argv, "n:fthH?")) != -1 )
        switch (copt)
          {
          case 'n':
            if ( *optarg >= 49 && *optarg <= 57) 
                strmin = *optarg - 48;   // 1 y ASCII character 49
            break;    
          case 'f':
            print_filename = 1;
            break;
          case 't':
            print_offset = 1;
            break;
          case 'h':
            print_usage();
            return -1;
          case 'H':
            print_usage();
            return -1;
          default:
            print_usage();
            return -1;
          }

    if ( optind != (argc -1) ) {
        print_usage();
        return -1;
    }    
    
    filename = argv[optind];

	unsigned int *buf =  (unsigned int *)  malloc (sizeof (unsigned int) * (strmin +1)  );		
	FILE *fich;
	unsigned int c;
	unsigned int cc;
	unsigned int n;
	int i;
	int ii;
	file_off offset;

	// conversion matrix
	unsigned int m[512];
    for (i=0; i<512; i++) { m[i] = 0; }

	m[9] = 9;   // TAB
 
	m[32] = 32; // printable ASCII
	m[33] = 33;
	m[34] = 34;
	m[35] = 35;
	m[36] = 36;
	m[37] = 37;
	m[38] = 38;
	m[39] = 39;
	m[40] = 40;
	m[41] = 41;
	m[42] = 42;
	m[43] = 43;
	m[44] = 44;
	m[45] = 45;
	m[46] = 46;
	m[47] = 47;
	m[48] = 48;
	m[49] = 49;
	m[50] = 50;
	m[51] = 51;
	m[52] = 52;
	m[53] = 53;
	m[54] = 54;
	m[55] = 55;
	m[56] = 56;
	m[57] = 57;
	m[58] = 58;
	m[59] = 59;
	m[60] = 60;
	m[61] = 61;
	m[62] = 62;
	m[63] = 63;
	m[64] = 64;
	m[65] = 97;
	m[66] = 98;
	m[67] = 99;
	m[68] = 100;
	m[69] = 101;
	m[70] = 102;
	m[71] = 103;
	m[72] = 104;
	m[73] = 105;
	m[74] = 106;
	m[75] = 107;
	m[76] = 108;
	m[77] = 109;
	m[78] = 110;
	m[79] = 111;
	m[80] = 112;
	m[81] = 113;
	m[82] = 114;
	m[83] = 115;
	m[84] = 116;
	m[85] = 117;
	m[86] = 118;
	m[87] = 119;
	m[88] = 120;
	m[89] = 121;
	m[90] = 122;
	m[91] = 91;
	m[92] = 92;
	m[93] = 93;
	m[94] = 94;
	m[95] = 95;
	m[96] = 96;
	m[97] = 97;
	m[98] = 98;
	m[99] = 99;
	m[100] = 100;
	m[101] = 101;
	m[102] = 102;
	m[103] = 103;
	m[104] = 104;
	m[105] = 105;
	m[106] = 106;
	m[107] = 107;
	m[108] = 108;
	m[109] = 109;
	m[110] = 110;
	m[111] = 111;
	m[112] = 112;
	m[113] = 113;
	m[114] = 114;
	m[115] = 115;
	m[116] = 116;
	m[117] = 117;
	m[118] = 118;
	m[119] = 119;
	m[120] = 120;
	m[121] = 121;
	m[122] = 122;
	m[123] = 123;
	m[124] = 124;
	m[125] = 125;
	m[126] = 126;

   	m[192] = 97;  // printable LATIN1
	m[193] = 97;
	m[194] = 97;
	m[195] = 97;
	m[196] = 97;
	m[197] = 97;
	m[199] = 99;
	m[200] = 101;
	m[201] = 101;
	m[202] = 101;
	m[203] = 101;
	m[204] = 105;
	m[205] = 105;
	m[206] = 105;
	m[207] = 105;
	m[209] = 110;
	m[210] = 111;
	m[211] = 111;
	m[212] = 111;
	m[213] = 111;
	m[214] = 111;
	m[217] = 117;
	m[218] = 117;
	m[219] = 117;
	m[220] = 117;
	m[224] = 97;
	m[225] = 97;
	m[226] = 97;
	m[227] = 97;
	m[228] = 97;
	m[229] = 97;
	m[231] = 99;
	m[232] = 101;
	m[233] = 101;
	m[234] = 101;
	m[235] = 101;
	m[236] = 105;
	m[237] = 105;
	m[238] = 105;
	m[239] = 105;
	m[241] = 110;
	m[242] = 111;
	m[243] = 111;
	m[244] = 111;
	m[245] = 111;
	m[246] = 111;
	m[249] = 117;
	m[250] = 117;
	m[251] = 117;
	m[252] = 117;


	m[384] = 97;   // printable UTF8 (+256)
	m[385] = 97;
	m[386] = 97;
	m[387] = 97;
	m[388] = 97;
	m[389] = 97;
	m[416] = 97;
	m[417] = 97;
	m[418] = 97;
	m[419] = 97;
	m[420] = 97;
	m[421] = 97;    
    
	m[392] = 101;
	m[393] = 101;
	m[394] = 101;
	m[395] = 101;
	m[424] = 101;
	m[425] = 101;
	m[426] = 101;
	m[427] = 101;

	m[396] = 105;
	m[397] = 105;
	m[398] = 105;
	m[399] = 105;	
	m[428] = 105;
	m[429] = 105;
	m[430] = 105;
	m[431] = 105;

	m[402] = 111;
	m[403] = 111;
	m[404] = 111;
	m[405] = 111;
	m[406] = 111;	
	m[434] = 111;
	m[435] = 111;
	m[436] = 111;
	m[437] = 111;
	m[438] = 111;

	m[409] = 117;
	m[410] = 117;
	m[411] = 117;
	m[412] = 117;
	m[441] = 117;
	m[442] = 117;
	m[443] = 117;
	m[444] = 117;

	m[391] = 99;	
	m[401] = 110;	
	m[423] = 99;	
	m[433] = 110;	
	
	
	

	fich = file_open( filename, "rb" );
	offset = ftello(fich);
	
	while ( 1 ) { 	
	
		tryline:
		offset = file_tell(fich);
		for (i = 0; i < strmin; i++) {
			c = fgetc(fich);
			switch (c) 	
			{
			case EOF:  
			    return;
			case 0 : 
			    c = fgetc(fich);
			    break;
			case 195 : 
				n = fgetc(fich); 
				if ( n != EOF  &&  m[n+256] != 0 ) 
				    c = n + 256;
				  else
				    ungetc(n, fich);
				break;    
			}
			
			cc = m[c];
			if ( cc == 0 ) { goto tryline; }
			buf[i] = cc;
		}

        if (print_filename)
            printf ("%s: ", filename);
		if (print_offset) 
		   printf ("%7li ", offset);

		// print buffer and following printable characters

		for ( ii = 0; ii < i; ii++ ) {
			putchar ((char) buf[ii]); 
		}		

		while (1) {
			c = fgetc(fich);
			switch (c)	
			{
			case EOF:  
			    putchar ('\n');
			    return;
			case 0 : 
			    c = fgetc(fich);
			    break;
			case 195 : 
				n = fgetc(fich); 
				if ( n != EOF  &&  m[n+256] != 0 ) 
				    c = n + 256;
				  else
				    ungetc(n, fich);
				break;    
			}
			
			cc = m[c];
			if ( cc == 0 )  break;
			putchar ((char) cc);
		}

		putchar ('\n');
	}

	return 0;
}










