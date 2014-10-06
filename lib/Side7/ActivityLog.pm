package Side7::ActivityLog;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

=pod


=head1 NAME

Side7::ActivityLog


=head1 DESCRIPTION

This package provides functionality into recording and reading activity log entries.


=head1 SCHEMA INFORMATION

    Table name: activity_logs

    | id         | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | user_id    | bigint(20) unsigned | NO   | MUL | NULL    |                |
    | activity   | varchar(255)        | NO   |     | NULL    |                |
    | created_at | datetime            | NO   |     | NULL    |                |
     
=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'activity_logs',
    columns => [ 
        id         => { type => 'serial',   not_null => 1 },
        user_id    => { type => 'integer' },
        activity   => { type => 'varchar',  not_null => 1, length => 255 },
        created_at => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    foreign_keys =>
    [
        user =>
        {
            class             => 'Side7::User',
            key_columns       => { user_id => 'id' },
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
