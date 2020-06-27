#!/bin/bash -e

function end_test() {
    echo "
  'Check environment' test failed
" >&2
    exit 1
}

# Check that the CCT_HOME variable is set
if [ -z "$CCT_HOME" ]; then
    echo "
  Please set the \$CCT_HOME environment variable to the full path to the
  cgview_comparison_tool directory.

  For example, add the following to your ~/.bashrc
  or ~/.bash_profile file:

    export CCT_HOME="/path/to/cgview_comparison_tool"

  After saving reload your ~/.bashrc or ~/.bash_profile file:

    source ~/.bashrc
" >&2

    end_test
fi

"${CCT_HOME}/scripts/build_cog_db.sh"

if [ ! -d "${CCT_HOME}"/test_output ]; then
  mkdir "${CCT_HOME}"/test_output
fi

TEST_PROJECTS=($(find "${CCT_HOME}/test_projects" -mindepth 1 -maxdepth 1 -name 'test_*' -type d))
for project in "${TEST_PROJECTS[@]}"; do
  p=$(basename "$project")
  echo "Processing project '$p'"
  cp -R "$project" "${CCT_HOME}"/test_output
  for j in project_settings.conf; do
    echo "Processing project '$p' using configuration '$j'"
    command="perl '${CCT_HOME}/scripts/cgview_comparison_tool.pl' -g '"${CCT_HOME}"/conf/global_settings.conf' -p '"${CCT_HOME}"/test_output/$p' -s '"${CCT_HOME}"/test_output/$p/$j' -f '${p}_${j}_'"
    eval $command
  done
done

echo "Test project output written to "${CCT_HOME}"/test_output"
