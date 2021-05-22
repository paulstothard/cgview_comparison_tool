#!/bin/bash -e

PROGNAME=$(basename "$0")

function usage() {
    echo "
USAGE:
   fetch_refseq_bacterial_genomes_by_name.sh -n STRING -o DIR 

DESCRIPTION:
   Downloads a GenBank record using a partial or complete bacterial species name.
   The --min and --max options can be used to restrict the size of the 
   returned sequences.

REQUIRED ARGUMENTS:
   -n, --name STRING
      Complete or partial name of the bacterial species.
   -m, --min INTEGER
      Records with a sequence length shorter than this value will be ignored.
   -x, --max INTEGER
      Records with a sequence length longer than this value will be ignored.
   -o, --output DIR
      The output directory to download the GenBank file into.

OPTIONAL ARGUMENTS:
   -h, --help
      Show this message.

EXAMPLE:
   fetch_refseq_bacterial_genomes_by_name.sh -n 'Escherichia*' -o my_project/comparison_genomes
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

min_length=""
max_length=""

while [ "$1" != "" ]; do
    case $1 in
    -n | --name)
        shift
        name=$1
        ;;
    -o | --directory)
        shift
        directory=$1
        ;;
    -m | --min)
        shift
        min_length=$1
        ;;
    -x | --max)
        shift
        max_length=$1
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

if [ -z "$name" ]; then
    error_exit "Please use '-n' to specify a species name. Use '-h' for help."
fi

if [ -z "$directory" ]; then
    error_exit "Please use '-o' to specify an output directory. Use '-h' for help."
fi

directory=$(remove_trailing_slash "$directory")

if [ ! -d "$directory" ]; then
    mkdir -p "$directory"
fi

query="${name}[Organism] AND nucleotide genome[Filter] AND (bacteria[Filter] OR archaea[Filter]) AND refseq[Filter] NOT wgs[Filter]"

# Add min and max lengths to query
if [ -n "$min_length" ]; then
    if [ -n "$max_length" ]; then
        query=$query" AND ${min_length}:${max_length}[SLEN]"
    else
        min_length="$(( min_length - 1 ))"
        query=$query" NOT 1:${min_length}[SLEN]"
    fi
elif [ -n "$max_length" ]; then
    query=$query" AND 1:${max_length}[SLEN]"
fi

perl "${cct_home}/scripts/ncbi_search.pl" -q "$query" -d nucleotide -o "$directory" -s -r gbwithparts -v

echo "Downloaded sequences saved to ${directory}"
