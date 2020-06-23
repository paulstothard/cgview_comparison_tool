#FILE: get_orfs.pl
#AUTH: Paul Stothard <stothard@ualberta.ca>
#DATE: June 22, 2020
#VERS: 1.2

use strict;
use warnings;

use Getopt::Long;
use Bio::SeqIO;
use Bio::SeqUtils;
use Bio::Tools::CodonTable;

my %options = (
    input            => undef,
    output           => undef,
    geneticCode      => 1,
    minOrfSizeCodons => undef,
    starts           => 'ttg|ctg|att|atc|ata|atg|gtg',
    stops            => 'taa|tag|tga',
    dna              => 'F',
    orfCount         => 0,
    help             => undef
);

GetOptions(
    'i=s'      => \$options{'input'},
    'o=s'      => \$options{'output'},
    'g=i'      => \$options{'geneticCode'},
    'm=i'      => \$options{'minOrfSizeCodons'},
    'starts=s' => \$options{'starts'},
    'stops=s'  => \$options{'stops'},
    'dna=s'    => \$options{'dna'},
    'h|help'   => \$options{'help'}
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
if ( !( defined( $options{'minOrfSizeCodons'} ) ) ) {
    _usage();
    exit(1);
}

if ( -e $options{'output'} ) {
    unlink( $options{'output'} )
      or die("Cannot remove $options{'output'} file: $!");
}

my $seqObject = _getSeqObject( \%options );

_writeORFs( \%options, $seqObject, 1, 1 );
_writeORFs( \%options, $seqObject, 1, 2 );
_writeORFs( \%options, $seqObject, 1, 3 );

_writeORFs( \%options, $seqObject, -1, 1 );
_writeORFs( \%options, $seqObject, -1, 2 );
_writeORFs( \%options, $seqObject, -1, 3 );

print
  "A total of $options{orfCount} records were written to $options{output}.\n";

sub _writeORFs {
    my $options    = shift;
    my $seqObject  = shift;
    my $strand     = shift;    #1 or -1
    my $rf         = shift;    #1,2, or 3
    my $rfForLabel = $rf;

    print "Extracting ORFs in reading frame $rf on strand $strand.\n";

    my $startCodons = $options->{'starts'};
    my $stopCodons  = $options->{'stops'};
    my $orfLength   = $options->{'minOrfSizeCodons'};

    my $codonTable =
      Bio::Tools::CodonTable->new( -id => $options->{'geneticCode'} );

    my $dna;
    if ( $strand == 1 ) {
        $dna = $seqObject->seq();
    }
    else {
        my $rev = $seqObject->revcom;
        $dna = $rev->seq();
    }
    my $length = length($dna);
    my $i      = 0;
    my $codon;
    my $foundStart    = 0;
    my $proteinLength = 0;
    my $foundStop     = 0;
    my $startPos      = $rf - 1;
    my $firstBase;
    my $lastBase;
    my $temp;
    my @protein = ();
    my @dna     = ();

    while ( $i <= $length - 3 ) {
        for ( $i = $startPos ; $i <= $length - 3 ; $i = $i + 3 ) {
            $codon = substr( $dna, $i, 3 );
            if (   ( $startCodons ne "any" )
                && ( $foundStart == 0 )
                && ( !( $codon =~ m/$startCodons/i ) ) )
            {
                last;
            }
            $foundStart = 1;

            if ( $codon =~ m/$stopCodons/i ) {
                $foundStop = 1;
            }

            $proteinLength++;
            push( @protein, $codonTable->translate($codon) );
            push( @dna,     $codon );

            if ( ($foundStop) && ( $proteinLength < $orfLength ) ) {
                last;
            }
            if (
                ( ($foundStop) && ( $proteinLength >= $orfLength ) )
                || (   ( $i >= $length - 5 )
                    && ( $proteinLength >= $orfLength ) )
              )
            {
                $firstBase = $startPos + 1;
                $lastBase  = $i + 3;

                if ( $strand == -1 ) {
                    $temp      = $length - $lastBase + 1;
                    $lastBase  = $length - $firstBase + 1;
                    $firstBase = $temp;
                }

            #write out orf here with $firstBase, $lastBase, $rfForLabel, $strand
                $options->{orfCount}++;

                #remove stop from protein
                pop(@protein);

                my $label = "orf_"
                  . $options->{orfCount}
                  . "_start=$firstBase;end=$lastBase;strand=$strand;rf=$rfForLabel";
                my $seqOut;
                if ( $options->{dna} =~ m/t/i ) {
                    $seqOut = join( "", @dna );
                }
                else {
                    $seqOut = join( "", @protein );
                }

                open( OUTFILE, "+>>" . $options->{"output"} )
                  or die("Cannot open file : $!");
                print( OUTFILE ">$label\n$seqOut\n\n" );
                close(OUTFILE) or die("Cannot close file : $!");
                last;
            }
        }
        $startPos      = $i + 3;
        $i             = $startPos;
        $foundStart    = 0;
        $foundStop     = 0;
        $proteinLength = 0;
        @protein       = ();
        @dna           = ();
    }
}

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
        elsif ( $line =~ m/^\s*>/ ) {
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
get_orfs.pl - identify open reading frames and return their DNA sequences or
protein translations.

DISPLAY HELP AND EXIT:

usage:

  perl get_orfs.pl -help

RETURN ORF TRANSLATIONS OR CODING SEQUENCES

usage:

  perl get_cds.pl -i <file> -o <file> -m <integer> [Options]

required arguments:

-i - Input file in FASTA, RAW, EMBL, or GenBank format.
-o - File of translations or coding sequences to create.

optional arguments:

-dna - Whether DNA coding sequences should be returned instead of their protein
translations. [T/F]. Default is F.

-starts - Start codons. Default is 'atg|ttg|att|gtg|ctg'. To allow ORFs to
begin with any codon, use the value 'any'. [String].

-stops - Stop codons. Default is 'taa|tag|tga'. [String].

-g - Genetic code for translating ORFs, using NCBI numbering. [Integer].
Default is 1.

example usage:

  perl get_orfs.pl -i input.gbk -o output.fasta -g 11 -m 100
BLOCK
}

