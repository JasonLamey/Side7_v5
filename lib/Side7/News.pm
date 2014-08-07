package Side7::News;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

=pod


=head1 NAME

Side7::News


=head1 DESCRIPTION

This package handles the setting and retrieval of site news headlines and articles.


=head1 SCHEMA INFORMATION

    Table name: news

    | id               | bigint(20) unsigned | NO   | PRI | NULL    | auto_increment |
    | title            | varchar(255)        | NO   |     | NULL    |                |
    | blurb            | tinytext            | YES  |     | NULL    |                |
    | body             | text                | YES  |     | NULL    |                |
    | link_to_article  | varchar(255)        | YES  |     | NULL    |                |
    | is_static        | tinyint(1)          | NO   |     | 0       |                |
    | not_static_after | date                | YES  |     | NULL    |                |
    | priority         | tinyint(4)          | NO   |     | 1       |                |
    | user_id          | bigint(20) unsigned | NO   |     | NULL    |                |
    | created_at       | datetime            | NO   |     | NULL    |                |
    | updated_at       | datetime            | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::User

One-to-one relationship with User, using user_id as a FK.

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'news',
    columns => [ 
        id               => { type => 'serial', not_null => 1 },
        title            => { type => 'varchar', length => 255,  not_null => 1 }, 
        blurb            => { type => 'text' }, 
        body             => { type => 'text' }, 
        link_to_article  => { type => 'varchar', length => 255 }, 
        is_static        => { type => 'boolean', not_null => 1, default => 0 }, 
        not_static_after => { type => 'date' }, 
        priority         => { type => 'integer', not_null => 1, default => 1 }, 
        user_id          => { type => 'integer', not_null => 1 }, 
        created_at       => { type => 'datetime', not_null => 1, default => 'now()' }, 
        updated_at       => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
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
