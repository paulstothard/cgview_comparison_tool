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

"${CCT_HOME}/scripts/check_env.sh"

if [ ! -d "${CCT_HOME}"/cog_db ]; then
  mkdir "${CCT_HOME}"/cog_db
fi

if [ -f "${CCT_HOME}"/cog_db/.complete ]; then
  echo "COG BLAST database already created"
  echo "Remove '"${CCT_HOME}"/cog_db/.complete' to create again"
  exit 0
fi

echo "Copying and extracting COG files"
cp "${CCT_HOME}"/lib/scripts/assign_cogs/db/whog.gz "${CCT_HOME}"/cog_db
cp "${CCT_HOME}"/lib/scripts/assign_cogs/db/myva.gz "${CCT_HOME}"/cog_db

gunzip "${CCT_HOME}"/cog_db/whog.gz
gunzip "${CCT_HOME}"/cog_db/myva.gz

echo "Preparing COG BLAST database"
formatdb -p T -i "${CCT_HOME}"/cog_db/myva -o T -l "${CCT_HOME}"/cog_db/formatdb.log

echo "COG BLAST database created"
touch "${CCT_HOME}"/cog_db/.complete
