#!/bin/bash -e

#changing this value may require editing of cgview_xml_builder.pl
#to adjust width of BLAST results tracks
comparison_genomes_to_display=100
mem=1500m
custom=""
size=""
start_at_map=""
start_at_xml=""
start_at_montage=""
columns=4

PROGNAME=$(basename $0)

function usage() {
    echo "
USAGE:
   build_blast_atlas_all_vs_all.sh -p DIR [Options]

DESCRIPTION:
   This script generates several CCT projects automatically, and then it
   combines the results into a single montage map. The montage consists
   of a separate map for each sequence of interest. This allows each sequence
   in a group of sequences to be visualized as the reference sequence.

   This command is used to first create a blast atlas all vs all project
   directory and then again to generate the montage. After the project has
   been created, place the genomes to compare in the comparison_genomes
   directory.

   [Optional] Make changes to the project_settings_multi.conf file to
   configure how the maps will be drawn. Add additional GFF files to the
   features and analysis directories.

   Draw maps by running this command again with the '-p' option pointing to the
   project directory.

REQUIRED ARGUMENTS:
   -p, --project DIR
      If no project exists yet, creates a new project directory. Otherwise,
      initiates map creation for the project.

OPTIONAL ARGUMENTS:
   -m, --memory STRING
      Memory value for Java's -Xmx option (Default: 1500m).
   -c, --custom STRING
      Custom settings for map creation.
   -b, --max_blast_comparisons INTEGER
      Maximum number of comparison genomes to display (Default: 100).
   -z, --map_size STRING
      Size of custom maps to create. For quickly regenerating new map sizes,
      use this option with the --start_at_xml option. Possible sizes include
      small/medium/large/x-large or a combination separated by commas (e.g.
      small,large). The size(s) provided will override the size(s) in the
      configuration files.
   -x, --start_at_xml
      Jump to XML generation. Skips performing blast, which can
      speed map generation if blast has already been done. This option is for
      creating new maps after making changes to the .conf files or if creating
      new map sizes (see --map_size). Note that any changes in the .conf files
      related to blast will be ignored. This option will be ignored if the
      --start_at_map or --start_at_montage option is also provided.
   -r, --start_at_map
      Start at map generation. Skips performing blast and
      generating XML. Useful if manual changes to the XML files have
      been made. This option will be ignored if the --start_at_montage
      option is also provided.
   -g, --start_at_montage
      Start at montage generation. Skips creating the individual maps.
      Useful if changing how many columns the montage should have.
   -y, --columns INTEGER
      The number of columns to use in the montage image (Default: 4). If the
      maps have already been drawn once, it is best to use this option with the
      --start_at_montage option.
   -h, --help
      Show this message.

NOTES:
   This script will likely not work if there are spaces in the path to the
   project directory because the NCBI tool 'formatdb' cannot handle such
   paths.
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

# Check for ImageMagick
if (! command -v convert &>/dev/null) || (! command -v montage &>/dev/null); then
    echo "
  ImageMagick is required for the build_blast_atlas_all_vs_all.sh command.
" >&2
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
    -p | --project)
        shift
        project_dir=$1
        ;;
    -m | --memory)
        shift
        mem=$1
        ;;
    -c | --custom)
        shift
        custom=$1
        ;;
    -b | --max_blast_comparisons)
        shift
        comparison_genomes_to_display=$1
        ;;
    -z | --map_size)
        shift
        size=$1
        ;;
    -x | --start_at_xml)
        start_at_xml="T"
        ;;
    -r | --start_at_map)
        start_at_map="T"
        ;;
    -g | --start_at_montage)
        start_at_montage="T"
        ;;
    -y | --columns)
        shift
        columns=$1
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
    error_exit "Please set the \$CCT_HOME environment variable to the path to the cgview_comparison_tool directory"
fi
cct_home=$CCT_HOME

if [ -z "$project_dir" ]; then
    error_exit "Please use '-p' to specify a project directory. Use '-h' for help."
fi

# Determine whether to create a new project or run an existing project
if [ ! -d "$project_dir" ] || [ ! "$(ls -A "$project_dir")" ]; then
    new_project=true
else
    new_project=false
fi

# CREATING A NEW PROJECT
if ($new_project) && [ -z "$start_at_montage" ]; then
    echo "Creating new project in '$project_dir'"

    if [ ! -d "$project_dir" ]; then mkdir "$project_dir"; fi

    mkdir "${project_dir}/comparison_genomes"
    mkdir "${project_dir}/cct_projects"

    cp "$cct_home"/conf/project_settings_multi.conf "$project_dir"/project_settings_multi.conf
    echo "Configuration file written to '$project_dir'."
    echo ""
    echo "TO CREATE MAPS:"
    echo "- Place comparison genomes into the '${project_dir}/comparison_genomes' directory."
    echo "- Edit configuration file 'project_settings_multi.conf' (Optional)."
    echo "- Rerun this script."
    echo ""
    exit
fi

# CREATE MAPS FOR AN EXISTING PROJECT
if (! $new_project) && [ -z "$start_at_montage" ]; then
    if [ ! -d "${project_dir}/cct_projects" ]; then
        mkdir "${project_dir}/cct_projects"
    fi

    # Find all the gbk files, sort by accession and for each one create a new cgview_comparison_tool project
    files=($(find "${project_dir}/comparison_genomes" -maxdepth 1 -type f \( -name "*.gbk" -o -name "*.gb" \) -print0 | perl -ne 'my @files = split(/\0/, $_); my @sorted = sort {$a =~ m/[AN]C_0*(\d+)/; $a_char = $1; $b =~ m/[AN]C_0*(\d+)/; $b_char = $1; return ($a_char <=> $b_char);} @files; foreach(@sorted) { print "$_\n";}'))
    length=${#files[@]}
    for ((i = 0; i < $length; i++)); do

        seqname=$(get_filename_without_extension "${files[$i]}")
        after=$i+1
        after_length=$length-$after
        reference_genome=$(basename "${files[$i]}")

        #the following leaves out the reference genome
        #comparison_genomes=( ${files[@]:0:$i} ${files[@]:$after:$after_length} )

        comparison_genomes=(${files[@]:0:$length})

        echo "Generating project for $reference_genome as the reference genome."
        echo "The comparison genomes are:"
        echo ${comparison_genomes[@]}

        # Create project and links
        if [ ! -d "${project_dir}/cct_projects/${seqname}" ]; then
            # Create CCT project
            perl "${cct_home}/scripts/cgview_comparison_tool.pl" --project "${project_dir}/cct_projects/${seqname}"
            # Create link to reference genome
            ln -s "../../../comparison_genomes/${reference_genome}" "${project_dir}/cct_projects/${seqname}/reference_genome/${reference_genome}"

            # Create links to comparison genomes
            length_comparison=${#comparison_genomes[@]}
            for ((j = 0; j < $length_comparison; j++)); do
                filename_comparison=$(basename "${comparison_genomes[$j]}")
                ln -s "../../../comparison_genomes/${filename_comparison}" "${project_dir}/cct_projects/${seqname}/comparison_genomes/${filename_comparison}"
            done
        fi

        # To force the analysis of a genome delete the xml file manually
        # and delete the image output manually
        command="perl ${cct_home}/scripts/cgview_comparison_tool.pl --project ${project_dir}/cct_projects/${seqname} --config $cct_home/conf/global_settings.conf --settings ${project_dir}/project_settings_multi.conf --map_prefix ${seqname}_ --sort_blast_tracks --max_blast_comparisons $comparison_genomes_to_display --cct"

        if [ -n "$mem" ]; then
            command=$command" --memory $mem"
        fi

        if [ -n "$custom" ]; then
            command=$command" --custom '${custom}'"
        fi

        if [ -n "$size" ]; then
            command=$command" --map_size $size"
        fi

        if [ -n "$start_at_map" ]; then
            if [ -d "${project_dir}/cct_projects/${seqname}/maps/cgview_xml/" ] && [ "$(ls -A ${project_dir}/cct_projects/${seqname}/maps/cgview_xml/)" ]; then
                #xml present, draw from xml
                echo "Redrawing maps for map $seqname using existing XML."
                eval "$command --start_at_map"
            else
                error_exit "The --start_at_map option was provided but there are no XML files present."
            fi
        elif [ -n "$start_at_xml" ]; then
            if [ -d "$project_dir/cct_projects/$seqname/blast/blast_results_local/" ] && [ "$(ls -A $project_dir/cct_projects/$seqname/blast/blast_results_local/)" ]; then
                #blast results present, build xml and draw
                echo "Redrawing maps for map $seqname using existing BLAST results."
                eval "$command --start_at_xml"
            else
                error_exit "The --start_at_xml option was provided but there are no blast files present."
            fi
        else
            # Redraw from start
            echo "Creating maps for map $seqname in $project_dir/cct_projects/$seqname/maps"
            eval $command
        fi
    done
fi

# COMBINE IMAGES USING IMAGEMAGICK
if (! $new_project) || [ -n "$start_at_montage" ]; then
    # This sorts the files by accession
    png_files=($(find "$project_dir"/cct_projects -type f \( -name "*.png" \) -print0 | perl -ne 'my @files = split(/\0/, $_); my @sorted = sort {$a =~ m/[A-Z][A-Z]_*0*(\d+)/; $a_char = $1; $b =~ m/[A-Z][A-Z]_*0*(\d+)/; $b_char = $1; return ($a_char <=> $b_char);} @files; foreach(@sorted) { print "$_\n";}'))
    png_length=${#png_files[@]}
    #for (( i=0; i<$png_length; i++ ));
    #do
    #convert "${png_files[$i]}" -resize 40% "${png_files[$i]}"
    #done
    montage "${png_files[@]:0}" -resize 40% -tile ${columns}x -geometry 800x800\>+2+2 -background "#FFFFFF" "$project_dir"/montage.png
    echo "Montage drawn to $project_dir/montage.png"
fi
