#!/bin/bash -e

PROGNAME=$(basename $0)

format=png
mem=1500m

function usage() {
    echo "
USAGE:
   redraw_maps.sh -p DIR [Options]

DESCRIPTION:
   Used to redraw the maps. This can be used after editing the CGView XML file
   or to change the output image formats.

REQUIRED ARGUMENTS:
   -p, --project DIR
      Path to a completed CCT project.

OPTIONAL ARGUMENTS:
   -f, --format STRING
      Image format for output map. Options are png, jpg, svg, svgz. 
      (Default: png)
   -m, --memory STRING
      Memory value for Java's -Xmx option (Default: 1500m).
   -h, --help
      Show this message

EXAMPLE:
   redraw_maps.sh -p my_project -f svg   
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

if [ -z "$project" ]; then
    error_exit "Please use '-p' to specify a project. Use '-h' for help."
fi

if [ -z $CCT_HOME ]; then
    error_exit "Please set the \$CCT_HOME environment variable to the path to the cgview_comparison_tool directory."
fi

cct_home=$CCT_HOME

project=$(remove_trailing_slash "$project")

# save and change IFS to avoid problems with filesnames with spaces
OLDIFS=$IFS
IFS=$'\n'

#find all XML files in the project
files=($(find "$project" -type f -name "*.xml"))

# restore IFS
IFS=$OLDIFS

length=${#files[@]}
for ((i = 0; i < $length; i++)); do
    xml_file=${files[$i]}
    echo "Generating  map from the file '$xml_file'."
    file_no_extension=$(get_filename_without_extension "$xml_file")
    path_to_maps=$(get_path_to_maps "$xml_file")
    java -jar -Xmx${mem} "$cct_home"/bin/cgview.jar -i "$xml_file" -o "$path_to_maps"/"${file_no_extension}"."$format" -f "$format"
    echo "Map drawn to $path_to_maps/${file_no_extension}.${format}"
done
