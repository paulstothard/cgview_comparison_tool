#!/bin/bash
set -e
if [ ! -d test_output ]; then
    mkdir test_output
fi

perl ncbi_search.pl -q 'NC_009925:NC_009934[Accession]' -o test_output/combined.gbk -d nuccore -r gbwithparts -v -m 2
perl ncbi_search.pl -q 'NC_009925:NC_009934[Accession]' -o test_output -d nuccore -r gbwithparts -s -v -m 2

#compare new output to sample output
new_output=test_output
old_output=sample_output
IFS=$'\n'
new_files=($( find $new_output -type f -print0 | perl -ne 'my @files = split(/\0/, $_); foreach(@files) { if (!($_ =~ m/\.svn/)) {print "$_\n";}}'))
unset IFS
for (( i=0; i<${#new_files[@]}; i++ ));
do
    old_file=${old_output}$(echo "${new_files[$i]}" | perl -nl -e 's/^[^\/]+//;' -e 'print $_')
    echo "Comparing ${old_file} to ${new_files[$i]}"
    set +e
    if diff -u "$old_file" "${new_files[$i]}"; then
	  echo "No differences found"
    fi
    set -e
done