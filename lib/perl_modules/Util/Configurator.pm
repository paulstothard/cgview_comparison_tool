#!/usr/bin/perl

=head1 NAME
    
    Configurator - a  configuration utility

=head1 SYNOPSIS

use Util::Configurator;

my $conf;

$conf = new Util::Configurator("/home/paul/paul_dev/perl/nmrq/conf/nmrq.conf");
my $value = $conf->getConfWithKey('some_key');


=head1 CONTACT

Paul Stothard, Genome Canada Help Desk <stothard@ualberta.ca>,
Gary Van Domselaar, <gvd@redpoll.pharmacy.ualberta.ca>


=head1 COPYRIGHT

(2004) Paul Stothard

=head1 DESCRIPTION
    
    Configurator - reads data from the configuration file. Contents of the configuration file
    are placed into a hash. The configuration file should contain fields marked with '#'. Each
    field should have a value on the next line, as in the following example:

    #the full path to your cgview_map_builder directory
    mapBuilder = /home/paul/stothard_dev/public/afns/cgview_map_builder

    getOrfs = $mapBuilder/lib/scripts/get_orfs.pl

=cut

package Util::Configurator;

use lib qw(..);
use strict;
use warnings;
use Error qw(:try);

=head2 new

     Title   : new
     Usage   : my $conf = Util::Configurator->new
     Function: Util::Configurator constructor.
     Returns : (Util::Configurator) instance
     Args    : none
     Throws  : none

=cut

sub new {
    my $object = shift;
    my $class  = ref($object) || $object;
    my $self   = {
        values       => {},
        confInfoRead => 0,
        _PATH        => undef
    };

    bless( $self, $class );
    return $self;
}

=head2 readConfInfo
     Title   :readConfInfo
     Usage   : $conf->readConfInfo()
     Function: loads the configuration file into the object
     Returns : (none) 
     Args    : (none)
     Throws  : (Error::Simple)

=cut

sub readConfInfo {
    my $self            = shift;
    my $valuesReference = $self->{values};
    open( INFILE, "<" . $self->{_PATH} )
        or throw Error::Simple(
              "Util::Configurator.readConfInfo(): The configuration file "
            . $self->{_PATH}
            . " could not be opened: $!" );

    my @conf = <INFILE>;

    close(INFILE)
        or throw Error::Simple(
              "Util::Configurator.readConfInfo():The configuration file "
            . $self->{_PATH}
            . " could not be closed." );

    my @conf_copy = ();
    foreach (@conf) {
        if ( $_ =~ m/^([^\#=\s]+)\s*=\s*([^\n]+)/ ) {
            my $key   = $1;
            my $value = $2;
            $value =~ s/\s+$//;

         #remove trailing '/' so that '/usr/bin/perl/' becomes '/usr/bin/perl'
            $value =~ s/\/$//;
            if ( !( $value =~ m/\S/ ) ) {
                throw Error::Simple(
                    "Util::Configurator.readConfInfo(): Please specify a value for the key '$key' in the configuration file or set an environment variable called '$key'."
                );
            }

            $valuesReference->{$key} = $value;
        }
    }

#some values will contain variables starting with '$'. These should be interpolated

    my @keys = keys(%$valuesReference);
    foreach (@keys) {
        my $key   = $_;
        my $value = $valuesReference->{$key};
        while ( $value =~ m/\$(\w+)/g ) {
            my $to_interpolate = $1;
            my $interpolated   = $valuesReference->{$to_interpolate};

            #if not defined, attempt to obtain value from environment variable
            if ( defined( $ENV{$to_interpolate} ) ) {
                $interpolated = $ENV{$to_interpolate};
            }

            if ( defined($interpolated) ) {
                $value =~ s/\$$to_interpolate/$interpolated/g;
            }
            else {

                #ignore
            }
        }
        $valuesReference->{$_} = $value;
    }

    $self->{confInfoRead} = 1;
}

=head2 getConfWithKey
     Title   : getConfWithKey
     Usage   : $conf->getConfWithKey($key)
     Function: returns the value, from the configuration file, of the supplied key
     Returns : (String) the configuration value
     Args    : (String) the configuration key
     Throws  : (Error::Simple)

=cut

sub getConfWithKey {
    my $self = shift;
    my $key;
    my $default;
    if (@_) {
        $key = shift;
    }
    else {
        throw Error::Simple(
            "Util::Configurator.getConfWithKey() requires key value.");
    }

    if (@_) {
        $default = shift;
    }

    if ( !( $self->{confInfoRead} ) ) {
        throw Error::Simple(
            "Util::Configurator.getConfWithKey(): info must be read first using readConfInfo()."
        );
    }

    my $valuesReference = $self->{values};
    if ( exists( $valuesReference->{$key} ) ) {
        return $valuesReference->{$key};
    }
    elsif ( defined($default) ) {
        return $default;
    }
    else {
        throw Error::Simple(
            "Util::Configurator.getConfWithKey(): The configuration key '$key' was not found."
        );
    }

}

sub getAllKeys {
    my $self = shift;
    my @keys = keys( %{ $self->{values} } );
    return \@keys;
}

sub path {
    my $self = shift;
    if (@_) {
        my $path = shift;
        if ( -e $path ) {
            $self->{_PATH} = $path;
        }
        else {
            die("Configuration file '$path' does not exist\n");
        }
    }
    return $self->{_PATH};
}

1;
