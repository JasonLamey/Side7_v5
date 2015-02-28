package Side7::UserContent::AlbumArtwork;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;
use parent 'Clone';

=pod

=head1 NAME

Side7::UserContent::AlbumArtwork

=head1 DESCRIPTION

This package represents artwork associated with a User's Album.

=head1 SCHEMA INFORMATION

    Table name: album_artwork

    | id         | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | album_id   | bigint(20) unsigned | NO   |     | NULL    |                |
    | filename   | varchar(255)        | NO   |     | NULL    |                |
    | created_at | datetime            | NO   |     | NULL    |                |
    | updated_at | datetime            | NO   |     | NULL    |                |

=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Album

One to one relationship with Album, through album_id

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'album_artwork',
    columns => [
        id         => { type => 'serial', not_null => 1 },
        album_id   => { type => 'integer', not_null => 1 },
        filename   => { type => 'varchar', length => 255, not_null => 1 },
        created_at => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    foreign_keys =>
    [
        album =>
        {
            class             => 'Side7::UserContent::Album',
            key_columns       => { album_id => 'id' },
            relationship_type => 'one to one',
        },
    ],
);


=head1 METHODS


=head2 get_cached_album_artwork_path()

Returns the path to the cached album artwork file to be used to display the album artwork image.

Parameters:

=over 4

=item size: The image size to return. Valid values are 'tiny', 'small', 'medium', 'large', 'original'. Default is 'original'.

=back

    my ( $artwork_path, $error ) = $album->artwork->get_cached_album_artwork_path( size => $size );

=cut

sub get_cached_album_artwork_path
{
    my ( $self, %args ) = @_;

    return if ! defined $self;

    my $size = delete $args{'size'} // 'original';

    my ( $success, $error, $image_path ) =
            Side7::Utils::File::create_user_cached_file_directory(
                                                                    user_id      => $self->album->user_id,
                                                                    content_type => 'album_artwork',
                                                                    content_size => $size,
                                                                 );

    if ( ! $success )
    {
        return (
                    Side7::UserContent::get_default_thumbnail_path( type => 'default_album', size => $size ),
                    $error
               );
    }

    my $user_album_artwork_path = $self->album->user->get_album_artwork_directory();

    my $original_image = Image::Magick->new();

    my ( $width, $height, $filesize, $format ) = $original_image->Ping( $user_album_artwork_path . $self->filename );

    if ( ! defined $format )
    {
        $LOGGER->warn( 'Getting album artwork path FAILED while getting properties of input file >' .
                        $user_album_artwork_path . $self->filename . '<' );
        return(
                Side7::UserContent::get_default_thumbnail_path( type => 'default_album', size => $size ),
                'A problem occurred while trying to get Album Artwork file.'
              );
    }

    my $extension = '';
    if ( $format eq 'JPEG' )
    {
        $extension = '.jpg';
    }
    elsif ( $format eq 'GIF' )
    {
        $extension = '.gif';
    }
    elsif ( $format eq 'PNG' )
    {
        $extension = '.png';
    }
    else
    {
        return(
                Side7::UserContent::get_default_thumbnail_path( type => 'default_album', size => $size ),
                'Invalid image file type.'
              );
    }

    my $filename = $self->id . $extension;

    my $album_artwork_path = $image_path . '/' . $filename;

    return ( $album_artwork_path, undef );
}


=head2 create_cached_file()

Creates a copy of the original file in the appropriate cached_file directory if it doesn't exist. Returns success or error.
Returns success if already existent.

Parameters:

=over 4

=item size: The image size. Valid values are 'tiny', 'small', 'medium', 'large', 'original'

=back

    my ( $success, $error ) = $album->artwork->create_cached_file( size => $size );

=cut

sub create_cached_file
{
    my ( $self, %args ) = @_;

    return ( 0, 'Invalid Album Artwork Object' ) if ! defined $self;

    my $size = delete $args{'size'} // undef;
    my $path = delete $args{'path'} // undef;

    if ( ! defined $size )
    {
        return ( 0, 'Invalid album artwork size passed.' );
    }

    if ( ! defined $path || $path eq '' )
    {
        $path = $self->get_cached_album_artwork_path( size => $size );
    }

    my ( $success, $error ) = Side7::Utils::Image::create_cached_album_artwork( image => $self, size => $size, path => $path );

    if ( ! defined $success )
    {
        $LOGGER->warn( "Could not create cached album artwork file for >$self->filename<, ID: >$self->id<: $error" );
        return ( 0, 'Could not create cached album artwork image.' );
    }

    return ( $success, undef );
}


=head2 delete_album_artwork()

Deletes the original and cached files for the Artwork, and then removes the DB record.
Returns a C<arrayref> of a C<boolean> for success, and a C<string> with any error messages.

Parameters: None

    my ( $success, $error ) = $album_artwork->delete_album_artwork();

=cut

sub delete_album_artwork
{
    my ( $self ) = @_;

    if ( ! defined $self || ref( $self ) ne 'Side7::UserContent::AlbumArtwork' )
    {
        return ( 0, 'Invalid Album Artwork object passed in for deletion.' );
    }

    # Find the cached files and delete them.
    foreach my $size ( qw/ tiny small medium large original / )
    {
        my ( $path, $error ) = $self->get_cached_album_artwork_path( size => $size );

        if ( defined $error )
        {
            $LOGGER->warn( 'Error when fetching cached Album Artwork path: ' . $error );
        }
        elsif ( -f $path )
        {
            my $deleted = unlink $path;

            if ( $deleted < 1 )
            {
                $LOGGER->warn( 'Could not delete cached Album Artwork file >' . $path . '<: ' . $! );
            }
        }
    }

    # Find the original file and delete it.
    my $user_album_artwork_path = $self->album->user->get_album_artwork_directory();

    my $filepath = $user_album_artwork_path . '/' . $self->filename;
    if ( ! -f $filepath )
    {
        $LOGGER->error( 'Could not find original Album Artwork file >' . $filepath .
                        '< during deletion for Album ID >' . $self->album->id . '<.' );
    }
    else
    {
        my $deleted = unlink $filepath;
        if ( $deleted < 1 )
        {
            $LOGGER->error( 'Could not delete original Album Artwork file >' . $filepath .
                            '< for Album ID >' . $self->album->id . '<: ' . $! );
            return( 0, 'Could not delete the Album Artwork file for some reason.' );
        }
    }

    # Delete the DB record.
    $self->delete;

    return ( 1, undef );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
