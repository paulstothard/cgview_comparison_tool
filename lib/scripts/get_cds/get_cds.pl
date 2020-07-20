#FILE: get_cds.pl
#AUTH: Paul Stothard <stothard@ualberta.ca>
#DATE: June 22, 2020
#VERS: 1.2

use strict;
use warnings;

use Getopt::Long;
use Bio::SeqIO;
use Bio::SeqUtils;

my %global = (
    input    => undef,
    output   => undef,
    cdsCount => 0,
    dna      => 'F',
    help     => undef
);

GetOptions(
    'i=s'    => \$global{'input'},
    'o=s'    => \$global{'output'},
    'dna=s'  => \$global{'dna'},
    'h|help' => \$global{'help'}
);

if ( defined( $global{'help'} ) ) {
    _usage();
    exit(0);
}

if ( !( defined( $global{'input'} ) ) ) {
    _usage();
    exit(1);
}
if ( !( defined( $global{'output'} ) ) ) {
    _usage();
    exit(1);
}

if ( -e $global{'output'} ) {
    unlink( $global{'output'} )
      or die("Cannot remove $global{'output'} file: $!");
}

my $seqObject = _getSeqObject( \%global );
if (   ( !( $global{"type"} eq "embl" ) )
    && ( !( $global{"type"} eq "genbank" ) ) )
{
    die("get_cds.pl requires a GenBank or EMBL file as input.");
}

_writeCDS( \%global, $seqObject, 1, 1 );
_writeCDS( \%global, $seqObject, 1, 2 );
_writeCDS( \%global, $seqObject, 1, 3 );

_writeCDS( \%global, $seqObject, -1, 1 );
_writeCDS( \%global, $seqObject, -1, 2 );
_writeCDS( \%global, $seqObject, -1, 3 );

print "A total of $global{cdsCount} records were written to $global{output}.\n";

sub _writeCDS {

    my $global     = shift;
    my $seqObject  = shift;
    my $strand     = shift;    #1 or -1
    my $rf         = shift;    #1,2,3
    my $rfForLabel = $rf;

    my $length = $seqObject->length();

    if ( ( defined($rf) ) && ( $rf == 3 ) ) {
        $rf = 0;
    }

    #need to get the features from from the GenBank record.
    my @features = $seqObject->get_SeqFeatures();
    @features = @{ _sortFeaturesByStart( \@features ) };

    if ( $strand == 1 ) {
        @features = reverse(@features);
    }

    foreach (@features) {
        my $feat = $_;

        my $type = lc( $feat->primary_tag );
        unless ( $type eq "cds" ) {
            next;
        }

        my $st = $feat->strand;
        unless ( ( defined($st) ) && ( $st == $strand ) ) {
            next;
        }

        my $start = $feat->start;
        my $stop  = $feat->end;

        my $location  = $feat->location;
        my $locString = $location->to_FTstring;
        my @loc       = split( /,/, $locString );

        if ( $loc[0] =~ m/(\d+)\.\.(\d+)/ ) {
            $start = $1;
        }

        if ( $loc[ scalar(@loc) - 1 ] =~ m/(\d+)\.\.(\d+)/ ) {
            $stop = $2;
        }

        if ( defined($rf) ) {
            if ( $strand == 1 ) {
                unless ( $rf == $start % 3 ) {
                    next;
                }
            }
            elsif ( $strand == -1 ) {
                unless ( $rf == ( $length - $stop + 1 ) % 3 ) {
                    next;
                }
            }
        }

        my @label = ();
        if ( $feat->has_tag('gene') ) {
            push( @label, join( ",", $feat->get_tag_values('gene') ) );
        }
        if ( $feat->has_tag('locus_tag') ) {
            push( @label, join( ",", $feat->get_tag_values('locus_tag') ) );
        }
        if ( $feat->has_tag('note') ) {

            #	    push (@label, join(",",$feat->get_tag_values('note')));
        }
        if ( $feat->has_tag('product') ) {

            #	    push (@label, join(",",$feat->get_tag_values('product')));
        }
        if ( $feat->has_tag('function') ) {

            #	    push (@label, join(",",$feat->get_tag_values('function')));
        }

        #add position information to label
        #label_start=4001;end=5000;strand=1;rf=1;
        #where strand is 1 or -1 and rf is 1,2, or 3
        #start should be smaller than the end
        push( @label, "_start=$start;end=$stop;strand=$strand;rf=$rfForLabel" );
        my $label = join( ";", @label );
        $label =~ s/\s+/_/g;
        $label =~ s/\n//g;
        $label =~ s/\t+/ /g;

        my $trans;
        if ( !( $feat->has_tag('translation') ) ) {
            print(
"Warning: get_cds.pl was unable to obtain translation for $label. Skipping\n"
            );
            next;
        }
        else {
            my @translation = $feat->get_tag_values('translation');
            $trans = $translation[0];
            $trans =~ s/[^A-Z]//ig;
        }

        my $dna = $feat->spliced_seq->seq;
        if ( ( !( defined($dna) ) ) && ( $global{'dna'} =~ m/t/i ) ) {
            print(
"Warning: get_cds.pl was unable to obtain the DNA coding sequence for $label. Skipping\n"
            );
            next;
        }
        $dna =~ s/[^A-Z]//ig;

        $global->{cdsCount}++;
        open( OUTFILE, "+>>" . $global->{"output"} )
          or die("Cannot open file : $!");

        if ( $global{'dna'} =~ m/t/i ) {
            print( OUTFILE ">$label\n$dna\n\n" );
        }
        else {
            print( OUTFILE ">$label\n$trans\n\n" );
        }
        close(OUTFILE) or die("Cannot close file : $!");
    }
}

sub _getSeqObject {
    my $global = shift;

    open( INFILE, $global->{'input'} ) or die("Cannot open input file: $!");
    while ( my $line = <INFILE> ) {
        if ( !( $line =~ m/\S/ ) ) {
            next;
        }

        #guess file type from first line
        if ( $line =~ m/^LOCUS\s+/ ) {
            $global->{'type'} = "genbank";
        }
        elsif ( $line =~ m/^ID\s+/ ) {
            $global->{'type'} = "embl";
        }
        elsif ( $line =~ m/^\s*>/ ) {
            $global->{'type'} = "fasta";
        }
        else {
            $global->{'type'} = "raw";
        }
        last;

    }

    close(INFILE) or die("Cannot close input file: $!");

    #get seqobj
    my $in = Bio::SeqIO->new(
        -format => $global->{'type'},
        -file   => $global->{'input'}
    );

    #merge multi-contig sequences
    my @seqs = ();

    while ( my $seq = $in->next_seq() ) {
        push( @seqs, $seq );
    }

    Bio::SeqUtils->cat(@seqs);

    return $seqs[0];

}

sub _sortFeaturesByStart {
    my $features = shift;

    @$features = map { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map { [ _getSortValueFeature($_), $_ ] } @$features;

    return $features;
}

sub _getSortValueFeature {
    my $feature = shift;
    my $start   = $feature->start;

   #occasionally BioPerl will obtain an unusual start value like 'join(42734'
   #typically these values come from features that do not represent CDS features
   #and are removed by this script after sorting
    $start =~ s/\D//g;
    return $start;
}

sub _usage {
    print <<BLOCK;
get_cds.pl - extract translations or coding sequences from a GenBank or EMBL
file.

DISPLAY HELP AND EXIT:

usage:

  perl get_cds.pl -help

EXTRACT TRANSLATIONS OR CODING SEQUENCES:

usage:

  perl get_cds.pl -i <file> -o <file> [Options]

required arguments:

-i - Input file in GenBank or EMBL format.

-o - Output file in FASTA format of translations or coding sequences to create.

optional arguments:

-dna - Whether DNA coding sequences should be returned instead of their protein
translations. [T/F]. Default is F.

example usage:

  perl get_cds.pl -i input.gbk -o output.fasta
BLOCK
}
