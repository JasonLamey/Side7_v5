package Side7::FAQCategory;

use strict;
use warnings;

use base 'Side7::DB::Object'; # Only needed if this is a database object.

use version; our $VERSION = qv( '0.1.1' );

=pod


=head1 NAME

Side7::FAQCategory


=head1 DESCRIPTION

This package represents a category entry in the FAQ system.


=head1 SCHEMA INFORMATION

    Table name: faq_categories

    | id         | int(8) unsigned | NO   | PRI | NULL    | auto_increment |
    | name       | varchar(255)    | NO   |     | NULL    |                |
    | priority   | int(3) unsigned | NO   |     | NULL    |                |
    | created_at | datetime        | NO   |     | NULL    |                |
    | updated_at | datetime        | NO   |     | NULL    |                |


=head1 RELATIONSHIPS

=over

=item Side7::FAQEntry

A one-to-many relationship, with faq_category_id being the FK in FAQEntry

=back

=cut

# TODO: Define the appropriate package meta config for the DB Object.

__PACKAGE__->meta->setup
(
    table   => 'faq_categories',
    columns => [
        id         => { type => 'serial', not_null => 1 },
        name       => { type => 'varchar', length => 255,  not_null => 1 },
        priority   => { type => 'integer', not_null => 1 },
        created_at => { type => 'datetime', not_null => 1, default => 'now()' },
        updated_at => { type => 'datetime', not_null => 1, default => 'now()' },
    ],
    pk_columns => 'id',
    unique_key => [ 'name' ],
    relationships =>
    [
        faq_entries =>
        {
            type       => 'one to many',
            class      => 'Side7::FAQEntry',
            column_map => { id => 'faq_category_id' },
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
