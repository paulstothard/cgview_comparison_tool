# sequence\_to\_multi\_fasta

FILE: sequence\_to\_multi\_fasta.pl  
AUTH: Paul Stothard <stothard@ualberta.ca>  
DATE: June 22, 2020  
VERS: 1.2  

This script accepts a file consisting of a single DNA sequence (in FASTA, RAW, EMBL, or GenBank format), and then divides the sequence into smaller sequences of the size you specify. The new sequences are written to a single output file with a modified title giving the position of the subsequence in relation to the original sequence. The new sequences are written in FASTA format. If the input file consists of multiple sequence records they are merged into a single record prior to splitting and coordinates are expressed relative to the single merged sequence. 

This script requires the `Bio::SeqIO` and `Bio::SeqUtils` Perl modules. These can be installed using CPAN, e.g.:

```
sudo perl -MCPAN -e "install Bio::SeqIO"
sudo perl -MCPAN -e "install Bio::SeqUtils"
```

## Usage

```
sequence_to_multi_fasta.pl - split a DNA sequence.

DISPLAY HELP AND EXIT:

usage:

  perl sequence_to_multi_fasta.pl -help

SPLIT DNA SEQUENCE

usage:

  perl sequence_to_multi_fasta.pl -i <file> -o <file> [Options]

required arguments:

-i - Input file in FASTA, RAW, EMBL, or GenBank format.

-o - Output file in FASTA format of sequence fragments.

optional arguments:

-v - The overlap to include between sequences, in bases. [Integer].

-s - The size of the sequences to create, in bases. [Integer]. Default is to
return the entire sequence as a single FASTA record.

example usage:

  perl sequence_to_multi_fasta.pl -i input.gbk -o output.fasta -s 10000 -v 500
```
