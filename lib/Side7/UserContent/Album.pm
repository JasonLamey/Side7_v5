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


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
