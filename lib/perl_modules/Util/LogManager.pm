#!/usr/bin/perl

=head1 NAME
    
LogManager - this module is used to write and read from a log file

=head1 SYNOPSIS
use Util::LogManager;
my $log;

$log = new Util::LogManager();
    my $geneCardManager = new BacMapUtil::LogManager();
    $geneCardManager->createCards();
try {
    $log->logNotice("Updating genome cards.");
    $log->logNotice("Genome cards have been updated.");
catch Error with {
    my $ex = shift;
    print $ex->{'-text'} . "\n";
    $log->logError($ex->{'-text'});
}

=head1 CONTACT

Paul Stothard, Genome Canada Help Desk <stothard@ualberta.ca>,
Gary Van Domselaar <gvd@redpoll.pharmacy.ualberta.ca>

=head1 COPYRIGHT

(2004) Paul Stothard, Genome Canada Help Desk

=head1 DESCRIPTION
    LogManager - this module is used to write and read from a log file

=cut

package Util::LogManager;
use lib qw(../);
use strict;
use warnings;
use Error qw(:try);
use Util::Configurator;

=head2 new

     Title   : new
     Usage   : my $logManager = Util::LogManager->new;
     Function: Util::LogManager constructor.
     Returns : (Util::LogManager) instance
     Args    : none
     Throws  : none

=cut

sub new {
    my $object = shift;
    my $class  = ref($object) || $object;
    my $conf   = Util::Configurator->new;
    my $self   = {};
    $self->{_VERBOSE}  = 1;
    $self->{_LOG_FILE} = undef;
    bless( $self, $class );
    return $self;
}

=head2 logError

     Title   : logError
     Usage   : $logManager->logError("error message");
     Function: appends a log message of type 'Error' to the log file
     Returns : (String) the log message if verbose is on.
     Args    : (String) the log message
     Throws  : (Error::Simple)

=cut

sub logError {
    my $self = shift;
    my $message;
    if (@_) {
        $message = shift;
    }
    else {
        throw Error::Simple("logError() requires message.");
    }
    my $logMessage = $self->writeToLog( "Error", $message );
    return $logMessage;
}

=head2 logWarning

     Title   : logWarning
     Usage   : $logManager->logWarning("warning message");
     Function: appends a log message of type 'Warning' to the log file
     Returns : (String) the log message if verbose is on.
     Args    : (String) the log message
     Throws  : (Error::Simple)

=cut

sub logWarning {
    my $self = shift;
    my $message;
    if (@_) {
        $message = shift;
    }
    else {
        throw Error::Simple("logError() requires message.");
    }
    my $logMessage = $self->writeToLog( "Warning", $message );
    return $logMessage;
}

=head2 logNotice

     Title   : logNotice
     Usage   : $logManager->logNotice("notice message");
     Function: appends a log message of type 'Notice' to the log file
     Returns : (String) the log message if verbose is on.
     Args    : (String) the log message
     Throws  : (Error::Simple)

=cut

sub logNotice {
    my $self = shift;
    my $message;
    if (@_) {
        $message = shift;
    }
    else {
        throw Error::Simple("logError() requires message.");
    }
    my $logMessage = $self->writeToLog( "Notice", $message );
    return $logMessage;
}

=head2 writeToLog

     Title   : writeToLog
     Usage   : $logManager->writeToLog($type, $message);
     Function: does the business of writing to the logfile.
     Returns : (String) the message that was written, if verbose is on
     Args    : (String, Sting) the type of message (error,warning,notice), 
                and the message text
     Throws  : (Error::Simple)

=cut

sub writeToLog {
    my $self = shift;

    my $messageType;
    if (@_) {
        $messageType = shift;
    }
    else {
        throw Error::Simple("writeToLog() requires message type.");
    }

    my $message;
    if (@_) {
        $message = shift;
    }
    else {
        throw Error::Simple("writeToLog() requires message.");
    }

    #get the path to the log file.
    my $conf = Util::Configurator->new;

    my $logPath = $self->log_file;
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

    open( OUTFILE, ">>" . $logPath )
        or throw Error::Simple(
        "Util::LogManager.writeToLog(): The log file $logPath could not be opened for appending."
        );

    #lock the file
    flock( OUTFILE, 2 );
    my $logMessage
        = "[" 
        . $time . "]" . " " . "["
        . $messageType . "]" . " "
        . $message . "\n";
    if ( $self->verbose ) {
        print $logMessage;
    }
    print( OUTFILE $logMessage );

    #unlock the file
    flock( OUTFILE, 8 );
    close(OUTFILE)
        or throw Error::Simple("The log file $logPath could not be closed.");
    return $logMessage;
}

=head2 verbose

     Title   : verbose
     Usage   : $logManager->verbose(1);
     Function: if this is set(default), then the logmanager will return the 
               content of the message written to the log file. Typically set
               verbose to zero if calling from a cgi script.
     Returns : (none)
     Args    : (Integer) 1 verbose , 0 silent
     Throws  : (none)

=cut

sub verbose {
    my $self = shift;
    if (@_) {
        $self->{_VERBOSE} = shift;
    }
    return $self->{_VERBOSE};
}

=head2 log_file

     Title   : log_file
     Usage   : $logManager->log_file("/path/to/logfile");
     Function: overrides the default logfile, for 
               writing in the superpose base directory
     Returns : (String) the log file path
     Args    : (String) the log file path
     Throws  : (none)

=cut

sub log_file {
    my $self = shift;
    if (@_) {
        $self->{_LOG_FILE} = shift;
    }
    return $self->{_LOG_FILE};
}

sub toString {
    my $self     = shift;
    my $log_file = $self->log_file;
    open( LOG, $log_file )
        || throw Error::Simple(
        "Util::LogManager->toString() could not open log file '$log_file' for reading: $!"
        );
    my @logText = <LOG>;
    close LOG
        || throw Error::Simple(
        "Util::LogManager->toString() could not close log file '$log_file': $!"
        );
    my $logString = join "", @logText;
    return $logString;
}

1;
