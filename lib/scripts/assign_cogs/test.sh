#!/bin/bash
set -e
FORMATDB=formatdb

if [ ! -d test_output ]; then
    mkdir test_output
fi

if [ ! -f test_output/myva ]; then
    cp -f db/myva.gz test_output
    gunzip test_output/myva.gz
fi

if [ ! -f test_output/whog ]; then
    cp -f db/whog.gz test_output
    gunzip test_output/whog.gz
fi

FORMATDB -p T -i test_output/myva -o T

rm formatdb.log

perl assign_cogs.pl -i test_input/sample_1.gbk \
-o test_output/sample_1.gff -s cds \
-myva test_output/myva -whog test_output/whog 

perl assign_cogs.pl -i test_input/sample_1.gbk \
-o test_output/sample_1b.gff -s cds \
-myva test_output/myva -whog test_output/whog \
-a -e 0.0000001 -p 0.60 -v

perl assign_cogs.pl -i test_input/sample_2.fna \
-o test_output/sample_2.gff -s orfs \
-myva test_output/myva -whog test_output/whog -v

perl assign_cogs.pl -i test_input/sample_2.fna \
-o test_output/sample_2b.gff -s orfs \
-myva test_output/myva -whog test_output/whog \
-a -e 0.0000001 -p 0.60 -v

rm test_output/myva*
rm test_output/whog*

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