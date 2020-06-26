#!/bin/bash -e

format=png
mem=1500m

PROGNAME=$(basename $0)

function usage() {
    echo "
USAGE:
   create_zoomed_maps.sh -p DIR -c INTEGER -z INTEGER [Options]

DESCRIPTION:
   Creates a zoomed map for completed CCT project.

REQUIRED ARGUMENTS:
   -p, --project DIR
      Path to a completed CCT project.
   -c, --center INTEGER
      Nucleotide position to center the zoomed map on.
   -z, --zoom INTEGER
      Zoom multiplier.

OPTIONAL ARGUMENTS:
   -f, --format STRING
      Image format for output map. Options are png, jpg, svg, svgz. 
      (Default: png)
   -m, --memory STRING
      Memory value for Java's -Xmx option (Default: 1500m).
   -h, --help
      Show this message

EXAMPLE:
   create_zoomed_maps.sh -p my_project -c 10000 -z 10 -format svg   
"
}

function error_exit() {
    echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
    exit 1
}

function get_filename_without_extension() {
    basefile=$(basename "$1")
    filename=${basefile%.*}
    echo $filename
}

function get_path_to_maps() {
    file="$1"
    filename=$(echo "$file" | perl -nl -e 'm/(.+)\/cgview_xml\/[^\/]+$/;' -e 'print $1')
    echo $filename
}

function remove_trailing_slash() {
    string="$1"
    new_string=$(echo "$string" | perl -nl -e 's/\/+$//;' -e 'print $_')
    echo $new_string
}

while [ "$1" != "" ]; do
    case $1 in
    -p | --project)
        shift
        project=$1
        ;;
    -c | --center)
        shift
        center=$1
        ;;
    -z | --zoom)
        shift
        zoom=$1
        ;;
    -f | --format)
        shift
        format=$1
        ;;
    -m | --memory)
        shift
        mem=$1
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

if [ -z "$project" ]; then
    error_exit "Please use '-p' to specify a project. Use '-h' for help."
fi

if [ -z "$center" ]; then
    error_exit "Please use '-c' to specify the nucleotide position of interest. Use '-h' for help."
fi

if [ -z "$zoom" ]; then
    error_exit "Please use '-z' to specify the zoom multiplier. Use '-h' for help."
fi

if [ -z "$CCT_HOME" ]; then
    error_exit "Please set the \$CCT_HOME environment variable to the path to the cgview_comparison_tool directory."
fi

project=$(remove_trailing_slash "$project")

# save and change IFS to avoid problems with filesnames with spaces
OLDIFS=$IFS
IFS=$'\n'

#find all XML files in the project
files=($(find -L "$project" -type f -name "*.xml"))

# restore IFS
IFS=$OLDIFS

length=${#files[@]}
for ((i = 0; i < $length; i++)); do
    xml_file=${files[$i]}
    echo "Generating zoomed map from the file '$xml_file'."
    file_no_extension=$(get_filename_without_extension "$xml_file")
    path_to_maps=$(get_path_to_maps "$xml_file")
    java -jar -Xmx"${mem}" "$cct_home"/bin/cgview/cgview.jar -i "$xml_file" -c $center -z $zoom -o "$path_to_maps"/"${file_no_extension}_${center}_${zoom}"."$format" -f "$format"
    echo "New map drawn to $path_to_maps/${file_no_extension}_${center}_${zoom}.${format}"
done
