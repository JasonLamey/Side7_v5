package Side7::Utils::File;

use strict;
use warnings;

use DateTime;
use File::Path;
use File::Basename;
use Filesys::DiskUsage;
use List::Util;

use Side7::Globals;
use Side7::AuditLog;

use version; our $VERSION = qv( '0.1.12' );


=head1 NAME

Side7::Utils::File


=head1 DESCRIPTION

Provides file and file attribute-related tools


=head1 FUNCTIONS


=head2 get_formatted_filesize_from_bytes()

Returns a formatted string from the value passed in.  Value is assumed to be in bytes.
If wantarray is set, then passes back the value and the units as separate values in an array.

Parameters:

=over 4

=item bytes: the filesize to format, given in bytes. Required.

=item force_units: A string to which to force a calculation. Optional, takes ( B, KB, MB, GB, TB, PB )

=back

    $filesize = Side7::Utils::File::get_formatted_filesize_from_bytes(
                                                                        bytes       => $filesize_in_bytes,
                                                                        force_units => $unit
                                                                     );

=cut

sub get_formatted_filesize_from_bytes
{
    my ( %args ) = @_;
    my $size_in_bytes = delete $args{'bytes'}       // 0;
    my $force_units   = delete $args{'force_units'} // undef;

    my @units = ( qw( B KB MB GB TB PB ) );

    # Ensure that force_units is a valid term, otherwise, undef it.
    if ( defined $force_units )
    {
        if ( ! List::Util::any { lc( $force_units ) eq lc( $_ ) } @units )
        {
            $force_units = undef;
        }
    }

    my $exp = 0;
    foreach my $unit ( @units ) {
        if ( defined $force_units )
        {
            last if lc( $force_units ) eq lc( $unit );
        }
        else
        {
            last if $size_in_bytes < 1024;
        }
        $size_in_bytes /= 1024;
        $exp++;
    }

    return wantarray ? ( $size_in_bytes, $units[$exp] ) : sprintf( "%d %s", $size_in_bytes, $units[$exp] );
}


=head2 create_user_directory()

Creates the file structure for a new User account.  Returns a boolean for success, and any error messages.

Parameters:

=over 4

=item user_id: The ID of the User for which to create directories.

=back

    my $success = Side7::Utils::File::create_user_directory( $user->id );


=cut

sub create_user_directory
{
    my ( $user_id ) = @_;

    return ( 0, 'Invalid User credentials' ) if ! defined $user_id || $user_id !~ m/^\d+$/;

    my $tier1 = substr( $user_id, 0, 1 );
    my $tier2 = substr( $user_id, 0, 3 );

    my $user_dir  = $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 . '/' . $user_id;

    if ( ! -d $CONFIG->{'general'}->{'base_gallery_directory'} )
    {
        my $error = 'ERROR: Base directory >' . $CONFIG->{'general'}->{'base_gallery_directory'} . '< does not exist.';
        my $audit_log = Side7::AuditLog->new(
                                                title       => 'Directory Creation Error',
                                                description => $error,
                                                ip_address  => '',
                                                timestamp   => DateTime->now(),
        );
        $audit_log->save();
        return ( 0, 'An error occurred while creating the User directory.' );
    }

    my $error_message = '';
    if ( ! -d $user_dir )
    {
        File::Path::make_path( $user_dir, { error => \my $error } );
        if ( @{ $error } )
        {
            foreach my $diag ( @{ $error } )
            {
                my ( $file, $message ) = %{ $diag };
                if ( $file eq '' )
                {
                    $error_message .= 'Directory creation error: ' . $message . '; ';
                }
                else
                {
                    $error_message .= 'Problem creating User directory >' . $file . '<: ' . $message . '; ';
                }
            }
            my $audit_msg = 'ERROR: User directory >' . $user_dir . '< was not created: ' . $error_message;
            my $audit_log = Side7::AuditLog->new(
                                                    title       => 'Directory Creation Error',
                                                    description => $audit_msg,
                                                    ip_address  => '',
                                                    timestamp   => DateTime->now(),
            );
            $audit_log->save();
            return ( 0, $error_message );
        }
    }

    if ( ! -d $user_dir )
    {
        my $error = 'ERROR: User directory >' . $user_dir . '< does not exist even after successful creation return.';
        my $audit_log = Side7::AuditLog->new(
                                                title       => 'Directory Creation Error',
                                                description => $error,
                                                ip_address  => '',
                                                timestamp   => DateTime->now(),
        );
        return ( 0, 'User directory still does not exist after successful creation return.' );
    }

    # Make user subdirectories
    foreach my $subdir ( qw/ album_artwork avatars user_bio_images character_bio_images / )
    {
        my $user_subdir = $user_dir . '/' . $subdir;
        if ( ! -d $user_subdir )
        {
            File::Path::make_path( $user_subdir, { error => \my $error } );
            if ( @{ $error } )
            {
                foreach my $diag ( @{ $error } )
                {
                    my ( $file, $message ) = %{ $diag };
                    if ( $file eq '' )
                    {
                        $error_message .= 'Sub-Directory creation error: ' . $message . '; ';
                    }
                    else
                    {
                        $error_message .= 'Problem creating User sub-directory >' . $file . '<: ' . $message . '; ';
                    }
                }
                my $audit_msg = 'ERROR: User sub-directory >' . $user_subdir . '< was not created: ' . $error_message;
                my $audit_log = Side7::AuditLog->new(
                                                        title       => 'Directory Creation Error',
                                                        description => $audit_msg,
                                                        ip_address  => '',
                                                        timestamp   => DateTime->now(),
                );
                $audit_log->save();
                return ( 0, $error_message );
            }
        }

        if ( ! -d $user_subdir )
        {
            my $error = 'ERROR: User sub-directory >' . $user_subdir . '< does not exist even after successful creation return.';
            my $audit_log = Side7::AuditLog->new(
                                                    title       => 'Directory Creation Error',
                                                    description => $error,
                                                    ip_address  => '',
                                                    timestamp   => DateTime->now(),
            );
            return ( 0, 'User directory still does not exist after successful creation return.' );
        }
    }

    $user_dir  = $CONFIG->{'general'}->{'base_music_directory'} . $tier1 . '/' . $tier2 . '/' . $user_id;

    if ( ! -d $CONFIG->{'general'}->{'base_music_directory'} )
    {
        my $error = 'ERROR: Base music directory >' . $CONFIG->{'general'}->{'base_music_directory'} . '< does not exist.';
        my $audit_log = Side7::AuditLog->new(
                                                title       => 'Directory Creation Error',
                                                description => $error,
                                                ip_address  => '',
                                                timestamp   => DateTime->now(),
        );
        $audit_log->save();
        return ( 0, 'An error occurred while creating the User directory.' );
    }

    if ( ! -d $user_dir )
    {
        File::Path::make_path( $user_dir, { error => \my $error } );
        if ( @{ $error } )
        {
            foreach my $diag ( @{ $error } )
            {
                my ( $file, $message ) = %{ $diag };
                if ( $file eq '' )
                {
                    $error_message .= 'Directory creation error: ' . $message . '; ';
                }
                else
                {
                    $error_message .= 'Problem creating User directory >' . $file . '<: ' . $message . '; ';
                }
            }
            my $audit_msg = 'ERROR: User directory >' . $user_dir . '< was not created: ' . $error_message;
            my $audit_log = Side7::AuditLog->new(
                                                    title       => 'Directory Creation Error',
                                                    description => $audit_msg,
                                                    ip_address  => '',
                                                    timestamp   => DateTime->now(),
            );
            $audit_log->save();
            return ( 0, $error_message );
        }
    }

    return ( 1, undef );
}


=head2 create_user_cached_file_directory()

Checks for the existence of the cached file directory in question, and if it's missing, creates it.
Returns a array of Success value, error message, and returned cached_file path.

Parameters:

=over 4

=item user_id: The User ID of the user to whom the directory is attributed.

=item content_type: The User Content type for this stored file type. Valid types are 'avatars', 'album_artwork', 'images', 'literature', 'music', and 'videos'.

=item content_size: The User Content size (dimensions) for this stored file type. Valid types are 'tiny', 'small', 'medium', 'large', and 'original'.

=back

    my ( $success, $error, $cached_file_path ) =
                Side7::Utils::File::create_user_cached_file_directory(
                                                                        user_id      => $user_id,
                                                                        content_type => $content_type,
                                                                        content_size => $content_size,
                                                                     );

=cut

sub create_user_cached_file_directory
{
    my ( %args ) = @_;

    my $user_id      = delete $args{'user_id'}      // undef;
    my $content_type = delete $args{'content_type'} // undef;
    my $content_size = delete $args{'content_size'} // undef;

    if ( ! defined $user_id || ! defined $content_type )
    {
        $LOGGER->warn( sprintf(
                                "Missing necessary values for creating cached_file directory: %s %s",
                                ( defined $user_id )      ? '' : 'user_id',
                                ( defined $content_type ) ? '' : 'content_type'
                              )
        );
        return ( 0, 'Cannot confirm cached file directory. Invalid User or Content information.', undef );
    }

    my $user = Side7::User->new( id => $user_id )->load( speculative => 1 );
    if ( ! defined $user || ref( $user ) ne 'Side7::User' )
    {
        $LOGGER->warn( 'Invalid User ID passed in: >' . $user_id . '<' );
        return( 0, 'Cannot confirm cached file directory. Invalid User information.', undef );
    }

    if (
            defined $content_type
            &&
            $content_type eq 'images'
            &&
            ( ! defined $content_size || $content_size eq '' )
    )
    {
        $LOGGER->warn( 'Image cached files dir requested but no size supplied.' );
        return( 0, 'Cannot confirm cached file directory. Invalid User Content information.', undef );
    }

    if (
        defined $content_size
        &&
        lc( $content_size ) ne 'tiny'
        &&
        lc( $content_size ) ne 'small'
        &&
        lc( $content_size ) ne 'medium'
        &&
        lc( $content_size ) ne 'large'
        &&
        lc( $content_size ) ne 'original'
    )
    {
        $LOGGER->warn( 'Invalid content_size value >' . $content_size . '< supplied when creating cached_file dir.' );
        return( 0, 'Cannot confirm cached file directory. Invalid User Content information.', undef );
    }

    # CACHED_FILE STRUCTURE:
    # /cached_files/user_content/CONTENT_TYPE/[ADDL_BREAKDOWN]/[USER_ID BREAKDOWN/content_id.ext
    #
    # So, for avatars:
    # /cached_files/user_content/avatars/[tiny|small|medium|large|original]/[user_id breakdown]/image_id.[jpg|gif|png]
    #
    # So, for album artwork
    # /cached_files/user_content/album_artwork/[tiny|small|medium|large|original]/[user_id breakdown]/image_id.[jpg|gif|png]
    #
    # For images:
    # /cached_files/user_content/images/[tiny|small|medium|large|original]/[user_id breakdown]/image_id.[jpg|gif|png]
    #
    # For literature:
    # /cached_files/user_content/words/[user_id breakdown]/words_id.[doc|docx|rtf|txt|pdf]
    #
    # For music:
    # /cached_files/user_content/music/[user_id breakdown]/music_id.[ogg|mp3|wma]

    if ( ! -d $CONFIG->{'general'}->{'cached_file_directory'} )
    {
        # This should exist at all times.  Bail out if it doesn't.
        $LOGGER->error( 'Cached file directory >' . $CONFIG->{'general'}->{'cached_file_directory'} . '< missing!' );
        return ( 0, 'An error occurred trying to store or retrieve the requested User Content.', undef );
    }

    my $tier1 = substr( $user_id, 0, 1 );
    my $tier2 = substr( $user_id, 0, 3 );

    my $cached_file_dir = '';
    if
    (
        lc( $content_type ) eq 'avatars'
        ||
        lc( $content_type ) eq 'images'
        ||
        lc( $content_type ) eq 'album_artwork'
    )
    {
        $cached_file_dir = $CONFIG->{'general'}->{'cached_file_directory'} .
                            'user_content' .
                            '/' .
                            $content_type .
                            '/' .
                            $content_size .
                            '/' .
                            $tier1 . '/' . $tier2 . '/' . $user_id;
    }
    elsif (
            lc( $content_type ) eq 'literature'
            ||
            lc( $content_type ) eq 'music'
          )
    {
        $cached_file_dir = $CONFIG->{'general'}->{'cached_file_directory'} .
                            'user_content' .
                            '/' .
                            $content_type .
                            '/' .
                            $tier1 . '/' . $tier2 . '/' . $user_id;
    }
    else
    {
        $LOGGER->error( 'Invalid Content Type value >' . $content_type . '< supplied when creating cached_file dir.' );
        return ( 0, 'An error occurred. Invalid Content Type passed in.', undef );
    }

    if ( ! -d $cached_file_dir )
    {
        File::Path::make_path( $cached_file_dir, { error => \my $error } );
        if ( @{ $error } )
        {
            my $error_message = '';
            foreach my $diag ( @{ $error } )
            {
                my ( $file, $message ) = %{ $diag };
                if ( $file eq '' )
                {
                    $error_message .= 'Directory creation error: ' . $message . '; ';
                }
                else
                {
                    $error_message .= 'Problem creating User cache directory >' . $file . '<: ' . $message . '; ';
                }
            }
            my $audit_msg = 'ERROR: User cache directory >' . $cached_file_dir . '< was not created: ' . $error_message;
            my $audit_log = Side7::AuditLog->new(
                                                    title       => 'Directory Creation Error',
                                                    description => $audit_msg,
                                                    ip_address  => '',
                                                    timestamp   => DateTime->now(),
            );
            $audit_log->save();
            return ( 0, $error_message, undef );
        }

        if ( ! -d $cached_file_dir )
        {
            my $error = 'ERROR: User cache directory >' . $cached_file_dir . '< does not exist even after successful creation return.';
            my $audit_log = Side7::AuditLog->new(
                                                    title       => 'Directory Creation Error',
                                                    description => $error,
                                                    ip_address  => '',
                                                    timestamp   => DateTime->now(),
            );
            return ( 0, 'User cache directory still does not exist after successful creation return.', undef );
        }
    }

    return( 1, undef, $cached_file_dir );
}


=head2 get_disk_usage()

Returns in bytes the amount of disk usage a particular account is using.

Parameters:

=over 4

=item filepath: The filepath to check for disk usage.

=back

    my $bytes = Side7::Utils::File::get_disk_usage( filepath => $filepath );

=cut

sub get_disk_usage
{
    my ( %args ) = @_;

    my $filepath = delete $args{'filepath'} // undef;

    if ( ! defined $filepath )
    {
        $LOGGER->warn( 'Invalid filepath provided: Null filepath.' );
        return 0;
    }

    if ( ! -d $filepath )
    {
        $LOGGER->warn( 'Invalid filepath provided: >' . $filepath . '< does not exist.' );
        return 0;
    }

    my $total = Filesys::DiskUsage::du( $filepath );

    return $total;
}


=head2 get_file_extension( $filepath )

Returns a C<string> containing the file extension for the filename/filepath provided.
Returns C<undef> if no extension exists or can be parsed.

Parameters:

=over 4

=item filepath: A C<string> containing the filepath to be parsed.

=back

    my $ext = Side7::Utils::File::get_file_extension( $filepath );

=cut

sub get_file_extension
{
    my ( $filepath ) = @_;

    return if ! defined $filepath || $filepath eq '';

    my ( $filename, $path, $extension ) = File::Basename::fileparse( $filepath, qr/\.[^.]*/ );

    $extension =~ s/^\.+//g;

    return $extension;
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
