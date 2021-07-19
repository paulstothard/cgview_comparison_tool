#FILE: local_blast_client.pl
#AUTH: Paul Stothard <stothard@ualberta.ca>
#DATE: June 22, 2020
#VERS: 5.1

use warnings;
use strict;
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use LWP::UserAgent;
use HTTP::Request::Common;
use File::Temp;
use Data::Dumper;

my %settings = (
    PROGRAM      => undef,
    DATABASE     => undef,
    EXPECT       => 10,
    WORD_SIZE    => undef,
    HITLIST_SIZE => 5,
    HSP_MAX      => undef,
    ERROR_RETRY  => 5,
    FILTER       => "T",
    OUTPUTFILE   => undef,
    INPUTFILE    => undef,
    INPUTTYPE    => undef,
    ALIGN_TYPE   => undef,
    BLAST_PATH   => "blastall",
    MIN_HSP_LENGTH        => undef,
    MIN_HSP_PROP          => undef,
    MIN_SCORE             => undef,
    MIN_IDENTITY          => undef,
    QUERY_GENETIC_CODE    => 1,
    DATABASE_GENETIC_CODE => 1,
    BROWSER               => undef,
    MAX_BYTES_RESPONSE    => 5000000,
    HSP_LABEL             => 'F'
);

my $blastType = undef;
my $wordSize  = undef;

GetOptions(
    'i|input_file=s'            => \$settings{INPUTFILE},
    'o|output_file=s'           => \$settings{OUTPUTFILE},
    'b|blast_program=s'         => \$blastType,
    'd|database=s'              => \$settings{DATABASE},
    'h|hsps=i'                  => \$settings{HSP_MAX},
    'l|filter=s'                => \$settings{FILTER},
    'a|min_hsp_length=i'        => \$settings{MIN_HSP_LENGTH},
    'p|min_hsp_prop=f'          => \$settings{MIN_HSP_PROP},
    's|min_score=i'             => \$settings{MIN_SCORE},
    'n|min_identity=f'          => \$settings{MIN_IDENTITY},
    'x|expect=f'                => \$settings{EXPECT},
    't|hit_list_size=i'         => \$settings{HITLIST_SIZE},
    'Q|query_genetic_code=i'    => \$settings{QUERY_GENETIC_CODE},
    'D|database_genetic_code=i' => \$settings{DATABASE_GENETIC_CODE},
    'y|blast_path=s'            => \$settings{BLAST_PATH},
    'hsp_label=s'               => \$settings{HSP_LABEL},
    'W|word_size=i'             => \$wordSize,
        'h|help' => \$settings{'help'}
);

if ( defined( $settings{'help'} ) ) {
    _usage();
    exit(0);
}

if ( !( defined($blastType) ) ) {
    _usage();
    exit(1);
}

if ( !( defined( $settings{DATABASE} ) ) ) {
    _usage();
    exit(1);
}

_setDefaults( $blastType, \%settings );

if ( !( defined( $settings{INPUTFILE} ) ) ) {
    _usage();
    exit(1);
}

if ( !( defined( $settings{OUTPUTFILE} ) ) ) {
    _usage();
    exit(1);
}

open( SEQFILE, $settings{INPUTFILE} ) or die("Cannot open file : $!");

my $inputLessExtentions = $settings{INPUTFILE};
if ( $settings{INPUTFILE} =~ m/(^[^\.]+)/g ) {
    $inputLessExtentions = $1;
}

$settings{HITLIST_SIZE}       = _get_integer( $settings{HITLIST_SIZE} );
$settings{HSP_MAX}            = _get_integer( $settings{HSP_MAX} );
$settings{MIN_HSP_LENGTH}     = _get_integer( $settings{MIN_HSP_LENGTH} );
$settings{MIN_HSP_PROP}       = _get_real( $settings{MIN_HSP_PROP} );
$settings{MIN_SCORE}          = _get_integer( $settings{MIN_SCORE} );
$settings{MIN_IDENTITY}       = _get_real( $settings{MIN_IDENTITY} );
$settings{EXPECT}             = _get_real( $settings{EXPECT} );
$settings{QUERY_GENETIC_CODE} = _get_integer( $settings{QUERY_GENETIC_CODE} );
$settings{DATABASE_GENETIC_CODE}
    = _get_integer( $settings{DATABASE_GENETIC_CODE} );
$wordSize = _get_integer($wordSize);

if ( defined($wordSize) ) {
    $settings{WORD_SIZE} = $wordSize;
}

open( OUTFILE, ">" . $settings{OUTPUTFILE} ) or die("Cannot open file : $!");
print( OUTFILE
        "#-------------------------------------------------------------------------------------------------------------------------------------------------\n"
);
print(    OUTFILE "#Results of automated BLAST query of performed on "
        . _getTime()
        . ".\n" );
print( OUTFILE
        "#Searches performed using local_blast_client.pl, written by Paul Stothard, stothard\@ualberta.ca.\n"
);
print( OUTFILE "#The following settings were specified:\n" );
my @settingsKeys = keys(%settings);

foreach (@settingsKeys) {
    if ( defined( $settings{$_} ) ) {
        print( OUTFILE "#" . $_ . "=" . $settings{$_} . "\n" );
    }
}
print( OUTFILE "#The following attributes are separated by tabs:\n" );
print( OUTFILE
        "#-------------------------------------------------------------------------------------------------------------------------------------------------\n"
);

print( OUTFILE
        "query_id\tmatch_id\tmatch_description\t\%_identity\talignment_length\tmismatches\tgap_openings\tq_start\tq_end\ts_start\ts_end\tevalue\tbit_score\n"
);

close(OUTFILE) or die("Cannot close file : $!");

$settings{BROWSER} = LWP::UserAgent->new();
$settings{BROWSER}->timeout(30);
$settings{BROWSER}->max_size( $settings{MAX_BYTES_RESPONSE} );

my $seqCount = 0;

local $/ = ">";
while ( my $sequenceEntry = <SEQFILE> ) {

    if ( $sequenceEntry eq ">" ) {
        next;
    }
    my $sequenceTitle = "";
    if ( $sequenceEntry =~ m/^([^\n\cM]+)/ ) {
        $sequenceTitle = $1;
    }
    else {
        $sequenceTitle = "No title available";
    }
    $sequenceEntry =~ s/^[^\n\cM]+//;
    $sequenceEntry =~ s/[^A-Z]//ig;
    if ( !( $sequenceEntry =~ m/[A-Z]/i ) ) {
        next;
    }
    my $query = ">" . $sequenceTitle . "\n" . $sequenceEntry;
    $seqCount++;

    if ( defined( $settings{MIN_HSP_PROP} ) ) {
        my $queryLength = length($sequenceEntry);
        if ( $settings{ALIGN_TYPE} eq "nucleotide" ) {
            $settings{MIN_HSP_LENGTH}
                = $settings{MIN_HSP_PROP} * $queryLength;
        }
        elsif ( $settings{ALIGN_TYPE} eq "protein" ) {
            $settings{MIN_HSP_LENGTH}
                = $settings{MIN_HSP_PROP} * $queryLength;
        }
        elsif ( $settings{ALIGN_TYPE} eq "translated" ) {
            $settings{MIN_HSP_LENGTH}
                = $settings{MIN_HSP_PROP} * $queryLength / 3;
        }
        $settings{MIN_HSP_LENGTH}
            = sprintf( "%.0f", $settings{MIN_HSP_LENGTH} );
    }

    #Write the query to a temporary file.
    #The $tmp object acts as a file handle
    my $tmp      = new File::Temp();
    my $filename = $tmp->filename;
    print( $tmp $query );
    close($tmp) or die ("Cannot close file : $!");


    my $format_type = '9';

#-b can be used to specify the number of hits to return when using -m 9. Each hit may consist of one or more HSPs.
#-b and -v must be set to specify the number of hits to return when using -m 7. Each hit may consist of one or more HSPs.
    my $blast_command
        = "$settings{BLAST_PATH} -p $settings{PROGRAM} -d $settings{DATABASE} -e $settings{EXPECT} -i $filename -b $settings{HITLIST_SIZE} -v $settings{HITLIST_SIZE} -m $format_type -W $settings{WORD_SIZE} -F $settings{FILTER}";

    if ($settings{PROGRAM} eq 'blastx') {
        $blast_command .= "-Q $settings{QUERY_GENETIC_CODE}";
    }
    elsif ($settings{PROGRAM} eq 'tblastn') {
        $blast_command .= "-D $settings{DATABASE_GENETIC_CODE}";
    }
    elsif ($settings{PROGRAM} eq 'tblastx') {
        $blast_command .= "-Q $settings{QUERY_GENETIC_CODE}";
        $blast_command .= "-D $settings{DATABASE_GENETIC_CODE}";
    }

    print
        "Performing BLAST search for sequence number $seqCount ($sequenceTitle).\n";

    my $result = `$blast_command`;

    my $hitFound = 0;
    my $HSPCount = 0;
    my @results;

    if ( !( defined($result) ) ) {
        die("Error: BLAST results not obtained for sequence number $seqCount ($sequenceTitle)."
        );
    }
    else {

            @results = @{ _parse_blast_table( \%settings, $result ) };

    }

    foreach (@results) {

        my $HSP = $_;

        $HSPCount++;

        if (   ( defined( $settings{HSP_MAX} ) )
            && ( $HSPCount > $settings{HSP_MAX} ) )
        {
            next;
        }

        if ( defined( $settings{MIN_HSP_LENGTH} ) ) {
            if ( $HSP->{alignment_length} < $settings{MIN_HSP_LENGTH} ) {
                print "Skipping HSP because alignment length is less than "
                    . $settings{MIN_HSP_LENGTH} . ".\n";
                next;
            }
        }

        if ( defined( $settings{MIN_SCORE} ) ) {
            if ( $HSP->{bit_score} < $settings{MIN_SCORE} ) {
                print "Skipping HSP because score is less than "
                    . $settings{MIN_SCORE} . ".\n";
                next;
            }
        }

        if ( defined( $settings{MIN_IDENTITY} ) ) {
            if ( $HSP->{identity} < $settings{MIN_IDENTITY} ) {
                print "Skipping HSP because identity is less than "
                    . $settings{MIN_IDENTITY} . ".\n";
                next;
            }
        }

        #this is to return a single gi number in $col2
        if ( $HSP->{match_id} =~ m/(ref|gi)\|(\d+)/ ) {
            $HSP->{uid}      = $2;
            $HSP->{match_id} = $1 . "|" . $2;
        }

        #write output
        print "Writing HSP to file.\n";

        if (   ( $settings{HSP_LABEL} =~ m/t/i )
            && ( defined( $HSP->{hit_number} ) )
            && ( defined( $HSP->{hsp_number} ) ) )
        {
            $HSP->{match_id}
                = $HSP->{match_id} . ";hit_number=$HSP->{hit_number}";
        }

        if ( !defined( $HSP->{match_description} ) ) {
            $HSP->{match_description} = "-";
        }

        open( OUTFILE, "+>>" . $settings{OUTPUTFILE} )
            or die("Cannot open file : $!");
        print( OUTFILE
                "$HSP->{query_id}\t$HSP->{match_id}\t$HSP->{match_description}\t$HSP->{identity}\t$HSP->{alignment_length}\t$HSP->{mismatches}\t$HSP->{gap_opens}\t$HSP->{q_start}\t$HSP->{q_end}\t$HSP->{s_start}\t$HSP->{s_end}\t$HSP->{evalue}\t$HSP->{bit_score}\n"
        );

        close(OUTFILE) or die("Cannot close file : $!");
        $hitFound = 1;

    }
    if ( !($hitFound) ) {
        open( OUTFILE, "+>>" . $settings{OUTPUTFILE} )
            or die("Cannot open file : $!");
        print( OUTFILE $sequenceTitle . "\t"
                . "no acceptable hits returned\n" );
        close(OUTFILE) or die("Cannot close file : $!");
    }

}
close(SEQFILE) or die("Cannot close file : $!");
print "Open " . $settings{OUTPUTFILE} . " to view the BLAST results.\n";

sub _getTime {
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst )
        = localtime(time);
    $year += 1900;

    my @days = (
        'Sunday',   'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday'
    );
    my @months = (
        'January',   'February', 'March',    'April',
        'May',       'June',     'July',     'August',
        'September', 'October',  'November', 'December'
    );
    my $time
        = $days[$wday] . " "
        . $months[$mon] . " "
        . sprintf( "%02d", $mday ) . " "
        . sprintf( "%02d", $hour ) . ":"
        . sprintf( "%02d", $min ) . ":"
        . sprintf( "%02d", $sec ) . " "
        . sprintf( "%04d", $year );
    return $time;
}

sub _setDefaults {
    my $blastType = shift;
    my $settings  = shift;

    #1 - Nucleotide-nucleotide BLAST (blastn)
    if ( ( $blastType =~ /^blastn$/i ) || ( $blastType eq "1" ) ) {
        $settings->{PROGRAM}    = "blastn";
        $settings->{WORD_SIZE}  = "11";
        $settings->{INPUTTYPE}  = "DNA";
        $settings->{ALIGN_TYPE} = "nucleotide";
    }

    #2 - Protein-protein BLAST (blastp)
    elsif ( ( $blastType =~ /^blastp$/i ) || ( $blastType eq "2" ) ) {
        $settings->{PROGRAM}    = "blastp";
        $settings->{WORD_SIZE}  = "3";
        $settings->{INPUTTYPE}  = "protein";
        $settings->{ALIGN_TYPE} = "protein";
    }

    #3 - Translated query vs protein database (blastx)
    elsif ( ( $blastType =~ /^blastx$/i ) || ( $blastType eq "3" ) ) {
        $settings->{PROGRAM}    = "blastx";
        $settings->{WORD_SIZE}  = "3";
        $settings->{INPUTTYPE}  = "DNA";
        $settings->{ALIGN_TYPE} = "translated";
    }

    #4 - Protein query vs translated database (tblastn)
    elsif ( ( $blastType =~ /^tblastn$/i ) || ( $blastType eq "4" ) ) {
        $settings->{PROGRAM}    = "tblastn";
        $settings->{WORD_SIZE}  = "3";
        $settings->{INPUTTYPE}  = "protein";
        $settings->{ALIGN_TYPE} = "translated";
    }

    #5 - Translated query vs. translated database (tblastx)
    elsif ( ( $blastType =~ /^tblastx$/i ) || ( $blastType eq "5" ) ) {
        $settings->{PROGRAM}    = "tblastx";
        $settings->{WORD_SIZE}  = "3";
        $settings->{INPUTTYPE}  = "DNA";
        $settings->{ALIGN_TYPE} = "translated";
    }
    else {
        die("BLAST type $blastType is not recognized.");
    }
}

sub _get_integer {
    my $value = shift;
    my $int   = undef;
    if ( ( defined($value) ) && ( $value =~ m/(\-*\d+)/ ) ) {
        $int = $1;
    }
    return $int;
}

sub _get_real {
    my $value = shift;
    my $real  = undef;
    if ( ( defined($value) ) && ( $value =~ m/(\S+)/ ) ) {
        $real = $1;
    }
    return $real;
}

sub _parse_blast_table {
    my $settings = shift;
    my $table    = shift;
    my $searchPattern
        = '^([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t]+([^\t]+)[\t\s]*$';

    my @results = split( /\n/, $table );
    my @HSPs = ();

    foreach (@results) {

        if ( $_ =~ m/^\#\sFields:/ ) {
            next;
        }

        if ( !( $_ =~ m/$searchPattern/ ) ) {
            next;
        }

        my %HSP = (
            query_id           => undef,
            match_id           => undef,
            match_description  => undef,
            identity           => undef,
            positives          => undef,
            query_sbjct_frames => undef,
            alignment_length   => undef,
            mismatches         => undef,
            gap_opens          => undef,
            q_start            => undef,
            q_end              => undef,
            s_start            => undef,
            s_end              => undef,
            evalue             => undef,
            bit_score          => undef,
            uid                => undef
        );

        $HSP{query_id}           = $1;
        $HSP{match_id}           = $2;
        $HSP{match_description}  = undef;
        $HSP{identity}           = $3;
        $HSP{positives}          = undef;
        $HSP{query_sbjct_frames} = undef;
        $HSP{alignment_length}   = $4;
        $HSP{mismatches}         = $5;
        $HSP{gap_opens}          = $6;
        $HSP{q_start}            = $7;
        $HSP{q_end}              = $8;
        $HSP{s_start}            = $9;
        $HSP{s_end}              = $10;
        $HSP{evalue}             = $11;
        $HSP{bit_score}          = $12;

        push( @HSPs, \%HSP );
    }
    return \@HSPs;
}

sub _usage {
    print <<BLOCK;
local_blast_client.pl - local BLAST searches using legacy BLAST.

DISPLAY HELP AND EXIT:

usage:

  perl local_blast_client.pl -help

PERFORM LOCAL BLAST SEARCH:

usage:

  perl local_blast_client.pl -i <file> -o <file> -d <file> -b <string> [Options]

required arguments:

-i - Input file containing one or more sequences in FASTA format.

-o - Output file in tab-delimited format to create.

-d - Database to search.

-b - BLAST search type: blastn, blastp, blastx, tblastn, or tblastx.

optional arguments:

-h - Number of HSPs to keep per query. [Integer]. Default is to keep all HSPs.

-filter - Whether to filter query sequence. [T/F]. Default is T.

-a - Minimum HSP length to keep. [Integer]. Default is to keep all HSPs.

-p - Minimum HSP length to keep, expressed as a proportion of the query
sequence length. [Real]. Overrides -a. Default is to keep all HSPs.

-s - Minimum HSP score to keep. [Integer]. Default is to keep all HSPs. 

-n - Minimum HSP identity to keep. [Real]. Default is to keep all HSPs.

-x - Expect value setting to supply to the blastall program. [Real]. Default is
10.0.

-t - Number of hits to keep. [Integer]. Default is 5.

-Q - The genetic code to use for the query sequence, for translated BLAST
searches. [Integer]. Default is 1.

-D - The genetic code to use for the database sequences, for translated BLAST
searches. [Integer]. Default is 1.

-y - The path to the blastall program. [File]. Default is blastall.

-hsp_label - Whether to add a label to the match_description of each. HSP to
indicate which hit it belongs to. [T/F]. Default is F.

-W - The word size to use. [Integer]. Default depends on search type.

example usage:

  perl local_blast_client.pl -i my_seqs.fasta -o blast_results.txt -b blastn \\
  -d sequences.fasta
BLOCK
}
