#!/bin/bash -e

function end_test() {
    echo "
  'Check environment' test failed
" >&2
    exit 1
}

# Check for required software
for j in blastall convert formatdb java montage perl; do
    if ! command -v $j &>/dev/null; then
        echo "
  '$j' is required but not installed." >&2

        end_test
    fi
done

# Check for perl modules
set +e
for j in Bio::SeqIO Bio::SeqUtils Bio::Tools::CodonTable Error File::Temp LWP::Protocol::https Tie::IxHash; do
    perl -e "use $j" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "
  The '$j' Perl module is required but not installed." >&2

        end_test
    fi
done
set -e

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

# Check that ${CCT_HOME}/lib/perl_modules has been added to PERL5LIB
set +e
for j in Util::Configurator Util::LogManager; do
    perl -e "use $j" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "
  Could not find the CGView Comparison Tool Perl module '$j'. Have you added
  the cgview_comparison_tool/lib/perl_modules directory to PERL5LIB?
  
  For example, add the following to your ~/.bashrc or ~/.bash_profile file:

    export PERL5LIB="\$PERL5LIB":"${CCT_HOME}"/lib/perl_modules

  After saving reload your ~/.bashrc or ~/.bash_profile file:

    source ~/.bashrc
" >&2

        end_test
    fi
done
set -e

# Check that ${CCT_HOME}/scripts has been added to PATH
if ! command -v cgview_comparison_tool.pl &>/dev/null; then
    echo "
  Could not find 'cgview_comparison_tool.pl'. Have you added the
  cgview_comparison_tool/scripts directory to your PATH?
  
  For example, add the following to your ~/.bashrc or ~/.bash_profile file:

    export PATH="\$PATH":"${CCT_HOME}"/scripts

  After saving reload your ~/.bashrc or ~/.bash_profile file:

    source ~/.bashrc
" >&2

    end_test
fi

echo "'Check environment' test passed"
