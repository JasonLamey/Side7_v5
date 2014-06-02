package Side7::UserContent::AlbumImageMap;

use strict;
use warnings;

use Side7::Globals;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod


=head1 NAME

Side7::UserContent::AlbumImageMap


=head1 DESCRIPTION

This package handles all the mapping of Images to Albums.


=head1 SCHEMA INFORMATION

    Table name: album_image_map

    | album_id      | bigint(20) unsigned | NO   | MUL | NULL    |       |
    | image_id      | bigint(20) unsigned | NO   |     | NULL    |       |
    | created_at    | datetime            | NO   |     | NULL    |       |
    | updated_at    | datetime            | NO   |     | NULL    |       |



=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Album

Many to many relationship, with album_id being the FK through albums

=item Side7::UserContent::Image

Many to many relationship, with image_id being the FK through images

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'album_image_map',
    columns => [ 
        album_id   => { type => 'integer',  not_null => 1 },
        image_id   => { type => 'integer',  not_null => 1 }, 
        created_at => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    unique_key => [ [ 'album_id', 'image_id' ], [ 'album_id' ], [ 'image_id' ], ],
    relationships =>
    [
        album =>
        {
            type        => 'many to one',
            class       => 'Side7::UserContent::Album',
            key_columns => { album_id => 'id' },
        },
        image =>
        {
            type        => 'many to one',
            class       => 'Side7::UserContent::Image',
            key_columns => { image_id => 'id' },
        },
    ],
);

=head1 METHODS


=head2 method_name()

TODO: Define what this method does, describing both input and output values and types.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $result = My::Package->method_name();

=cut

sub method_name
{
}


=head1 FUNCTIONS


=head2 function_name()

TODO: Define what this method does, describing both input and output values and types.

Parameters:

=over 4

=item parameter1: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=item parameter2: what is this parameter, and what kind of data is it? What is it for? What is it's default value?

=back

    my $result = My::Package::function_name();

=cut

sub function_name
{
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
