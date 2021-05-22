#!/bin/bash
set -e
if [ ! -d test_output ]; then
    mkdir test_output
fi

perl get_cds.pl -i test_input/R_denitrificans.gbk -o test_output/R_denitrificans.cds.faa
perl get_cds.pl -i test_input/R_denitrificans.gbk -o test_output/R_denitrificans.cds.fna -dna T

perl get_cds.pl -i test_input/prokka_multicontig.gbk -o test_output/prokka_multicontig.cds.faa
perl get_cds.pl -i test_input/prokka_multicontig.gbk -o test_output/prokka_multicontig.cds.fna -dna T

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