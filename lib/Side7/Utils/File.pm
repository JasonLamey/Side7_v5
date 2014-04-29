package Side7::Utils::File;

use strict;
use warnings;

use Side7::Globals;


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

    if ( ! -d $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 )
    {
        mkdir $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 || return ( 0, $! );
    }

    if ( ! -d $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 )
    {
        mkdir $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 || return ( 0, $! );
    }

    if ( ! -d $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 . '/' . $user_id )
    {
        mkdir $CONFIG->{'general'}->{'base_gallery_directory'} . $tier1 . '/' . $tier2 . '/' . $user_id || return ( 0, $! );
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

    my $base_cached_dir = $CONFIG->{'general'}->{'cached_file_directory'} . 'user_content';

    if ( ! -d $base_cached_dir )
    {
        mkdir $base_cached_dir || return ( 0, $!, undef );
    }

    my $base_content_dir = join( '/', $base_cached_dir, $content_type );

    if ( ! -d $base_content_dir )
    {
        mkdir $base_content_dir || return ( 0, $!, undef );
    }

    if ( defined $content_size )
    {
        $base_content_dir = join( '/', $base_content_dir, lc( $content_size ) );
        if ( ! -d $base_content_dir )
        {
            mkdir $base_content_dir || return ( 0, $!, undef );
        }
    }
   
    my $base_content_t1_dir = join( '/', $base_content_dir, $tier1 );
    if ( ! -d $base_content_t1_dir )
    {
        mkdir $base_content_t1_dir || return ( 0, $!, undef );
    }
    
    my $base_content_t1_t2_dir = join( '/', $base_content_t1_dir, $tier2 );
    if ( ! -d $base_content_t1_t2_dir )
    {
        mkdir $base_content_t1_t2_dir || return ( 0, $!, undef );
    }
    
    my $base_content_t1_t2_id_dir = join( '/', $base_content_t1_t2_dir, $user_id );
    if ( ! -d $base_content_t1_t2_id_dir )
    {
        mkdir $base_content_t1_t2_id_dir || return ( 0, $!, undef );
    }

    return( 1, undef, $base_content_t1_t2_id_dir );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
