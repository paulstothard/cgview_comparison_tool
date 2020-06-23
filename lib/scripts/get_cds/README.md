# get\_cds

FILE: get\_cds.pl  
AUTH: Paul Stothard <stothard@ualberta.ca>  
DATE: June 22, 2020  
VERS: 1.2  

This script accepts a GenBank or EMBL file and extracts the protein translations or the DNA coding sequences and writes them to a new file in FASTA format. Information indicating the reading frame and position of the coding sequence relative to the source sequence is added to the titles. If the input file consists of multiple sequence records they are merged into a single record and coordinates and reading frame are expressed relative to the single merged sequence. 

This script requires the `Bio::SeqIO` and `Bio::SeqUtils` Perl modules. These can be installed using CPAN, e.g.:

```
sudo perl -MCPAN -e "install Bio::SeqIO"
sudo perl -MCPAN -e "install Bio::SeqUtils"
```

## Usage

```
get_cds.pl - extract translations or coding sequences from a GenBank or EMBL
file.

DISPLAY HELP AND EXIT:

usage:

  perl get_cds.pl -help

EXTRACT TRANSLATIONS OR CODING SEQUENCES

usage:

  perl get_cds.pl -i <file> -o <file> [Options]

required arguments:

-i - Input file in GenBank or EMBL format.

-o - Output file in FASTA format of translations or coding sequences to create.

optional arguments:

-dna - Whether DNA coding sequences should be returned instead of their protein
translations. [T/F]. Default is F.

example usage:

  perl get_cds.pl -i input.gbk -o output.fasta
```
