#!/bin/bash -e

PROGNAME=`basename $0`

function usage {
    echo "usage: remove_short_seqs.sh [[-i input] [-l length] | [-h]]"
    echo "-i DIRECTORY the input directory of GenBank files with .gbk extensions"
    echo "-l INTEGER remove GenBank files that describe sequences shorter than this length"
    echo "
USAGE:
   remove_short_seqs.sh -i DIR -l INTEGER

DESCRIPTION:
   Removes GenBank files that are shorter than the specified length from the
   provided directory.

REQUIRED ARGUMENTS:
   -i, --input DIR
      Input directory of GenBank files with .gbk extensions.
   -l, --length INTEGER
      Remove GenBank files that describe sequences shorter than this length.

OPTIONAL ARGUMENTS:
   -h, --help
      Show this message

EXAMPLE:
   remove_short_seqs.sh -i my_project/comparison_genomes -l 100000
"
}

function error_exit {
        echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
        exit 1
}

function remove_trailing_slash {
    string="$1"
    new_string=`echo "$string" | perl -nl -e 's/\/+$//;' -e 'print $_'`
    echo $new_string
}

function get_sequence_length {
    file="$1"
    seq_length=`head -n 1 "$file" | perl -nl -e 'm/(\d+)\sbp/;' -e 'print $1'`
    echo $seq_length
}

while [ "$1" != "" ]; do
    case $1 in
        -i | --input )          shift
                                input=$1
                                ;;
        -l | --length )         shift
                                min_length=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ -z $input ]; then
    error_exit "Please use '-i' to specify an input directory of GenBank files with .gbk extensions. Use '-h' for help."
fi

if [ -z $min_length ]; then
    error_exit "Please use '-l' to specify a minimum sequence length to keep. Use '-h' for help."
fi

cct_home=$CCT_HOME

input=`remove_trailing_slash "$input"`

# save and change IFS to avoid problems with filesnames with spaces
OLDIFS=$IFS
IFS=$'\n'
 
#find all GenBank files in the directory
files=($( find "$input" -maxdepth 1 -type f -name "*.gbk" ))

# restore IFS
IFS=$OLDIFS

length=${#files[@]}
for (( i=0; i<$length; i++ ));
do
    gbk_file=${files[$i]}
    seq_length=`get_sequence_length "$gbk_file"`

    if [ -z $seq_length ]; then
        error_exit "Unable to determine length of sequence '$gbk_file'"
    fi

    if [ "$seq_length" -lt "$min_length" ]; then
	echo "Removing file '$gbk_file' because sequence length is $seq_length"
	rm -f "$gbk_file"
    else
	echo "Keeping file '$gbk_file' because sequence length is $seq_length"
    fi
done
