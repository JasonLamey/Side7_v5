package Side7::Globals;

use strict;
use warnings;

require Exporter;
use Log::Log4perl;
use Data::Dumper;

use Side7::Config;
use Side7::DB;

use version; our $VERSION = qv( '0.1.2' );


use vars qw(
    $LOGGER $DB $DBH $CONFIG
);

our @ISA = qw( Exporter );

our @EXPORT = qw(
    $LOGGER $DB $DBH $CONFIG
);

our @EXPORT_OK = qw();


=head1 NAME

Side7::Globals


=head1 DESCRIPTION

This class provides globally accessible and needed data.

=cut

BEGIN
{
    # Create config.
    $CONFIG = Side7::Config::new();

    # Create logger.
    my $logger_config = qq(
        log4perl.rootLogger                = $CONFIG->{'log4perl'}->{'rootLogger'}

        log4perl.appender.LOGFILE          = $CONFIG->{'log4perl'}->{'LOGFILE'}
        log4perl.appender.LOGFILE.filename = $CONFIG->{'log4perl'}->{'LOGFILE.filename'}
        log4perl.appender.LOGFILE.mode     = $CONFIG->{'log4perl'}->{'LOGFILE.mode'}

        log4perl.appender.LOGFILE.layout   = $CONFIG->{'log4perl'}->{'LOGFILE.layout'}
        log4perl.appender.LOGFILE.layout.ConversionPattern = $CONFIG->{'log4perl'}->{'LOGFILE.layout.ConversionPattern'}
    );

    Log::Log4perl->init( \$logger_config );
    $LOGGER = Log::Log4perl::get_logger();

    # Create DB connection.
    $DB  = Side7::DB::get_db( type => 'main' );
    $DBH = $DB->dbh or croak $DB->error;
}


=head1 METHODS


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
