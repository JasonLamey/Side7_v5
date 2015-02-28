package Side7::Config;

use strict;
use warnings;

use version; our $VERSION = qv( '0.1.12' );

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
    $CONFIG->{'general'}->{'base_music_directory'}   = '/data/user_audio/'; # Outside of web-accessible dir tree.
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

    # Album Artwork Related
    $CONFIG->{'album'}->{'size'}->{'tiny'}     = '50x50';
    $CONFIG->{'album'}->{'size'}->{'small'}    = '100x100';
    $CONFIG->{'album'}->{'size'}->{'medium'}   = '300x300';
    $CONFIG->{'album'}->{'size'}->{'large'}    = '600x600';
    $CONFIG->{'album'}->{'cached_file_path'}   = '/data/cached_files/album_artwork/';

    # Log4perl settings
    $CONFIG->{'log4perl'}->{'rootLogger'}       = 'DEBUG, LOGFILE';
    $CONFIG->{'log4perl'}->{'LOGFILE'}          = 'Log::Log4perl::Appender::File';
    $CONFIG->{'log4perl'}->{'LOGFILE.filename'} = $CONFIG->{'app_dir'} . '/log/logger.log';
    $CONFIG->{'log4perl'}->{'LOGFILE.mode'}     = 'append';
    $CONFIG->{'log4perl'}->{'LOGFILE.layout'}   = 'PatternLayout';
    $CONFIG->{'log4perl'}->{'LOGFILE.layout.ConversionPattern'} = '[%d] [%p] %M %L - %m%n';

    # Kudos Coins Awards & Costs
    $CONFIG->{'kudos_coins'}->{'award'}->{'referral'}             = 50;
    $CONFIG->{'kudos_coins'}->{'award'}->{'leave_commentary'}     = 2;
    $CONFIG->{'kudos_coins'}->{'award'}->{'leave_light_critique'} = 3;
    $CONFIG->{'kudos_coins'}->{'award'}->{'leave_heavy_critique'} = 5;
    $CONFIG->{'kudos_coins'}->{'award'}->{'gave_owner_rating'}    = 10;
    $CONFIG->{'kudos_coins'}->{'award'}->{'owner_rating_1'}       = 0;
    $CONFIG->{'kudos_coins'}->{'award'}->{'owner_rating_2'}       = 1;
    $CONFIG->{'kudos_coins'}->{'award'}->{'owner_rating_3'}       = 3;
    $CONFIG->{'kudos_coins'}->{'award'}->{'owner_rating_4'}       = 4;
    $CONFIG->{'kudos_coins'}->{'award'}->{'owner_rating_5'}       = 5;

    $CONFIG->{'kudos_coins'}->{'cost'}->{'test'}      = -50;

    $CONFIG->{'owner_ratings'} = [ 'Completely Unhelpful', 'Somewhat Unhelpful', 'Helpful', 'Very Helpful', 'Extremely Helpful' ];

    return $CONFIG;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
