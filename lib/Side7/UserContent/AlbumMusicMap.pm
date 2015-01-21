package Side7::UserContent::AlbumMusicMap;

use strict;
use warnings;

use Side7::Globals;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use version; our $VERSION = qv( '0.1.2' );

=pod


=head1 NAME

Side7::UserContent::AlbumMusicMap


=head1 DESCRIPTION

This package handles all the mapping of Music to Albums.


=head1 SCHEMA INFORMATION

    Table name: album_music_map

    | album_id      | bigint(20) unsigned | NO   | MUL | NULL    |       |
    | music_id      | bigint(20) unsigned | NO   |     | NULL    |       |
    | created_at    | datetime            | NO   |     | NULL    |       |
    | updated_at    | datetime            | NO   |     | NULL    |       |



=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Album

Many to many relationship, with album_id being the FK through albums

=item Side7::UserContent::Music

Many to many relationship, with music_id being the FK through musics

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'album_music_map',
    columns => [
        album_id   => { type => 'integer',  not_null => 1 },
        music_id   => { type => 'integer',  not_null => 1 },
        created_at => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => [ 'album_id', 'music_id' ],
    relationships =>
    [
        album =>
        {
            type        => 'many to one',
            class       => 'Side7::UserContent::Album',
            key_columns => { album_id => 'id' },
        },
        music =>
        {
            type        => 'many to one',
            class       => 'Side7::UserContent::Music',
            key_columns => { music_id => 'id' },
        },
    ],
);

=head1 METHODS


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
