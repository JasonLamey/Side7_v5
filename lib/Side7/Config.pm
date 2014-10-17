package Side7::Config;

use strict;
use warnings;

use version; our $VERSION = qv( '0.1.10' );

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
    $CONFIG->{'app_dir'} = '/home/badkarma/src/dancer_projects/side7v5/Side7';
    $CONFIG->{'general'}->{'version'}                = '5.0';
    $CONFIG->{'general'}->{'base_gallery_directory'} = '/data/galleries/';
    $CONFIG->{'general'}->{'base_gallery_uri'}       = '/galleries/';
    $CONFIG->{'general'}->{'cached_file_directory'}  = '/data/cached_files/';
    $CONFIG->{'general'}->{'cached_file_uri'}        = '/cached_files/';

    # Page-related variables
    $CONFIG->{'page'}->{'default'}->{'pagination_limit'} = 50;

    # Image Related
    $CONFIG->{'image'}->{'default_thumb_path'} = '/images/defaults/:::SIZE:::/:::TYPE:::.jpg';
    $CONFIG->{'image'}->{'size'}->{'tiny'}     = '50x50';
    $CONFIG->{'image'}->{'size'}->{'small'}    = '100x100';
    $CONFIG->{'image'}->{'size'}->{'medium'}   = '300x300';
    $CONFIG->{'image'}->{'size'}->{'large'}    = '800x800';

    # Avatar Related
    $CONFIG->{'avatar'}->{'size'}->{'tiny'}     = '50x50';
    $CONFIG->{'avatar'}->{'size'}->{'small'}    = '100x100';
    $CONFIG->{'avatar'}->{'size'}->{'medium'}   = '150x150';
    $CONFIG->{'avatar'}->{'size'}->{'large'}    = '200x200';
    $CONFIG->{'system_avatar'}->{'cached_file_path'}   = '/data/cached_files/system_avatars/';
    $CONFIG->{'system_avatar'}->{'original_file_path'} = $CONFIG->{'app_dir'} . '/public/images/avatars/';

    # Log4perl settings
    $CONFIG->{'log4perl'}->{'rootLogger'}       = 'DEBUG, LOGFILE';
    $CONFIG->{'log4perl'}->{'LOGFILE'}          = 'Log::Log4perl::Appender::File';
    $CONFIG->{'log4perl'}->{'LOGFILE.filename'} = $CONFIG->{'app_dir'} . '/log/logger.log';
    $CONFIG->{'log4perl'}->{'LOGFILE.mode'}     = 'append';
    $CONFIG->{'log4perl'}->{'LOGFILE.layout'}   = 'PatternLayout';
    $CONFIG->{'log4perl'}->{'LOGFILE.layout.ConversionPattern'} = '[%d] [%p] %M %L - %m%n';

    # Kudos Coins Awards & Costs
    $CONFIG->{'kudos_coins'}->{'award'}->{'referral'} = 25;
    $CONFIG->{'kudos_coins'}->{'cost'}->{'test'}      = -50;

    return $CONFIG;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2013

=cut

1;
