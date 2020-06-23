#!/bin/bash
set -e
if [ ! -d test_output ]; then
    mkdir test_output
fi

perl sequence_to_multi_fasta.pl -i test_input/test_seq.fasta -o test_output/test_seq_s100_v5.fasta -s 100 -v 5 
perl sequence_to_multi_fasta.pl -i test_input/test_seq.fasta -o test_output/test_seq_v5.fasta -v 5
perl sequence_to_multi_fasta.pl -i test_input/test_seq.fasta -o test_output/test_seq.fasta

perl sequence_to_multi_fasta.pl -i test_input/test_seq_multi.fasta -o test_output/test_seq_multi_s100_v5.fasta -s 100 -v 5 
perl sequence_to_multi_fasta.pl -i test_input/test_seq_multi.fasta -o test_output/test_seq_multi_v5.fasta -v 5
perl sequence_to_multi_fasta.pl -i test_input/test_seq_multi.fasta -o test_output/test_seq_multi.fasta

#compare new output to sample output
new_output=test_output
old_output=sample_output
new_files=($( find $new_output -type f -print0 | perl -ne 'my @files = split(/\0/, $_); foreach(@files) { if (!($_ =~ m/\.svn/)) {print "$_\n";}}'))
for (( i=0; i<${#new_files[@]}; i++ ));
do
    old_file=${old_output}`echo "${new_files[$i]}" | perl -nl -e 's/^[^\/]+//;' -e 'print $_'`
    echo "Comparing ${old_file} to ${new_files[$i]}"
    set +e
    diff -u $old_file ${new_files[$i]}
    if [ $? -eq 0 ]; then
	echo "No differences found"
    fi
    set -e
done