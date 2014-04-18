package Side7::UserContent::Image::Property;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::UserContent::Image::Property

=head1 DESCRIPTION

This package represents Image properties, image data that is less uniform across Images.

=head1 SCHEMA INFORMATION

    Table name: image_properties
     
    | id         | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | image_id   | bigint(20) unsigned | NO   |     | NULL    |                |
    | name       | varchar(255)        | NO   | MUL | NULL    |                |
    | value      | varchar(255)        | NO   | MUL | NULL    |                |
    | created_at | datetime            | NO   |     | NULL    |                |
    | updated_at | datetime            | NO   |     | NULL    |                |

=head1 RELATIONSHIPS

=over

=item Side7::UserContent::Image

Many to One relationship, FK: image_id

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'image_properties',
    columns => [ 
        id            => { type => 'integer', not_null => 1 },
        image_id      => { type => 'integer', not_null => 1 }, 
        name          => { type => 'varchar', length => 255, not_null => 1 }, 
        value         => { type => 'varchar', length => 255, not_null => 1 }, 
        created_at    => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at    => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'image_id', 'name' ], [ 'image_id' ], [ 'name' ] ],
    foreign_key =>
    [
        image =>
        {
            type       => 'many to one',
            class      => 'Side7::UserContent::Image',
            column_map => { id => 'image_id' },
        },
    ],
);

=head1 METHODS


=head2 method_name()

    my $result = My::Package->method_name();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub method_name
{
}


=head1 FUNCTIONS


=head2 function_name()

    my $result = My::Package::function_name();

TODO: Define what this method does, describing both input and output values and types.

=cut

sub function_name
{
}


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2014

=cut

1;
