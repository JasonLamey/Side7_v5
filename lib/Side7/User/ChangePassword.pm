package Side7::User::ChangePassword;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

=pod

=head1 NAME

Side7::User::ChangePassword


=head1 DESCRIPTION

This library handles the saving, looking up, and removal of interim password changes.


=head1 SCHEMA INFORMATION

    Table name: user_password_changes
     
    | id                | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | confirmation_code | varchar(60)         | NO   | UNI | NULL    |                |
    | user_id           | bigint(20) unsigned | NO   | MUL | NULL    |                |
    | new_password      | varchar(45)         | NO   |     | NULL    |                |
    | created_at        | datetime            | NO   | MUL | NULL    |                |
    | updated_at        | datetime            | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

One-to-one relationship with Side7::User, using user_id as the FK.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'user_password_changes',
    columns => [ 
        id                => { type => 'serial', not_null => 1 },
        confirmation_code => { type => 'varchar', length => 60,  not_null => 1 }, 
        user_id           => { type => 'integer', not_null => 1 }, 
        new_password      => { type => 'varchar', length => 45,  not_null => 1 }, 
        created_at        => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at        => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ [ 'confirmation_code', 'user_id' ], [ 'user_id' ], [ 'confirmation_code' ], [ 'created_at' ] ],
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
