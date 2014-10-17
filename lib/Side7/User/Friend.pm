package Side7::User::Friend;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '0.1.1' );

=pod


=head1 NAME

Side7::User::Friend


=head1 DESCRIPTION

This package manages friend relationships between Users.


=head1 SCHEMA INFORMATION

    Table name: friends

    | id         | int(20) unsigned                              | NO   | PRI | NULL    | auto_increment |
    | user_id    | int(8) unsigned                               | NO   | MUL | NULL    |                |
    | friend_id  | int(8) unsigned                               | NO   | MUL | NULL    |                |
    | status     | enum('Pending','Approved','Denied','Ignored') | NO   | MUL | Pending |                |
    | created_at | datetime                                      | NO   |     | NULL    |                |
    | updated_at | datetime                                      | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

One-to-many relationship via user_id as the FK

=item Side7::User

Many-to-one relationship via friend_id as the FK (aliasing user_id)

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'friends',
    columns => [
        id            => { type => 'serial', not_null => 1 },
        user_id       => { type => 'integer', not_null => 1 },
        friend_id     => { type => 'integer', not_null => 1 },
        status        => {
                            type     => 'enum',
                            values   => [ qw/ Pending Approved Denied Ignored / ],
                            not_null => 1,
                            default  => 'Pending',
                         },
        created_at    => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at    => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'user_id', 'friend_id' ], [ 'user_id' ], [ 'friend_id' ],  ],
    foreign_keys =>
    [
        user =>
        {
            class             => 'Side7::User',
            key_columns       => { user_id => 'id' },
            relationship_type => 'many to one',
        },
        friend =>
        {
            class             => 'Side7::User',
            key_columns       => { friend_id => 'id' },
            relationship_type => 'many to one',
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
