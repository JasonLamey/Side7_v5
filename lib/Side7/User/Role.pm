package Side7::User::Role;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '0.1.4' );

=pod


=head1 NAME

Side7::User::Role


=head1 DESCRIPTION

This package handles all the access and management for User Roles.


=head1 SCHEMA INFORMATION

    Table name: user_roles

    | id         | int(3) unsigned | NO   | PRI | NULL    | auto_increment |
    | name       | varchar(255)    | NO   |     | NULL    |                |
    | priority   | int(3) unsigned | NO   |     | NULL    |                |
    | created_at | datetime        | NO   |     | NULL    |                |
    | updated_at | datetime        | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::User::Permission

Many to many relationship, with id being the FK through user_roles_permissions_map

=item Side7::User::Perk

Many to many relationship, with id being the FK through user_roles_perks_map

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'user_roles',
    columns => [
        id            => { type => 'serial',   not_null => 1 },
        name          => { type => 'varchar',  length => 255,  not_null => 1 },
        priority      => { type => 'integer',  not_null => 1 },
        created_at    => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at    => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ 'name' ],
    relationships =>
    [
        permissions =>
        {
            type       => 'many to many',
            map_class  => 'Side7::User::RolesPermissionsMap',
        },
        perks =>
        {
            type       => 'many to many',
            map_class  => 'Side7::User::RolesPerksMap',
        },
    ],
);

=head1 METHODS


=head2 has_permission()

Returns a true/false value for whether a role has a particular permission.

Parameters:

=over 4

=item The permission name.

=back

    my $has_permission = Side7::User::Role->has_permission( $permission_name );

=cut

sub has_permission
{
    my ( $self, $permission_name ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'Invalid or undefined Role object passed in.' );
        return 0;
    }

    if ( ! defined $permission_name || $permission_name eq '' )
    {
        $LOGGER->warn( 'Invalid or undefined permission name passed in.' );
        return 0;
    }

    foreach my $permission ( map { $_->name } $self->permissions )
    {
        if ( lc( $permission ) eq lc( $permission_name ) )
        {
            return 1;
        }
    }

    return 0;
}


=head2 has_perk()

Returns a true/false value for whether a role has a particular perk.

Parameters:

=over 4

=item The perk name.

=back

    my $has_perk = Side7::User::Role->has_perk( $permission_name );

=cut

sub has_perk
{
    my ( $self, $perk_name ) = @_;

    if ( ! defined $self )
    {
        $LOGGER->warn( 'Invalid or undefined Role object passed in.' );
        return 0;
    }

    if ( ! defined $perk_name || $perk_name eq '' )
    {
        $LOGGER->warn( 'Invalid or undefined perk name passed in.' );
        return 0;
    }

    foreach my $perk ( map { $_->name } $self->perks )
    {
        if ( lc( $perk ) eq lc( $perk_name ) )
        {
            return 1;
        }
    }

    return 0;
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
