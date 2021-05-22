#!/bin/bash -e

PROGNAME=$(basename "$0")

function usage() {
    echo "
USAGE:
   fetch_genome_by_accession.sh -a STRING -o DIR 

DESCRIPTION:
   Downloads a GenBank record using the accession number.

REQUIRED ARGUMENTS:
   -a, --accession STRING
      Accession number of the sequence to download.
   -o, --output DIR
      The output directory to download the GenBank file into.

OPTIONAL ARGUMENTS:
   -h, --help
      Show this message.

EXAMPLE:
   fetch_genome_by_accession.sh -a NC_007719 -o my_project/reference_genome
"
}

function error_exit() {
    echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
    exit 1
}

function remove_trailing_slash() {
    string="$1"
    new_string=$(echo "$string" | perl -nl -e 's/\/+$//;' -e 'print $_')
    echo "$new_string"
}

while [ "$1" != "" ]; do
    case $1 in
    -a | --accession)
        shift
        accession=$1
        ;;
    -o | --output)
        shift
        directory=$1
        ;;
    -h | --help)
        usage
        exit
        ;;
    *)
        usage
        exit 1
        ;;
    esac
    shift
done

# The CCT_HOME variable must be set
if [ -z "$CCT_HOME" ]; then
    error_exit "Please set the \$CCT_HOME environment variable to the path to the cgview_comparison_tool directory."
fi
cct_home=$CCT_HOME

if [ -z "$accession" ]; then
    error_exit "Please use '-a' to specify the accession number of the genome to download. Use '-h' for help."
fi

if [ -z "$directory" ]; then
    error_exit "Please use '-o' to specify an output directory. Use '-h' for help."
fi

if [ -z "$CCT_HOME" ]; then
    error_exit "Please set the \$CCT_HOME environment variable to the path to the cgview_comparison_tool directory"
fi

directory=$(remove_trailing_slash "$directory")

if [ ! -d "$directory" ]; then
    mkdir -p "$directory"
fi

perl "$cct_home/lib/scripts/ncbi_search/ncbi_search.pl" -q "$accession"'[ACCESSION]' -d nucleotide -o "$directory/$accession.gbk" -r gbwithparts -m 1 -v

echo "The record has been saved to ${directory}/${accession}.gbk"
