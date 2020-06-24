#FILE: convert_vcf_to_features.pl
#AUTH: Jason Grant <jason.grant@ualberta.ca>
#DATE: June 22, 2020
#VERS: 1.1

use warnings;
use strict;
use Getopt::Long;

# initialize options
my %options = (
    infile  => undef,
    outfile => undef,
    help    => undef
);

# get command line options
GetOptions(
    'i|input=s'  => \$options{infile},
    'o|output=s' => \$options{outfile},
    'h|help'     => \$options{help}
);

if ( defined( $options{help} ) ) {
    _usage();
    exit(0);
}

if (   !( defined( $options{infile} ) )
    or !( defined( $options{outfile} ) ) )
{
    _usage();
    exit(1);
}

open( my $INFILE, "$options{infile}" )
  or die("Cannot open file '$options{infile}': $!");

my $chrom_files      = {};  # keys: chromosomes; values: file variables;
my $variant_counters = {};  # keys: chromosomes; values: current variant number;
my $header_found     = 0;

while ( my $line = <$INFILE> ) {

    # Skip meta-data
    if ( $line =~ m/^\#\#/ ) {
        next;
    }

    # Found header line
    if ( $line =~ m/^\#CHROM/ ) {
        $header_found = 1;

        # could process header if needed
        next;
    }

    # Data lines
    if ($header_found) {
        process_line( $chrom_files, $variant_counters, $line );
    }
}

close($INFILE) or die("Cannot close file '$options{infile}': $!");
for my $chrom ( keys %$chrom_files ) {
    close $chrom_files->{$chrom} or die("Cannot close output file: $!");
}

sub process_line {
    my $chrom_files      = shift;
    my $variant_counters = shift;
    my $line             = shift;

    if ( $line =~ /^(\S+)\t(\S+)\t\S+\t(\S+)/ ) {
        my $chrom = $1;
        my $pos   = $2;
        my $ref   = $3;

        my $end = $pos + length($ref) - 1;

        if ( exists $chrom_files->{$chrom} ) {
            $variant_counters->{$chrom}++;
        }
        else {
            $chrom_files->{$chrom}      = open_outfile($chrom);
            $variant_counters->{$chrom} = 1;
        }

        my $output =
"variant_$variant_counters->{$chrom}\t.\tother\t$pos\t$end\t.\t+\t.\n";
        print { $chrom_files->{$chrom} } $output;
    }
    else {
        print "Could not parse line: $line\n";
    }

}

sub output_header {
    return "seqname\tsource\tfeature\tstart\tend\tscore\tstrand\tframe\n";
}

sub open_outfile {
    my $chrom = shift;

    my $outname = $options{outfile};

    $chrom =~ s/[^A-Za-z0-9]+/_/g;

    if ( $outname =~ m/([^\/]+)\.+([^\/]+)$/ ) {
        $outname =~ s/([^\/]+)\.+([^\/]+)$/${1}_${chrom}.${2}/g;
    }
    elsif ( $outname =~ m/([^\/]+)$/ ) {
        $outname =~ s/([^\/]+)$/${1}_${chrom}/g;
    }
    else {
        die("Could not parse filename '$outname'.");
    }

    open( my $fh, '>', "$outname" ) or die("Cannot open file '$outname': $!");
    print $fh output_header;
    return $fh;
}

sub _usage {
    print <<BLOCK;
convert_vcf_to_features.pl - convert VCF file to tab-delimited file for
the CGView Comparison Tool.

DISPLAY HELP AND EXIT:

usage:

  perl convert_vcf_to_features.pl -help

CONVERT VCF TO TAB-DELIMITED

usage:

  perl convert_vcf_to_features.pl -i <file> -o <file>

required arguments:

-i - Input file in VCF format.

-o - Output file in tab-delimited format for CGView Comparison Tool. This name
will have the chromosome name as read from the VCF file added to the end,
before the file extension if one is present. If multiple chromosomes are
present in the VCF file then multiple output files will be generated, each with
a different suffix.

example usage:

  perl convert_vcf_to_features.pl -i input.vcf -o output.gff
BLOCK
}

