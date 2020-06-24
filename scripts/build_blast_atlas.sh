#!/bin/bash -e

#changing this value may require editing of cgview_xml_builder.pl
#to adjust width of BLAST results tracks
comparison_genomes_to_display=100
mem=1500m
custom=""
size=""
start_at_map=""
start_at_xml=""

PROGNAME=`basename $0`

function usage {
    echo "
USAGE:
   build_blast_atlas.sh -i FILE [-p DIR] [Options]
   build_blast_atlas.sh -p DIR [Options]

DESCRIPTION:
   This command is used to first create a blast atlas project directory and
   then again to generate maps.  Run this command with the '-i' option and a
   GenBank file to create a new project using the GenBank file as the reference
   genome. Alternatively, a blank project can be created using the '-p'
   option, in which case a reference GenBank file will have to be placed in the
   reference_genomes directory. After the project has been created, place the
   genomes to compare with the reference in the comparison_genomes directory.

   [Optional] Make changes to the *.conf files to configure how the maps will
   be drawn. Add additional GFF files to the features and analysis directories.

   Draw maps by running this command again with the '-p' option pointing to the
   project directory.

REQUIRED ARGUMENTS:
   -i, --input FILE
      Sequence file in GenBank format, with a .gbk extension. This option is
      only required when first creating a blast atlas project. The project
      directory will be named after this file unless the '-p' option is
      provided.
   -p, --project DIR
      Initiates map creation for the project. If no project exists yet, a blank
      project will be created. When used with the '-i' option, this will be
      where the project is created. This option is only required when creating
      the blast atlas maps.

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
      Jump to XML generation. Skips performing blast, which can speed map
      generation if blast has already been done. This option is for creating
      new maps after making changes to the .conf files.  Note that any changes
      in the .conf files related to blast will be ignored. This option will be
      ignored if the --start_at_map option is also provided.
   -r, --start_at_map
      Start at map generation. Skips performing blast and
      generating XML. Useful if manual changes to the XML files have
      been made or if creating new map sizes (see --map_size).
   -h, --help
      Show this message.

NOTE:
   This script will likely not work if there are spaces in the path to the
   project directory because the NCBI tool 'formatdb' cannot handle such
   paths.
"
}

function error_exit {
    echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
    exit 1
}

function get_filename_without_extension {
    basefile=$(basename "$1")
    filename=${basefile%.*}
    echo $filename
}

while [ "$1" != "" ]; do
    case $1 in
        -i | --input )                 shift
                                       input=$1
                                       ;;
        -p | --project )               shift
                                       project=$1
                                       ;;
        -m | --memory )                shift
                                       mem=$1
                                       ;;
        -c | --custom )                shift
                                       custom=$1
                                       ;;
        -b | --max_blast_comparisons)  shift
                                       comparison_genomes_to_display=$1
                                       ;;
        -z | --map_size )              shift
                                       size=$1
                                       ;;
        -x | --start_at_xml )          start_at_xml="T"
                                       ;;
        -r | --start_at_map )          start_at_map="T"
                                       ;;
        -h | --help )                  usage
                                       exit
                                       ;;
        * )                            usage
                                       exit 1
    esac
    shift
  done


# The CCT_HOME variable must be set
if [ -z $CCT_HOME ]; then
    error_exit "Please set the \$CCT_HOME environment variable to the path to the cgview_comparison_tool directory."
fi
cct_home=$CCT_HOME

# Set the project directory
if [ -n "$project" ]; then
    project_dir="$project"
elif [ -n "$input" ]; then
    if [ ! -f "$input" ]; then
        error_exit "The input GenBank file '$input' does not exist"
    fi
    project_dir=`get_filename_without_extension $input`
else
    error_exit "Please use '-i' to specify an input sequence file in GenBank format, with .gbk extension or the '-p' option to specify the project directory. For a full list of options use '-h'."
fi

# Determine whether to create a new project or run an existing project
if [ ! -d "$project_dir" ] || [ ! "$(ls -A "$project_dir")" ]; then
    new_project=true
else
    new_project=false
    if [ -n "$input" ]; then
        error_exit "You have used the '-i' option, yet there is already a non empty project directory '$project_dir', so a new project can not be started. Please use the '-p' option without '-i' to start map creation or use '-p NEW_PROJECT_NAME' with '-i' to create a new project with a different name."
    fi
fi


# CREATING A NEW PROJECT
if $new_project; then
    echo "Creating new project in '$project_dir'"

    if [ ! -d "$project_dir" ]; then mkdir "$project_dir" ; fi

    mkdir "${project_dir}/cct_projects"
    mkdir "${project_dir}/reference_genome"
    mkdir "${project_dir}/comparison_genomes"
    mkdir "${project_dir}/features"
    mkdir "${project_dir}/analysis"

    if [ -n "$input" ]; then
        cp "$input" "$project_dir"/reference_genome
    fi

    for type in dna_vs_dna cds_vs_cds
    do
        echo "Creating project for $type"
        cp "${cct_home}/conf/project_settings_${type}.conf" "${project_dir}/project_settings_${type}.conf"
        perl "${cct_home}/scripts/cgview_comparison_tool.pl" --project "${project_dir}/cct_projects/${type}" --settings "${project_dir}/project_settings_${type}.conf"

        # Create symbolic links for the various project directories
        rmdir "${project_dir}/cct_projects/${type}/maps"
        rmdir "${project_dir}/cct_projects/${type}/reference_genome"
        rmdir "${project_dir}/cct_projects/${type}/comparison_genomes"
        rmdir "${project_dir}/cct_projects/${type}/features"
        rmdir "${project_dir}/cct_projects/${type}/analysis"
        mkdir "${project_dir}/maps_for_${type}"
        ln -s "../../maps_for_${type}" "${project_dir}/cct_projects/${type}/maps"
        ln -s "../../reference_genome" "${project_dir}/cct_projects/${type}/reference_genome"
        ln -s "../../comparison_genomes" "${project_dir}/cct_projects/${type}/comparison_genomes"
        ln -s "../../features" "${project_dir}/cct_projects/${type}/features"
        ln -s "../../analysis" "${project_dir}/cct_projects/${type}/analysis"
    done

    echo "Configuration files written to '${project_dir}'."
    echo ""
    echo "TO CREATE MAPS:"
    if [ -z "$input" ]; then
        echo "- Place a reference genome into the '${project_dir}/reference_genome' directory."
    fi
    echo "- Place comparison genomes into the '${project_dir}/comparison_genomes' directory."
    echo "- Edit configurations file (Optional)."
    echo "- Add analysis and/or features data files (Optional)."
    echo "- Rerun this script."
    echo ""
    exit
fi


# CREATE MAPS FOR AN EXISTING PROJECT
if ! $new_project; then

    #merge multi-contig GenBank files
    files=($( find "${project_dir}/comparison_genomes" "${project_dir}/reference_genome" -maxdepth 1 -type f \( -name "*.gbk" -o -name "*.gb" \)))
    for i in "${files[@]}"
    do

      #check each file for multiple contigs
      set +e
      seqs=$(grep -c '^LOCUS' "$i")
      set -e

      if [ "$seqs" -gt 1 ]; then

        if ! [ -x "$(command -v merge-gbk-records)" ]; then
          error_exit "Error: merge-gbk-records is not installed. Unable to merge sequences in multi-sequence file $i"
        fi

        echo "Merging $seqs sequence records in file '$i'."

        command="merge-gbk-records -l 0 '$i' -o '${i}.new'"

        eval $command

        mv "$i" "${i}.bac"
        mv "${i}.new" "$i"

      fi
    done

    for type in dna_vs_dna cds_vs_cds
    do
      command="perl '${cct_home}/scripts/cgview_comparison_tool.pl' --project '${project_dir}/cct_projects/${type}' --config '${cct_home}/conf/global_settings.conf' --settings '${project_dir}/project_settings_${type}.conf' --map_prefix ${type}_ --sort_blast_tracks --max_blast_comparisons $comparison_genomes_to_display --cct"
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
            if [ -d "${project_dir}/maps_for_${type}/cgview_xml/" ] && [ "$(ls -A ${project_dir}/maps_for_${type}/cgview_xml/)" ]; then
                echo "Redrawing maps for map type $type using existing XML."
                eval "$command --start_at_map"
                echo "Maps drawn to ${project_dir}/maps_for_${type}"
            else
                error_exit "The --start_at_map option was provided but there are no XML files present."
            fi
        elif [ -n "$start_at_xml" ]; then
            if [ -d "${project_dir}/cct_projects/${type}/blast/blast_results_local/" ] && [ "$(ls -A $project_dir/cct_projects/$type/blast/blast_results_local/)" ]; then
                echo "Redrawing maps for map type $type using existing BLAST results."
                eval "$command --start_at_xml"
                echo "Maps drawn to ${project_dir}/maps_for_${type}"
            else
                error_exit "The --start_at_xml option was provided but there are no blast files present."
            fi
        else
            # Redraw from start
            echo "Creating maps for map type $type in ${project_dir}/maps_for_${type}"
            eval $command
            echo "Maps drawn to ${project_dir}/maps_for_${type}"
        fi

    done
fi



