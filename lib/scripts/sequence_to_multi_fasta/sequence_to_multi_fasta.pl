#FILE: sequence_to_multi_fasta.pl
#AUTH: Paul Stothard <stothard@ualberta.ca>
#DATE: June 22, 2020
#VERS: 1.2

use strict;
use warnings;

use Getopt::Long;
use Bio::SeqIO;
use Bio::SeqUtils;

my %options = (
    input   => undef,
    output  => undef,
    size    => undef,
    overlap => undef,
    title   => undef,
    type    => undef,
    help    => undef
);

Getopt::Long::Configure('bundling');
GetOptions(
    'i=s'    => \$options{'input'},
    'o=s'    => \$options{'output'},
    's=i'    => \$options{'size'},
    'v=i'    => \$options{'overlap'},
    'h|help' => \$options{'help'}
);

if ( defined( $options{'help'} ) ) {
    _usage();
    exit(0);
}
if ( !( defined( $options{'input'} ) ) ) {
    _usage();
    exit(1);
}
if ( !( defined( $options{'output'} ) ) ) {
    _usage();
    exit(1);
}

my $seqObject = _getSeqObject( \%options );
if ( ( $options{"type"} eq "embl" ) || ( $options{"type"} eq "genbank" ) ) {
    $options{"accession"} = $seqObject->accession_number;
    if ( !( defined( $options{"title"} ) ) ) {
        $options{"title"} = $seqObject->description();
    }
}
if ( $options{"type"} eq "fasta" ) {
    if ( !( defined( $options{"title"} ) ) ) {
        $options{"title"} = $seqObject->description();
    }
}

if ( !( defined( $options{"title"} ) ) ) {
    $options{"title"} = "split";
}

my $dna    = $seqObject->seq();
my $length = length($dna);

$options{'title'} =~ s/\s+/_/g;

if ( !( defined( $options{'size'} ) ) ) {
    $options{'size'} = $length;
}

open( OUTFILE, ">" . $options{"output"} ) or die("Cannot open file : $!");
for ( my $i = 0 ; $i < $length ; $i = $i + $options{'size'} ) {

    #if using overlap adjust $i
    if ( ( defined( $options{'overlap'} ) ) && ( $i > $options{'overlap'} ) ) {
        $i = $i - $options{'overlap'};
    }
    my $start         = $i + 1;
    my $subseq        = substr( $dna, $i, $options{'size'} );
    my $subseq_length = length($subseq);
    my $end           = $start + $subseq_length - 1;
    print(  OUTFILE ">"
          . $options{'title'}
          . "_start=$start;end=$end;length=$subseq_length;source_length=$length\n$subseq\n"
    );
}
close(OUTFILE) or die("Cannot close file : $!");

sub _getSeqObject {
    my $options = shift;

    open( INFILE, $options->{'input'} ) or die("Cannot open input file: $!");
    while ( my $line = <INFILE> ) {
        if ( !( $line =~ m/\S/ ) ) {
            next;
        }

        #guess file type from first line
        if ( $line =~ m/^LOCUS\s+/ ) {
            $options->{'type'} = "genbank";
        }
        elsif ( $line =~ m/^ID\s+/ ) {
            $options->{'type'} = "embl";
        }
        elsif ( $line =~ m/^>/ ) {
            $options->{'type'} = "fasta";
        }
        else {
            $options->{'type'} = "raw";
        }
        last;

    }

    close(INFILE) or die("Cannot close input file: $!");

    #get seqobj
    my $in = Bio::SeqIO->new(
        -format => $options->{'type'},
        -file   => $options->{'input'}
    );

    #merge multi-contig sequences
    my @seqs = ();

    while ( my $seq = $in->next_seq() ) {
        push( @seqs, $seq );
    }

    Bio::SeqUtils->cat(@seqs);

    return $seqs[0];
}

sub _usage {
    print <<BLOCK;
sequence_to_multi_fasta.pl - split a DNA sequence.

DISPLAY HELP AND EXIT:

usage:

  perl sequence_to_multi_fasta.pl -help

SPLIT DNA SEQUENCE

usage:

  perl sequence_to_multi_fasta.pl -i <file> -o <file> [Options]

required arguments:

-i - Input file in FASTA, RAW, EMBL, or GenBank format.
-o - Output file in FASTA format of sequence fragments.

optional arguments:

-v - The overlap to include between sequences, in bases. [Integer].

-s - The size of the sequences to create, in bases. [Integer]. Default is to
return the entire sequence as a single FASTA record.

example usage:

  perl sequence_to_multi_fasta.pl -i input.gbk -o output.fasta -s 10000 -v 500
BLOCK
}
