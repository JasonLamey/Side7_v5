package Side7::KudosCoin;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod

=head1 NAME

Side7::KudosCoin

=head1 DESCRIPTION

This package adds facilities for management of the purchase, usage, and tracking
of Side 7 Kudos Coins.

=head1 SCHEMA INFORMATION

    Table name: kudos_coin_ledger
     
    | id          | bigint(20) unsigned | NO   | PRI | NULL    |       |
    | user_id     | bigint(20) unsigned | NO   | MUL | NULL    |       |
    | timestamp   | datetime            | NO   |     | NULL    |       |
    | amount      | int(11)             | NO   |     | NULL    |       |
    | description | text                | NO   |     | NULL    |       |

=head1 RELATIONSHIPS

=over

=item Side7::User

Many to one relationship, with user_id being the FK to users.id

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'kudos_coin_ledger',
    columns => [ 
        id            => { type => 'serial',  not_null => 1 },
        user_id       => { type => 'integer', not_null => 1 }, 
        timestamp     => { type => 'datetime', not_null => 1, default => 'now()' }, 
        amount        => { type => 'integer', not_null => 1 }, 
        description   => { type => 'text',    not_null => 1 }, 
    ],
    pk_columns => 'id',
    unique_key => [ [ 'user_id' ], [ 'timestamp' ], [ 'user_id', 'timestamp' ], ],
    foreign_keys =>
    [
        user =>
        {
            type       => 'many to one',
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
