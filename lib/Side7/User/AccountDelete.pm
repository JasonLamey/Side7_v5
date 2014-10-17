package Side7::User::AccountDelete;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '0.1.1' );

=pod


=head1 NAME

Side7::User::AccountDelete


=head1 DESCRIPTION

This package holds the temporary requests for setting the account deletion flag. These requests
are held for 48 hours, or until the request is confirmed, whichever comes first.  After 48
hours, the request is automatically deleted.


=head1 SCHEMA INFORMATION

    Table name: user_set_delete_flag_requests

    | id                | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | confirmation_code | varchar(60)         | NO   | UNI | NULL    |                |
    | user_id           | bigint(20) unsigned | NO   | MUL | NULL    |                |
    | created_at        | datetime            | NO   | MUL | NULL    |                |
    | updated_at        | datetime            | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

One to one relationship, using User_id as a foreign key.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'user_set_delete_flag_requests',
    columns => [
        id                => { type => 'serial', not_null => 1 },
        confirmation_code => { type => 'varchar', length => 60,  not_null => 1 },
        user_id           => { type => 'integer', not_null => 1 },
        created_at        => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at        => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'user_id' ], [ 'confirmation_code' ], [ 'created_at' ], [ 'user_id', 'confirmation_code' ] ],
    foreign_keys =>
    [
        user =>
        {
            type       => 'one to one',
            class      => 'Side7::User',
            column_map => { user_id => 'id' },
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
