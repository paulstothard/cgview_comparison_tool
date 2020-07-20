# convert\_vcf\_to\_features

FILE: convert\_vcf\_to\_features.pl  
AUTH: Jason Grant <jason.grant@ualberta.ca>  
DATE: June 22, 2020  
VERS: 1.1  

This script converts a VCF (Variant Call Format) file into a tab-delimited file that can be used by the CGView Comparison Tool (CCT). Simply place the output file in the `features` directory of a CCT project created for the same reference genome as used to generate the VCF file. The output file is suffixed with the name of the chromosome as obtained from the `CHROM` field in the VCF file. If there are multiple chromosomes in the VCF then multiple output files are generated. 

## Usage

```
convert_vcf_to_features.pl - convert VCF file to tab-delimited file for
the CGView Comparison Tool.

DISPLAY HELP AND EXIT:

usage:

  perl convert_vcf_to_features.pl -help

CONVERT VCF TO TAB-DELIMITED:

usage:

  perl convert_vcf_to_features.pl -i <file> -o <file>

required arguments:

-i - Input file in VCF format.

-o - Output file in tab-delimited format for CGView Comparison Tool. This name
will have the chromosome name as read from the VCF file added to the end,
before the file extension if one is present. If multiple chromosomes are
present in the VCF file then multiple output files will be generated, each with
a different suffix.

example usage:

  perl convert_vcf_to_features.pl -i input.vcf -o output.gff
```
