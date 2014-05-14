package Side7::AuditLog;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod


=head1 NAME

Side7::AuditLog


=head1 DESCRIPTION

This package provides functionality into recording and reading audit log entries.


=head1 SCHEMA INFORMATION

    Table name: audit_logs

    | id             | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | timestamp      | datetime            | NO   | MUL | NULL    |                |
    | title          | varchar(255)        | NO   | MUL | NULL    |                |
    | affected_id    | bigint(20) unsigned | YES  |     | NULL    |                |
    | user_id        | bigint(20) unsigned | YES  |     | NULL    |                |
    | description    | text                | NO   |     | NULL    |                |
    | original_value | text                | YES  |     | NULL    |                |
    | new_value      | text                | YES  |     | NULL    |                |
    | ip_address     | varchar(255)        | YES  |     | NULL    |                |
     
=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'audit_logs',
    columns => [ 
        id             => { type => 'serial',   not_null => 1 },
        timestamp      => { type => 'datetime', not_null => 1, default => 'now()' },
        title          => { type => 'varchar',  length => 255, not_null => 1 },
        affected_id    => { type => 'integer' },
        user_id        => { type => 'integer' },
        description    => { type => 'text',     not_null => 1 },
        original_value => { type => 'text' },
        new_value      => { type => 'text' },
        ip_address     => { type => 'varchar',  length => 255 },
    ],
    pk_columns => 'id',
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
