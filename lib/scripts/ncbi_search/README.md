# ncbi\_search

FILE: ncbi\_search.pl  
AUTH: Paul Stothard <stothard@ualberta.ca>  
DATE: April 18, 2020  
VERS: 1.2

This script uses NCBI's Entrez Programming Utilities to perform searches of
NCBI databases. This script can return either the complete database records, or
the IDs of the records.

For additional information on NCBI's Entrez Programming Utilities see:
<https://www.ncbi.nlm.nih.gov/books/NBK25499/#chapter4.ESearch>

This script requires the `LWP::Protocol::https` Perl modules. This can be installed using CPAN, e.g.:

```
sudo perl -MCPAN -e "install LWP::Protocol::https"
```

## Usage

```
ncbi_search.pl - search NCBI databases.

DISPLAY HELP AND EXIT:

usage:

  perl ncbi_search.pl -help

PERFORM NCBI SEARCH

usage:

  perl ncbi_search.pl -q <string> -o <file> -d <string> [Options]

required arguments:

-q - Entrez query text.

-o - Output file to create. If the -s option is used this is the output
directory to create.

-d - Name of the NCBI database to search, such as 'nuccore', 'protein', or
'gene'.

optional arguments:

-r - Type of information to download. For sequences, 'fasta' is typically
specified. The accepted formats depend on the database being queried. The
default is to specify no format.
  
-m - The maximum number of records to download. Default is to download all
records.
  
-s - Save each record as a separate file. This option is only supported for -r
values of 'gb' and 'gbwithparts'.

-v - Provide progress messages.

example usage:

  perl ncbi_search.pl -q 'NC_045512[Accession]' -o NC_045512.gbk -d nuccore \
  -r gbwithparts
```

### Example usage:

Download a sequence in GenBank format (with the full sequence included), using
an accession number:

```bash
perl ncbi_search.pl -q 'NC_045512[Accession]' \
-o NC_045512.gbk \
-d nuccore \
-r gbwithparts \
-v
```

Download the protein sequences encoded by a genome, using the genome's
accession number:

```bash
perl ncbi_search.pl -q 'NC_012920.1[Accession]' \
-o AL513382.1.faa \
-d nuccore \
-r fasta_cds_aa \
-v
```

Download multiple genomes using an accession number range, and save each genome
to a file named after its accession number:

```bash
perl ncbi_search.pl -q 'NC_009925:NC_009934[Accession]' \
-o outdir1 \
-d nuccore \
-r gbwithparts \
-s \
-v
```

Download five coronavirus genomes from the RefSeq collection, and save each
genome to a separate file:

```bash
perl ncbi_search.pl -q 'coronavirus[Organism] AND nucleotide genome[Filter] AND refseq[Filter]' \
-o outdir2 \
-d nuccore \
-r gbwithparts \
-m 5 \
-s \
-v
```

Download five abstracts from PubMed using an author name:

```bash
perl ncbi_search.pl -q 'Stothard P[Author]' \
-o abstracts.txt \
-d pubmed \
-r abstract \
-m 5 \
-v
```

Download information on the genes located in a genome region of interest:

```bash
perl ncbi_search.pl -q 'homo sapiens[Organism] AND 17[Chromosome] AND 7614064:7833711[Base position] AND GRCh38.p13[Assembly name]' \
-o gene_list.txt \
-d gene \
-r gene_table \
-v
```

Download information about a gene of interest:

```bash
perl ncbi_search.pl -q 'homo sapiens[Organism] AND PRNP[Gene name]' \
-o gene_info.txt \
-d gene \
-v
```

Download information about health-affecting variants for a genome region of
interest:

```bash
perl ncbi_search.pl -q '17[Chromosome] AND 7614064:7620000[Base Position]' \
-o clinvar_info.xml \
-d clinvar \
-r clinvarset \
-v
```

Download a sequence record for each accession number in a file of accession
numbers:

```bash
#preparing sample file of accession numbers
echo $'NP_776246.1\nNP_001073369.1\nXP_006724594.1\nNP_995328.2\nNP_115906.3\n' \
> accessions.txt

#performing search for each accession using xargs
cat accessions.txt | xargs -t -I{} \
perl ncbi_search.pl -q '{}[Accession]' \
-o {}.fasta \
-d protein \
-r fasta \
-v
```

Download sequences in fasta format and then save each sequence as a separate
file:

```bash
#download fasta file containing multiple sequences
perl ncbi_search.pl -q 'coronavirus[Organism] AND nucleotide genome[Filter] AND refseq[Filter]' \
-o sequences.fasta \
-d nuccore \
-r fasta \
-m 5 \
-v

#create separate file for each sequence
outputdir=output_directory/
mkdir -p "$outputdir"
awk '/^>/ {OUT=substr($0,2); split(OUT, a, " "); sub(/[^A-Za-z_0-9\.\-]/, "", a[1]); OUT = "'"$outputdir"'" a[1] ".fa"}; OUT {print >>OUT; close(OUT)}' \
sequences.fasta
```

---

### Supported -d option values:

- annotinfo
- assembly
- bioproject
- biosample
- biosystems
- blastdbinfo
- books
- cdd
- clinvar
- dbvar
- gap
- gapplus
- gds
- gene
- genome
- geoprofiles
- grasp
- homologene
- ipg
- medgen
- mesh
- ncbisearch
- nlmcatalog
- nuccore
- nucleotide
- omim
- orgtrack
- pcassay
- pccompound
- pcsubstance
- pmc
- popset
- probe
- protein
- proteinclusters
- pubmed
- seqannot
- snp
- sparcle
- sra
- structure
- taxonomy

---

### Supported -r option values:

The supported -r option values are grouped by database type (i.e. -d option value) below. The name of each format is followed by the corresponding -r option value in parentheses. A value of _null_ indicates that the -r option should be omitted in order to obtain that output format.

##### All Databases

- Document summary (docsum)
- List of UIDs in plain text (uilist)

##### d = bioproject

- Full record XML (xml)

##### d = biosample

- Full record text (full)

##### d = biosystems

- Full record XML (xml)

##### d = gds

- Summary (summary)

##### d = gene

- text ASN.1 (_null_)
- Gene table (gene\_table)

##### d = homologene

- text ASN.1 (_null_)
- Alignment scores (alignmentscores)
- FASTA (fasta)
- HomoloGene (homologene)

##### d = mesh

- Full record (full)

##### d = nlmcatalog

- Full record (_null_)

##### d = nuccore, nucest, nucgss, protein or popset

- text ASN.1 (_null_)
- Full record in XML (native)
- Accession number(s) (acc)
- FASTA (fasta)
- SeqID string (seqid)

##### Additional options for d = nuccore, nucest, nucgss or popset

- GenBank flat file (gb)
- INSDSeq XML (gbc)

##### Additional option for d = nuccore and protein

- Feature table (ft)

##### Additional options for d = nuccore

- GenBank flat file with full sequence (gbwithparts)
- CDS nucleotide FASTA (fasta\_cds\_na)
- CDS protein FASTA (fasta\_cds\_aa)

##### Additional option for d = nucest

- EST report (est)

##### Additional option for d = nucgss

- GSS report (gss)

##### Additional options for d = protein

- GenPept flat file (gp)
- INSDSeq XML (gpc)
- Identical Protein XML (ipg)

##### d = pmc

- XML (_null_)
- MEDLINE (medline)

##### d = pubmed

- text ASN.1 (_null_)
- MEDLINE (medline)
- PMID list (uilist)
- Abstract (abstract)

##### d = sequences

- text ASN.1 (_null_)
- Accession number(s) (acc)
- FASTA (fasta)
- SeqID string (seqid)

##### d = snp

- text ASN.1 (_null_)
- Flat file (flt)
- FASTA (fasta)
- RS Cluster report (rsr)
- SS Exemplar list (ssexemplar)
- Chromosome report (chr)
- Summary (docset)
- UID list (uilist)

##### d = sra

- XML (full)

##### d = taxonomy

- XML (_null_)
- TaxID list (uilist)

##### d = clinvar

- ClinVar Set (clinvarset)
- UID list (uilist)

##### d = gtr

- GTR Test Report (gtracc)
