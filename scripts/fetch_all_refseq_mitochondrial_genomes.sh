#!/bin/bash -e

PROGNAME=$(basename $0)

function usage() {
    echo "
USAGE:
   fetch_all_refseq_mitochondrial_genomes.sh -o DIR 

DESCRIPTION:
   Downloads all bacterial RefSeq sequences form NCBI in GenBank format.

REQUIRED ARGUMENTS:
   -o, --output DIR
      The output directory to contain the downloaded GenBank files.

OPTIONAL ARGUMENTS:
   -h, --help
      Show this message.

EXAMPLE:
   fetch_all_refseq_mitochondrial_genomes.sh -o my_project/comparison_genomes
"
}

function error_exit() {
    echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
    exit 1
}

function remove_trailing_slash() {
    string="$1"
    new_string=$(echo "$string" | perl -nl -e 's/\/+$//;' -e 'print $_')
    echo $new_string
}

while [ "$1" != "" ]; do
    case $1 in
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
if [ -z $CCT_HOME ]; then
    error_exit "Please set the \$CCT_HOME environment variable to the path to the cgview_comparison_tool directory."
fi
cct_home=$CCT_HOME

if [ -z "$directory" ]; then
    error_exit "Please use '-o' to specify an output directory. Use '-h' for help."
fi

directory=$(remove_trailing_slash "$directory")

if [ ! -d "$directory" ]; then
    mkdir -p "$directory"
fi

perl "${cct_home}/scripts/ncbi_search.pl" -q "nucleotide genome[Filter] AND mitochondrion[Filter] AND refseq[Filter] NOT wgs[Filter]" -d nucleotide -o "$directory" -s -r gbwithparts -v

echo "Downloaded sequences saved to ${directory}"
