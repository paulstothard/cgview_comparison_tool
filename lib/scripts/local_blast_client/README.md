# local\_blast\_client

FILE: local\_blast\_client.pl  
AUTH: Paul Stothard <stothard@ualberta.ca>  
DATE: June 22, 2020  
VERS: 1.2  

This script performs BLAST searches against a local database. Each hit and its descriptive title are written to a single tab-delimited output file. The results are formatted for use with the `-blast` option of the `cgview_xml_builder.pl` script.

This script requires `blastall` and `formatdb` from [legacy BLAST](https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/). The path to the `blastall` and `formatdb` program directory should be added to `PATH`. Alternatively, the path to `blastall` can be specified using the `-y` option. 

The database to be searched needs to first be formatted using the `formatdb` program, e.g.:

```
#a DNA database
formatdb -i sequences.fasta -p F

#a protein database
formatdb -i sequences.fasta -p T
```

## Usage

```
local_blast_client.pl - local BLAST searches using legacy BLAST.

DISPLAY HELP AND EXIT:

usage:

  perl local_blast_client.pl -help

PERFORM LOCAL BLAST SEARCH

usage:

  perl local_blast_client.pl -i <file> -o <file> -d <file> -b <string> [Options]

required arguments:

-i - Input file containing one or more sequences in FASTA format.

-o - Output file in tab-delimited format to create.

-d - Database to search.

-b - BLAST search type: blastn, blastp, blastx, tblastn, or tblastx.

optional arguments:

-h - Number of HSPs to keep per query. [Integer]. Default is to keep all HSPs.

-filter - Whether to filter query sequence. [T/F]. Default is T.

-a - Minimum HSP length to keep. [Integer]. Default is to keep all HSPs.

-p - Minimum HSP length to keep, expressed as a proportion of the query
sequence length. [Real]. Overrides -a. Default is to keep all HSPs.

-s - Minimum HSP score to keep. [Integer]. Default is to keep all HSPs. 

-n - Minimum HSP identity to keep. [Real]. Default is to keep all HSPs.

-x - Expect value setting to supply to the blastall program. [Real]. Default is
10.0.

-t - Number of hits to keep. [Integer]. Default is 5.

-Q - The genetic code to use for the query sequence, for translated BLAST
searches. [Integer]. Default is 1.

-D - The genetic code to use for the database sequences, for translated BLAST
searches. [Integer]. Default is 1.

-y - The path to the blastall program. [File]. Default is blastall.

-hsp_label - Whether to add a label to the match_description of each. HSP to
indicate which hit it belongs to. [T/F]. Default is F.

-W - The word size to use. [Integer]. Default depends on search type.

example usage:

  perl local_blast_client.pl -i my_seqs.fasta -o blast_results.txt -b blastn \
  -d sequences.fasta
```
