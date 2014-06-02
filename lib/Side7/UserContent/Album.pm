package Side7::UserContent::Album;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

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

=item Side7::UserContent::Word

Many-to-many relationship with Words, mapping through AlbumWordMap.

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
