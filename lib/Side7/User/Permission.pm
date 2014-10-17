package Side7::User::Permission;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '0.1.2' );

=pod

=head1 NAME

Side7::User::Permission

=head1 DESCRIPTION

This package handles all the access and management for User Permissions.

=head1 SCHEMA INFORMATION

    Table name: permissions

    | id           | bigint(10) unsigned | NO   | PRI | NULL    | auto_increment |
    | name         | varchar(255)        | NO   |     | NULL    |                |
    | description  | text                | YES  |     | NULL    |                |
    | purchaseable | tinyint(1)          | NO   | MUL | 0       |                |
    | created_at   | datetime            | NO   |     | NULL    |                |
    | updated_at   | datetime            | NO   |     | NULL    |                |

=head1 RELATIONSHIPS

=over

=item Side7::User::Role

Many to many relationship, with id being the FK through user_roles_permissions

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'permissions',
    columns => [
        id            => { type => 'serial',   not_null => 1 },
        name          => { type => 'varchar',  length => 255,  not_null => 1 },
        description   => { type => 'text' },
        purchaseable  => { type => 'boolean',  not_null => 1, default => 0 },
        created_at    => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at    => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'name' ], [ 'purchaseable' ], ],
    relationships =>
    [
        user_roles =>
        {
            type       => 'many to many',
            map_class  => 'Side7::User::RolesPermissionsMap',
        },
        user_owned_permissions =>
        {
            type       => 'one to one',
            class      => 'Side7::User::UserOwnedPermission',
            column_map => { id => 'permission_id' },
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
