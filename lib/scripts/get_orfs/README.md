# get\_orfs

FILE: get\_orfs.pl  
AUTH: Paul Stothard <stothard@ualberta.ca>  
DATE: June 22, 2020  
VERS: 1.2  

This script accepts a sequence file as input and extracts the open reading frames (ORFs) greater than or equal to the specified size. The resulting ORFs can be returned as DNA sequences, or as protein sequences translated using the specified genetic code. The titles of the sequences include start, stop, strand, and reading frame information. The sequence numbering includes the stop codon (when encountered) but the translations do not include a stop codon character. If the input file consists of multiple sequence records they are merged into a single record and coordinates and reading frame are expressed relative to the single merged sequence.

The start and stop codons used when identifying ORFs are specified using the 'starts' and 'stops' options. 

This script requires the `Bio::SeqIO`, `Bio::SeqUtils`, and `Bio::Tools::CodonTable` Perl modules. These can be installed using CPAN, e.g.:

```
sudo perl -MCPAN -e "install Bio::SeqIO"
sudo perl -MCPAN -e "install Bio::SeqUtils"
sudo perl -MCPAN -e "Bio::Tools::CodonTable"
```

## Usage

```
get_orfs.pl - identify open reading frames and return their DNA sequences or
protein translations.

DISPLAY HELP AND EXIT:

usage:

  perl get_orfs.pl -help

RETURN ORF TRANSLATIONS OR CODING SEQUENCES

usage:

  perl get_orfs.pl -i <file> -o <file> -m <integer> [Options]

required arguments:

-i - Input file in FASTA, RAW, EMBL, or GenBank format.

-o - Output file in FASTA format of translations or coding sequences to create.

-m - Minimum ORF size in codons.

optional arguments:

-dna - Whether DNA coding sequences should be returned instead of their protein
translations. [T/F]. Default is F.

-starts - Start codons. [String]. Default is 'atg|ttg|att|gtg|ctg'. To allow ORFs to
begin with any codon, use the value 'any'.

-stops - Stop codons. [String]. Default is 'taa|tag|tga'.

-g - Genetic code for translating ORFs, using NCBI numbering. [Integer].
Default is 1.

example usage:

  perl get_orfs.pl -i input.gbk -o output.fasta -g 11 -m 100
```
