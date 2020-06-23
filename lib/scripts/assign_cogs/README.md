# assign\_cogs

FILE: assign\_cogs.pl  
AUTH: Paul Stothard <stothard@ualberta.ca>  
DATE: June 22, 2020  
VERS: 1.1  

This script accepts a FASTA, RAW, EMBL, or GenBank format DNA sequence file as input and uses BLAST and a COG database to assign COG functional categories and IDs to each protein produced by the input sequence. The results are written to a tab-delimited file consisting of the following columns: seqname, source, feature, start, end, score, strand, frame. The results are formatted for use with the `-genes` option of the `cgview_xml_builder.pl` script. If the input file consists of multiple sequence records they are merged into a single record and coordinates and reading frame are expressed relative to the single merged sequence. 

This script requires the `Bio::SeqIO` and `Bio::SeqUtils` Perl modules. These can be installed using CPAN, e.g.:

```
sudo perl -MCPAN -e "install Bio::SeqIO"
sudo perl -MCPAN -e "install Bio::SeqUtils"
```

This script requires the `get_orfs.pl`, `get_cds.pl`, and `local_blast_client.pl` scripts included with CGView Comparison Tool.

The `local_blast_client.pl` script requires `blastall` and `formatdb` from [legacy BLAST](https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/). The path to the `blastall` and `formatdb` program directory should be added to `PATH`.

The COG information is included in the `db` directory but first needs to be uncompressed and prepared using `formatdb`. For example:

```
gunzip db/*.gz
formatdb -p T -i db/myva -o T
```

The COG files can then be supplied to `assign_cogs.pl` using the `-myva` and `-whog` options, for example `-myva db/myva -whog db/whog`.

The included `test.sh` script expects to find the compressed COG files in the `db` directory and assumes that `get_orfs.pl`, `get_cds.pl`, and `local_blast_client.pl` are accessible at `../get_orfs/get_orfs.pl`, `../get_cds/get_cds.pl`, and `../local_blast_client/local_blast_client.pl`, respectively.


## Usage

```
assign_cogs.pl - assign COG functional categories and IDs to proteins.

DISPLAY HELP AND EXIT:

usage:

  perl assign_cogs.pl -help

ASSIGN COGS

usage:

  perl assign_cogs.pl -i <file> -o <file> -s <string>[Options]

required arguments:

-i - Input file in FASTA, RAW, EMBL, or GenBank format.

-o - Output file in tab-delimited format to create.

-s - Source of protein sequences. Use 'cds' to indicate that the CDS
translations in the GenBank or EMBL file should be used. Use 'orfs' to indicate
that translated open reading frames should be used.

optional arguments:

-myva - COG myva file formatted as a BLAST database. [FILE]. Default is
db/myva.

-whog - COG whog file. [FILE]. Default is db/whog.

-get_orfs - Path to the get_orfs.pl script. [FILE]. Default is
../get_orfs/get_orfs.pl.

-get_cds - Path to the get_cds.pl script. [FILE]. Default is
../get_cds/get_cds.pl.

-local_bl - Path to the local_blast_client.pl script. [FILE]. Default is
../local_blast_client/local_blast_client.pl.

-blastall - The path to the blastall program. [File]. Default is blastall.

-c - NCBI genetic code to use for translations. [INTEGER]. Default is 11.

-a - use all BLAST hits when assigning COGs. Default is to use top BLAST hit.

-e - Expect value setting to supply to the blastall program. [Real]. Default is
10.0.

-p - Minimum HSP length to keep, expressed as a proportion of the query
sequence length. [Real]. Default is to keep all HSPs.

-starts - Start codons. [String]. Default is 'atg|ttg|att|gtg|ctg'. To allow
ORFs to begin with any codon, use the value 'any'.
                    
-stops - Stop codons. [String]. Default is 'taa|tag|tga'.
                    
-m_orf - Minimum acceptable length for ORFs in codons. [Integer]. Default is
30.
                    
-m_score - Minimum acceptable BLAST score for COG assignment. [Real]. Default
is to ignore score.
                    
-v - provide progress messages (Optional).

example usage:

  perl assign_cogs.pl -i NC_013407.gbk -o out.gff -s cds
```
