#!/usr/bin/env perl
#FILE: ncbi_search.pl
#AUTH: Paul Stothard (stothard@ualberta.ca)
#DATE: April 18, 2020
#VERS: 1.2

use warnings;
use strict;
use Getopt::Long;
use URI::Escape;
use LWP::Protocol::https;
use LWP::UserAgent;
use HTTP::Request::Common;

my %param = (
    query       => undef,
    output_file => undef,
    database    => undef,
    return_type => '',
    max_records => undef,
    format      => undef,
    verbose     => undef,
    separate    => undef,
    url         => 'https://www.ncbi.nlm.nih.gov/entrez/eutils',
    retries     => 0,
    max_retries => 5,
    help        => undef
);

Getopt::Long::Configure('bundling');
GetOptions(
    'q|query=s'       => \$param{query},
    'o|output_file=s' => \$param{output_file},
    'd|database=s'    => \$param{database},
    'r|return_type=s' => \$param{return_type},
    'm|max_records=i' => \$param{max_records},
    's|separate'      => \$param{separate},
    'verbose|v'       => \$param{verbose},
    'h|help'          => \$param{help}
);

if ( defined( $param{help} ) ) {
    print_usage();
    exit(0);
}

if (   !( defined( $param{query} ) )
    or !( defined( $param{output_file} ) )
    or !( defined( $param{database} ) ) )
{
    print_usage();
    exit(1);
}

$param{return_type} = lc( $param{return_type} );

$param{query} = uri_escape( $param{query} );

# Set up for the -split option
if ( $param{separate} ) {
    if (   ( $param{return_type} eq 'gb' )
        || ( $param{return_type} eq 'gbwithparts' ) )
    {
        if ( !( -d $param{output_file} ) ) {
            mkdir( $param{output_file}, 0775 )
              or
              die( "Could not create directory " . $param{output_file} . "." );
        }

    }
    else {
        $param{separate} = 0;
        print
"-r is not 'gb' or 'gbwithparts', so the -s option will be ignored.\n";
    }
}

search(%param);

sub search {
    my %param = @_;

    my $esearch = "$param{url}/esearch.fcgi?db=$param{database}"
      . "&retmax=1&usehistory=y&term=$param{query}";

    my $ua = LWP::UserAgent->new(
        ssl_opts          => { verify_hostname => 0 },
        protocols_allowed => ['https'],
    );
    my $esearch_response = $ua->get($esearch);
    my $esearch_result   = $esearch_response->decoded_content;

    while (
        ( !defined($esearch_result) )
        || (
            !(
                $esearch_result =~
m/<Count>(\d+)<\/Count>.*<QueryKey>(\d+)<\/QueryKey>.*<WebEnv>(\S+)<\/WebEnv>/s
            )
        )
      )
    {
        if ( $esearch_result =~ m/<ERROR>(.*)<\/ERROR>/is ) {
            die("ESearch returned an error: $1");
        }
        message( $param{verbose},
            "ESearch results could not be parsed. Resubmitting query.\n" );
        sleep(10);
        if ( $param{retries} >= $param{max_retries} ) {
            die("Too many failures--giving up search.");
        }

        $esearch_response = $ua->get($esearch);
        $esearch_result   = $esearch_response->decoded_content;
        $param{retries}++;
    }

    $param{retries} = 0;

    $esearch_result =~
m/<Count>(\d+)<\/Count>.*<QueryKey>(\d+)<\/QueryKey>.*<WebEnv>(\S+)<\/WebEnv>/s;

    my $count     = $1;
    my $query_key = $2;
    my $web_env   = $3;

    if ( defined( $param{max_records} ) ) {
        if ( $count > $param{max_records} ) {
            message( $param{verbose},
"Retrieving $param{max_records} records out of $count available records.\n"
            );
            $count = $param{max_records};
        }
        else {
            message( $param{verbose},
                "Retrieving $count records out of $count available records.\n"
            );
        }
    }
    else {
        message( $param{verbose},
            "Retrieving $count records out of $count available records.\n" );
    }

    my $retmax = 500;

    if ( $param{separate} ) {
        $retmax = 1;
    }

    if ( $retmax > $count ) {
        $retmax = $count;
    }

    my $OUTFILE;
    if ( !$param{separate} ) {
        open( $OUTFILE, ">" . $param{output_file} )
          or die("Error: Cannot open $param{output_file} : $!");
    }

    for (
        my $retstart = 0 ;
        $retstart < $count ;
        $retstart = $retstart + $retmax
      )
    {
        if ( $retmax == 1 ) {
            message( $param{verbose},
                "Downloading record " . ( $retstart + 1 ) . "\n" );
        }
        else {
            message( $param{verbose},
                    "Downloading records "
                  . ( $retstart + 1 ) . " to "
                  . ( $retstart + $retmax )
                  . "\n" );
        }

        my $efetch =
"$param{url}/efetch.fcgi?rettype=$param{return_type}&retmode=text&retstart=$retstart&retmax=$retmax&db=$param{database}&query_key=$query_key&WebEnv=$web_env";
        my $efetch_response = $ua->get($efetch);
        my $efetch_result   = $efetch_response->decoded_content;

        while ( !defined($efetch_result) ) {
            message( $param{verbose},
                "EFetch results could not be parsed. Resubmitting query.\n" );
            sleep(10);
            if ( $param{retries} >= $param{max_retries} ) {
                die("Too many failures--giving up search.");
            }

            $efetch_response = $ua->get($efetch);
            $efetch_result   = $efetch_response->decoded_content;
            $param{retries}++;
        }

        $efetch_result =~ s/[^[:ascii:]]+//g;
        if ( $param{separate} ) {
            my $record_num = $retstart + 1;
            write_separate_record( $efetch_result, $record_num );
        }
        else {
            print( $OUTFILE $efetch_result );
        }

        unless (
            ( defined( $param{max_records} ) && ( $param{max_records} == 1 ) ) )
        {
            sleep(1);
        }
    }

    if ( !$param{separate} ) {
        close($OUTFILE)
          or die("Error: Cannot close $param{output_file} file: $!");
    }
}

sub write_separate_record {
    my $record     = shift;
    my $record_num = shift;
    if ( $record =~ /ACCESSION\s+(\S+)/ ) {
        my $accession = $1;
        my $filename  = $param{output_file} . "/$accession.gbk";
        my $count     = 0;
        while ( -e $filename ) {
            $filename =
              $param{output_file} . "/$accession" . '_' . "$count.gbk";
            $count++;
        }
        open( my $RECORD_FILE, ">" . $filename );
        print( $RECORD_FILE $record );
        close($RECORD_FILE);
    }
    else {
        print("Could not find accession line in record '$record_num'.\n");
    }
}

sub message {
    my $verbose = shift;
    my $message = shift;
    if ($verbose) {
        print $message;
    }
}

sub print_usage {
    print <<BLOCK;
ncbi_search.pl - search NCBI databases.

DISPLAY HELP AND EXIT:

usage:

  perl ncbi_search.pl -help

PERFORM NCBI SEARCH:

usage:

  perl ncbi_search.pl -q <string> -o <file> -d <string> [Options]

required arguments:

-q - Entrez query text.

-o - Output file to create. If the -s option is used this is the output
directory to create.

-d - Name of the NCBI database to search, such as 'nuccore', 'protein', or
'gene'.

optional arguments:

-r - Type of information to download. For sequences, 'fasta' is typically
specified. The accepted formats depend on the database being queried. The
default is to specify no format.
  
-m - The maximum number of records to download. Default is to download all
records.
  
-s - Save each record as a separate file. This option is only supported for -r
values of 'gb' and 'gbwithparts'.

-v - Provide progress messages.

example usage:

  perl ncbi_search.pl -q 'NC_045512[Accession]' -o NC_045512.gbk -d nuccore \\
  -r gbwithparts
BLOCK
}
