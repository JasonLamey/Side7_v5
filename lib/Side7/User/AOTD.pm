package Side7::User::AOTD;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use Side7::Globals;

use version; our $VERSION = qv( '1.0.0' );

=pod


=head1 NAME

Side7::User::AOTD


=head1 DESCRIPTION


This package represents Artist of the Day selections.


=head1 SCHEMA INFORMATION

    Table name: aotds

    | id         | bigint(20) unsigned | NO   | PRI | NOTNULL | auto_increment |
    | user_id    | bigint(20) unsigned | NO   |     | NOTNULL |                |
    | date       | date                | NO   |     | NOTNULL |                |


=head1 RELATIONSHIPS

=over

=item Class::Name

TODO: Define the relationship type, and list the foreign key (FK).

=back

=cut

__PACKAGE__->meta->setup
(
    table   => 'aotds',
    columns => [
        id      => { type => 'serial',  not_null => 1 },
        user_id => { type => 'integer', not_null => 1 },
        date    => { type => 'date',    not_null => 1 },
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


=head1 COPYRIGHT

All code is Copyright (C) Side 7 1992 - 2015

=cut

1;
