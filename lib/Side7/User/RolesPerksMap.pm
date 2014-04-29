package Side7::User::RolesPerksMap;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::User::RolesPerksMap

=head1 DESCRIPTION

This package handles all the mapping of perks to user roles.

=head1 SCHEMA INFORMATION

    Table name: user_roles_permissions_map

    | user_role_id  | int(3) unsigned     | NO   | MUL | NULL    |       |
    | perk_id       | int(3) unsigned     | NO   |     | NULL    |       |
    | created_at    | datetime            | NO   |     | NULL    |       |
    | updated_at    | datetime            | NO   |     | NULL    |       |



=head1 RELATIONSHIPS

=over

=item Side7::User::Role

Many to many relationship, with user_role_id being the FK through user_roles

=item Side7::User::Perk

Many to many relationship, with perk_id being the FK through perks

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'user_roles_perks_map',
    columns => [ 
        user_role_id  => { type => 'integer',  not_null => 1 },
        perk_id       => { type => 'integer',  not_null => 1 }, 
        created_at    => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at    => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    unique_key => [ 'user_role_id', 'perk_id' ],
    relationships =>
    [
        user_role =>
        {
            type        => 'many to one',
            class       => 'Side7::User::Role',
            key_columns => { user_role_id => 'id' },
        },
        perk =>
        {
            type        => 'many to one',
            class       => 'Side7::User::Perk',
            key_columns => { perk_id => 'id' },
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
