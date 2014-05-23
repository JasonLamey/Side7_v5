package Side7::Utils::File;

use strict;
use warnings;

use DateTime;
use File::Path;

use Side7::Globals;
use Side7::AuditLog;


=head1 NAME

Side7::Utils::File


=head1 DESCRIPTION

Provides file and file attribute-related tools


=head1 FUNCTIONS


=head2 get_formatted_filesize_from_bytes()

    $filesize = Side7::Utils::File::get_formatted_filesize_from_bytes( $filesize_in_bytes );

Returns a formatted string from the value passed in.  Value is assumed to be in bytes.

=cut

sub get_formatted_filesize_from_bytes
{
    my ( $size_in_bytes ) = @_;

    my $exp = 0;

    my $units = [ qw( B KB MB GB TB PB ) ];

    foreach my $unit ( @$units ) {
        last if $size_in_bytes < 1024;
        $size_in_bytes /= 1024;
        $exp++;
    }

    return wantarray ? ( $size_in_bytes, $units->[$exp] ) : sprintf( "%d %s", $size_in_bytes, $units->[$exp] );
}


=head2 create_user_directory

    my $success = Side7::Utils::File::create_user_directory( $user->id );

Creates the file structure for a new User account.  Returns a boolean for success, and any error messages.

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

    return ( 1, undef );
}


=head2 create_user_cached_file_directory()

Checks for the existence of the cached file directory in question, and if it's missing, creates it.
Returns a array of Success value, error message, and returned cached_file path.

Parameters:

=over 4

=item user_id: The User ID of the user to whom the directory is attributed.

=item content_type: The User Content type for this stored file type. Valid types are 'images', 'words', 'music', and 'videos'.

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
        return ( 0, 'Cannot confirm cached file directory. Invalid User Content information.', undef );
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
    # So, for images:
    # /cached_files/user_content/images/[tiny|small|medium|large|original]/[user_id breakdown]/image_id.[jpg|gif|png]
    #
    # For words:
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
    if ( lc( $content_type ) eq 'images' )
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
            lc( $content_type ) eq 'words'
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
        return ( 0, 'Invalid content_type passed in.', undef );
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

    return( 1, undef, $cached_file_dir );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
