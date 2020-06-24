#!/usr/bin/perl
#FILE: cgview_comparison_tool.pl
#AUTH: Paul Stothard (stothard@ualberta.ca)
#DATE: March 5, 2010
#VERS: 1.0

use strict;
use warnings;
use Getopt::Long;
use Util::Configurator;
use Util::LogManager;
use Data::Dumper;
use File::Path 'rmtree';
use File::Copy;

use Error qw(:try);
$Error::Debug = 1;

#check to see that CCT_HOME environment variable is set
if ( !defined( $ENV{CCT_HOME} ) ) {
    print
        "The CCT_HOME enviroment variable is not set--see the 'Set up your environment' section of the installation instructions.\n";
    exit(1);
}

my %options = (
    conf                    => "$ENV{CCT_HOME}/conf/global_settings.conf",
    settings                => undef,
    project                 => undef,
    start_at_xml            => undef,
    start_at_map            => undef,
    map_prefix              => "",
    max_blast_comparisons   => 100,
    sort_blast_tracks       => 'F',
    cct                     => 'F',
    settings_file_specified => 0,
    mem                     => '1500m',
    custom                  => undef,
    map_size                => undef,
    help                    => undef
);

GetOptions(
    'g|config=s'                => \$options{conf},
    's|settings=s'              => \$options{settings},
    'p|project=s'               => \$options{project},
    'x|start_at_xml'            => \$options{start_at_xml},
    'r|start_at_map'            => \$options{start_at_map},
    'f|map_prefix=s'            => \$options{map_prefix},
    'b|max_blast_comparisons=i' => \$options{max_blast},
    't|sort_blast_tracks'       => \$options{sort_blast_tracks},
    'cct'                       => \$options{cct},
    'm|memory=s'                => \$options{mem},
    'c|custom=s@{,}'            => \$options{custom},
    'z|map_size=s@{,}'          => \$options{map_size},
    'h|help'                    => \$options{help}
);

if ( defined( $options{help} ) ) {
    print_usage();
    exit(0);
}

#check for required options
if ( !( defined( $options{project} ) ) ) {
    print_usage();
    exit(1);
}

#remove trailing slash
$options{project} =~ s/\/+$//;

my $conf = Util::Configurator->new();

#read in the global configuration
$conf->path( $options{conf} );
$conf->readConfInfo();

#read in the settings for this project
if ( defined( $options{settings} ) ) {
    $options{settings_file_specified} = 1;
}
elsif ( -f $options{project} . "/" . "project_settings.conf" ) {
    $options{settings} = $options{project} . "/" . "project_settings.conf";
}
else {
    $options{settings} = $conf->getConfWithKey('project_settings');
}
$conf->path( $options{settings} );
$conf->readConfInfo();

my $log = Util::LogManager->new;
$log->log_file( $options{project} . "/" . "log.txt" );

if ( _isTrue( $options{start_at_xml} ) ) {
    _xmlCreation( \%options, $conf, $log );
    _graphicalMapCreation( \%options, $conf, $log );
}
elsif ( _isTrue( $options{start_at_map} ) ) {
    _graphicalMapCreation( \%options, $conf, $log );
}
else {
    _sequenceAnalysis( \%options, $conf, $log );
    _xmlCreation( \%options, $conf, $log );
    _graphicalMapCreation( \%options, $conf, $log );
}

sub _sequenceAnalysis {
    my $options = shift;
    my $conf    = shift;
    my $log     = shift;

    _createProject( $options, $conf, $log );
    $log->logNotice(
        "Using the settings file " . $options->{settings} . "." );

    #check for reference genome
    my $seqFiles = _getFiles(
        $options->{project} . "/" . "reference_genome",
        [   ".fna",     ".fasta", ".gbk", ".gb",
            ".genbank", ".embl",  ".raw", ".txt",
            ".fas"
        ]
    );
    if ( scalar(@$seqFiles) == 0 ) {
        exit(0);
    }

    #
    #
    #
    #reference genome processing
    #
    #
    #
    #

    #split reference_genome sequence into smaller sequences for BLAST searches
    if ( $conf->getConfWithKey('query_source') =~ m/trans|nucleotide/i ) {
        try {
            my %param = (
                seqDir => $options->{project} . "/" . "reference_genome",
                seqExt => [
                    ".fasta", ".gbk", ".gb",  ".genbank",
                    ".embl",  ".raw", ".txt", ".fas"
                ],
                splitter  => $conf->getConfWithKey('seq_split'),
                fragSize  => $conf->getConfWithKey('query_size'),
                outputDir => $options->{project} . "/"
                    . "reference_genome" . "/" . "split",
                outputExt => "_split",
                perl      => $conf->getConfWithKey('perl')
            );

            $log->logNotice(
                "Splitting the reference genome sequence in $param{seqDir} for BLAST searches."
            );
            _splitSeq( \%param );
            $log->logNotice(
                "Reference genome sequence has been split and written to $param{outputDir}."
            );

        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

#get CDS translations from reference genome sequence for use in BLAST searches
    if ( $conf->getConfWithKey('query_source') =~ m/cds/i ) {
        try {
            my %param = (
                seqDir    => $options->{project} . "/" . "reference_genome",
                seqExt    => [ ".gbk", ".gb", ".genbank", ".embl" ],
                script    => $conf->getConfWithKey('get_cds'),
                outputDir => $options->{project} . "/"
                    . "reference_genome" . "/" . "cds",
                outputExt => "_cds",
                perl      => $conf->getConfWithKey('perl')
            );

            $log->logNotice(
                "Extracting CDS translations from reference genome sequence in $param{seqDir} for BLAST searches."
            );
            _getCds( \%param );
            $log->logNotice(
                "Reference genome CDS translations have been written to $param{outputDir}."
            );

        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

#get ORF translations from reference genome sequence for use in BLAST searches
    if ( $conf->getConfWithKey('query_source') =~ m/orfs/i ) {
        try {
            my %param = (
                seqDir => $options->{project} . "/" . "reference_genome",
                seqExt => [
                    ".fasta", ".gbk", ".gb",  ".genbank",
                    ".embl",  ".raw", ".txt", ".fas"
                ],
                script    => $conf->getConfWithKey('get_orfs'),
                outputDir => $options->{project} . "/"
                    . "reference_genome" . "/" . "orfs",
                perl          => $conf->getConfWithKey('perl'),
                geneticCode   => $conf->getConfWithKey('genetic_code'),
                minSizeCodons => $conf->getConfWithKey('minimum_orf_length'),
                starts        => $conf->getConfWithKey('start_codons'),
                outputExt     => "_orfs",
                stops         => $conf->getConfWithKey('stop_codons')
            );

            $log->logNotice(
                "Extracting ORF translations from reference genome sequence in $param{seqDir} for BLAST searches."
            );
            _getOrfs( \%param );
            $log->logNotice(
                "Reference genome ORF translations have been written to $param{outputDir}."
            );

        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

    #
    #
    #
    #comparison_genomes processing
    #
    #
    #
    #

    #Convert comparison genomes into fasta format by setting fragSize to undef
    #and calling 'seq_split'
    if ( $conf->getConfWithKey('database_source') =~ m/trans|nucleotide/i ) {
        try {
            my %param = (
                seqDir => $options->{project} . "/" . "comparison_genomes",
                seqExt => [
                    ".fasta", ".gbk", ".gb",  ".genbank",
                    ".embl",  ".raw", ".txt", ".fas"
                ],
                splitter  => $conf->getConfWithKey('seq_split'),
                fragSize  => undef,
                outputDir => $options->{project} . "/"
                    . "comparison_genomes" . "/" . "split",
                outputExt => "_split",
                perl      => $conf->getConfWithKey('perl')
            );

            $log->logNotice(
                "Splitting the comparison genome sequences in $param{seqDir} for BLAST searches."
            );
            _splitSeq( \%param );
            $log->logNotice(
                "Comparison genome sequences have been split and written to $param{outputDir}."
            );
        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

#get CDS translations from comparison genome sequences for use in BLAST searches
    if ( $conf->getConfWithKey('database_source') =~ m/cds/i ) {
        try {
            my %param = (
                seqDir    => $options->{project} . "/" . "comparison_genomes",
                seqExt    => [ ".gbk", ".gb", ".genbank", ".embl" ],
                script    => $conf->getConfWithKey('get_cds'),
                outputDir => $options->{project} . "/"
                    . "comparison_genomes" . "/" . "cds",
                outputExt => "_cds",
                perl      => $conf->getConfWithKey('perl')
            );

            $log->logNotice(
                "Extracting CDS translations from comparison genome sequences in $param{seqDir} for BLAST searches."
            );
            _getCds( \%param );
            $log->logNotice(
                "Comparison genome CDS translations have been written to $param{outputDir}."
            );
        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

#get ORF translations from comparison genome sequences for use in BLAST searches
    if ( $conf->getConfWithKey('database_source') =~ m/orfs/i ) {
        try {
            my %param = (
                seqDir => $options->{project} . "/" . "comparison_genomes",
                seqExt => [
                    ".fasta", ".gbk", ".gb",  ".genbank",
                    ".embl",  ".raw", ".txt", ".fas"
                ],
                script    => $conf->getConfWithKey('get_orfs'),
                outputDir => $options->{project} . "/"
                    . "comparison_genomes" . "/" . "orfs",
                perl          => $conf->getConfWithKey('perl'),
                geneticCode   => $conf->getConfWithKey('genetic_code'),
                minSizeCodons => $conf->getConfWithKey('minimum_orf_length'),
                starts        => $conf->getConfWithKey('start_codons'),
                outputExt     => "_orfs",
                stops         => $conf->getConfWithKey('stop_codons')
            );

            $log->logNotice(
                "Extracting ORF translations from comparison genome sequences in $param{seqDir} for BLAST searches."
            );
            _getOrfs( \%param );
            $log->logNotice(
                "Comparison genome ORF translations have been written to $param{outputDir}."
            );
        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

    if ( $conf->getConfWithKey('database_source') =~ m/protein/i ) {

        #create a 'proteins' directory to contain a copy of the sequences
        try {
            my %param = (
                seqDir    => $options->{project} . "/" . "comparison_genomes",
                seqExt    => [".faa"],
                outputDir => $options->{project} . "/"
                    . "comparison_genomes" . "/"
                    . "proteins",
                outputExt => "_proteins"
            );

            $log->logNotice(
                "Copying protein sequences in $param{seqDir} for BLAST searches."
            );
            _copySeq( \%param );
            $log->logNotice(
                "Protein sequences have been copied to $param{outputDir}.");
        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };

    }

    if ( $conf->getConfWithKey('database_source') =~ m/dna/i ) {

        #create a 'dna' directory to contain a copy of the sequences
        try {
            my %param = (
                seqDir    => $options->{project} . "/" . "comparison_genomes",
                seqExt    => [".fna"],
                outputDir => $options->{project} . "/"
                    . "comparison_genomes" . "/" . "dna",
                outputExt => "_dna"
            );

            $log->logNotice(
                "Copying DNA sequences in $param{seqDir} for BLAST searches."
            );
            _copySeq( \%param );
            $log->logNotice(
                "DNA sequences have been copied to $param{outputDir}.");
        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

    #
    #
    #
    #blast processing
    #
    #
    #
    #

    my @reference_features
        = split( /,|\s/, $conf->getConfWithKey('query_source') );
    my @comparison_features
        = split( /,|\s/, $conf->getConfWithKey('database_source') );

    #can handle remote searches here

    foreach (@reference_features) {
        my $reference_feature = $_;

        foreach (@comparison_features) {
            my $comparison_feature = $_;

            #format blast databases from comparison_genomes
            my $queryLoc;
            my $queryExt;
            my $databaseLoc;
            my $databaseExt;
            my $databaseType;
            my $isProteinDb;
            my $blastType;

            if ( $reference_feature =~ m/trans/i ) {
                $queryLoc = $options->{project} . "/"
                    . "reference_genome" . "/" . "split";
                $queryExt = "_split";
                if ( $comparison_feature =~ m/trans/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "split",
                        "_split",
                        "tblastx",
                        "F"
                    );
                }
                if ( $comparison_feature =~ m/nucleotide/i ) {

                    #not allowed
                    print(
                        "The 'trans' setting for 'BLAST query source settings' cannot be used with the 'nucleotide' setting for 'BLAST database source settings'.\n"
                    );
                }
                if ( $comparison_feature =~ m/cds/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "cds",
                        "_cds",
                        "blastx",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/orfs/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "orfs",
                        "_orfs",
                        "blastx",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/protein/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/"
                            . "proteins",
                        "_proteins",
                        "blastx",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/dna/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "dna",
                        "_dna",
                        "tblastx",
                        "F"
                    );
                }

            }
            if ( $reference_feature =~ m/cds/i ) {
                $queryLoc = $options->{project} . "/"
                    . "reference_genome" . "/" . "cds";
                $queryExt = "_cds";
                if ( $comparison_feature =~ m/trans/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "split",
                        "_split",
                        "tblastn",
                        "F"
                    );
                }
                if ( $comparison_feature =~ m/nucleotide/i ) {

                    #not allowed
                    print(
                        "The 'cds' setting for 'BLAST query source settings' cannot be used with the 'nucleotide' setting for 'BLAST database source settings'.\n"
                    );
                }
                if ( $comparison_feature =~ m/cds/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "cds",
                        "_cds",
                        "blastp",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/orfs/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "orfs",
                        "_orfs",
                        "blastp",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/protein/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/"
                            . "proteins",
                        "_proteins",
                        "blastp",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/dna/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "dna",
                        "_dna",
                        "tblastn",
                        "F"
                    );
                }
            }
            if ( $reference_feature =~ m/orfs/i ) {
                $queryLoc = $options->{project} . "/"
                    . "reference_genome" . "/" . "orfs";
                $queryExt = "_orfs";
                if ( $comparison_feature =~ m/trans/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "split",
                        "_split",
                        "tblastn",
                        "F"
                    );
                }
                if ( $comparison_feature =~ m/nucleotide/i ) {

                    #not allowed
                    print(
                        "The 'orfs' setting for 'BLAST query source settings' cannot be used with the 'nucleotide' setting for 'BLAST database source settings'.\n"
                    );
                }
                if ( $comparison_feature =~ m/cds/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "cds",
                        "_cds",
                        "blastp",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/orfs/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "orfs",
                        "_orfs",
                        "blastp",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/protein/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/"
                            . "proteins",
                        "_proteins",
                        "blastp",
                        "T"
                    );
                }
                if ( $comparison_feature =~ m/dna/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "dna",
                        "_dna",
                        "tblastn",
                        "F"
                    );
                }
            }
            if ( $reference_feature =~ m/nucleotide/i ) {
                $queryLoc = $options->{project} . "/"
                    . "reference_genome" . "/" . "split";
                $queryExt = "_split";
                if ( $comparison_feature =~ m/trans/i ) {

                    #not allowed
                    print(
                        "The 'nucleotide' setting for 'BLAST query source settings' cannot be used with the 'trans' setting for 'BLAST database source settings'.\n"
                    );
                }
                if ( $comparison_feature =~ m/nucleotide/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "split",
                        "_split",
                        "blastn",
                        "F"
                    );
                }
                if ( $comparison_feature =~ m/cds/i ) {

                    #not allowed
                    print(
                        "The 'nucleotide' setting for 'BLAST query source settings' cannot be used with the 'cds' setting for 'BLAST database source settings'.\n"
                    );
                }
                if ( $comparison_feature =~ m/orfs/i ) {

                    #not allowed
                    print(
                        "The 'nucleotide' setting for 'BLAST query source settings' cannot be used with the 'orfs' setting for 'BLAST database source settings'.\n"
                    );
                }
                if ( $comparison_feature =~ m/protein/i ) {

                    #not allowed
                    print(
                        "The 'nucleotide' setting for 'BLAST query source settings' cannot be used with the 'proteins' setting for 'BLAST database source settings'.\n"
                    );
                }
                if ( $comparison_feature =~ m/dna/i ) {
                    _doLocalBlastSearch(
                        $options,
                        $conf,
                        $log,
                        $queryLoc,
                        $queryExt,
                        $options->{project} . "/"
                            . "comparison_genomes" . "/" . "dna",
                        "_dna",
                        "blastn",
                        "F"
                    );
                }
            }
        }
    }

    #
    #
    #
    #COG functional categories processing
    #
    #
    #
    #
    if ( $conf->getConfWithKey('cog_source') =~ m/cds/i ) {
        try {
            my %param = (
                seqDir      => $options->{project} . "/" . "reference_genome",
                seqExt      => [ ".gbk", ".gb", ".genbank", ".embl" ],
                script      => $conf->getConfWithKey('assign_cogs'),
                outputDir   => $options->{project} . "/" . "features",
                outputExt   => "_cds_cogs.gff",
                blastall    => $conf->getConfWithKey('blastall'),
                blastScript => $conf->getConfWithKey('local_blast'),
                eValue      => $conf->getConfWithKey('expect'),
                score       => $conf->getConfWithKey('score'),
                geneticCode => $conf->getConfWithKey('genetic_code'),
                minHitProp => $conf->getConfWithKey('minimum_hit_proportion'),
                perl       => $conf->getConfWithKey('perl'),
                cogSource  => 'cds',
                myva       => $conf->getConfWithKey('myva_file'),
                whog       => $conf->getConfWithKey('whog_file'),
                getOrfs    => $conf->getConfWithKey('get_orfs'),
                getCds     => $conf->getConfWithKey('get_cds'),
                topHit     => _isTrue( $conf->getConfWithKey('cog_top_hit') ),
                minSizeCodons => $conf->getConfWithKey('minimum_orf_length'),
                starts        => $conf->getConfWithKey('start_codons'),
                stops         => $conf->getConfWithKey('stop_codons')
            );

            $log->logNotice(
                "Assigning COG categories to CDS translations from reference genome sequence in $param{seqDir}."
            );
            _assignCogs( \%param, $log );
            $log->logNotice(
                "COG categories have been written to $param{outputDir}.");

        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

    if ( $conf->getConfWithKey('cog_source') =~ m/orfs/i ) {
        try {
            my %param = (
                seqDir      => $options->{project} . "/" . "reference_genome",
                seqExt      => [ ".gbk", ".gb", ".genbank", ".embl", ".fasta", ".fna", ".txt" ],
                script      => $conf->getConfWithKey('assign_cogs'),
                outputDir   => $options->{project} . "/" . "features",
                outputExt   => "_orf_cogs.gff",
                blastall    => $conf->getConfWithKey('blastall'),
                blastScript => $conf->getConfWithKey('local_blast'),
                eValue      => $conf->getConfWithKey('expect'),
                score       => $conf->getConfWithKey('score'),
                geneticCode => $conf->getConfWithKey('genetic_code'),
                minHitProp => $conf->getConfWithKey('minimum_hit_proportion'),
                perl       => $conf->getConfWithKey('perl'),
                cogSource  => 'orfs',
                myva       => $conf->getConfWithKey('myva_file'),
                whog       => $conf->getConfWithKey('whog_file'),
                getOrfs    => $conf->getConfWithKey('get_orfs'),
                getCds     => $conf->getConfWithKey('get_cds'),
                topHit     => _isTrue( $conf->getConfWithKey('cog_top_hit') ),
                minSizeCodons => $conf->getConfWithKey('minimum_orf_length'),
                starts        => $conf->getConfWithKey('start_codons'),
                stops         => $conf->getConfWithKey('stop_codons')
            );

            $log->logNotice(
                "Assigning COG categories to ORF translations from reference genome sequence in $param{seqDir}."
            );
            _assignCogs( \%param, $log );
            $log->logNotice(
                "COG categories have been written to $param{outputDir}.");

        }
        catch Error with {
            my $ex = shift;
            print $ex->{'-text'} . "\n";
            print $ex->{'-stacktrace'} . "\n";
            $log->logError( $ex->{'-text'} . "\n" );
            $log->logError( $ex->{'-stacktrace'} . "\n" );
            exit(1);
        };
    }

}

sub _assignCogs {
    my $param    = shift;
    my $log      = shift;
    my $seqFiles = _getFiles( $param->{seqDir}, $param->{seqExt} );

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    #options for assign_cogs.pl:
    # -i [FILE]        : GenBank, EMBL, FASTA, or raw DNA sequence file
    #                    (Required).
    # -o [FILE]        : Output file to create (Required).
    # -s [STRING]      : Source of protein sequences. Use 'cds' to indicate
    #                    that the CDS translations in the GenBank file
    #                    should be used. Use 'orfs' to indicate that
    #                    translated open reading frames should be used
    #                    (Required).
    # -myva [FILE]     : COG myva file formatted as a BLAST database
    #                    (Required).
    # -whog [FILE]     : COG whog file (Required).
    # -get_orfs [FILE] : Path to the get_orfs.pl script (Required).
    # -get_cds [FILE]  : Path to the get_cds.pl script (Required).
    # -local_bl [FILE] : Path to the local_blast_client.pl script
    #                    (Required).
    # -blastall [FILE] : Path to the blastall program (Required).
    # -c [INTEGER]     : NCBI genetic code to use for translations
    #                    (Optional. Default is 11).
    # -a               : report all COG functional categories identified by
    #                    BLAST (Optional. Default is to report functional
    #                    category from top BLAST hit).
    # -e [REAL]        : E value cutoff for BLAST search (Optional. Default
    #                    is 10.0).
    # -p [REAL]        : Minimum HSP length to keep, expressed as a
    #                    proportion of the query sequence length
    #                    (Optional. Default is to ignore length).
    # -starts [STRING] : Start codons for ORFs (Optional. Default is
    #                    'atg|ttg|att|gtg|ctg'. To allow ORFs to begin with
    #                    any codon, use the value 'any').
    # -stops [STRING]  : Stop codons for ORFs (Optional. Default is
    #                    'taa|tag|tga').
    # -m_orf [INTEGER] : Minimum acceptable length for ORFs in codons
    #                    (Optional. Default is 30 codons).
    # -m_score [REAL]  : Minimum acceptable BLAST score for COG assignment
    #                    (Optional. Default is to ignore score).
    # -v               : provide progress messages (Optional).
    foreach (@$seqFiles) {

        #skip if already an output file
        if ( -f "$param->{outputDir}/$_$param->{outputExt}" ) {
            $log->logNotice(
                "Skipping COG assignment for '$param->{seqDir}/$_' using '$param->{cogSource}' since output already detected."
            );
            next;
        }

        my $command
            = "$param->{perl} $param->{script} -i '$param->{seqDir}/$_' -o '$param->{outputDir}/$_$param->{outputExt}' -s '$param->{cogSource}' -myva '$param->{myva}' -whog '$param->{whog}' -get_orfs '$param->{getOrfs}' -get_cds '$param->{getCds}' -local_bl '$param->{blastScript}' -blastall '$param->{blastall}' -c '$param->{geneticCode}' -e '$param->{eValue}' -starts '$param->{starts}' -stops '$param->{stops}' -m_orf '$param->{minSizeCodons}' -m_score '$param->{score}'";

        if ( !( $param->{topHit} ) ) {
            $command = $command . " -a";
        }
        my $result = system($command);
        if ( $result != 0 ) {
            throw Error::Simple(
                "The following command failed: " . $command . "." );
        }
    }

}

sub _doLocalBlastSearch {

    my $options = shift;
    my $conf    = shift;
    my $log     = shift;

    my $queryLoc    = shift;
    my $queryExt    = shift;
    my $databaseLoc = shift;
    my $databaseExt = shift;
    my $blastType   = shift;
    my $isProteinDb = shift;

    try {
        my %param = (
            seqDir    => $databaseLoc,
            seqExt    => [$databaseExt],
            formatdb  => $conf->getConfWithKey('formatdb'),
            isProtein => $isProteinDb,
            outputDir => $options->{project} . "/" . "blast" . "/"
                . "blast_db"
        );

        $log->logNotice(
            "Creating BLAST databases using the files in $param{seqDir}.");
        _formatBlastDatabases( \%param );
        $log->logNotice(
            "The BLAST databases have been created in $param{outputDir}.");

    }
    catch Error with {
        my $ex = shift;
        print $ex->{'-text'} . "\n";
        print $ex->{'-stacktrace'} . "\n";
        $log->logError( $ex->{'-text'} . "\n" );
        $log->logError( $ex->{'-stacktrace'} . "\n" );
        exit(1);
    };

    #perform local BLAST searches
    my $formatedDbExt;
    if ( $isProteinDb eq "T" ) {
        $formatedDbExt = ".phr";
    }
    else {
        $formatedDbExt = ".nhr";
    }

    try {
        my %param = (
            blastDbDir => $options->{project} . "/" . "blast" . "/"
                . "blast_db",
            searchType  => $blastType,
            dbExt       => [$formatedDbExt],
            queryDir    => $queryLoc,
            queryExt    => [$queryExt],
            blastall    => $conf->getConfWithKey('blastall'),
            blastScript => $conf->getConfWithKey('local_blast'),
            hitLimit    => $conf->getConfWithKey('hits'),
            eValue      => $conf->getConfWithKey('expect'),
            score       => $conf->getConfWithKey('score'),
            outputDir   => $options->{project} . "/" . "blast" . "/"
                . "blast_results_local",
            outputExt              => $blastType,
            geneticCode            => $conf->getConfWithKey('genetic_code'),
            fetchEntrezDescription => "F",
            minHitProp => $conf->getConfWithKey('minimum_hit_proportion'),
            perl       => $conf->getConfWithKey('perl')
        );

        $log->logNotice(
            "Performing BLAST comparisons between sequences in $param{queryDir} and databases in $param{blastDbDir}."
        );
        _doLocalBlast( \%param );
        $log->logNotice(
            "The BLAST results have been written to $param{outputDir}.");

    }
    catch Error with {
        my $ex = shift;
        print $ex->{'-text'} . "\n";
        print $ex->{'-stacktrace'} . "\n";
        $log->logError( $ex->{'-text'} . "\n" );
        $log->logError( $ex->{'-stacktrace'} . "\n" );
        exit(1);
    };
}

#
#
#
#build CGView XML file
#
#
#
#

sub _xmlCreation {
    my $options = shift;
    my $conf    = shift;
    my $log     = shift;

    try {
        my %param = (
            projectDir => $options->{project},
            seqDir     => $options->{project} . "/" . "reference_genome",
            seqExt     => [
                ".fna",     ".fasta", ".gbk", ".gb",
                ".genbank", ".embl",  ".raw", ".txt",
                ".fas"
            ],
            featDir     => $options->{project} . "/" . "features",
            featExt     => [ ".gff", ".txt", ".tab", ".cvs" ],
            analysisDir => $options->{project} . "/" . "analysis",
            analysisExt => [ ".gff", ".txt", ".tab", ".cvs" ],
            blastDir    => $options->{project} . "/" . "blast" . "/"
                . "blast_results_local",
            blastExt =>
                [ "_blastx", "_blastn", "_tblastx", "_blastp", "_tblastn" ],
            outputDir => $options->{project} . "/" . "maps" . "/"
                . "cgview_xml",
            outputPrefix     => $options->{map_prefix},
            outputExt        => ".xml",
            minSizeCodons    => $conf->getConfWithKey('minimum_orf_length'),
            starts           => $conf->getConfWithKey('start_codons'),
            stops            => $conf->getConfWithKey('stop_codons'),
            perl             => $conf->getConfWithKey('perl'),
            cgviewXmlBuilder => $options->{project} . "/"
                . "cgview_xml_builder.pl",
            drawDivider => _isTrue( $conf->getConfWithKey('draw_divider') ),
            drawOrfs    => _isTrue( $conf->getConfWithKey('draw_orfs') ),
            drawGcContent =>
                _isTrue( $conf->getConfWithKey('draw_gc_content') ),
            drawGcSkew => _isTrue( $conf->getConfWithKey('draw_gc_skew') ),
            drawLegend => _isTrue( $conf->getConfWithKey('draw_legend') ),
            drawFeatureLabels =>
                _isTrue( $conf->getConfWithKey('draw_feature_labels') ),
            drawOrfLabels =>
                _isTrue( $conf->getConfWithKey('draw_orf_labels') ),
            drawHitLabels =>
                _isTrue( $conf->getConfWithKey('draw_hit_labels') ),
            drawCondensed =>
                _isTrue( $conf->getConfWithKey('draw_condensed') ),
            drawDividerRings =>
                _isTrue( $conf->getConfWithKey('draw_divider_rings') ),
            drawHitsByReadingFrame => _isTrue(
                $conf->getConfWithKey('draw_hits_by_reading_frame')
            ),
            mapSize        => $conf->getConfWithKey('map_size'),
            geneDecoration => $conf->getConfWithKey('gene_decoration'),
            useOpacity     => _isTrue( $conf->getConfWithKey('use_opacity') ),
            highlightQuery =>
                _isTrue( $conf->getConfWithKey('highlight_query') ),
            drawNavigable =>
                _isTrue( $conf->getConfWithKey( 'draw_navigable', 'F' ) ),
            drawZoomed =>
                _isTrue( $conf->getConfWithKey( 'draw_zoomed', 'F' ) ),
            sort_blast_tracks => _isTrue( $options->{sort_blast_tracks} ),
            max_blast         => $options->{max_blast},
            cct               => _isTrue( $options->{cct} ),
            scale_blast => _isTrue( $conf->getConfWithKey('scale_blast') ),
            log         => $log
        );

        $log->logNotice("Creating CGView XML files.");
        _buildCgviewXml( \%param, $options );
        $log->logNotice(
            "CGView XML files have been created in $param{outputDir}.");

    }
    catch Error with {
        my $ex = shift;
        print $ex->{'-text'} . "\n";
        print $ex->{'-stacktrace'} . "\n";
        $log->logError( $ex->{'-text'} . "\n" );
        $log->logError( $ex->{'-stacktrace'} . "\n" );
        exit(1);
    };
}

#
#
#
#draw CGView map
#
#
#
#

sub _graphicalMapCreation {
    my $options = shift;
    my $conf    = shift;
    my $log     = shift;

    try {
        my %param = (
            xmlDir => $options->{project} . "/" . "maps" . "/" . "cgview_xml",
            xmlExt => [".xml"],
            outputDir => $options->{project} . "/" . "maps",
            java      => $conf->getConfWithKey('java'),
            drawNavigable =>
                _isTrue( $conf->getConfWithKey( 'draw_navigable', 'F' ) ),
            drawZoomed =>
                _isTrue( $conf->getConfWithKey( 'draw_zoomed', 'F' ) ),
            zoom_amount => $conf->getConfWithKey( 'zoom_amount', '1' ),
            zoom_center => $conf->getConfWithKey( 'zoom_center', '1' ),
            cgview      => $conf->getConfWithKey('cgview')
        );

        $log->logNotice("Creating CGView maps.");
        _drawMap( \%param, $options );
        $log->logNotice(
            "CGView maps have been created in $param{outputDir}.");

    }
    catch Error with {
        my $ex = shift;
        print $ex->{'-text'} . "\n";
        print $ex->{'-stacktrace'} . "\n";
        $log->logError( $ex->{'-text'} . "\n" );
        $log->logError( $ex->{'-stacktrace'} . "\n" );
        exit(1);
    };
}

sub _createProject {
    my $options = shift;
    my $conf    = shift;
    my $log     = shift;

    my $dir                   = $options->{project};
    my $default_settings_file = $conf->getConfWithKey('project_settings');

    my $is_new_project = 0;

    #create project directory
    if ( !( -d $dir ) ) {
        mkdir( $dir, 0775 )
            or
            throw Error::Simple( "Could not create directory " . $dir . "." );
        $is_new_project = 1;
    }

    my @nestedDirs = (
        "reference_genome", "comparison_genomes",
        "blast",            "features",
        "maps",             "analysis"
    );
    foreach (@nestedDirs) {
        my $nested_dir = $_;
        if ( !( -d $dir . "/" . $nested_dir ) ) {
            mkdir( $dir . "/" . $nested_dir, 0775 )
                or throw Error::Simple( "Could not create directory " 
                    . $dir . "/"
                    . $nested_dir
                    . "." );
        }
    }

    #clean up directories created by cgview_comparison_tool
    rmtree("$dir/reference_genome/split");
    rmtree("$dir/reference_genome/cds");
    rmtree("$dir/reference_genome/orfs");
    rmtree("$dir/comparison_genomes/split");
    rmtree("$dir/comparison_genomes/cds");
    rmtree("$dir/comparison_genomes/orfs");
    rmtree("$dir/comparison_genomes/proteins");
    rmtree("$dir/comparison_genomes/dna");
    rmtree("$dir/blast/blast_db");
    rmtree("$dir/blast/blast_results_local");
    rmtree("$dir/maps/cgview_xml");

#copy the default settings file to the project directory if it is not already there
    if (   ( !( -f "$dir/project_settings.conf" ) )
        && ( !( $options->{settings_file_specified} ) ) )
    {
        copy( $default_settings_file, "$dir/project_settings.conf" )
            or throw Error::Simple( "Could not copy settings file to "
                . "$dir/project_settings.conf"
                . "." );
    }

#copy cgview_xml_builder.pl to the project directory if it is not already there
    my $cgviewXmlBuilder = $conf->getConfWithKey('cgview_xml_builder');
    if ( !( -f "$dir/cgview_xml_builder.pl" ) ) {
        copy( $cgviewXmlBuilder, "$dir/cgview_xml_builder.pl" )
            or throw Error::Simple(
            "Could not copy cgview_xml_builder.pl to " . "$dir/" . "." );
    }

    if ($is_new_project) {
        $log->logNotice( "A new project has been created in " . $dir . "." );
        exit(0);
    }
}

sub _splitSeq {
    my $param = shift;
    my $seqFiles = _getFiles( $param->{seqDir}, $param->{seqExt} );

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    #options for sequence_to_multi_fasta.pl:
    #-i input file
    #-o output file
    #-s size of sequence fragments to create
    #-v overlap between fragments (optional)
    foreach (@$seqFiles) {
        my $command;
        if ( !( defined( $param->{fragSize} ) ) ) {
            $command
                = "$param->{perl} $param->{splitter} -i '$param->{seqDir}/$_' -o '$param->{outputDir}/$_$param->{outputExt}'";
        }
        else {
            $command
                = "$param->{perl} $param->{splitter} -i '$param->{seqDir}/$_' -o '$param->{outputDir}/$_$param->{outputExt}' -s $param->{fragSize}";
        }
        my $result = system($command);
        if ( $result != 0 ) {
            throw Error::Simple(
                "The following command failed: " . $command . "." );
        }
    }
}

sub _getCds {

    my $param = shift;
    my $seqFiles = _getFiles( $param->{seqDir}, $param->{seqExt} );

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    #options for getCds.pl:
    #-i input file
    #-o output file
    foreach (@$seqFiles) {
        my $command
            = "$param->{perl} $param->{script} -i '$param->{seqDir}/$_' -o '$param->{outputDir}/$_$param->{outputExt}'";
        my $result = system($command);
        if ( $result != 0 ) {
            throw Error::Simple(
                "The following command failed: " . $command . "." );
        }
    }
}

sub _getOrfs {

    my $param = shift;
    my $seqFiles = _getFiles( $param->{seqDir}, $param->{seqExt} );

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    #options for getOrfs.pl:
    #-i input file
    #-o output file
    #-m minimum size in codons
    #-g genetic code
    foreach (@$seqFiles) {
        my $command
            = "$param->{perl} $param->{script} -i '$param->{seqDir}/$_' -o '$param->{outputDir}/$_$param->{outputExt}' -g $param->{geneticCode} -m $param->{minSizeCodons} -starts '$param->{starts}' -stops '$param->{stops}'";
        my $result = system($command);
        if ( $result != 0 ) {
            throw Error::Simple(
                "The following command failed: " . $command . "." );
        }
    }
}

sub _copySeq {

    my $param = shift;
    my $seqFiles = _getFiles( $param->{seqDir}, $param->{seqExt} );

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    foreach (@$seqFiles) {
        copy( "$param->{seqDir}/$_",
            "$param->{outputDir}/$_$param->{outputExt}" )
            or throw Error::Simple(
            "Could not copy $param->{seqDir}/$_ to $param->{outputDir}/$_$param->{outputExt}."
            );
    }
}

sub _formatBlastDatabases {
    my $param = shift;
    my $fastaFiles = _getFiles( $param->{seqDir}, $param->{seqExt} );

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    #options for formatdb:
    #-t title
    #-i input file
    #-n path to output
    #-p T for protein, F for nucleotide
    #-o T - Parse SeqId and create indexes.
    #-l logfile
    foreach (@$fastaFiles) {
        my $command
            = "$param->{formatdb} -i '$param->{seqDir}/$_' -n '$param->{outputDir}/$_' -p '$param->{isProtein}' -o F -l '$param->{outputDir}/$_.log'";
        my $result = system($command);
        if ( $result != 0 ) {
            throw Error::Simple(
                "The following command failed: " . $command . "." );
        }
    }
}

sub _doLocalBlast {
    my $param      = shift;
    my $queryFiles = _getFiles( $param->{queryDir}, $param->{queryExt} );
    my $blastFiles = _getFiles( $param->{blastDbDir}, $param->{dbExt} );

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    #options for local_blast_client:
    #-Q genetic code to use for translated blast searches
    #-i input file
    #-o output file
    #-b blast search type
    #-t number of hits to keep
    #-x e_value
    #-f fetch description from Entrez
    #-p min hit length as a proportion of query
    #-y path to blastall

    foreach (@$queryFiles) {
        my $query = $_;
        foreach (@$blastFiles) {
            my $blastDb = $_;
            $blastDb =~ s/\.[^\.]+$//;
            my $tempFile = $query . "_temp";

#Recover some information about the query and database for incorporation into the output file name.
#This will allow the information to appear in the map legend.
            my $query_type = $query;
            if ( $query_type =~ m/_([^_]+)$/ ) {
                $query_type = $1;
                $query_type =~ s/split/dna/i;
                $query_type = uc($query_type);
            }

            #what aspect of the sequence (orfs, nucleotide, etc).
            my $database_type = $blastDb;
            if ( $database_type =~ m/_([^_]+)$/ ) {
                $database_type = $1;
                $database_type =~ s/split/dna/i;
                $database_type = uc($database_type);
            }

           #which sequence record
           #want to convert things like FSC033_1.1.fasta_dna.nhr to FSC033_1.1
            my $database_source = $blastDb;
            if ( $database_source =~ m/(.+)\.[^\.]+\.[^\.]{3}$/ ) {
                $database_source = $1;
            }

            my $query_name = $query;
            if ( $query_name =~ m/^([^\.]+)/ ) {
                $query_name = $1;
            }

            my $blast_type = $param->{outputExt};

            my $blastOutputFile
                = "$param->{outputDir}/$query_name" . "_"
                . $query_type . "_vs_"
                . $database_source . "_"
                . $database_type . "_"
                . $param->{outputExt};
            my $command
                = "$param->{perl} $param->{blastScript} -y $param->{blastall} -Q $param->{geneticCode} -i '$param->{queryDir}/$query' -o '$blastOutputFile' -b $param->{searchType} -d '$param->{blastDbDir}/$blastDb' -p $param->{minHitProp} -t $param->{hitLimit} -s $param->{score} -x $param->{eValue} -f $param->{fetchEntrezDescription} -filter F";

#This uses BLAST filter option
#            my $command
#                = "$param->{perl} $param->{blastScript} -y $param->{blastall} -Q $param->{geneticCode} -i '$param->{queryDir}/$query' -o '$blastOutputFile' -b $param->{searchType} -d '$param->{blastDbDir}/$blastDb' -p $param->{minHitProp} -t $param->{hitLimit} -s $param->{score} -x $param->{eValue} -f $param->{fetchEntrezDescription} -filter T";

            my $result = system($command);
            if ( $result != 0 ) {
                throw Error::Simple(
                    "The following command failed: " . $command . "." );
            }
        }

        #currently only want to use one query
        last;
    }
}

sub _buildCgviewXml {
    my $param     = shift;
    my $options   = shift;
    my $seqFiles  = _getFiles( $param->{seqDir}, $param->{seqExt} );
    my $featFiles = _getFiles( $param->{featDir}, $param->{featExt} );
    my $analysisFiles
        = _getFiles( $param->{analysisDir}, $param->{analysisExt} );
    my $blastFiles = _getFiles( $param->{blastDir}, $param->{blastExt} );
    ##$param->{sort_blast_tracks} = 0;##
    if ( $param->{sort_blast_tracks} ) {
        my @ordered = map { $_->[1] }
            sort { $b->[0] <=> $a->[0] }
            map {
            [   _getBlastCoverageRevised(
                    $param->{blastDir} . "/" . $_,
                    $param->{log}
                ),
                $_
            ]
            } @{$blastFiles};
        $blastFiles = \@ordered;
    }

    if ( defined( $param->{max_blast} ) ) {
        if ( scalar( @{$blastFiles} ) > $param->{max_blast} ) {
            my @temp = @$blastFiles[ 0 .. ( $param->{max_blast} - 1 ) ];
            $blastFiles = \@temp;
        }
    }

    if ( scalar( @{$blastFiles} ) > 0 ) {
        $param->{log}->logNotice(
            "The following BLAST results will be drawn, from outside to center:"
        );
        foreach my $blast_file ( @{$blastFiles} ) {
            $param->{log}->logNotice("$blast_file");
        }
    }

    my $featString     = "";
    my $analysisString = "";

    foreach (@$featFiles) {
        $featString = $featString . $param->{featDir} . "/" . $_ . " ";
    }

    foreach (@$analysisFiles) {
        $analysisString
            = $analysisString . $param->{analysisDir} . "/" . $_ . " ";
    }

#write BLAST file names to a text file that can be passed to cgview_xml_builder.pl
    my $blast_list_file;
    if ( scalar(@$blastFiles) > 0 ) {

        $blast_list_file = $param->{blastDir} . "/" . "_blast_file_list.txt";
        open( my $BLASTFILE, '>', $blast_list_file )
            or die("Cannot open file '$blast_list_file': $!");

        foreach my $blast_file (@$blastFiles) {
            print $BLASTFILE $param->{blastDir} . "/" . "$blast_file\n";
        }

        close($BLASTFILE) or die("Cannot close file : $!");
    }

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    #options for cgview_xml_builder.pl
    #See cgview_xml_builder.pl

    my $paramString          = "";
    my $paramStringNavigable = "";

    if ( $param->{drawDivider} ) {
        $paramString          = $paramString . " -linear T";
        $paramStringNavigable = $paramStringNavigable . " -linear T";
    }
    else {
        $paramString          = $paramString . " -linear F";
        $paramStringNavigable = $paramStringNavigable . " -linear F";
    }

    if ( $param->{drawOrfs} ) {
        $paramString          = $paramString . " -orfs T";
        $paramStringNavigable = $paramStringNavigable . " -orfs T";
    }
    else {
        $paramString          = $paramString . " -orfs F";
        $paramStringNavigable = $paramStringNavigable . " -orfs F";
    }

    if ( $param->{drawGcContent} ) {
        $paramString          = $paramString . " -gc_content T";
        $paramStringNavigable = $paramStringNavigable . " -gc_content T";
    }
    else {
        $paramString          = $paramString . " -gc_content F";
        $paramStringNavigable = $paramStringNavigable . " -gc_content F";
    }

    if ( $param->{drawGcSkew} ) {
        $paramString          = $paramString . " -gc_skew T";
        $paramStringNavigable = $paramStringNavigable . " -gc_skew T";
    }
    else {
        $paramString          = $paramString . " -gc_skew F";
        $paramStringNavigable = $paramStringNavigable . " -gc_skew F";
    }

    if ( $param->{drawLegend} ) {
        $paramString = $paramString . " -legend T -details T";
        $paramStringNavigable
            = $paramStringNavigable . " -legend T -details T";
    }
    else {
        $paramString = $paramString . " -legend F -details F";
        $paramStringNavigable
            = $paramStringNavigable . " -legend F -details F";
    }

    if ( $param->{drawFeatureLabels} ) {
        $paramString = $paramString . " -feature_labels T -gene_labels T";
        $paramStringNavigable
            = $paramStringNavigable . " -feature_labels T -gene_labels T";
    }
    else {
        $paramString = $paramString . " -feature_labels F -gene_labels F";
        $paramStringNavigable
            = $paramStringNavigable . " -feature_labels T -gene_labels T";
    }

    if ( $param->{drawHitLabels} ) {
        $paramString          = $paramString . " -hit_labels T";
        $paramStringNavigable = $paramStringNavigable . " -hit_labels T";
    }
    else {
        $paramString          = $paramString . " -hit_labels F";
        $paramStringNavigable = $paramStringNavigable . " -hit_labels T";
    }

    if ( $param->{drawOrfLabels} ) {
        $paramString          = $paramString . " -orf_labels T";
        $paramStringNavigable = $paramStringNavigable . " -orf_labels T";
    }
    else {
        $paramString          = $paramString . " -orf_labels F";
        $paramStringNavigable = $paramStringNavigable . " -orf_labels T";
    }

    if ( $param->{drawCondensed} ) {
        $paramString          = $paramString . " -condensed T";
        $paramStringNavigable = $paramStringNavigable . " -condensed T";
    }
    else {
        $paramString          = $paramString . " -condensed F";
        $paramStringNavigable = $paramStringNavigable . " -condensed T";
    }

    if ( $param->{drawDividerRings} ) {
        $paramString = $paramString . " -draw_divider_rings T";
        $paramStringNavigable
            = $paramStringNavigable . " -draw_divider_rings T";
    }
    else {
        $paramString = $paramString . " -draw_divider_rings F";
        $paramStringNavigable
            = $paramStringNavigable . " -draw_divider_rings T";
    }

    if ( $param->{drawHitsByReadingFrame} ) {
        $paramString = $paramString . " -parse_reading_frame T";
        $paramStringNavigable
            = $paramStringNavigable . " -parse_reading_frame T";
    }
    else {
        $paramString = $paramString . " -parse_reading_frame F";
        $paramStringNavigable
            = $paramStringNavigable . " -parse_reading_frame F";
    }

    if ( $param->{highlightQuery} ) {
        $paramString          = $paramString . " -show_queries T";
        $paramStringNavigable = $paramStringNavigable . " -show_queries T";
    }
    else {
        $paramString          = $paramString . " -show_queries F";
        $paramStringNavigable = $paramStringNavigable . " -show_queries F";
    }

    if ( $param->{useOpacity} ) {
        $paramString          = $paramString . " -use_opacity T";
        $paramStringNavigable = $paramStringNavigable . " -use_opacity T";
    }
    else {
        $paramString          = $paramString . " -use_opacity F";
        $paramStringNavigable = $paramStringNavigable . " -use_opacity F";
    }

    if ( $param->{geneDecoration} =~ m/arc/i ) {
        $paramString = $paramString . " -gene_decoration arc";
        $paramStringNavigable
            = $paramStringNavigable . " -gene_decoration arc";
    }
    elsif ( $param->{geneDecoration} =~ m/arrow/i ) {
        $paramString = $paramString . " -gene_decoration arrow";
        $paramStringNavigable
            = $paramStringNavigable . " -gene_decoration arrow";
    }

    if ( $param->{cct} ) {
        $paramString          = $paramString . " -cct " . '1';
        $paramStringNavigable = $paramStringNavigable . " -cct " . '1';
    }

    if ( $param->{scale_blast} ) {
        $paramString          = $paramString . " -scale_blast T";
        $paramStringNavigable = $paramStringNavigable . " -scale_blast T";
    }
    else {
        $paramString          = $paramString . " -scale_blast F";
        $paramStringNavigable = $paramStringNavigable . " -scale_blast F";
    }

    #check for labels_to_show.txt file in project directory
    if ( -f $param->{projectDir} . "/" . "labels_to_show.txt" ) {
        $paramString
            = $paramString
            . " -labels_to_show "
            . $param->{projectDir} . "/"
            . "labels_to_show.txt";
        $paramStringNavigable
            = $paramStringNavigable
            . " -labels_to_show "
            . $param->{projectDir} . "/"
            . "labels_to_show.txt";
    }

    #want global_label set to 'auto' for navigable map
    $paramStringNavigable = $paramStringNavigable . " -global_label auto";

    my @sizes = @{ _split( $param->{mapSize} ) };

 #2011-06-26
 #Override sizes read from configuration file if size supplied using -map_size
    if (   ( defined( $options->{map_size} ) )
        && ( scalar( @{ $options->{map_size} } ) > 0 ) )
    {
        @sizes = @{ $options->{map_size} };
    }

    #create a medium map for series
    if ( $param->{drawNavigable} ) {
        push( @sizes, "medium_navigable" );
    }

    #create a medium zoomed map
    if ( $param->{drawZoomed} ) {
        push( @sizes, "medium_zoomed" );
    }

    foreach (@$seqFiles) {
        my $seq = $_;
        foreach (@sizes) {
            my $command;
            if ( $_ =~ m/navigable/i ) {
                my $size = $_;
                $size =~ s/_navigable//gi;
                $command
                    = "$param->{perl} $param->{cgviewXmlBuilder} -size $size -sequence '$param->{seqDir}/$seq' -output '$param->{outputDir}/$param->{outputPrefix}$_.xml' -orf_size $param->{minSizeCodons} -starts '$param->{starts}' -stops '$param->{stops}'$paramStringNavigable -tick_density 0.8 -log '$param->{outputDir}/$param->{outputPrefix}$_.log'";
            }
            elsif ( $_ =~ m/zoomed/i ) {
                my $size = $_;
                $size =~ s/_zoomed//gi;
                $command
                    = "$param->{perl} $param->{cgviewXmlBuilder} -size $size -sequence '$param->{seqDir}/$seq' -output '$param->{outputDir}/$param->{outputPrefix}$_.xml' -orf_size $param->{minSizeCodons} -starts '$param->{starts}' -stops '$param->{stops}'$paramString -log '$param->{outputDir}/$param->{outputPrefix}$_.log'";
            }
            else {
                $command
                    = "$param->{perl} $param->{cgviewXmlBuilder} -size $_ -sequence '$param->{seqDir}/$seq' -output '$param->{outputDir}/$param->{outputPrefix}$_.xml' -orf_size $param->{minSizeCodons} -starts '$param->{starts}' -stops '$param->{stops}'$paramString -log '$param->{outputDir}/$param->{outputPrefix}$_.log'";
            }

            if ( defined($blast_list_file) ) {
                $command = $command . " -blast_list $blast_list_file";
            }
            if ( $analysisString =~ m/\S/ ) {
                $command = $command . " -analysis $analysisString";
            }
            if ( $featString =~ m/\S/ ) {
                $command = $command . " -genes $featString";
            }

            #2011-06-26
            #implement -custom option
            if (   ( defined( $options->{custom} ) )
                && ( scalar( @{ $options->{custom} } ) > 0 ) )
            {
                $command
                    = $command
                    . ' -custom '
                    . _quote_rgb( join( ' ', @{ $options->{custom} } ) );
                print $command . "\n";
            }

            my $result = system($command);
            if ( $result != 0 ) {
                throw Error::Simple(
                    "The following command failed: " . $command . "." );
            }
        }

        #currently only want to use one seq
        last;
    }
}

sub _drawMap {
    my $param    = shift;
    my $options  = shift;
    my $xmlFiles = _getFiles( $param->{xmlDir}, $param->{xmlExt} );

    if ( !( -d $param->{outputDir} ) ) {
        mkdir( $param->{outputDir}, 0775 )
            or throw Error::Simple(
            "Could not create directory " . $param->{outputDir} . "." );
    }

    #options for cgview_xml_builder.pl
    foreach (@$xmlFiles) {
        my $file = $_;
        my $command;
        my $output = _removeExtension($_);

        if ( ( $_ =~ m/navigable/i ) && ( $param->{drawNavigable} ) ) {
            $command
                = "$param->{java} -Djava.awt.headless=true -jar -Xmx"
                . $options->{mem}
                . " $param->{cgview} -i '$param->{xmlDir}/$file' -s '$param->{outputDir}/navigable"
                . "' -e T -x 1,6,36,216";
        }
        elsif ( ( $_ =~ m/zoomed/i ) && ( $param->{drawZoomed} ) ) {
            $command
                = "$param->{java} -Djava.awt.headless=true -jar -Xmx"
                . $options->{mem}
                . " $param->{cgview} -i '$param->{xmlDir}/$file' -f png -o '$param->{outputDir}/$output.png' -h '$param->{outputDir}/$output.html' -p '$output.png' -z $param->{zoom_amount} -c $param->{zoom_center}";
        }
        else {
            $command
                = "$param->{java} -Djava.awt.headless=true -jar -Xmx"
                . $options->{mem}
                . " $param->{cgview} -i '$param->{xmlDir}/$file' -f png -o '$param->{outputDir}/$output.png' -h '$param->{outputDir}/$output.html' -p '$output.png'";
        }

        my $result = system($command);
        if ( $result != 0 ) {
            throw Error::Simple(
                "The following command failed: " . $command . "." );
        }
    }
}

sub _getFiles {
    my $dir       = shift;
    my $extension = shift;
    my @wanted    = ();

    if ( !( -d $dir ) ) {
        return \@wanted;
    }

    opendir( DIR, $dir ) or die("Cannot open dir $dir $!");
    my @files = readdir(DIR);
    foreach (@files) {
        my $file = $_;
        foreach ( @{$extension} ) {
            if ( $file =~ m/\Q$_\E$/i ) {
                push( @wanted, $file );
            }
        }
    }
    @wanted = sort(@wanted);
    return \@wanted;
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

sub _isTrue {
    my $string = shift;
    if (   ( defined($string) )
        && ( ( $string =~ m/t/i ) || ( $string eq '1' ) ) )
    {
        return 1;
    }
    return 0;
}

sub _removeExtension {
    my $file = shift;
    $file =~ s/\..*$//;
    return $file;
}

sub _quote_rgb {
    my $string = shift;
    $string =~ s/(rgb.+?\))/\'$1\'/g;
    return $string;
}

sub _getBlastCoverageRevised {
    my $file         = shift;
    my $log          = shift;
    my $coverage     = 0;
    my @columnTitles = ();
    my $columnsRead  = 0;
    my $program      = undef;
    open( my $FILE, '<', $file ) or die "can't open $file: $!";
    while ( my $line = <$FILE> ) {
        $line =~ s/\cM|\n//g;
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

    my $previous_query               = undef;
    my %query_identity_coverage_hash = ();
    $columnsRead = 0;
    while ( my $line = <$FILE> ) {
        $line =~ s/\cM|\n//g;
        if ( $line =~ m/^\#/ ) {
            next;
        }
        if ( !($columnsRead) && ( $line =~ m/^query_id/ ) ) {
            $columnsRead = 1;
            next;
        }
        if ( $line =~ m/\S/ ) {
            my @values = @{ _split($line) };

            #skip lines with missing values
            if ( scalar(@values) != scalar(@columnTitles) ) {
                next;
            }

            my %entry = ();
            for ( my $i = 0; $i < scalar(@columnTitles); $i++ ) {
                $entry{ $columnTitles[$i] } = $values[$i];
            }

            my $start;
            my $end;
            if ( $entry{'q_start'} < $entry{'q_end'} ) {
                $start = $entry{'q_start'};
                $end   = $entry{'q_end'};
            }
            else {
                $start = $entry{'q_end'};
                $end   = $entry{'q_start'};
            }

            if (   ( !defined($previous_query) )
                || ( $previous_query eq $entry{'query_id'} ) )
            {

                #start to summarize coverage for new segment
                #or continue to summarize current segment
                for ( my $i = $start; $i <= $end; $i++ ) {
                    if ( defined( $query_identity_coverage_hash{$i} ) ) {
                        if ( $entry{'%_identity'}
                            > $query_identity_coverage_hash{$i} )
                        {
                            $query_identity_coverage_hash{$i}
                                = $entry{'%_identity'};
                        }
                    }
                    else {
                        $query_identity_coverage_hash{$i}
                            = $entry{'%_identity'};
                    }
                }
            }
            else {

                #process summary for previous segment
                my @keys = keys(%query_identity_coverage_hash);
                my $coverage_for_query_segment = 0;
                foreach my $key (@keys) {
                    $coverage_for_query_segment = $coverage_for_query_segment
                        + $query_identity_coverage_hash{$key};
                }
                $coverage = $coverage + $coverage_for_query_segment;
#for larger genomes log may work better
#                $coverage = $coverage + log($coverage_for_query_segment);

                #start to summarize coverage for new segment
                %query_identity_coverage_hash = ();
                for ( my $i = $start; $i <= $end; $i++ ) {
                    if ( defined( $query_identity_coverage_hash{$i} ) ) {
                        if ( $entry{'%_identity'}
                            > $query_identity_coverage_hash{$i} )
                        {
                            $query_identity_coverage_hash{$i}
                                = $entry{'%_identity'};
                        }
                    }
                    else {
                        $query_identity_coverage_hash{$i}
                            = $entry{'%_identity'};
                    }
                }
            }
            $previous_query = $entry{'query_id'};
        }
    }

    #process summary for previous segment
    my @keys                       = keys(%query_identity_coverage_hash);
    my $coverage_for_query_segment = 0;
    foreach my $key (@keys) {
        $coverage_for_query_segment = $coverage_for_query_segment
            + $query_identity_coverage_hash{$key};
    }
    $coverage = $coverage + $coverage_for_query_segment;

#for larger genomes log may work better
#    $coverage = $coverage + log($coverage_for_query_segment);   

    close($FILE);

    $coverage = sprintf( "%d", $coverage );

    $log->logNotice("The overall similarity score for file $file is $coverage");
    return $coverage;
}

sub _getBlastCoverage {
    my $file         = shift;
    my $log          = shift;
    my $coverage     = 0;
    my @columnTitles = ();
    my $columnsRead  = 0;
    my $program      = undef;
    open( my $FILE, '<', $file ) or die "can't open $file: $!";
    while ( my $line = <$FILE> ) {
        $line =~ s/\cM|\n//g;
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

    my %distribution = (
        100 => 0,
        90  => 0,
        80  => 0,
        70  => 0,
        60  => 0,
        50  => 0,
        40  => 0,
        30  => 0,
        20  => 0,
        10  => 0,
        0   => 0
    );
    while ( my $line = <$FILE> ) {
        $line =~ s/\cM|\n//g;
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
            for ( my $i = 0; $i < scalar(@columnTitles); $i++ ) {
                $entry{ $columnTitles[$i] } = $values[$i];
            }

            my $align_length_no_gaps;
            my $q_length = abs( $entry{'q_start'} - $entry{'q_end'} ) + 1;
            my $s_length = abs( $entry{'s_start'} - $entry{'s_end'} ) + 1;

            if ( $q_length > $s_length ) {
                $align_length_no_gaps = $q_length;
            }
            else {
                $align_length_no_gaps = $s_length;
            }

            foreach my $key ( sort { $b <=> $a } ( keys %distribution ) ) {
                if ( $entry{'%_identity'} >= $key ) {
                    $distribution{$key}
                        = $distribution{$key} + $align_length_no_gaps;
                    last;
                }
            }
        }
    }

    close($FILE);
    $log->logNotice("The BLAST summary for file $file is:");

    my $total_aligned = 0;
    foreach my $key ( keys %distribution ) {
        $total_aligned = $total_aligned + $distribution{$key};
    }

    #favor hits where identity > 50%
    foreach my $key ( sort { $b <=> $a } ( keys %distribution ) ) {
        $log->logNotice( "alignment residues with identity level $key is "
                . $distribution{$key} );

        my $adjustment = 1;
        if ( $key > 50 ) {
            $adjustment = 10;
        }

        $coverage
            = $coverage + ( $key / 100 ) * $distribution{$key} * $adjustment;
    }

    $coverage = sprintf( "%d", $coverage );

    $log->logNotice("Total coverage is $coverage");
    return $coverage;
}

sub print_usage {
    print <<BLOCK;

USAGE:
   cgview_comparison_tool.pl -p DIR [options]

DESCRIPTION:
   Run this command once to generate a project directory. After the project is
   created place a reference genome in the reference_genome directory and any
   genomes to compare with the reference in the comparison_genomes directory.

   [Optional] Make changes to the project_settings.conf file to configure how
   the maps will be drawn. Add additional GFF files to the features and
   analyis directories.

   Draw maps by running this command again with the '-p' option pointing to
   the project directory.

REQUIRED ARGUMENTS:
   -p, --project DIR
      If no project exists yet, a blank project directory will be created.
      If the project exists, maps will be created.

OPTIONAL ARGUMENTS:

   -s, --settings FILE
      The settings file. If none is provided, the default settings file will be
      copied from \$CCT_HOME/conf/project_settings.conf to the project
      directory.
   -g, --config FILE
      The configuration file. The default is to use the
      \$CCT_HOME/conf/global_settings.conf file.
   -z, --map_size STRING
      Size of custom maps to create. For quickly generating new map sizes, use
      this option with the --start_at_xml option. Possible sizes include
      small/medium/large/x-large or a combination separated by commas (e.g.
      small,large). The size(s) provided will override the size(s) in the
      configuration files.
   -x, --start_at_xml
      Jump to XML generation. Skips performing blast, which can
      speed map generation if blast has already been done. This option is for
      creating new maps after making changes to the .conf files. Note that
      any changes in the .conf files related to blast will be ignored.
   -r, --start_at_map
      Start at map generation. Skips performing blast and
      generating XML. Useful if manual changes to the XML files have 
      been made or if creating new map sizes (see --map_size).
   -f, --map_prefix STRING
      Prefix to be appended to map names (Default is to add no additional
      prefix).
   -b, --max_blast_comparisons INTEGER
      The maximum number of BLAST results sets to be passed to the XML
      creation phase (Default is 100).
   -t, --sort_blast_tracks
      Sort BLAST results such that genomes with highest similarity are plotted
      first.
   --cct
      Colour BLAST results based on percent identity of hit instead of by
      source genome, and ignore 'use_opacity' setting in configuration file.
   -m, --memory STRING
      Memory string to pass to Java's '-Xmx' option (Default is 1500m).
   -c, --custom STRINGS
      Settings used to customize the appearance of the map.
   -h, --help
      Show this message.

EXAMPLE: 
   perl cgview_comparison_tool.pl -p my_project -b 50 -t \\
     --custom tickLength=20 labelFontSize=15 --map_size medium,x-large

BLOCK
}
