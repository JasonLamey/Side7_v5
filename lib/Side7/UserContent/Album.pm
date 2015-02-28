package Side7::UserContent::Album;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.
use parent 'Clone';

use Data::Dumper;

use Side7::Globals;

use version; our $VERSION = qv( '0.1.4' );

=pod


=head1 NAME

Side7::UserContent::Album


=head1 DESCRIPTION

Represents User Content Albums, which are used for grouping a User's content
into logical groups.


=head1 SCHEMA INFORMATION

    Table name: albums

    | id         | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
    | user_id    | int(20) unsigned | NO   | UNI | NULL    |                |
    | name       | varchar(255)     | NO   |     | NULL    |                |
    | description| text(16)         | YES  |     | NULL    |                |
    | system     | tinyint(1)       | NO   |     | 0       |                |
    | created_at | datetime         | NO   |     | NULL    |                |
    | updated_at | datetime         | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

Many-to-one relationship with User, using the User ID as a FK.

=item Side7::UserContent::Image

Many-to-many relationship with Images, mapping through AlbumImageMap.

=item Side7::UserContent::Music

Many-to-many relationship with Music, mapping through AlbumMusicMap.

=item Side7::UserContent::Literature

Many-to-many relationship with Literature, mapping through AlbumLiteratureMap.

=item Side7::UserContent::AlbumArtwork

One-to-one relationship with AlbumArtwork.

=back

=cut


# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'albums',
    columns => [
        id          => { type => 'serial',   not_null => 1 },
        user_id     => { type => 'integer',  not_null => 1 },
        name        => { type => 'varchar',  length => 255, not_null => 1 },
        description => { type => 'text',     default => 'null' },
        system      => { type => 'integer',  not_null => 1, default => 0 },
        created_at  => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at  => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ 'user_id', 'name' ],
    foreign_keys =>
    [
        user =>
        {
            type       => 'many to one',
            class      => 'Side7::User',
            column_map => { user_id => 'id' },
        },
    ],
    relationships =>
    [
        artwork =>
        {
            type => 'one to one',
            class => 'Side7::UserContent::AlbumArtwork',
            column_map => { id => 'album_id' },
        },
        images =>
        {
            type      => 'many to many',
            map_class => 'Side7::UserContent::AlbumImageMap',
        },
        music =>
        {
            type      => 'many to many',
            map_class => 'Side7::UserContent::AlbumMusicMap',
        },
    ],
);

=head1 METHODS


=head2 get_content_count()

Returns an integer of the total number of objects associated with the album.

Parameters: None.

    my $count = $album->get_content_count();

=cut

sub get_content_count
{
    my ( $self ) = @_;

    # TODO: THERE HAS TO BE A CLEANER WAY OF DOING THIS
    my $images = $self->images();
    my $image_count = scalar( @$images ) // 0;

    # TODO Fix literature_count once UserContent::Literature is made.
    my $literature_count = 0;

    # TODO Fix music_count once UserContent::Music is made.
    my $music = $self->music();
    my $music_count = scalar( @$music ) // 0;

    return ( $image_count + $literature_count + $music_count );
}


=head2 get_content()

Returns an arrayref of the objects associated with the album, sorted by created_at desc by default.

Parameters:

=over 4

=item sort_by: The field_name by which to sort the array, default is 'created_at'.

=item sort_order: The direction to sort in, either 'asc' or 'desc'.  Default is 'desc'.

=back

    my $content = $album->get_content( sort_by => 'title', sort_order => 'asc' );

=cut

sub get_content
{
    my ( $self, %args ) = @_;

    my $sort_by    = delete $args{'sort_by'}    // 'created_at';
    my $sort_order = delete $args{'sort_order'} // 'desc';

    # TODO: THERE HAS TO BE A CLEANER WAY OF DOING THIS
    my $images = $self->images();

    # TODO Fix literature once UserContent::Literature is made.
    my $literature = [];

    # TODO DITTO
    my $music = $self->music();

    my @content = ();
    if ( lc($sort_order) eq 'asc' )
    {
        @content = sort {
                            if ( $a->$sort_by() =~ m/^\d+$/ && $b->$sort_by() =~ m/^\d+$/ )
                            {
                                return $a->$sort_by() <=> $b->$sort_by()
                            }
                            else
                            {
                                return lc( $a->$sort_by() ) cmp lc( $b->$sort_by() )
                            }
                        }
                        ( @$images, @$literature, @$music );
    }
    else
    {
        @content = sort {
                            if ( $a->$sort_by() =~ m/^\d+$/ && $b->$sort_by() =~ m/^\d+$/ )
                            {
                                return $b->$sort_by() <=> $a->$sort_by()
                            }
                            else
                            {
                                return lc( $b->$sort_by() ) cmp lc( $a->$sort_by() )
                            }
                        }
                        ( @$images, @$literature, @$music );
    }

    return \@content;
}


=head2 get_artwork_uri( size => $size )

Returns a C<string> containing the URI of the artwork associated with the Album.

Parameters:

=over 4

=item size: A C<string> indicating the size of the image to generate. Takes 'tiny', 'small', 'medium', 'large', 'original'. Optional; defaults to 'small'.

=back

    my $artwork = $album->get_artwork_uri( size => $size );

=cut

sub get_artwork_uri
{
    # Since we call this from templates, which passes named params as a hash ref, let's ensure we're getting a reference vs a hash.
    my $self = undef;
    my %args = ();
    if ( ref( $_[-1] ) eq 'HASH' )
    {
        $self = $_[0];
        %args = %{ $_[-1] };
    }
    else
    {
        ( $self, %args ) = @_;
    }

    my $size  = delete $args{'size'}  // 'small';

    if ( ! defined $self || ref( $self ) ne 'Side7::UserContent::Album' )
    {
        $LOGGER->warn( 'Invalid Album object passed in when getting Artwork.' );
        return Side7::UserContent::get_default_thumbnail_path( type => 'default_album', size => $size );
    }

    my $artwork_uri = '';
    my $error       = '';

    if ( defined $self->artwork )
    {
        ( $artwork_uri, $error ) = $self->artwork->get_cached_album_artwork_path( size => $size );

        if ( defined $error && $error ne '' )
        {
            $LOGGER->warn( $error );
            $artwork_uri = Side7::UserContent::get_default_thumbnail_path( type => 'default_album', size => $size );
        }
        else
        {
            if ( ! -f $artwork_uri )
            {
                my ( $success, $error ) = Side7::Utils::Image::create_cached_album_artwork( image => $self->artwork, size => $size );
                if ( defined $error && $error ne '' )
                {
                    $LOGGER->warn( $error );
                    $artwork_uri = Side7::UserContent::get_default_thumbnail_path( type => 'default_album', size => $size );
                }
            }
        }
    }
    else
    {
        $artwork_uri = Side7::UserContent::get_default_thumbnail_path( type => 'default_album', size => $size );
    }

    $artwork_uri =~ s/^\/data//;
    return $artwork_uri;
}


=head2 delete_album_artwork()

Calls the deletion of the associated Album Artwork object, including the original and cached files.
Receives an array of a success C<boolean> and an error C<string>.

Parameters: None

    my ( $success, $error ) = $album->delete_album_artwork;

=cut

sub delete_album_artwork
{
    my ( $self ) = @_;

    if ( ! defined $self || ref( $self ) ne 'Side7::UserContent::Album' )
    {
        $LOGGER->error( 'Invalid Album object referenced.' );
        return ( 0, 'Invalid Album object referenced when attempting to delete Artwork.' );
    }

    if ( ! defined $self->artwork )
    {
        $LOGGER->error( 'Album has no associated Artwork when attempting to delete Artwork.' );
        return ( 0, 'Album has no associated Artwork when attemtping to delete Artwork.' );
    }

    my ( $success, $error ) = $self->artwork->delete_album_artwork();

    return( $success, $error );
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
