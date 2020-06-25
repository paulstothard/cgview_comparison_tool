#!/bin/bash -e
./build_cog_db.sh

if [ ! -d ./test_output ]; then
  mkdir ./test_output
fi

TEST_PROJECTS=($(find ./test_projects -name "test_*" -type d -depth 1))
for project in "${TEST_PROJECTS[@]}"; do
  p=$(basename "$project")
  echo "Processing project '$p'"
  cp -R "$project" ./test_output
  for j in project_settings.conf; do
    echo "Processing project '$p' using configuration '$j'"
    command="perl '${CCT_HOME}/scripts/cgview_comparison_tool.pl' -c './conf/global_settings.conf' -p './test_output/$p' -s './test_output/$p/$j' -f '${p}_${j}_'"
    eval $command
  done
done

echo "Test project output written to ./test_output"
