package Side7::Config;

use strict;
use warnings;

=pod

=head1 NAME

Side7::Config

=head1 DESCRIPTION

This package provides configuration data for the application.

=cut


=head1 FUNCTIONS

=head2 new

    $CONFIG = Side7::Config::new();

Returns the configuration data for the application.

=cut

sub new
{
    my $CONFIG = {};

    # General Globals
    $CONFIG->{'general'}->{'version'}           = '5.0';

    # Page-related variables
    $CONFIG->{'page'}->{'user_directory'}->{'pagination_limit'} = 50;

    # Log4perl settings
    $CONFIG->{'log4perl'}->{'rootLogger'}       = 'DEBUG, LOGFILE';
    $CONFIG->{'log4perl'}->{'LOGFILE'}          = 'Log::Log4perl::Appender::File';
    $CONFIG->{'log4perl'}->{'LOGFILE.filename'} = 'log/logger.log';
    $CONFIG->{'log4perl'}->{'LOGFILE.mode'}     = 'append';
    $CONFIG->{'log4perl'}->{'LOGFILE.layout'}   = 'PatternLayout';
    $CONFIG->{'log4perl'}->{'LOGFILE.layout.ConversionPattern'} = '[%d] [%p] %M %L - %m%n';

    return $CONFIG;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
