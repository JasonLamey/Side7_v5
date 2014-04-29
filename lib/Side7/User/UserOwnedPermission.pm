package Side7::User::UserOwnedPermission;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::User::UserOwnedPermission

=head1 DESCRIPTION

This package handles all the access and management for User Owned Permissions (permissions purchased, or revoked).

=head1 SCHEMA INFORMATION

    Table name: user_owned_permissions

    | id                    | bigint(20) unsigned | NO   | PRI | NULL    |       |
    | permission_id         | bigint(10) unsigned | NO   |     | NULL    |       |
    | user_id               | bigint(20) unsigned | NO   |     | NULL    |       |
    | suspended             | tinyint(1)          | YES  |     | 0       |       |
    | reinstate_on          | date                | YES  |     | NULL    |       |
    | revoked               | tinyint(1)          | YES  |     | 0       |       |
    | administrative_reason | text                | YES  |     | NULL    |       |
    | created_at            | datetime            | NO   |     | NULL    |       |
    | updated_at            | datetime            | NO   |     | NULL    |       |


=head1 RELATIONSHIPS

=over

=item Side7::User

Many to one relationship, with user_id being the FK

=item Side7::User::Permission

Many to one relationship, with permission_id being the FK

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'user_owned_permissions',
    columns => [ 
        id                    => { type => 'serial',   not_null => 1 },
        permission_id         => { type => 'integer',  not_null => 1 },
        user_id               => { type => 'integer',  not_null => 1 },
        suspended             => { type => 'boolean',  default => 0 }, 
        reinstate_on          => { type => 'date' }, 
        revoked               => { type => 'boolean',  default => 0 }, 
        administrative_reason => { type => 'text' }, 
        created_at            => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at            => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'permission_id', 'user_id' ], [ 'user_id' ], ],
    relationships =>
    [
        user =>
        {
            type       => 'many to one',
            map_class  => 'Side7::User',
        },
        permission =>
        {
            type       => 'many to one',
            map_class  => 'Side7::User::Permission',
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