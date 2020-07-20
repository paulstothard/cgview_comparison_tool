#FILE: assign_cogs.pl
#AUTH: Paul Stothard <stothard@ualberta.ca>
#DATE: June 22, 2020
#VERS: 1.1

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use File::Temp;
use Bio::SeqIO;
use Bio::SeqUtils;

my %options = (
    input          => undef,
    output         => undef,
    protein_source => undef,
    myva           => 'db/myva',
    whog           => 'db/whog',
    get_orfs       => '../get_orfs/get_orfs.pl',
    get_cds        => '../get_cds/get_cds.pl',
    local_bl       => '../local_blast_client/local_blast_client.pl',
    blastall       => 'blastall',
    genetic_code   => 11,
    all_cogs       => undef,
    e_value        => 10.0,
    hit_proportion => undef,
    starts         => 'atg|ttg|att|gtg|ctg',
    stops          => 'taa|tag|tga',
    m_orf          => 30,
    m_score        => undef,
    verbose        => undef,
    help           => undef
);

GetOptions(
    'i=s'        => \$options{input},
    'o=s'        => \$options{output},
    's=s'        => \$options{protein_source},
    'myva=s'     => \$options{myva},
    'whog=s'     => \$options{whog},
    'get_orfs=s' => \$options{get_orfs},
    'get_cds=s'  => \$options{get_cds},
    'local_bl=s' => \$options{local_bl},
    'blastall=s' => \$options{blastall},
    'c=i'        => \$options{genetic_code},
    'a'          => \$options{all_cogs},
    'e=f'        => \$options{e_value},
    'p=f'        => \$options{hit_proportion},
    'starts=s'   => \$options{starts},
    'stops=s'    => \$options{stops},
    'm_orf=i'    => \$options{m_orf},
    'm_score=f'  => \$options{m_score},
    'v'          => \$options{verbose},
    'help'       => \$options{help}
);

if ( defined( $options{help} ) ) {
    _usage();
    exit(0);
}

if ( !defined( $options{input} ) ) {
    print "Please specify an input file using the '-i' option.\n";
    _usage();
    exit(1);
}
if ( !defined( $options{output} ) ) {
    print "Please specify an output file using the '-o' option.\n";
    _usage();
    exit(1);
}
if ( !defined( $options{protein_source} ) ) {
    _usage();
    exit(1);
}

#determine length of input sequence
my $sequence_length = get_seq_length( $options{input} );

#parse whog file
message( $options{verbose}, "Parsing whog file '$options{whog}'.\n" );
my $seq_id_to_function_hash = parse_whog_file( $options{whog} );

#obtain protein sequences
my $protein_file      = new File::Temp();
my $protein_file_name = $protein_file->filename;

if ( lc( $options{protein_source} ) eq 'cds' ) {
    message( $options{verbose},
        "Obtaining CDS translations from '$options{input}'.\n" );
    my $command =
      "perl $options{get_cds} -i $options{input} -o $protein_file_name";
    my $result = system($command);
    if ( $result != 0 ) {
        die("The following command failed: '$command'\n");
    }

    #file will not exist if no CDS features found
    if ( !-f $protein_file_name ) {
        message( $options{verbose},
            "No CDS translations found in '$options{input}'.\n" );
        exit;
    }
}
elsif ( lc( $options{protein_source} ) eq 'orfs' ) {
    message( $options{verbose},
        "Obtaining ORF translations from '$options{input}'.\n" );
    my $command =
"perl $options{get_orfs} -i $options{input} -o $protein_file_name -g $options{genetic_code}"
      . " -starts '$options{starts}' -stops '$options{stops}' -m $options{m_orf}";
    my $result = system($command);
    if ( $result != 0 ) {
        die("The following command failed: '$command'\n");
    }

    #file will not exist if no ORFs found
    if ( !-f $protein_file_name ) {
        message( $options{verbose},
            "No ORF translations found in '$options{input}'.\n" );
        exit;
    }
}
else {
    print
"Please specify 'cds' or 'orfs' as the protein source using the '-s' option.\n";
    die( print_usage() . "\n" );
}

#perform blast search
my $blast_file      = new File::Temp();
my $blast_file_name = $blast_file->filename;
if (1) {
    message( $options{verbose},
        "Performing BLAST comparison for proteins from '$options{input}'.\n" );
    my $command =
        "perl $options{local_bl} -i $protein_file_name -o $blast_file_name"
      . " -d $options{myva} -b blastp -x $options{e_value} -y $options{blastall}";
    if ( defined( $options{hit_proportion} ) ) {
        $command = $command . " -p $options{hit_proportion}";
    }

    if ( defined( $options{m_score} ) ) {
        $command = $command . " -s $options{m_score}";
    }

    if ( !defined( $options{all_cogs} ) ) {
        $command = $command . " -t 1";
    }
    else {
        $command = $command . " -t 100";
    }

    my $result = system($command);
    if ( $result != 0 ) {
        die("The following command failed: '$command'\n");
    }
}

#parse blast results and write output file
message( $options{verbose},
    "Assigning COG functional categories to proteins from '$options{input}'.\n"
);

my $blast_results = parse_blast( $blast_file_name, $sequence_length );

open( my $OUTFILE, '>', $options{output} ) or die("Cannot open file : $!");

print $OUTFILE "seqname\tsource\tfeature\tstart\tend\tscore\tstrand\tframe\n";

foreach my $blast_result ( @{$blast_results} ) {

    #determine cog functional category
    my $cog_function;
    my $cog_id = '.';
    if (
        defined(
            $seq_id_to_function_hash->{ $blast_result->{match_id} }->{function}
        )
      )
    {
        $cog_function =
          $seq_id_to_function_hash->{ $blast_result->{match_id} }->{function};
    }
    if (
        defined(
            $seq_id_to_function_hash->{ $blast_result->{match_id} }->{id}
        )
      )
    {
        $cog_id = $seq_id_to_function_hash->{ $blast_result->{match_id} }->{id};
    }

    my $seq_name = $blast_result->{query_id};

    my $strand = $blast_result->{q_strand};
    if ( $strand == -1 ) {
        $strand = '-';
    }
    elsif ( $strand == 1 ) {
        $strand = '+';
    }

    my $score = sprintf( "%.2f", ( $blast_result->{'%_identity'} / 100 ) );

    if ( defined($cog_function) ) {
        print $OUTFILE
"$seq_name\t$cog_id\t$cog_function\t$blast_result->{q_start}\t$blast_result->{q_end}\t$score\t$strand\t$blast_result->{q_rf}\n";
    }

}

close($OUTFILE) or die("Cannot close file: $!");

message( $options{verbose}, "Open '$options{output}' to view the results.\n" );

sub parse_whog_file {

    my $whog_file     = shift;
    my %cog_whog_hash = ();

    open( my $WHOG, $whog_file ) or die("Cannot open file : $!");
    local $/ = "_______";
    while ( my $record = <$WHOG> ) {
        my $cog_function;
        my $cog_id;

        #[H] COG0001 Glutamate-1-semialdehyde aminotransferase
        #[LKJ] COG0513 Superfamily II DNA and RNA helicases
        if ( $record =~ m/\[([A-Z]+)\]\s+(COG\d+)\s+([^\n\cM]+)/ ) {
            $cog_function = $1;
            $cog_id       = $2;
        }

        #  Ape:  APE2130 APE2299
        while ( $record =~ m/\s{2}\S+:\s+([^\n\cM]+)/g ) {
            my @ids = split( /\s/, $1 );
            foreach my $id (@ids) {
                my %hash = ( function => $cog_function, id => $cog_id );
                $cog_whog_hash{$id} = \%hash;
            }
        }
    }
    close($WHOG) or die("Cannot close file : $!");
    return \%cog_whog_hash;
}

sub get_seq_length {
    my $file = shift;
    my $type;

    open( INFILE, $file ) or die("Cannot open file: $!");
    while ( my $line = <INFILE> ) {
        if ( !( $line =~ m/\S/ ) ) {
            next;
        }

        #guess file type from first line
        if ( $line =~ m/^LOCUS\s+/ ) {
            $type = "genbank";
        }
        elsif ( $line =~ m/^ID\s+/ ) {
            $type = "embl";
        }
        elsif ( $line =~ m/^\s*>/ ) {
            $type = "fasta";
        }
        else {
            $type = "raw";
        }
        last;

    }
    close(INFILE) or die("Cannot close file: $!");

    #get seqobj
    my $in = Bio::SeqIO->new(
        -format => $type,
        -file   => $file
    );

    #merge multi-contig sequences
    my @seqs = ();

    while ( my $seq = $in->next_seq() ) {
        push( @seqs, $seq );
    }

    Bio::SeqUtils->cat(@seqs);

    return $seqs[0]->length();
}

#based on the _parseBlast subroutine from cgview_xml_builder.pl
sub parse_blast {
    my $file            = shift;
    my $sequence_length = shift;

#The file can contain comments starting with'#'
#The file must have a line beginning with a 'query_id' and indicating the column names:
#query_id   match_id    match_description   %_identity  alignment_length    mismatches  gap_openings    q_start q_end   s_start s_end   evalue  bit_score

    my @required = (
        'query_id',         '%_identity', 'q_start', 'q_end',
        'alignment_length', 'evalue'
    );

    my $lineCount    = 0;
    my @columnTitles = ();
    my $columnsRead  = 0;

#program will be used to store the value of #PROGRAM in the blast results header.
#if it is blastp or tblastn then q_start and q_end are in residues and need to
#be converted to bases.
    my $program = undef;

    open( INFILE, $file )
      or die("Cannot open the BLAST results file '$file'\n");

    #check for column titles
    while ( my $line = <INFILE> ) {
        $line =~ s/\cM|\n//g;
        $lineCount++;
        if ( $line =~ m/^\#PROGRAM\s*=\s*([^\s]+)/ ) {
            $program = $1;
        }
        if ( $line =~ m/^\#/ ) {
            next;
        }
        if ( $line =~ m/^query_id/ ) {
            $columnsRead  = 1;
            @columnTitles = @{ _split($line) };
            last;
        }
    }

    if ( !( defined($program) ) ) {
        die(
"Cannot parse the #PROGRAM field in the BLAST results file '$file'\n"
        );
    }

    if ( !( $program =~ m/^blastp$/ ) ) {
        die("#PROGRAM field in the BLAST results file '$file' is not 'blastp'\n"
        );
    }

    #print Dumper(@columnTitles);

    #now check for required columns
    foreach (@required) {
        my $req   = $_;
        my $match = 0;
        foreach (@columnTitles) {
            my $columnTitle = $_;
            if ( $columnTitle eq $req ) {
                $match = 1;
                last;
            }
        }
        if ( !($match) ) {
            die(
"The BLAST results in '$file' do not contain a column labeled '$req'\n"
            );
        }
    }

    my $scale = 3;

    #read the remaining entries
    my @entries = ();
    while ( my $line = <INFILE> ) {
        $line =~ s/\cM|\n//g;
        $lineCount++;
        if ( $line =~ m/^\#/ ) {
            next;
        }
        if ( $line =~ m/\S/ ) {
            my @values = @{ _split($line) };

            #skip lines with missing values
            if ( scalar(@values) != scalar(@columnTitles) ) {
                next;
            }

            my %entry = ();
            for ( my $i = 0 ; $i < scalar(@columnTitles) ; $i++ ) {
                $entry{ $columnTitles[$i] } = $values[$i];
            }

            #do some error checking of values
            #check query_id, %_identity, q_start, and q_end
            #skip if no identity value
            if ( !( $entry{'%_identity'} =~ m/\d/ ) ) {
                die(
"No \%_identity value BLAST results '$file' line '$lineCount'\n"
                );
            }

            if ( !( $entry{'q_start'} =~ m/\d/ ) ) {
                die("No q_start value BLAST results '$file' line '$lineCount'\n"
                );
            }
            if ( !( $entry{'q_end'} =~ m/\d/ ) ) {
                die("No q_end value BLAST results '$file' line '$lineCount'\n");
            }

#Note that the following example blast result is not handled properly:
#tagA;pO157p01;_start=92527;end=2502;strand=1;rf=1       tagA;pO157p01;_start=92527;end=2502;strand=1;rf=1       -       100.00  898     0       0       1       898     1       898     0.0     1845
#This is because the feature spans the end/start boundary of the circular sequence.
#For now such features will be skipped.

    #try to add reading frame and strand information using information
    #in the query_id:
    #orf3_start=3691;end=3858;strand=1;rf=1
    #orf16_start=8095;end=8178;strand=1;rf=1
    #
    #The q_start and q_end values are to be the region of the query that matched
    #the hit. Depending on the search type, these can be in amino acids
    #or bases. The values in the query_id are always in bases. The
    #scale factor is used to convert the q_start and q_end values
    #so that they can be used to adjust the values in the query_id.
    #This allows hits to be mapped to the genomic sequence
            if ( $entry{'query_id'} =~
                m/start=(\d+);end=(\d+);strand=(\-*\d+);rf=(\d+)\s*$/ )
            {

                my $genome_start  = $1;
                my $genome_end    = $2;
                my $genome_strand = $3;
                my $genome_rf     = $4;
                $entry{'q_rf'} = $genome_rf;

                my $match_length_bases;
                if ( $entry{'q_start'} > $entry{'q_end'} ) {
                    my $temp = $entry{'q_start'};
                    $entry{'q_start'} = $entry{'q_end'};
                    $entry{'q_end'}   = $temp;
                    $genome_strand    = $genome_strand * -1;
                    $entry{'q_rf'}    = undef;
                }

                $match_length_bases =
                  ( $entry{'q_end'} - $entry{'q_start'} + 1 ) * $scale;

                if ( $genome_strand == -1 ) {
                    $entry{'q_strand'} = -1;
                    $entry{'q_end'} =
                      $genome_end -
                      ( $entry{'q_start'} * $scale ) +
                      ( 1 * $scale );
                    $entry{'q_start'} =
                      $entry{'q_end'} - $match_length_bases + 1;
                }
                else {
                    $entry{'q_strand'} = 1;
                    $entry{'q_start'} =
                      $genome_start +
                      ( $entry{'q_start'} * $scale ) -
                      ( 1 * $scale );
                    $entry{'q_end'} =
                      $entry{'q_start'} + $match_length_bases - 1;
                }
            }
            else {
                die(
"Unable to parse BLAST result from file '$file' line '$lineCount'."
                );
            }

            if ( $entry{'q_start'} < 1 ) {
                $entry{'q_start'} = $entry{'q_start'} + $sequence_length;
            }
            if ( $entry{'q_end'} < 1 ) {
                $entry{'q_end'} = 1;
            }
            if ( $entry{'q_start'} > $sequence_length ) {
                $entry{'q_start'} = $sequence_length;
            }
            if ( $entry{'q_end'} > $sequence_length ) {
                $entry{'q_end'} = $entry{'q_end'} - $sequence_length;
            }

            push( @entries, \%entry );
        }
    }
    close(INFILE) or die("Cannot close file : $!");
    return \@entries;
}

sub _split {
    my $line   = shift;
    my @values = ();
    if ( $line =~ m/\t/ ) {
        @values = split( /\t/, $line );
    }
    elsif ( $line =~ m/\,/ ) {
        @values = split( /\,/, $line );
    }
    else {
        @values = split( /\s/, $line );
    }
    foreach (@values) {
        $_ = _cleanValue($_);
    }
    return \@values;
}

sub _cleanValue {
    my $value = shift;
    if ( !defined($value) ) {
        return ".";
    }
    if ( $value =~ m/^\s*$/ ) {
        return ".";
    }
    $value =~ s/^\s+//g;
    $value =~ s/\s+$//g;
    $value =~ s/\"|\'//g;
    return $value;
}

sub message {
    my $verbose = shift;
    my $message = shift;
    if ($verbose) {
        print $message;
    }
}

sub _usage {
    print <<BLOCK;
assign_cogs.pl - assign COG functional categories and IDs to proteins.

DISPLAY HELP AND EXIT:

usage:

  perl assign_cogs.pl -help

ASSIGN COGS:

usage:

  perl assign_cogs.pl -i <file> -o <file> -s <string>[Options]

required arguments:

-i - Input file in FASTA, RAW, EMBL, or GenBank format.

-o - Output file in tab-delimited format to create.

-s - Source of protein sequences. Use 'cds' to indicate that the CDS
translations in the GenBank or EMBL file should be used. Use 'orfs' to indicate
that translated open reading frames should be used.

optional arguments:

-myva - COG myva file formatted as a BLAST database. [FILE]. Default is
db/myva.

-whog - COG whog file. [FILE]. Default is db/whog.

-get_orfs - Path to the get_orfs.pl script. [FILE]. Default is
../get_orfs/get_orfs.pl.

-get_cds - Path to the get_cds.pl script. [FILE]. Default is
../get_cds/get_cds.pl.

-local_bl - Path to the local_blast_client.pl script. [FILE]. Default is
../local_blast_client/local_blast_client.pl.

-blastall - The path to the blastall program. [File]. Default is blastall.

-c - NCBI genetic code to use for translations. [INTEGER]. Default is 11.

-a - use all BLAST hits when assigning COGs. Default is to use top BLAST hit.

-e - Expect value setting to supply to the blastall program. [Real]. Default is
10.0.

-p - Minimum HSP length to keep, expressed as a proportion of the query
sequence length. [Real]. Default is to keep all HSPs.

-starts - Start codons. [String]. Default is 'atg|ttg|att|gtg|ctg'. To allow
ORFs to begin with any codon, use the value 'any'.
                    
-stops - Stop codons. [String]. Default is 'taa|tag|tga'.
                    
-m_orf - Minimum acceptable length for ORFs in codons. [Integer]. Default is
30.
                    
-m_score - Minimum acceptable BLAST score for COG assignment. [Real]. Default
is to ignore score.
                    
-v - provide progress messages (Optional).

example usage:

  perl assign_cogs.pl -i NC_013407.gbk -o out.gff -s cds
BLOCK
}
